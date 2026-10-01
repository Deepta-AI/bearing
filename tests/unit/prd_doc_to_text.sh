#!/usr/bin/env bash
# tests/unit/prd_doc_to_text.sh: plugins/bearing/skills/prd/scripts/doc_to_text.py
# turns a .docx or .odt brief into one line per paragraph (headings "# ",
# list items "- ", table rows "| a | b |") so REQ sources cite stable line
# numbers; an ODT list item is one line, not repeated for its paragraph;
# fails on a document with no text and on an unsupported format.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CONV="$KIT/plugins/bearing/skills/prd/scripts/doc_to_text.py"
d="$(tmpdir)"

# zip_doc <out> <member> <xml>: a stored (uncompressed) zip, so the fixture
# needs no zlib.
zip_doc() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_STORED) as z:
    z.writestr(sys.argv[2], sys.argv[3])
PY
}

WNS='xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
zip_doc "$d/brief.docx" word/document.xml "<w:document $WNS><w:body>
<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr><w:r><w:t>Clinic portal</w:t></w:r></w:p>
<w:p><w:r><w:t>Receptionists re-key reports.</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val=\"Heading2\"/></w:pPr><w:r><w:t>Scope</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val=\"0\"/></w:numPr></w:pPr><w:r><w:t>The system </w:t></w:r><w:r><w:t>files lab reports</w:t></w:r></w:p>
<w:p><w:r><w:t>   </w:t></w:r></w:p>
<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Limit</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>60 a day</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
</w:body></w:document>"

t_begin "docx: headings, a list item split across runs, a table row, blank lines dropped"
assert_exit 0 python3 "$CONV" "$d/brief.docx" "$d/brief.txt"
assert_contains "$T_OUT" "5 lines from"
assert_eq "# Clinic portal|Receptionists re-key reports.|## Scope|- The system files lab reports|| Limit | 60 a day |" "$(paste -sd'|' "$d/brief.txt")"
t_end

ONS='xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"'
zip_doc "$d/brief.odt" content.xml "<office:document-content $ONS><office:body><office:text>
<text:h text:outline-level=\"2\">Scope</text:h>
<text:list><text:list-item><text:p>Match reports by name</text:p></text:list-item></text:list>
<table:table><table:table-row><table:table-cell><text:p>Owner</text:p></table:table-cell><table:table-cell><text:p>Front desk</text:p></table:table-cell></table:table-row></table:table>
<text:p>Closing note.</text:p>
</office:text></office:body></office:document-content>"

t_begin "odt: a list item and a table row are one line each, not repeated per paragraph"
assert_exit 0 python3 "$CONV" "$d/brief.odt" "$d/odt.txt"
assert_eq "## Scope|- Match reports by name|| Owner | Front desk ||Closing note." "$(paste -sd'|' "$d/odt.txt")"
t_end

t_begin "a document with no text fails: an empty export is not a brief"
zip_doc "$d/empty.docx" word/document.xml "<w:document $WNS><w:body><w:p/></w:body></w:document>"
assert_exit 1 python3 "$CONV" "$d/empty.docx" "$d/empty.txt"
assert_contains "$T_OUT" "0 lines of text"
t_end

t_begin "an unsupported format fails and names what is supported"
printf '%%PDF-1.4\n' > "$d/brief.pdf"
assert_exit 1 python3 "$CONV" "$d/brief.pdf" "$d/pdf.txt"
assert_contains "$T_OUT" "not supported (docx, odt)"
t_end

t_summary
