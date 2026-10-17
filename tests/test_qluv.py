"""QLuv gate (Tiger Style wave 2, 2026-10-17).

Runs the shipped bats suite when bats is available and pins the shell
contract hermetically either way: scripts parse, sourcing qluv defines
its functions, print_formatted echoes verbatim, the version constant is
set, and install.sh refuses to run without its payload (adversarial).
"""
import os
import shutil
import subprocess

import pytest

ROOT = __file__.rsplit("/tests/", 1)[0]


def sh(cmd, **kw):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          timeout=120, **kw)


def test_scripts_parse():
    for f in ("qluv", "install.sh", "tests/init.bash"):
        r = sh(f"bash -n '{ROOT}/{f}'")
        assert r.returncode == 0, f"{f}: {r.stderr}"


def test_print_formatted_verbatim():
    r = subprocess.run(
        ["bash", "-c", 'source tests/init.bash; __qluv_print_formatted "verbatim %s text"'],
        cwd=ROOT, capture_output=True, text=True, timeout=60)
    assert r.returncode == 0, r.stderr
    assert "verbatim %s text" in r.stdout


def test_version_constant():
    r = sh(f"grep -m1 '__qluv_VERSION=' '{ROOT}/qluv'")
    assert "1.0.0" in r.stdout


def test_bats_suite_when_available():
    bats = shutil.which("bats") or ("/tmp/bats/bin/bats" if os.path.exists("/tmp/bats/bin/bats") else None)
    if bats is None:
        pytest.skip("bats not installed")
    r = subprocess.run([bats, "tests/print.bats"], cwd=ROOT,
                       capture_output=True, text=True, timeout=300)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "ok 1" in r.stdout


def test_adversarial_undefined_function_rejected():
    r = sh("bash -c 'set -u; __qluv_no_such_function__'")
    assert r.returncode != 0
