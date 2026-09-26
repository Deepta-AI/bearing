import { Link } from "react-router";
import { Compass } from "../components/Compass";
import { Terminal } from "../components/Terminal";
import { Page } from "../components/ui";
import { data } from "../lib/data";

export default function Home() {
  const c = data.counts;
  const manifest: [string, number | string, string, string, string][] = [
    ["Skills", c.skills, "skills/*/SKILL.md", "/skills-work", `${c.commandSkills} you type, ${c.skills - c.commandSkills} the model picks, ${c.stackSkills} stack lanes`],
    ["Subagents", c.agents, "agents/*.md", "/agents", "forked contexts with fewer tools than the session"],
    ["Hook events", c.hooks, "hooks/hooks.json", "/session", "each a few lines of shell over one guard script"],
    ["Guard rules", data.guardRules.length, "bin/brg-guard", "/guard", "the verbs an agent may not run"],
    ["Scripts", c.scripts, "bin/, hooks/scripts/, skills/*/scripts/", "/scripts", `${c.scriptLines.toLocaleString("en")} lines of bash and Python`],
    ["Stacks", c.stacks, "skills/*/templates*/stack.json", "/scaffold", "what brg-scaffold can build"],
    ["Repository templates", c.templates, "templates/", "/scaffold", "the files every product repository commits"],
    ["Gates in make check", c.gates, "Makefile", "/gates", "each prints what it counted and fails on zero"],
    ["Test files", c.tests, "tests/", "/gates", `plus ${c.fixtures} fixtures`],
    ["CI jobs", c.ciJobs, ".gitlab-ci.yml", "/gates", "including a scaffold of every stack, every morning"],
  ];
  return (
    <Page full title="How Bearing works inside" lede={
      <>
        Bearing is a Claude Code plugin that gives every stage of a product a skill, and makes the rules that must not bend (the agent never pushes, every
        gate counts, everything traces) physical instead of polite. This guide is its service manual: what runs when, which file decides, and where to make
        a change without breaking the rest.
      </>
    }>
      <p className="kicker">Every Bearing session passes the same six checkpoints. Pick one to see what fires.</p>
      <Compass />

      <h2 id="ways-in">Three ways in</h2>
      <div className="cols">
        <Link className="card" to="/start">
          <h3>You have an hour</h3>
          <p>Read chapters 1 to 4 in order: where things live, the five layers, one session event by event, and the guard. Everything else hangs off those.</p>
          <span className="meta">Where to start, then Next at the foot of each page</span>
        </Link>
        <Link className="card" to="/change">
          <h3>You need to change something</h3>
          <p>Recipes for a new skill, a script, a stack, a tracker, a harness and a guard rule, each with the gates it must pass and the tests to add.</p>
          <span className="meta">Changing Bearing</span>
        </Link>
        <Link className="card" to="/guard">
          <h3>Something was blocked</h3>
          <p>Every refusal comes from one of four places: the guard, the settings deny list, a git hook or a gate. The guard chapter shows how to tell which.</p>
          <span className="meta">The guard, then Gates, tests and CI</span>
        </Link>
      </div>

      <h2 id="manifest">What the kit is made of</h2>
      <p>Counted from the repository when this site was built. Nothing on this page is typed by hand.</p>
      <div className="tablewrap">
        <table className="manifest">
          <thead>
            <tr>
              <th>Part</th>
              <th>Count</th>
              <th>Where</th>
              <th>Note</th>
            </tr>
          </thead>
          <tbody>
            {manifest.map(([part, n, where, to, note]) => (
              <tr key={part}>
                <td>
                  <Link to={to}>{part}</Link>
                </td>
                <td className="num">{n}</td>
                <td>
                  <code>{where}</code>
                </td>
                <td>{note}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <h2 id="see-it">See it refuse a push</h2>
      <p>
        A recording of the guard run by hand against seven commands. The same script answers every Bash call Claude makes in a Bearing repository, in
        about 20 milliseconds.
      </p>
      <Terminal id="guard" height={300} />
    </Page>
  );
}
