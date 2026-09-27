// k6 load script written by load-test. Adapt every TODO to the service:
// routes, auth and bodies come from the code, rates and SLOs from the HLD.
//
//   STAGE=smoke BASE_URL=http://localhost:8080 API_KEYS=k1 \
//     k6 run --summary-export=tests/load/results/<flow>-smoke.json tests/load/<flow>.js
//
// Never point BASE_URL at production. The Makefile and the CI job refuse a
// production host; this script checks it again below.
import http from "k6/http";
import { check } from "k6";
import { Counter, Rate, Trend } from "k6/metrics";

const baseUrl = __ENV.BASE_URL;
const stage = __ENV.STAGE || "smoke";
const runId = __ENV.RUN_ID || `${stage}-${Date.now()}`;
// Flow iterations a second at the peak (HLD section 7, arithmetic in docs/testing/load-tests.md).
const peak = Number(__ENV.PEAK_RATE || 1); // TODO: the computed peak, not a default
const normal = Number(__ENV.NORMAL_RATE || 1); // TODO: busy-hour rate, used by soak
const ramp = __ENV.RAMP || "30s"; // how fast the real peak arrives; a step event ramps in seconds
const hold = __ENV.HOLD || "10m"; // how long the real peak lasts
const soakFor = __ENV.SOAK_DURATION || "8h";
const requestsPerIteration = 3; // TODO: requests one flow iteration sends
const perKeyLimit = Number(__ENV.PER_KEY_LIMIT || 0); // requests a second per key, 0 = no limit
// Every production host, from CI, deploy values and docs; a substring check misses most of them.
const productionHosts = (__ENV.PRODUCTION_HOSTS || "TODO.production.host").split(",").map((h) => h.trim().toLowerCase());

if (!baseUrl) throw new Error("BASE_URL is required");
if (productionHosts.includes(new URL(baseUrl).hostname.toLowerCase())) throw new Error("refused: production URL");

// Auth as the service does it (TODO): an API key pool, a token, or nothing.
const keys = (__ENV.API_KEYS || "").split(",").filter(Boolean);
if (keys.length === 0) throw new Error("API_KEYS is required");

const plans = {
  smoke: { rate: 1, stages: [{ duration: "1m", target: 1 }] },
  load: { rate: peak, stages: [{ duration: ramp, target: peak }, { duration: hold, target: peak }, { duration: "1m", target: 0 }] },
  stress: { rate: peak * 2, stages: [{ duration: ramp, target: peak }, { duration: hold, target: peak }, { duration: "5m", target: peak * 2 }, { duration: "1m", target: 0 }] },
  soak: { rate: normal, stages: [{ duration: "2m", target: normal }, { duration: soakFor, target: normal }] },
};
const plan = plans[stage];
if (!plan) throw new Error(`unknown STAGE ${stage}; use smoke, load, stress or soak`);

// 80% of the per-key limit: a bucket driven at exactly its rate rejects on jitter.
if (perKeyLimit > 0) {
  const needed = Math.ceil((plan.rate * requestsPerIteration) / (perKeyLimit * 0.8));
  if (keys.length < needed) throw new Error(`STAGE ${stage} needs ${needed} keys at ${perKeyLimit} rps each; API_KEYS has ${keys.length}`);
}

const serverErrors = new Rate("server_errors"); // what the SLO counts: 5xx and timeouts
const rateLimited = new Counter("rate_limited"); // 429: a test fault, not a service error
const clientErrors = new Counter("client_errors"); // other 4xx: a wrong body or route
const heapBytes = new Trend("heap_bytes"); // soak memory samples

const scenarios = {
  main: {
    executor: "ramping-arrival-rate",
    startRate: stage === "soak" ? normal : 1,
    timeUnit: "1s",
    // Little's law: rate x p99 seconds x 2. TODO: the p99 the SLO allows.
    preAllocatedVUs: Math.max(5, Math.ceil(plan.rate * 1 * 2)),
    maxVUs: Math.max(20, Math.ceil(plan.rate * 10)),
    stages: plan.stages,
  },
};
// Soak: sample memory on a clock, independent of the load (TODO: the runtime's own endpoint).
if (__ENV.MEMORY_URL) {
  scenarios.memory = { executor: "constant-arrival-rate", rate: 1, timeUnit: __ENV.SAMPLE_EVERY || "30s", duration: stage === "soak" ? soakFor : "10m", preAllocatedVUs: 1, exec: "sampleMemory" };
}

export const options = {
  scenarios,
  thresholds: {
    // TODO: one line per route, from HLD section 9.
    "http_req_waiting{name:GET /TODO}": ["p(95)<500"],
    server_errors: ["rate<0.01"],
    // Worthless-run guards only. Never abort on latency in a soak.
    rate_limited: [{ threshold: "count<10", abortOnFail: true, delayAbortEval: "30s" }],
    client_errors: [{ threshold: "count<10", abortOnFail: true, delayAbortEval: "30s" }],
    dropped_iterations: ["count<10"], // TODO: 1% of the planned iterations
  },
  tags: { run_id: runId, stage },
};

function record(res) {
  serverErrors.add(res.status === 0 || res.status >= 500);
  if (res.status === 429) rateLimited.add(1);
  else if (res.status >= 400 && res.status < 500) clientErrors.add(1);
}

export default function () {
  const key = keys[(__VU + __ITER) % keys.length];
  const headers = { "X-Api-Key": key, "Content-Type": "application/json", "x-load-test": runId }; // TODO: real auth header
  // TODO: the flow as the code serves it, one request per step, tagged by route.
  const res = http.get(`${baseUrl}/TODO`, { headers, tags: { name: "GET /TODO" } });
  record(res);
  check(res, { "GET /TODO 200": (r) => r.status === 200 });
}

export function sampleMemory() {
  const res = http.get(__ENV.MEMORY_URL, { tags: { name: "memory sample" } });
  if (res.status !== 200) {
    console.log(JSON.stringify({ memsample: true, t: Date.now(), up: false, status: res.status }));
    return;
  }
  const m = res.json("memstats") || {};
  heapBytes.add(m.HeapInuse || 0);
  // NumGC and TotalAlloc only grow; a drop between samples is a restart.
  console.log(JSON.stringify({ memsample: true, t: Date.now(), up: true, heapInuse: m.HeapInuse, sys: m.Sys, totalAlloc: m.TotalAlloc, numGC: m.NumGC }));
}

// No teardown by default: delete only through a route the service really has.
// Otherwise the data carries the run id and docs/testing/load-tests.md says how to clean it.
