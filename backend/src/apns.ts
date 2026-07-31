import crypto from "node:crypto";
import http2 from "node:http2";

export interface APNsConfig {
  teamID: string;
  keyID: string;
  privateKey: string; // PEM contents of the .p8 auth key
  bundleID: string; // used as the APNs "topic"
}

export interface APNsClient {
  sendSilentPush(
    deviceToken: string,
    environment: "sandbox" | "production",
    payload: Record<string, unknown>,
  ): Promise<void>;
}

/// Hand-rolled token-based (.p8) APNs client over Node's built-in HTTP/2
/// support — no APNs library dependency, consistent with the rest of this
/// backend (see ics.ts for the same "roll it yourself" approach). Reuses
/// one signed provider JWT across requests, regenerating only once it's
/// more than ~50 minutes old, per Apple's guidance against minting a
/// fresh token for every push.
export function createAPNsClient(config: APNsConfig): APNsClient {
  let cachedToken: { value: string; issuedAt: number } | null = null;

  function providerToken(): string {
    const now = Math.floor(Date.now() / 1000);
    if (cachedToken && now - cachedToken.issuedAt < 50 * 60) {
      return cachedToken.value;
    }

    const encode = (obj: unknown) => Buffer.from(JSON.stringify(obj)).toString("base64url");
    const header = { alg: "ES256", kid: config.keyID };
    const payload = { iss: config.teamID, iat: now };
    const signingInput = `${encode(header)}.${encode(payload)}`;
    // ES256 JWS wants the raw 64-byte R||S signature, not crypto's default
    // ASN.1 DER encoding — `dsaEncoding: "ieee-p1363"` is what asks for that.
    const signature = crypto.sign("sha256", Buffer.from(signingInput), {
      key: config.privateKey,
      dsaEncoding: "ieee-p1363",
    });

    const token = `${signingInput}.${signature.toString("base64url")}`;
    cachedToken = { value: token, issuedAt: now };
    return token;
  }

  function sendSilentPush(
    deviceToken: string,
    environment: "sandbox" | "production",
    payload: Record<string, unknown>,
  ): Promise<void> {
    const host = environment === "sandbox" ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
    // No alert/sound/badge — this only wakes the app in the background to
    // generate a review from on-device Health data the backend never
    // sees. The visible notification is a *local* one the app posts
    // itself once that finishes (see WorkoutReviewGenerator on the iOS
    // side).
    const body = JSON.stringify({ aps: { "content-available": 1 }, ...payload });

    return new Promise((resolve, reject) => {
      const client = http2.connect(host);
      client.on("error", reject);

      const req = client.request({
        ":method": "POST",
        ":path": `/3/device/${deviceToken}`,
        authorization: `bearer ${providerToken()}`,
        "apns-topic": config.bundleID,
        "apns-push-type": "background",
        "apns-priority": "5", // background pushes must use 5, not 10
        "content-type": "application/json",
      });

      let status = 0;
      let responseBody = "";
      req.setEncoding("utf8");
      req.on("response", (headers) => {
        status = Number(headers[":status"] ?? 0);
      });
      req.on("data", (chunk) => {
        responseBody += chunk;
      });
      req.on("end", () => {
        client.close();
        if (status === 200) {
          resolve();
        } else {
          reject(new Error(`APNs responded ${status}: ${responseBody}`));
        }
      });
      req.on("error", (err) => {
        client.close();
        reject(err);
      });

      req.end(body);
    });
  }

  return { sendSilentPush };
}
