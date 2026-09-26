"""Every Down undoes its Up: the schema after up, down, up is the same."""

import migrate


def test_there_are_migrations():
    assert len(migrate.migrations()) > 0


def test_each_down_reverses_its_up(conn):
    versions = [v for v, _ in migrate.migrations()]
    checked = 0
    for i, v in enumerate(versions):
        prev = versions[i - 1] if i else 0
        migrate.up_to(conn, v)
        after_up = migrate.schema(conn)
        migrate.down_to(conn, prev)
        migrate.up_to(conn, v)
        assert migrate.schema(conn) == after_up, f"migration {v}: up, down, up changed the schema"
        checked += 1
    assert checked == len(versions)


def test_all_the_way_down_and_up(conn):
    migrate.up_to(conn)
    full = migrate.schema(conn)
    migrate.down_to(conn, 0)
    assert migrate.schema(conn) == []
    migrate.up_to(conn)
    assert migrate.schema(conn) == full
