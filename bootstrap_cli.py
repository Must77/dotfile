#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
HELP = """usage: ./init_ubuntu [--target=NAME] [--download=NAME] [--script=NAME]

  --target=NAME  run bootstrap/NAME
  --download=NAME  run download/NAME
  --script=NAME  run script/NAME
  -h, --help     show this help
"""


args = sys.argv[1:]
if not args:
    print(HELP, end="")
    raise SystemExit

paths = []
for arg in args:
    if arg in ("-h", "--help"):
        print(HELP, end="")
        raise SystemExit
    if arg.startswith("--target="):
        directory, name = "bootstrap", arg.split("=", 1)[1]
    elif arg.startswith("--download="):
        directory, name = "download", arg.split("=", 1)[1]
    elif arg.startswith("--script="):
        directory, name = "script", arg.split("=", 1)[1]
    else:
        raise SystemExit(f"unknown argument: {arg}\n\n{HELP}")

    path = ROOT / directory / name
    if not name or name.startswith(".") or Path(name).name != name or not path.is_file():
        raise SystemExit(f"unknown {directory} entry: {name}")
    paths.append(path)

shell = 'for file in "$@"; do echo "==> Running $file"; source "$file"; done'
subprocess.run(
    ["bash", "-Eeuo", "pipefail", "-c", shell, "init_ubuntu", *map(str, paths)],
    check=True,
)
