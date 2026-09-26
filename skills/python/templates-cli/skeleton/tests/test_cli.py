"""The command line: output, exit codes and where each message goes."""

import runpy
import sys
from importlib.metadata import PackageNotFoundError
from pathlib import Path

import pytest

from app import cli
from app.cli import EXIT_FAILURE, EXIT_OK, EXIT_USAGE, main


def test_lines_counts_one_file(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    path = tmp_path / "a.txt"
    path.write_text("one\ntwo\nthree\n")

    code = main(["lines", str(path)])

    out, err = capsys.readouterr()
    assert code == EXIT_OK
    assert out == f"3\t{path}\n"
    assert err == ""


def test_lines_totals_several_files(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    a = tmp_path / "a.txt"
    b = tmp_path / "b.txt"
    a.write_text("one\n")
    b.write_text("one\ntwo\n")

    code = main(["lines", str(a), str(b)])

    assert code == EXIT_OK
    assert capsys.readouterr().out == f"1\t{a}\n2\t{b}\n3\ttotal\n"


def test_missing_file_fails_with_exit_1(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    missing = tmp_path / "nope.txt"

    code = main(["lines", str(missing)])

    out, err = capsys.readouterr()
    assert code == EXIT_FAILURE
    assert out == ""
    assert err == f"{cli.PROG}: error: {missing}: No such file or directory\n"


def test_version_prints_the_installed_version(
    capsys: pytest.CaptureFixture[str],
) -> None:
    code = main(["--version"])

    assert code == EXIT_OK
    assert capsys.readouterr().out == f"{cli.PROG} {cli.package_version()}\n"
    assert cli.package_version() != "0+unknown"


def test_version_without_an_installed_distribution(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def not_installed(name: str) -> str:
        raise PackageNotFoundError(name)

    monkeypatch.setattr(cli, "version", not_installed)

    assert cli.package_version() == "0+unknown"


def test_unknown_subcommand_is_a_usage_error(
    capsys: pytest.CaptureFixture[str],
) -> None:
    code = main(["frobnicate"])

    out, err = capsys.readouterr()
    assert code == EXIT_USAGE
    assert out == ""
    assert "invalid choice: 'frobnicate'" in err


def test_missing_subcommand_is_a_usage_error(
    capsys: pytest.CaptureFixture[str],
) -> None:
    code = main([])

    assert code == EXIT_USAGE
    assert "required: COMMAND" in capsys.readouterr().err


@pytest.mark.parametrize(
    "argv",
    [
        ["lines"],
        ["lines", "--bogus", "a.txt"],
    ],
)
def test_bad_arguments_are_usage_errors(
    argv: list[str], capsys: pytest.CaptureFixture[str]
) -> None:
    code = main(argv)

    out, err = capsys.readouterr()
    assert code == EXIT_USAGE
    assert out == ""
    assert err.startswith("usage: ")


def test_help_exits_0(capsys: pytest.CaptureFixture[str]) -> None:
    code = main(["--help"])

    assert code == EXIT_OK
    assert "lines" in capsys.readouterr().out


def test_python_dash_m_runs_main(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setattr(sys, "argv", ["app", "--version"])

    with pytest.raises(SystemExit) as exited:
        runpy.run_module("app", run_name="__main__")

    assert exited.value.code == EXIT_OK
    assert capsys.readouterr().out.startswith(f"{cli.PROG} ")
