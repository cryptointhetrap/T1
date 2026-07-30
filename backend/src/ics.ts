export interface FeedWorkout {
  id: string;
  date: string; // ISO 8601, UTC
  sport: string;
  title: string;
  notes: string;
}

/// Escapes text per RFC 5545 §3.3.11 (comma, semicolon, backslash, newline).
function escapeText(value: string): string {
  return value
    .replace(/\\/g, "\\\\")
    .replace(/,/g, "\\,")
    .replace(/;/g, "\\;")
    .replace(/\r?\n/g, "\\n");
}

function toICSDateTime(iso: string): string | null {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString().replace(/[-:]/g, "").split(".")[0] + "Z";
}

/// Builds a minimal RFC 5545 calendar: one VEVENT per scheduled workout, as
/// a timed event in UTC. Called fresh on every feed request rather than
/// cached, since the feed is small and this keeps it always current.
export function generateICS(workouts: FeedWorkout[]): string {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//TrainingMonitor//Scheduled Workouts//EN",
    "CALSCALE:GREGORIAN",
    "X-WR-CALNAME:TrainingMonitor",
  ];

  const stamp = new Date().toISOString().replace(/[-:]/g, "").split(".")[0] + "Z";

  for (const workout of workouts) {
    const start = toICSDateTime(workout.date);
    if (!start) continue;

    lines.push(
      "BEGIN:VEVENT",
      `UID:${workout.id}@trainingmonitor.app`,
      `DTSTAMP:${stamp}`,
      `DTSTART:${start}`,
      `SUMMARY:${escapeText(`${workout.sport}: ${workout.title}`)}`,
    );
    if (workout.notes) {
      lines.push(`DESCRIPTION:${escapeText(workout.notes)}`);
    }
    lines.push("END:VEVENT");
  }

  lines.push("END:VCALENDAR");
  return lines.join("\r\n");
}
