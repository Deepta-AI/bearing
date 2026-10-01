#!/usr/bin/env python3
"""doc_to_text.py: turn a .docx or .odt brief into plain text the prd skill
can cite by line.

Usage: python3 doc_to_text.py <input.docx|input.odt> <output.txt>

Headings become "# " lines, list items "- " lines and table rows
"| a | b |" lines, one paragraph per line, so a requirement keeps a stable
line number (L<n>) in the saved export. Standard library only. Some Python
builds lack zlib and cannot inflate a zip member; the script then reads the
member with `unzip -p` (a client .docx arrived this way on 1 Oct 2026 and
the skill used to stop and ask for a text export).

Exit 0 and prints "<lines> lines from <input>"; exit 1 when the document
holds no text, because an empty export is a failed conversion, not a brief.
"""

import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
TEXT = "{urn:oasis:names:tc:opendocument:xmlns:text:1.0}"
TABLE = "{urn:oasis:names:tc:opendocument:xmlns:table:1.0}"


def read_member(path, member):
    try:
        with zipfile.ZipFile(path) as z:
            return z.read(member)
    except RuntimeError:  # "Compression requires the (missing) zlib module"
        return subprocess.run(
            ["unzip", "-p", path, member], check=True, capture_output=True
        ).stdout


def docx_lines(path):
    body = ET.fromstring(read_member(path, "word/document.xml")).find(W + "body")

    def text(el):
        return "".join(t.text or "" for t in el.iter(W + "t")).strip()

    out = []
    for el in body:
        if el.tag == W + "p":
            t = text(el)
            if not t:
                continue
            style = el.find(f"{W}pPr/{W}pStyle")
            style = style.get(W + "val", "") if style is not None else ""
            if style.lower().startswith("heading") or style == "Title":
                level = "".join(c for c in style if c.isdigit()) or "1"
                out.append("#" * int(level) + " " + t)
            elif el.find(f"{W}pPr/{W}numPr") is not None or style.startswith("List"):
                out.append("- " + t)
            else:
                out.append(t)
        elif el.tag == W + "tbl":
            for tr in el.iter(W + "tr"):
                out.append(
                    "| " + " | ".join(text(tc) for tc in tr.findall(W + "tc")) + " |"
                )
    return out


def odt_lines(path):
    root = ET.fromstring(read_member(path, "content.xml"))

    def text(el):
        return "".join(el.itertext()).strip()

    out = []

    def walk(el):  # a list item or table row is one line; its paragraphs are not walked again
        if el.tag == TEXT + "h" and text(el):
            out.append("#" * int(el.get(TEXT + "outline-level", "1")) + " " + text(el))
        elif el.tag == TEXT + "list-item":
            if text(el):
                out.append("- " + text(el))
        elif el.tag == TABLE + "table-row":
            out.append(
                "| "
                + " | ".join(text(c) for c in el.findall(TABLE + "table-cell"))
                + " |"
            )
        elif el.tag == TEXT + "p":
            if text(el):
                out.append(text(el))
        else:
            for child in el:
                walk(child)

    walk(root)
    return out


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: doc_to_text.py <input.docx|input.odt> <output.txt>")
    src, dst = sys.argv[1], sys.argv[2]
    ext = src.lower().rsplit(".", 1)[-1]
    if ext == "docx":
        lines = docx_lines(src)
    elif ext == "odt":
        lines = odt_lines(src)
    else:
        sys.exit(
            f"doc_to_text: .{ext} is not supported (docx, odt); read PDFs with the Read tool"
        )
    if not lines:
        sys.exit(f"doc_to_text: 0 lines of text in {src}; the conversion failed")
    with open(dst, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{len(lines)} lines from {src}")


if __name__ == "__main__":
    main()
