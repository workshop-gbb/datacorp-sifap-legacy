from __future__ import annotations

import os
import re
import shutil
import subprocess
import time

import pytest

from conftest import DDM_DIR, LAB, LOAD_SCRIPT, PROVISIONING, SEED_DIR, WORK_DIR

CONTAINER = "sifap-ada-tests"
IMAGE = "softwareag/adabas-ce:7.4.0"
EXPECTED_COUNTS = {150: 500, 151: 6, 152: 2000, 153: 200}


def docker_available():
    return shutil.which("docker") and subprocess.run(["docker", "info"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def image_available():
    return subprocess.run(["docker", "image", "inspect", IMAGE], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def docker(*args, check=True, **kwargs):
    return subprocess.run(["docker", *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=check, **kwargs)


@pytest.mark.live
def test_should_load_all_sifap_files_with_zero_incorrect_records():
    if not docker_available():
        pytest.skip("Docker is unavailable; skipping live Adabas CE loader test")
    if not image_available():
        pytest.skip(f"Docker image {IMAGE} is unavailable; skipping live Adabas CE loader test")

    docker("rm", "-f", CONTAINER, check=False)
    try:
        docker("run", "-d", "--platform", "linux/amd64", "--name", CONTAINER, "-e", "ACCEPT_EULA=Y", IMAGE)
        deadline = time.monotonic() + int(os.environ.get("SIFAP_LIVE_ADABAS_READY_TIMEOUT", "900"))
        while time.monotonic() < deadline:
            health = docker("exec", CONTAINER, "sh", "/usr/local/bin/healthcheck.sh", check=False)
            if health.returncode == 0:
                break
            time.sleep(5)
        else:
            pytest.fail("Timed out waiting for Adabas CE healthcheck")

        work = WORK_DIR / "live"
        shutil.rmtree(work, ignore_errors=True)
        work.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env.update(
            {
                "ADABAS_CONTAINER": CONTAINER,
                "ADABAS_DBID": "1",
                "PROVISIONING_DIR": str(PROVISIONING),
                "SIFAP_CORPUS_DIR": str(DDM_DIR.parent),
                "DDM_DIR": str(DDM_DIR),
                "SEED_DIR": str(SEED_DIR),
                "SIFAP_PROVISIONING_WORK_DIR": str(work),
                "SIFAP_ADABAS_READY_TIMEOUT": "120",
            }
        )
        result = subprocess.run(["bash", str(LOAD_SCRIPT)], cwd=LAB.parents[1], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=True)
        output = result.stdout

        records_read = [int(x) for x in re.findall(r"Number of records read\s*:\s*(\d+)", output)]
        incorrect = [int(x) for x in re.findall(r"Number of incorrect records\s*:\s*(\d+)", output)]
        added = {int(fnr): int(count) for fnr, count in re.findall(r"file\s+(\d+),\s+(\d+)\s+records added", output)}

        assert records_read == list(EXPECTED_COUNTS.values())
        assert incorrect == [0, 0, 0, 0]
        assert added == EXPECTED_COUNTS
        assert "adalod is not present" in output
    finally:
        docker("rm", "-f", CONTAINER, check=False)
