#!/usr/bin/env python3
import argparse
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent

def path_type(folder):
    return lambda name: ROOT / folder / name

parser = argparse.ArgumentParser(prog="./init_ubuntu")
parser.add_argument(
    "--target", dest="paths", action="append", type=path_type("bootstrap")
)
parser.add_argument(
    "--download", dest="paths", action="append", type=path_type("download")
)
parser.add_argument(
    "--script", dest="paths", action="append", type=path_type("scripts")
)
paths = parser.parse_args().paths or []

for path in paths:
    print(f"==> Running {path}", flush=True)
    returncode = subprocess.call(["bash", "-Eeuo", "pipefail", str(path)])
    if returncode:
        raise SystemExit(returncode)
