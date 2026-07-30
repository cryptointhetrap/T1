const STRAVA_TOKEN_URL = "https://www.strava.com/oauth/token";

export interface StravaTokenResponse {
  token_type: string;
  expires_at: number;
  expires_in: number;
  refresh_token: string;
  access_token: string;
  athlete?: unknown;
}

export class StravaApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
  ) {
    super(message);
    this.name = "StravaApiError";
  }
}

async function postToStrava(body: Record<string, string>): Promise<StravaTokenResponse> {
  const response = await fetch(STRAVA_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(body),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new StravaApiError(`Strava token request failed: ${detail}`, response.status);
  }

  return (await response.json()) as StravaTokenResponse;
}

export function exchangeAuthorizationCode(
  clientId: string,
  clientSecret: string,
  code: string,
): Promise<StravaTokenResponse> {
  return postToStrava({
    client_id: clientId,
    client_secret: clientSecret,
    code,
    grant_type: "authorization_code",
  });
}

export function refreshAccessToken(
  clientId: string,
  clientSecret: string,
  refreshToken: string,
): Promise<StravaTokenResponse> {
  return postToStrava({
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: refreshToken,
    grant_type: "refresh_token",
  });
}
