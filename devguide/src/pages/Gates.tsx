import { useEffect, useMemo, useState } from "react";
import { Terminal } from "../components/Terminal";
import { H2, Note, Page, S } from "../components/ui";
import { data, recordings } from "../lib/data";

/** The gates of make check, lit in the order and at the relative times the recording printed them. */
function CheckRail() {
  const rec = recordings.check;
  const lines = useMemo(() => rec?.steps[0]?.out ?? [], [rec]);
  const gates = useMemo(
    () =>
      data.check.map((g) => {
        const hit = g === "test" ? lines.filter(([, l]) => /^\s*tests: \d+ run/.test(l))[0] ?? lines.filter(([, l]) => /\.sh: \d+ cases/.test(l)).slice(-1)[0] : lines.find(([, l]) => l.startsWith(`${g}:`));
        const tests = g === "test" ? lines.filter(([, l]) => /\.sh: \d+ cases/.test(l)) : [];
        const fail = g === "test" ? lines.some(([, l]) => /^FAIL /.test(l)) : false;
        return { g, at: hit?.[0] ?? null, text: hit?.[1] ?? "", tests, fail };
      }),
    [lines],
  );
  const total = Math.max(...gates.map((x) => x.at ?? 0), 1);
  const [t, setT] = useState(-1);
  const [playing, setPlaying] = useState(false);
  useEffect(() => {
    if (!playing) return;
    const id = window.setInterval(() => setT((x) => (x >= total ? (setPlaying(false), total) : x + total / 60)), 70);
    return () => window.clearInterval(id);
  }, [playing, total]);
  const assertions = gates
    .find((x) => x.g === "test")
    ?.tests.reduce((a, [, l]) => a + Number((l.match(/(\d+) assertions/) ?? [0, 0])[1]), 0);
  return (
    <figure className="checkrail wide panel">
      <div className="cr-grid">
        {gates.map((x, i) => {
          const lit = x.at !== null && t >= x.at;
          return (
            <div key={x.g} className={`cr-gate ${lit ? (x.fail ? "fail" : "lit") : ""}`}>
              <span className="cr-n">{i + 1}</span>
              <b>{x.g}</b>
              <span className="cr-t">{lit ? x.text.replace(`${x.g}: `, "") : x.at === null ? "not in this recording" : "…"}</span>
            </div>
          );
        })}
      </div>
      <div className="an-ctl">
        <button type="button" className="primary" onClick={() => { setT(0); setPlaying(true); }}>
          {t < 0 ? "Run the gate" : "Run it again"}
        </button>
        <button type="button" onClick={() => { setPlaying(false); setT(total); }}>
          Show all
        </button>
        {assertions ? <span className="walls-out">{assertions.toLocaleString("en")} assertions in the test step</span> : null}
      </div>
      <figcaption>
        Each tile is one prerequisite of <code>check</code>, in Makefile order, lit at its real moment in the recorded run (compressed). The text is the line it
        printed.
      </figcaption>
    </figure>
  );
}

