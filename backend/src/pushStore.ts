import { mkdir, readFile, unlink, writeFile } from "node:fs/promises";
import path from "node:path";

export interface DeviceRegistration {
  deviceToken: string;
  environment: "sandbox" | "production";
  updatedAt: number;
}

const ATHLETE_ID_PATTERN = /^\d{1,20}$/;

/// One JSON file per athlete holding their current APNs device token —
/// same file-per-key pattern as the webhook status cache and compare
/// groups. Registering (`PUT /push/:athleteID/token`) is what turns on
/// workout-review push for that athlete; there's no separate on/off flag,
/// just whether a token is on file.
export function createPushStore(dataDir: string) {
  const fileFor = (athleteID: string) => path.join(dataDir, `${athleteID}.json`);

  return {
    isValidAthleteID: (athleteID: string) => ATHLETE_ID_PATTERN.test(athleteID),

    async get(athleteID: string): Promise<DeviceRegistration | null> {
      try {
        const raw = await readFile(fileFor(athleteID), "utf8");
        return JSON.parse(raw) as DeviceRegistration;
      } catch {
        return null;
      }
    },

    async set(athleteID: string, registration: DeviceRegistration): Promise<void> {
      await mkdir(dataDir, { recursive: true });
      await writeFile(fileFor(athleteID), JSON.stringify(registration), "utf8");
    },

    async delete(athleteID: string): Promise<void> {
      try {
        await unlink(fileFor(athleteID));
      } catch {
        // Already gone — fine.
      }
    },
  };
}
