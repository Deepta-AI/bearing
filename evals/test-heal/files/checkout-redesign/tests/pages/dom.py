"""A small DOM for server-rendered pages, with user-facing queries.

Queries are strict: `one()` fails when zero or several elements match, so
a locator always names exactly one control.
"""

from html.parser import HTMLParser

VOID = {"input", "br", "img", "meta", "link", "hr"}
IMPLICIT_ROLE = {"button": "button", "a": "link", "h1": "heading", "h2": "heading", "table": "table", "form": "form"}


class Element:
    def __init__(self, tag, attrs, parent):
        self.tag, self.attrs, self.parent = tag, dict(attrs), parent
        self.children, self.parts = [], []

    @property
    def text(self) -> str:
        return " ".join("".join(self._texts()).split())

    def _texts(self):
        for p in self.parts:
            yield p if isinstance(p, str) else "".join(p._texts())

    @property
    def role(self):
        return self.attrs.get("role") or IMPLICIT_ROLE.get(self.tag)

    @property
    def name(self) -> str:
        return self.attrs.get("aria-label") or self.text

    @property
    def disabled(self) -> bool:
        return "disabled" in self.attrs

    def walk(self):
        for c in self.children:
            yield c
            yield from c.walk()


class _Builder(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Element("#document", {}, None)
        self.cur = self.root

    def handle_starttag(self, tag, attrs):
        el = Element(tag, attrs, self.cur)
        self.cur.children.append(el)
        self.cur.parts.append(el)
        if tag not in VOID:
            self.cur = el

    def handle_endtag(self, tag):
        node = self.cur
        while node is not self.root and node.tag != tag:
            node = node.parent
        if node is not self.root:
            self.cur = node.parent

    def handle_data(self, data):
        self.cur.parts.append(data)


class Page:
    def __init__(self, html: str):
        b = _Builder()
        b.feed(html)
        self.root = b.root

    def all(self, pred):
        return [e for e in self.root.walk() if pred(e)]

    def one(self, pred, what: str) -> Element:
        found = self.all(pred)
        if len(found) != 1:
            raise LookupError(f"{what}: expected exactly one element, found {len(found)}")
        return found[0]

    def by_id(self, id_):
        return self.one(lambda e: e.attrs.get("id") == id_, f"#{id_}")

    def by_test_id(self, tid):
        return self.one(lambda e: e.attrs.get("data-testid") == tid, f"[data-testid={tid}]")

    def by_role(self, role, name=None):
        return self.one(
            lambda e: e.role == role and (name is None or e.name == name),
            f"role={role} name={name!r}",
        )

    def by_label(self, label):
        lab = self.one(lambda e: e.tag == "label" and e.text == label, f"label {label!r}")
        return self.by_id(lab.attrs.get("for"))
