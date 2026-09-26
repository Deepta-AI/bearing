"""Nightly export: renders each invoice with the configured renderer."""

import importlib
import os

from invoicing import settings


def load_renderer(path=None):
    path = path or settings.RENDERER
    module, _, name = path.rpartition(".")
    return getattr(importlib.import_module(module), name)


def export(invoices, directory=None):
    directory = directory or settings.EXPORT_DIR
    os.makedirs(directory, exist_ok=True)
    render = load_renderer()
    written = []
    for inv in invoices:
        path = os.path.join(directory, f"{inv.number}.txt")
        with open(path, "w", encoding="utf-8") as f:
            f.write(render(inv))
        written.append(path)
    return written
