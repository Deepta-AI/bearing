#!/usr/bin/env bash
# bin/evals-timer.sh: print the user-level systemd units that run
# bin/evals-weekly.sh for this clone every Sunday at 02:00, and the commands
# that install them. Installs nothing: a timer is standing configuration, so
# the maintainer reads the units and runs the commands. Linux with systemd
# only; on a Mac, run `make evals-weekly` by hand or from launchd. Run it from
# a clone kept on main: the units measure whatever this clone has checked out.
set -u
kit="$(cd "$(dirname "$0")/.." && pwd)"
claude="$(command -v claude || true)"
if [ -z "$claude" ]; then
  echo "evals-timer: claude is not on PATH; sign in with the claude CLI first (the run uses the subscription)" >&2
  exit 1
fi
cat <<EOF
# ~/.config/systemd/user/bearing-evals.service
[Unit]
Description=Bearing weekly evals (trigger-eval, harness-eval, scoreboard)

[Service]
Type=oneshot
WorkingDirectory=$kit
Environment=PATH=$(dirname "$claude"):/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/env bash $kit/bin/evals-weekly.sh

# ~/.config/systemd/user/bearing-evals.timer
[Unit]
Description=Run the Bearing weekly evals

[Timer]
OnCalendar=Sun *-*-* 02:00
Persistent=true

[Install]
WantedBy=timers.target

# Run from a clone kept on main ($kit is on $(git -C "$kit" branch --show-current 2>/dev/null || echo unknown)):
# the timer measures whatever is checked out there.
# Install (prints only; run these yourself):
#   mkdir -p ~/.config/systemd/user
#   (save the two units above to the paths in their headers)
#   systemctl --user daemon-reload
#   systemctl --user enable --now bearing-evals.timer
#   loginctl enable-linger "\$USER"   # so it runs while you are logged out
# See the last run: journalctl --user -u bearing-evals.service
EOF
