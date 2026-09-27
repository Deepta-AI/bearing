import sys

from notes import store


def main(argv):
    if argv[:1] == ["add"] and len(argv) == 2:
        n = store.add(argv[1])
        print(f"added {n['id']}")
        return 0
    if argv == ["list"]:
        for n in store.notes():
            print(f"{n['id']}: {n['text']}")
        return 0
    print("usage: python -m notes add TEXT | list", file=sys.stderr)
    return 2


sys.exit(main(sys.argv[1:]))
