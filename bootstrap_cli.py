#!/usr/bin/env python3
"""bootstrap 脚本调度器：按分类运行 dotfile 中的脚本。"""
import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CATEGORIES = {"--target": "bootstrap", "--download": "download", "--script": "scripts"}


def available(folder):
    directory = ROOT / folder
    if not directory.is_dir():
        return []
    return sorted(p.name for p in directory.iterdir() if p.is_file())


def path_type(folder):
    def resolve(name):
        path = ROOT / folder / name
        if not path.is_file():
            names = ", ".join(available(folder)) or "（空）"
            raise argparse.ArgumentTypeError(f"{folder}/{name} 不存在，可用: {names}")
        return path

    return resolve


def build_parser():
    lines = ["可用目标:"]
    for flag, folder in CATEGORIES.items():
        lines.append(f"  {flag:<11} ({folder}/) {', '.join(available(folder)) or '（空）'}")
    lines += [
        "",
        "示例:",
        "  ./init_ubuntu                                   # 基础安装（apt 包 / ssh / nvm / node / tldr）",
        "  ./init_ubuntu --target devops --script no_proxy",
    ]
    return argparse.ArgumentParser(
        prog="./init_ubuntu",
        description="运行 dotfile 中的初始化脚本（无参数时显示本帮助）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="\n".join(lines),
    )


def main():
    parser = build_parser()
    for flag, folder in CATEGORIES.items():
        parser.add_argument(
            flag,
            dest="paths",
            action="append",
            type=path_type(folder),
            metavar="NAME",
            help=f"运行 {folder}/ 下的脚本，可重复",
        )
    paths = parser.parse_args().paths
    if not paths:
        parser.error("没有指定任何目标")
    for path in paths:
        print(f"==> 运行 {path.relative_to(ROOT)}", flush=True)
        returncode = subprocess.call(["bash", "-Eeuo", "pipefail", str(path)])
        if returncode:
            raise SystemExit(returncode)


if __name__ == "__main__":
    main()
