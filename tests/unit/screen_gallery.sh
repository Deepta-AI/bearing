#!/usr/bin/env bash
# tests/unit/screen_gallery.sh: plugins/bearing/skills/screen-design/scripts/gallery_check.py,
# the gate for screens as code on the default react-shadcn stack. Every
# inventory screen needs a src/features/*/screens/<id>-*.screen.tsx whose
# states map holds every inventory state; a screen file whose id is not in
# the inventory, a state missing, a raw <table>/<button>/<input>/<select>/
# <textarea>/<dialog> in a screen file, and zero screen files all fail.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/plugins/bearing/skills/screen-design/scripts/gallery_check.py"

flows() {
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<'MD'
## 1. Screen inventory

| Id | Screen |
| --- | --- |
| S-10 | Runs |
| S-12 | Run view |

## 2. Interaction states

### S-10 Runs

| State | The user sees | Copy |
| --- | --- | --- |
| loading | skeleton rows | "Loading runs" |
| empty | an invitation | "No runs yet" |
| error | a banner | "Could not load runs. Retry." |
| success | the table | "12 runs" |
| offline | n/a: read only | |

### S-12 Run view

| State | The user sees | Copy |
| --- | --- | --- |
| loading | skeleton | "Loading the run" |
| success | the stages | "Research, done" |
| `failed` | the stage that failed | "Contacts failed" |

## 3. Journey storyboard
MD
}
screen() { # screen <file> <id> <state>...
  local f="$1" id="$2"; shift 2
  mkdir -p "$(dirname "$f")"
  { echo 'import type { ScreenSpec } from "@/design/screen";'
    echo 'import { RunsTableView } from "../components/RunsTable";'
    echo 'export const screen: ScreenSpec = {'
    echo "  id: \"$id\","
    echo '  name: "Runs",'
    echo '  feature: "runs",'
    echo '  job: "List every run.",'
    echo '  states: {'
    for s in "$@"; do echo "    \"$s\": () => <RunsTableView state=\"$s\" />,"; done
    echo '  },'
    echo '};'
  } > "$f"
}

t_begin "every inventory screen with every state passes, with counts"
d="$(tmpdir)"; flows "$d/docs/design/flows/runs/flows.md"
screen "$d/src/features/runs/screens/S-10-runs.screen.tsx" S-10 loading empty error success
screen "$d/src/features/runs/screens/S-12-run-view.screen.tsx" S-12 loading success failed
assert_exit 0 python3 "$CHK" --src "$d/src" --flows "$d/docs/design/flows/runs/flows.md"
assert_contains "$T_OUT" "screen-gallery: 2 screens from $d/docs/design/flows/runs/flows.md, 7 states, 2 of 2 screens with all inventory states, 0 problems"
t_end

t_begin "a missing screen, a missing state and an unknown screen fail"
d="$(tmpdir)"; flows "$d/flows.md"
screen "$d/src/features/runs/screens/S-10-runs.screen.tsx" S-10 loading empty success
screen "$d/src/features/runs/screens/S-40-stray.screen.tsx" S-40 loading
assert_exit 1 python3 "$CHK" --src "$d/src" --flows "$d/flows.md"
assert_contains "$T_OUT" "S-10 (S-10-runs.screen.tsx): no state error"
assert_contains "$T_OUT" "S-12: no src/features/*/screens/S-12-*.screen.tsx"
assert_contains "$T_OUT" "S-40 (S-40-stray.screen.tsx): not in the inventory"
t_end

t_begin "a raw element in a screen file fails; the component library is the rule"
d="$(tmpdir)"; flows "$d/flows.md"
screen "$d/src/features/runs/screens/S-10-runs.screen.tsx" S-10 loading empty error success
screen "$d/src/features/runs/screens/S-12-run-view.screen.tsx" S-12 loading success failed
printf 'export const x = <table><tbody /></table>;\nexport const y = <button type="button">Go</button>;\n' >> "$d/src/features/runs/screens/S-12-run-view.screen.tsx"
assert_exit 1 python3 "$CHK" --src "$d/src" --flows "$d/flows.md"
assert_contains "$T_OUT" "S-12 (S-12-run-view.screen.tsx): raw <table>, <button>; use src/components/ui"
t_end

t_begin "two error rows need two error states; a labelled row names its key"
d="$(tmpdir)"; flows "$d/flows.md"
replace_in "$d/flows.md" '| error | a banner | "Could not load runs. Retry." |' "$(printf '%s\n%s\n%s' '| error | a banner | "Could not load runs. Retry." |' '| error | too many requests | "Try again at 14:02." |' '| error: not_found | the run is gone | "That run was deleted." |')"
screen "$d/src/features/runs/screens/S-10-runs.screen.tsx" S-10 loading empty error success error-not-found
screen "$d/src/features/runs/screens/S-12-run-view.screen.tsx" S-12 loading success failed
assert_exit 1 python3 "$CHK" --src "$d/src" --flows "$d/flows.md"
assert_contains "$T_OUT" "S-10 (S-10-runs.screen.tsx): 2 error rows in the flows, 1 error states (error); name each, such as error-rate-limited"
assert_not_contains "$T_OUT" "no state error-not-found"
screen "$d/src/features/runs/screens/S-10-runs.screen.tsx" S-10 loading empty error error-rate-limited success error-not-found
assert_exit 0 python3 "$CHK" --src "$d/src" --flows "$d/flows.md"
t_end

t_begin "the scaffold's example screen S-00 is named, not counted as a stray"
d="$(tmpdir)"; flows "$d/flows.md"
screen "$d/src/features/runs/screens/S-10-runs.screen.tsx" S-10 loading empty error success
screen "$d/src/features/runs/screens/S-12-run-view.screen.tsx" S-12 loading success failed
screen "$d/src/features/health/screens/S-00-health.screen.tsx" S-00 error success
assert_exit 0 python3 "$CHK" --src "$d/src" --flows "$d/flows.md"
assert_contains "$T_OUT" "the scaffold's example S-00-health.screen.tsx is not checked"
t_end

t_begin "zero screen files fail"
d="$(tmpdir)"; flows "$d/flows.md"; mkdir -p "$d/src"
assert_exit 1 python3 "$CHK" --src "$d/src" --flows "$d/flows.md"
assert_contains "$T_OUT" "screen-gallery: 0 screen files under $d/src"
t_end

t_summary
