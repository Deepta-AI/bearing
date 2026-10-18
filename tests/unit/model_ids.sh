#!/usr/bin/env bash
# tests/unit/model_ids.sh: lint-model-ids holds every Claude id under plugins/
# to bin/model-ids.txt (the claude-api skill's current and still-active ids).
set -u
. "$(dirname "$0")/../lib/assert.sh"
t_begin "the repository has only listed ids"
assert_exit 0 python3 "$KIT/bin/lint-model-ids.py"
assert_contains "$T_OUT" "0 unknown"
assert_contains "$T_OUT" "files scanned"
t_end
t_begin "an unlisted id fails with its place"
r="$(tmpdir)"; mkdir -p "$r/plugins/p/skills/s" "$r/bin"; cp "$KIT/bin/model-ids.txt" "$r/bin/"
printf 'model: claude-opus-4-1\nmodel: claude-opus-5-5\n' > "$r/plugins/p/skills/s/SKILL.md"
assert_exit 1 python3 "$KIT/bin/lint-model-ids.py" "$r"
assert_contains "$T_OUT" "unknown model id claude-opus-4-1 in plugins/p/skills/s/SKILL.md:1"
assert_not_contains "$T_OUT" "claude-opus-5-5 in"
t_end
t_begin "claude-haiku-5-5 does not exist and is unknown"
printf 'claude-haiku-5-5\n' > "$r/plugins/p/skills/s/SKILL.md"
assert_exit 1 python3 "$KIT/bin/lint-model-ids.py" "$r"
assert_contains "$T_OUT" "unknown model id claude-haiku-5-5"
t_end
t_begin "a dated snapshot is one id, not its alias plus digits"
printf 'claude-haiku-4-5-20251001 and claude-haiku-4-5\n' > "$r/plugins/p/skills/s/SKILL.md"
assert_exit 0 python3 "$KIT/bin/lint-model-ids.py" "$r"
assert_contains "$T_OUT" "2 ids found"
t_end
t_begin "an unlisted snapshot of a listed alias is unknown"
printf 'claude-haiku-4-5-20990101\n' > "$r/plugins/p/skills/s/SKILL.md"
assert_exit 1 python3 "$KIT/bin/lint-model-ids.py" "$r"
t_end
t_begin "a run-on id is not read as its listed prefix"
printf 'claude-opus-5-5x\n' > "$r/plugins/p/skills/s/SKILL.md"
assert_exit 1 python3 "$KIT/bin/lint-model-ids.py" "$r"
assert_contains "$T_OUT" "unknown model id claude-opus-5-5x in"
printf 'claude-haiku-4-5-2025x\n' > "$r/plugins/p/skills/s/SKILL.md"
assert_exit 1 python3 "$KIT/bin/lint-model-ids.py" "$r"
assert_contains "$T_OUT" "unknown model id claude-haiku-4-5-2025x in"
t_end
t_begin "a hyphen after a listed id ends the token"
printf 'the claude-haiku-4-5- tier\n' > "$r/plugins/p/skills/s/SKILL.md"
assert_exit 0 python3 "$KIT/bin/lint-model-ids.py" "$r"
assert_contains "$T_OUT" "1 ids found"
t_end
t_begin "no files is a failure"
e="$(tmpdir)"; mkdir -p "$e/plugins" "$e/bin"; cp "$KIT/bin/model-ids.txt" "$e/bin/"
assert_exit 2 python3 "$KIT/bin/lint-model-ids.py" "$e"
assert_contains "$T_OUT" "nothing checked"
t_end
t_begin "an empty id list is a failure"
z="$(tmpdir)"; mkdir -p "$z/plugins/p" "$z/bin"; echo x > "$z/plugins/p/f.md"; printf '# nothing\n' > "$z/bin/model-ids.txt"
assert_exit 2 python3 "$KIT/bin/lint-model-ids.py" "$z"
assert_contains "$T_OUT" "no ids listed"
t_end
t_summary
