import { useSearchParams } from "react-router";
import { Code, Page } from "../components/ui";
import { data, type DefaultFile } from "../lib/data";

function groupsOf(files: DefaultFile[]) {
  const out: { group: string; files: DefaultFile[] }[] = [];
  for (const f of files) {
    const g = f.group ?? "";
    const last = out[out.length - 1];
    if (last && last.group === g) last.files.push(f);
    else out.push({ group: g, files: [f] });
  }
  return out;
}

export default function Files() {
  const [params, setParams] = useSearchParams();
  const scope = data.defaultFiles.find((s) => s.id === params.get("scope")) ?? data.defaultFiles[0];
  const file = scope.files.find((f) => f.path === params.get("file")) ?? scope.files[0];
  const pick = (s: string, f?: string) => setParams(f ? { scope: s, file: f } : { scope: s }, { replace: true });
  const lines = file.content ? file.content.split("\n").length - 1 : 0;
  return (
    <Page
      full
      title="Default files"
      lede="What every developer has on their machine and what every repository carries, with the exact contents the installer and onboard-repo write. Copy a file from here when you set one up by hand."
    >
      <nav className="flow-tabs" aria-label="Scope">
        {data.defaultFiles.map((s) => (
          <a
            key={s.id}
            href={`?scope=${s.id}`}
            className={s.id === scope.id ? "on" : ""}
            onClick={(e) => {
              e.preventDefault();
              pick(s.id);
            }}
          >
            {s.title} <span className="muted">({s.files.length})</span>
          </a>
        ))}
      </nav>
      <p className="muted" style={{ maxWidth: "78ch" }}>
        {scope.summary}
      </p>
      <div className="files">
        <nav className="file-list" aria-label="Files">
          {groupsOf(scope.files).map((g) => (
            <div key={g.group || "_"}>
              {g.group && <div className="fl-g">{g.group}</div>}
              {g.files.map((f) => (
                <button key={f.path} type="button" aria-current={f.path === file.path} onClick={() => pick(scope.id, f.path)}>
                  {f.path}
                </button>
              ))}
            </div>
          ))}
        </nav>
        <div className="file-view">
          <h2 className="fv-path">{file.path}</h2>
          <dl className="fv-meta">
            <dt>What it is</dt>
            <dd>{file.purpose}</dd>
            <dt>Put there by</dt>
            <dd>{file.installedBy}</dd>
            <dt>You may change</dt>
            <dd>{file.edit}</dd>
            <dt>Leave alone</dt>
            <dd>{file.keep}</dd>
            {file.source && (
              <>
                <dt>Source in the kit</dt>
                <dd>
                  <code>{file.source}</code>
                </dd>
              </>
            )}
          </dl>
          {file.content ? (
            <>
              <div className="fv-bar">
                <span>{lines} lines</span>
              </div>
              <Code exact>{file.content}</Code>
            </>
          ) : (
            <div className="note">{file.note}</div>
          )}
        </div>
      </div>
    </Page>
  );
}
