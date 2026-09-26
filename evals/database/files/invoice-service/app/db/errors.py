"""Driver errors translated into errors the services understand."""

UNIQUE_VIOLATION = "23505"


class DuplicateKey(Exception):
    """An insert or update hit a unique index. `constraint` names it."""

    def __init__(self, constraint):
        super().__init__(f"duplicate key on {constraint}")
        self.constraint = constraint


def is_unique_violation(exc):
    return getattr(exc, "sqlstate", None) == UNIQUE_VIOLATION


def constraint_name(exc):
    diag = getattr(exc, "diag", None)
    return getattr(diag, "constraint_name", None)
