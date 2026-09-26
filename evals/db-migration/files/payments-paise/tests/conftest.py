import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pytest

from app.db import connect


@pytest.fixture
def conn(tmp_path):
    c = connect(str(tmp_path / "ledger.db"))
    yield c
    c.close()
