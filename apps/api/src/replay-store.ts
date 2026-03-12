import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import type { AppConfig } from "./config.ts";
import type { ReplayFrame } from "./contracts.ts";

export interface ReplayFrameStore {
  append(frame: ReplayFrame): Promise<void>;
  list(): Promise<ReplayFrame[]>;
}

const MAX_STORED_FRAMES = 24 * 60 * 3;

export function createReplayFrameStore(config: AppConfig): ReplayFrameStore {
  return new FileReplayFrameStore(resolve(config.replayStorePath));
}

class FileReplayFrameStore implements ReplayFrameStore {
  constructor(private readonly filePath: string) {}

  async append(frame: ReplayFrame): Promise<void> {
    const frames = await this.list();
    const merged = dedupeFrames([...frames, frame]).slice(-MAX_STORED_FRAMES);
    await mkdir(dirname(this.filePath), { recursive: true });
    await writeFile(this.filePath, JSON.stringify(merged, null, 2), "utf8");
  }

  async list(): Promise<ReplayFrame[]> {
    try {
      const payload = await readFile(this.filePath, "utf8");
      const parsed = JSON.parse(payload) as ReplayFrame[];
      if (!Array.isArray(parsed)) {
        return [];
      }

      return dedupeFrames(parsed);
    } catch (error) {
      if (isMissingFile(error)) {
        return [];
      }

      throw error;
    }
  }
}

function dedupeFrames(frames: ReplayFrame[]): ReplayFrame[] {
  const map = new Map<string, ReplayFrame>();

  for (const frame of frames) {
    if (typeof frame?.timestamp !== "string") {
      continue;
    }

    map.set(frame.timestamp, frame);
  }

  return Array.from(map.values()).sort((left, right) => left.timestamp.localeCompare(right.timestamp));
}

function isMissingFile(error: unknown): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error && (error as NodeJS.ErrnoException).code === "ENOENT";
}
