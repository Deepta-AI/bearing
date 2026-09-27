from worker.jobs import Rider, assign


def test_round_robin():
    got, left = assign(["d1", "d2", "d3"], [Rider("a", 5), Rider("b", 5)])
    assert got == {"a": ["d1", "d3"], "b": ["d2"]}
    assert left == []


def test_capacity_is_respected():
    got, left = assign(["d1", "d2", "d3"], [Rider("a", 1), Rider("b", 1)])
    assert got == {"a": ["d1"], "b": ["d2"]}
    assert left == ["d3"]


def test_no_riders_leaves_everything_unassigned():
    got, left = assign(["d1"], [])
    assert got == {}
    assert left == ["d1"]
