import { Router } from "express";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";

interface MemberStats {
  relativeEffort: number;
  hours: number;
  miles: number;
}

interface GroupMember extends MemberStats {
  athleteID: number;
  displayName: string;
  updatedAt: number;
}

interface Group {
  code: string;
  createdAt: number;
  members: Record<string, GroupMember>;
}

// Excludes 0/O and 1/I so a code read aloud or handwritten isn't ambiguous.
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_PATTERN = /^[A-Z0-9]{6}$/;

function generateCode(): string {
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += CODE_ALPHABET[crypto.randomInt(CODE_ALPHABET.length)];
  }
  return code;
}

function isMemberStats(value: unknown): value is MemberStats {
  if (typeof value !== "object" || value === null) return false;
  const v = value as Record<string, unknown>;
  return (
    typeof v.relativeEffort === "number" &&
    typeof v.hours === "number" &&
    typeof v.miles === "number"
  );
}

/// Small invite-code-based groups so athletes can compare relative effort,
/// hours, and mileage with specific people who also use this app —
/// deliberately not a public leaderboard. There's no login: whoever holds
/// the 6-character code can join or read the group, the same trust model
/// as the `.ics` feed token elsewhere in this backend. This is
/// appropriate for a small group of people who know each other; it is
/// NOT a substitute for real access control if this ever needs to
/// support strangers.
export function createGroupsRouter(dataDir: string): Router {
  const router = Router();
  const fileFor = (code: string) => path.join(dataDir, `${code}.json`);

  async function readGroup(code: string): Promise<Group | null> {
    try {
      const raw = await readFile(fileFor(code), "utf8");
      return JSON.parse(raw) as Group;
    } catch {
      return null;
    }
  }

  async function writeGroup(group: Group): Promise<void> {
    await mkdir(dataDir, { recursive: true });
    await writeFile(fileFor(group.code), JSON.stringify(group), "utf8");
  }

  router.post("/", async (req, res) => {
    const { athleteID, displayName, stats } = req.body ?? {};
    if (
      typeof athleteID !== "number" ||
      typeof displayName !== "string" ||
      !displayName.trim() ||
      !isMemberStats(stats)
    ) {
      res.status(400).json({ error: "Body must be { athleteID, displayName, stats }" });
      return;
    }

    let code = generateCode();
    for (let attempts = 0; attempts < 10 && (await readGroup(code)); attempts++) {
      code = generateCode();
    }

    const group: Group = {
      code,
      createdAt: Date.now(),
      members: {
        [String(athleteID)]: {
          athleteID,
          displayName: displayName.trim(),
          updatedAt: Date.now(),
          ...stats,
        },
      },
    };

    await writeGroup(group);
    res.status(201).json(group);
  });

  router.get("/:code", async (req, res) => {
    const code = req.params.code.toUpperCase();
    if (!CODE_PATTERN.test(code)) {
      res.status(400).json({ error: "Invalid code" });
      return;
    }

    const group = await readGroup(code);
    if (!group) {
      res.status(404).json({ error: "Group not found" });
      return;
    }
    res.json(group);
  });

  router.put("/:code/members/:athleteID", async (req, res) => {
    const code = req.params.code.toUpperCase();
    const athleteID = Number(req.params.athleteID);
    if (!CODE_PATTERN.test(code) || !Number.isFinite(athleteID)) {
      res.status(400).json({ error: "Invalid code or athlete ID" });
      return;
    }

    const { displayName, stats } = req.body ?? {};
    if (typeof displayName !== "string" || !displayName.trim() || !isMemberStats(stats)) {
      res.status(400).json({ error: "Body must be { displayName, stats }" });
      return;
    }

    // Upsert within an existing group — this doubles as both "join" and
    // "push my latest stats". Deliberately 404s rather than creating the
    // group on a miss, so a mistyped code fails loudly instead of quietly
    // spinning up an orphan group under the typo.
    const group = await readGroup(code);
    if (!group) {
      res.status(404).json({ error: "Group not found" });
      return;
    }

    group.members[String(athleteID)] = {
      athleteID,
      displayName: displayName.trim(),
      updatedAt: Date.now(),
      ...stats,
    };
    await writeGroup(group);
    res.json(group);
  });

  router.delete("/:code/members/:athleteID", async (req, res) => {
    const code = req.params.code.toUpperCase();
    if (!CODE_PATTERN.test(code)) {
      res.status(400).json({ error: "Invalid code" });
      return;
    }

    const group = await readGroup(code);
    if (!group) {
      res.status(404).json({ error: "Group not found" });
      return;
    }

    delete group.members[req.params.athleteID];
    await writeGroup(group);
    res.json(group);
  });

  return router;
}
