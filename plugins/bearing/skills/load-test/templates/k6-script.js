// k6 load script written by load-test. Stages are picked with STAGE:
//   STAGE=smoke BASE_URL=http://localhost:8080 k6 run tests/load/<flow>.js
// Never point BASE_URL at production. The Makefile and the CI job refuse a
// production host; this script checks it again below.
import http from "k6/http";
import { check } from "k6";
import { SharedArray } from "k6/data";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.1.0/index.js";

const baseUrl = __ENV.BASE_URL;
const stage = __ENV.STAGE || "smoke";
const runId = __ENV.RUN_ID || `${stage}-${Date.now()}`;
const peak = Number(__ENV.PEAK_RPS || 50); // requests per second, HLD section 7
const productionHost = __ENV.PRODUCTION_HOST || "__REPO_SLUG__.example.com";

if (!baseUrl) throw new Error("BASE_URL is required");
if (new URL(baseUrl).hostname === productionHost) throw new Error("refused: production URL");

// Test data built with the repository's builders, one row per user.
const users = new SharedArray("users", () => JSON.parse(open("./data/users.json")));

const stages = {
  smoke: [{ duration: "1m", target: 1 }],
  load: [{ duration: "1m", target: peak }, { duration: "5m", target: peak }, { duration: "1m", target: 0 }],
  stress: [{ duration: "2m", target: peak }, { duration: "3m", target: peak * 2 }, { duration: "1m", target: 0 }],
  soak: [{ duration: "2m", target: peak }, { duration: "30m", target: peak }, { duration: "1m", target: 0 }],
};
if (!stages[stage]) throw new Error(`unknown STAGE ${stage}; use smoke, load, stress or soak`);

export const options = {
  scenarios: {
    main: {
      executor: "ramping-arrival-rate",
      startRate: 1,
      timeUnit: "1s",
      preAllocatedVUs: 20,
      maxVUs: peak * 4,
      stages: stages[stage],
    },
  },
  // Thresholds come from the HLD SLOs. abortOnFail stops the run and fails the job.
  thresholds: {
    http_req_failed: [{ threshold: "rate<0.01", abortOnFail: true }],
    http_req_waiting: [{ threshold: "p(95)<500", abortOnFail: true }],
    checks: ["rate>0.99"],
  },
  tags: { run_id: runId, stage },
};

export function setup() {
  // Log in once; the token reaches every VU through the returned object.
  const res = http.post(`${baseUrl}/auth/login`, JSON.stringify(users[0]), {
    headers: { "Content-Type": "application/json", "x-load-test": runId },
  });
  check(res, { "login ok": (r) => r.status === 200 });
  return { token: res.json("token") };
}

export default function (data) {
  const headers = { Authorization: `Bearer ${data.token}`, "x-load-test": runId };
  // One request per endpoint under test; tag the name so the summary groups by route.
  const res = http.get(`${baseUrl}/healthz`, { headers, tags: { name: "GET /healthz" } });
  check(res, { "healthz 200": (r) => r.status === 200 });
}

export function teardown(data) {
  // Delete everything this run created, matched by the run id, so qa does not grow.
  http.del(`${baseUrl}/test-data?run=${runId}`, null, {
    headers: { Authorization: `Bearer ${data.token}`, "x-load-test": runId },
  });
}

export function handleSummary(data) {
  return {
    "tests/load/results/summary.json": JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: " ", enableColors: false }),
  };
}
