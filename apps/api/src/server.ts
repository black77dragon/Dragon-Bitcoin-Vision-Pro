import { createServer as createHttpServer, type ServerResponse } from "node:http";
import { URL, pathToFileURL } from "node:url";
import { readConfig, type AppConfig } from "./config.ts";
import type { DataMode, ReplayBucket, ReplayRange } from "./contracts.ts";
import { buildCurrentBriefing } from "./briefing.ts";
import { buildMethodologyResponse } from "./methodology.ts";
import { buildReplayTimeline } from "./replay.ts";
import { createReplayFrameStore, type ReplayFrameStore } from "./replay-store.ts";

type FetchFn = typeof fetch;

export function createServer(input: {
  config?: AppConfig;
  fetchImpl?: FetchFn;
  replayStore?: ReplayFrameStore;
} = {}) {
  const config = input.config ?? readConfig();
  const fetchImpl = input.fetchImpl ?? fetch;
  const replayStore = input.replayStore ?? createReplayFrameStore(config);

  return createHttpServer(async (request, response) => {
    const url = new URL(request.url ?? "/", `http://${request.headers.host ?? "localhost"}`);

    try {
      const result = await handleApiRequest({ url, config, fetchImpl, replayStore });
      writeJson(response, result.statusCode, result.body);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      writeJson(response, 500, {
        error: "internal_error",
        message
      });
    }
  });
}

export async function startServer(input: {
  config?: AppConfig;
  fetchImpl?: FetchFn;
  replayStore?: ReplayFrameStore;
} = {}) {
  const config = input.config ?? readConfig();
  const server = createServer({
    config,
    fetchImpl: input.fetchImpl,
    replayStore: input.replayStore
  });

  await new Promise<void>((resolve) => {
    server.listen(config.port, () => resolve());
  });

  return server;
}

export async function handleApiRequest(input: {
  url: URL;
  config: AppConfig;
  fetchImpl?: FetchFn;
  replayStore?: ReplayFrameStore;
}): Promise<{ statusCode: number; body: unknown }> {
  const fetchImpl = input.fetchImpl ?? fetch;
  const replayStore = input.replayStore ?? createReplayFrameStore(input.config);

  if (input.url.pathname === "/healthz") {
    return {
      statusCode: 200,
      body: { status: "ok" }
    };
  }

  if (input.url.pathname === "/v1/briefing/current") {
    return {
      statusCode: 200,
      body: await buildCurrentBriefing({
        mode: parseMode(input.url.searchParams.get("mode"), input.config.defaultMode),
        config: input.config,
        fetchImpl
      })
    };
  }

  if (input.url.pathname === "/v1/mempool/replay") {
    return {
      statusCode: 200,
      body: await buildReplayTimeline({
        range: parseRange(input.url.searchParams.get("range")),
        bucket: parseBucket(input.url.searchParams.get("bucket")),
        mode: parseMode(input.url.searchParams.get("mode"), input.config.defaultMode),
        config: input.config,
        fetchImpl,
        replayStore
      })
    };
  }

  if (input.url.pathname === "/v1/methodology") {
    return {
      statusCode: 200,
      body: buildMethodologyResponse()
    };
  }

  return {
    statusCode: 404,
    body: {
      error: "not_found",
      message: `No route defined for ${input.url.pathname}`
    }
  };
}

function writeJson(response: ServerResponse, statusCode: number, payload: unknown) {
  response.setHeader("Content-Type", "application/json; charset=utf-8");
  response.setHeader("Access-Control-Allow-Origin", "*");
  response.statusCode = statusCode;
  response.end(JSON.stringify(payload, null, 2));
}

function parseMode(value: string | null, fallback: DataMode): DataMode {
  if (value === "demo" || value === "live" || value === "auto") {
    return value;
  }

  return fallback;
}

function parseRange(value: string | null): ReplayRange {
  if (value === "6h" || value === "24h") {
    return value;
  }

  return "6h";
}

function parseBucket(value: string | null): ReplayBucket {
  if (value === "1m" || value === "5m") {
    return value;
  }

  return "1m";
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const config = readConfig();
  const server = await startServer({ config });
  process.on("SIGINT", () => {
    server.close(() => process.exit(0));
  });
  console.log(`Bitcoin Regime Navigator API listening on http://localhost:${config.port}`);
}
