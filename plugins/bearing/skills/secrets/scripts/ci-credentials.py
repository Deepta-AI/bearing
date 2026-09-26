#!/usr/bin/env python3
"""ci-credentials: CI files that carry a credential inline instead of
reading it from the CI's secret store.

  ci-credentials.py [--root DIR]

Reads .gitlab-ci.yml, .gitlab-ci/*.yml, .github/workflows/*.yml and *.yaml,
.github/actions/*/action.yml, .circleci/config.yml, bitbucket-pipelines.yml,
azure-pipelines.yml, .drone.yml, .travis.yml and Jenkinsfile. A finding is:
  - a key whose name says credential (password, passwd, token, secret,
    api_key, apikey, access_key, private_key, client_secret) with a literal
    value, where a reference (${{ secrets.X }}, $VAR, ${VAR}, a vault or
    !reference lookup) or an empty or placeholder value is not a finding;
  - a --password, --token or --api-key flag given a literal;
  - a URL with a password in it (scheme://user:literal@host);
  - a credential-shaped string (the patterns the pre-commit hook blocks).
The default password of a throwaway service container (postgres, mysql,
guest and the like, for a database that lives for one job) is counted
separately and is not a finding. Values are never printed: a finding is the
file, the line and the key.

Prints one line per finding and the count line
  ci-credentials: F CI files, K credential keys examined,
  T throwaway service passwords, N inline credentials
and exits 1 on any finding, or when zero CI files were found.
"""

import argparse
import glob
import os
import re
import sys

PATTERNS = [
    ".gitlab-ci.yml",
    ".gitlab-ci/*.yml",
    ".gitlab-ci/*.yaml",
    ".github/workflows/*.yml",
    ".github/workflows/*.yaml",
    ".github/actions/*/action.yml",
    ".circleci/config.yml",
    "bitbucket-pipelines.yml",
    "azure-pipelines.yml",
    ".drone.yml",
    ".travis.yml",
    "Jenkinsfile",
]
CRED = r"(password|passwd|token|secret|api[_-]?key|apikey|access[_-]?key|private[_-]?key|client[_-]?secret)"
# A credential-named key and its value, at the start of a line or inside a
# flow map ({ A: x, B: y }) or a shell assignment.
PAIR_RE = re.compile(
    r"(?:^|[{,\s-])[\"']?([A-Za-z0-9_.-]*"
    + CRED
    + r"[A-Za-z0-9_.-]*)[\"']?\s*[:=]\s*([^,}\n]*)",
    re.I,
)
FLAG_RE = re.compile(
    r"--(password|token|api-key)[= ]+([^\s\"']+|\"[^\"]*\"|'[^']*')", re.I
)
URL_RE = re.compile(r"[a-z][a-z0-9+.-]*://[^\s:/@]+:([^\s@/]+)@", re.I)
SHAPED_RE = re.compile(
    r"AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{36}"
    r"|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20}|sk-ant-[A-Za-z0-9_-]{20,}"
    r"|sk_live_[A-Za-z0-9]{16,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}"
)
PLACEHOLDER_RE = re.compile(
    r"^(changeme|change-me|your[_-].*|xxx+|<[^>]*>|todo|example|dummy|none|null|true|false|read|write|~|\*+|\.\.\.|[0-9]+)$",
    re.I,
)


# Default passwords of throwaway CI service containers (postgres, mysql,
# redis, rabbitmq). Counted and reported, not findings: the container lives
# for one job and is reachable only from it.
THROWAWAY = {
    "postgres",
    "password",
    "root",
    "secret",
    "mysql",
    "test",
    "testing",
    "guest",
    "redis",
    "mongo",
    "ci",
}


def bare(v):
    v = v.strip()
    if "#" in v and not v.startswith(("'", '"')):
        v = v.split("#", 1)[0].strip()
    return v.strip("'\"").strip()


def is_reference(v):
    v = bare(v)
    if not v or v in ("|", ">", "|-", ">-"):
        return True  # empty, or a block whose lines are checked on their own
    if "$" in v or "secrets." in v or "vault" in v.lower() or v.startswith("!"):
        return True
    if "credentials(" in v or "withCredentials" in v:
        return True
    return bool(PLACEHOLDER_RE.match(v))


def ci_files(root):
    out = []
    for p in PATTERNS:
        out.extend(sorted(glob.glob(os.path.join(root, p))))
    return [f for f in out if os.path.isfile(f)]


def scan(path, rel):
    keys = throwaway = 0
    findings = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for n, line in enumerate(f, 1):
            if line.lstrip().startswith("#"):
                continue
            hit = False
            for key, _, value in PAIR_RE.findall(line):
                if key.startswith("-"):
                    continue  # a --flag=value; FLAG_RE below judges it
                keys += 1
                if is_reference(value):
                    continue
                if bare(value).lower() in THROWAWAY:
                    throwaway += 1
                    continue
                findings.append("%s:%d: key %s has a literal value" % (rel, n, key))
                hit = True
            if hit:
                continue
            fm = FLAG_RE.search(line)
            if fm and not is_reference(fm.group(2)):
                keys += 1
                if bare(fm.group(2)).lower() in THROWAWAY:
                    throwaway += 1
                else:
                    findings.append(
                        "%s:%d: --%s is given a literal" % (rel, n, fm.group(1))
                    )
                    continue
            um = URL_RE.search(line)
            if um and not is_reference(um.group(1)):
                if bare(um.group(1)).lower() in THROWAWAY:
                    throwaway += 1
                else:
                    findings.append("%s:%d: a URL carries a password" % (rel, n))
                    continue
            if SHAPED_RE.search(line):
                findings.append("%s:%d: a credential-shaped string" % (rel, n))
    return keys, throwaway, findings


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    args = ap.parse_args()
    root = os.path.abspath(args.root)
    files = ci_files(root)
    if not files:
        print(
            "ci-credentials: 0 CI files under %s, nothing checked" % root,
            file=sys.stderr,
        )
        sys.exit(1)
    keys = throwaway = 0
    findings = []
    for f in files:
        k, t, fs = scan(f, os.path.relpath(f, root))
        keys += k
        throwaway += t
        findings.extend(fs)
    for f in findings:
        print("finding: " + f)
    print(
        "ci-credentials: %d CI files, %d credential keys examined, "
        "%d throwaway service passwords, %d inline credentials"
        % (len(files), keys, throwaway, len(findings))
    )
    sys.exit(1 if findings else 0)


if __name__ == "__main__":
    main()
