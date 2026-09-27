from backupctl.cli import main


def test_prune_prints_what_it_deleted(tmp_path, capsys):
    for d in (1, 2, 3):
        (tmp_path / f"db-0{d}-09-2026.tar.gz").write_text("x")
    assert main(["prune", "--dir", str(tmp_path), "--keep", "2"]) == 0
    out = capsys.readouterr().out
    assert "deleted db-01-09-2026.tar.gz" in out
    assert "1 local backups deleted" in out
    assert not (tmp_path / "db-01-09-2026.tar.gz").exists()