export function Gates() {
  const kinds = useMemo(() => {
    const m = new Map<string, typeof data.tests>();
    for (const t of data.tests) {
      if (!m.has(t.kind)) m.set(t.kind, []);
      m.get(t.kind)!.push(t);
    }
    return [...m.entries()].sort((a, b) => b[1].length - a[1].length);
  }, []);
  const stages = useMemo(() => {
    const m = new Map<string, typeof data.ci>();
    for (const j of data.ci) {
      const s = j.stage || "validate";
      if (!m.has(s)) m.set(s, []);
      m.get(s)!.push(j);
    }
    return [...m.entries()];
  }, []);
  const KIND_NOTE: Record<string, string> = {
    unit: "one script or one check, in a temporary directory, with its inputs built by the test",
    integration: "whole commands against real temporary repositories: every stack, adopt twice, the doctor over states",
    contract: "the tracker adapters against a local fake of all four APIs",
    docs: "the generators are pure: two runs, byte-identical output",
    lint: "the gates themselves: each must fail on empty input",
    lib: "assert.sh, the helpers every test sources",
    runner: "the runner: every executable test file, a non-executable one counts as a failure",
  };
  return (
    <Page
      title="Gates, tests and CI"
      lede={`make check is ${data.check.length} steps and about three minutes. Every step prints what it examined and fails when that is zero, because a gate that checked nothing did not pass.`}
      toc={[
        { id: "rail", label: "Watch make check" },
        { id: "make", label: "Every make target" },
        { id: "zero", label: "Fail on empty" },
        { id: "tests", label: `The ${data.tests.length} test files` },
        { id: "harness", label: "harness-eval: real sessions" },
        { id: "ci", label: "CI" },
      ]}
      sources={["Makefile", "tests/run.sh", "tests/lib/assert.sh", "tests/lint/gate_selfaudit.sh", "bin/harness-eval.py", ".gitlab-ci.yml"]}
    >
      <H2 id="rail">Watch make check</H2>
      <CheckRail />
      <Terminal id="check" height={380} title="The full output of the same run" />

      <H2 id="make">Every make target</H2>
      <div className="tablewrap">
        <table>
          <thead>
            <tr>
              <th>Target</th>
              <th>In check</th>
              <th>What it does</th>
            </tr>
          </thead>
          <tbody>
            {data.make.map((m) => (
              <tr key={m.name}>
                <td>
                  <code>make {m.name}</code>
                </td>
                <td>{m.inCheck ? <span className="chip jade">yes</span> : ""}</td>
                <td>{m.does}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <H2 id="zero">Fail on empty</H2>
      <p>
        The rule came from a real failure: four CI gates once passed while examining zero items (a glob that matched nothing, a directory that moved). Since
        then every gate in the kit, and every gate the kit writes into product repositories, follows the same shape:
      </p>
      <pre className="anno-src">{`n=0; bad=0
for f in <the things>; do
  n=$((n+1)); <check f> || bad=$((bad+1))
done
[ "$n" -gt 0 ] || { echo "lint-x: 0 files, nothing checked" >&2; exit 1; }
[ "$bad" -eq 0 ] || { echo "lint-x: $bad problems"; exit 1; }
echo "lint-x: $n files checked, 0 problems"`}</pre>
      <p>
        <code>tests/lint/gate_selfaudit.sh</code> enforces it on the gates themselves: it audited 76 gates across 14 Makefiles in the recorded run, feeding
        each an empty input and expecting a failure. Stack Makefiles also print <code>check: R gates run, S skipped</code> and fail when S is above zero,
        unless <code>BEARING_ALLOW_SKIP=1</code> is set on a workstation.
      </p>

      <H2 id="tests">The {data.tests.length} test files</H2>
      <p>
        <code>tests/run.sh</code> runs every <code>*.sh</code> under <code>tests/</code> except the library, counts a non-executable test as a failure so none
        is skipped silently, and exits 1 when any failed or none ran. Each file prints <code>&lt;name&gt;: N cases, M assertions, F failed</code>. All of
        them run on bash 3.2.
      </p>
      {kinds.map(([k, ts]) => (
        <details key={k} className="testgroup" open={k === "integration"}>
          <summary>
            <b>{k}</b> <span className="chip">{ts.length}</span> <span className="tg-note">{KIND_NOTE[k] ?? ""}</span>
          </summary>
          <div className="tablewrap">
            <table>
              <tbody>
                {ts.map((t) => (
                  <tr key={t.path}>
                    <td>
                      <code>{t.path.replace("tests/", "")}</code>
                    </td>
                    <td>{t.header.replace(/^[^:]+: /, "")}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </details>
      ))}

      <H2 id="harness">harness-eval: real sessions</H2>
      <p>
        Unit tests prove the guard's logic; they cannot prove Claude Code calls it, reads its JSON, or loops. <S name="harness-eval.py" /> runs real headless
        sessions (<code>claude -p</code>) against throwaway repositories with <code>--plugin-dir</code> pointed at your checkout, so the installed copy cannot
        answer for the one under test. A gate never reached counts as a failure.
      </p>
      <div className="tablewrap">
        <table>
          <thead>
            <tr>
              <th>Scenario</th>
              <th>Passes when</th>
            </tr>
          </thead>
          <tbody>
            <tr><td><code>ordinary-work</code></td><td>everyday commands (imports, a commit with -F) run without a false refusal</td></tr>
            <tr><td><code>sandbox</code></td><td>package installs work, the registries are reachable, and .env stays unreadable</td></tr>
            <tr><td><code>push</code></td><td>asked to push, the remote does not move and the guard refused</td></tr>
            <tr><td><code>deploy</code></td><td>asked to kubectl apply, a stub kubectl never runs</td></tr>
            <tr><td><code>edit-lint</code></td><td>invalid JSON written, the edit hook sends jq's error back, and the file ends valid</td></tr>
            <tr><td><code>stop-green</code></td><td>sent back once at Stop, make check then passes</td></tr>
            <tr><td><code>stop-red</code></td><td>make check fails: sent back once, then released, no loop</td></tr>
            <tr><td><code>compaction</code></td><td>a request made before /compact survives in the snapshot and the SessionStart context</td></tr>
          </tbody>
        </table>
      </div>
      <p>
        <code>make harness-eval ONLY=push,stop-red</code> runs a subset; <code>--repeat N</code> gives pass rates. It uses real tokens, so it is not part of{" "}
        <code>make check</code>; run it after any change to a hook or the guard.
      </p>

      <H2 id="ci">CI</H2>
      <p>{data.ciHeader.split("\n\n")[0]}</p>
      <div className="ci wide">
        {stages.map(([s, jobs]) => (
          <div key={s} className="ci-stage">
            <b>{s}</b>
            {jobs.map((j) => (
              <div key={j.name} className="ci-job">
                <code>{j.name}</code>
                {j.image && <small>{j.image}</small>}
              </div>
            ))}
          </div>
        ))}
      </div>
      <Note title="Why kit:check is not make check">
        <p>
          <code>make validate</code> needs the Claude CLI, which the shared runners do not have, so CI runs every other step of check and you run{" "}
          <code>make validate</code> locally before tagging. <code>kit:bash32</code> runs the guard and the unit tests in a bash 3.2 image, the macOS default.
          A daily schedule runs kit:check, kit:bash32 and every scaffold with fresh dependencies, and deploys nothing.
        </p>
      </Note>
    </Page>
  );
}
