#!/usr/bin/env python3
"""Rebuild the booking mockups: one HTML page per screen in screens.json,
from template.html. Run with `make screens` from the repository root."""

import html
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def panel(screen, state):
    return (
        f'<section class="phone" data-state="{state["name"]}" aria-label="{html.escape(state["label"])}">\n'
        f'  <header class="appbar">{html.escape(screen["title"])}</header>\n'
        f'  <div class="content">\n{state["body"]}\n  </div>\n'
        + (f'  <div class="actions">\n{state["actions"]}\n  </div>\n' if state.get("actions") else "")
        + "</section>"
    )


def main():
    spec = json.load(open(os.path.join(HERE, "screens.json"), encoding="utf-8"))
    template = open(os.path.join(HERE, "template.html"), encoding="utf-8").read()
    for screen in spec["screens"]:
        buttons = "\n".join(
            f'  <button type="button" data-target="{s["name"]}">{html.escape(s["label"])}</button>'
            for s in screen["states"]
        )
        panels = "\n".join(panel(screen, s) for s in screen["states"])
        page = (
            template.replace("{{ID}}", screen["id"])
            .replace("{{TITLE}}", html.escape(screen["title"]))
            .replace("{{STATE_BUTTONS}}", buttons)
            .replace("{{PANELS}}", panels)
        )
        with open(os.path.join(HERE, screen["file"]), "w", encoding="utf-8") as f:
            f.write(page)
        print(f"wrote {screen['file']} ({len(screen['states'])} states)")
    print(f"screens: {len(spec['screens'])} built")


if __name__ == "__main__":
    main()
