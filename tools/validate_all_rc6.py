from __future__ import annotations

from argparse import ArgumentParser
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

parser = ArgumentParser(description="Run all DRO 2026 RC6 static and optional RPT gates")
parser.add_argument("--rpt", action="append", default=[])
parser.add_argument("--require-hemtt", action="store_true")
args = parser.parse_args()

commands: list[list[str]] = [
    [sys.executable, str(ROOT / "tools" / "validate_source_manifest.py")],
    [sys.executable, str(ROOT / "tools" / "validate_arma_wiki_contracts.py")],
    [sys.executable, str(ROOT / "tools" / "validate_side_contracts.py")],
    [sys.executable, str(ROOT / "tools" / "validate_orientation_contracts.py")],
    [sys.executable, str(ROOT / "tools" / "validate_runtime_transactions.py")],
]

base = [sys.executable, str(ROOT / "tools" / "validate_rc6.py")]
if args.require_hemtt:
    base.append("--require-hemtt")
for rpt in args.rpt:
    base.extend(["--rpt", rpt])
commands.append(base)

if args.rpt:
    rpt = [sys.executable, str(ROOT / "tools" / "validate_rc6_rpt_stabilization.py")]
    for path in args.rpt:
        rpt.extend(["--rpt", path])
    if args.require_hemtt:
        rpt.append("--require-hemtt")
    commands.append(rpt)

results: list[dict[str, object]] = []
failed = False
for command in commands:
    process = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    results.append(
        {
            "command": " ".join(command),
            "exitCode": process.returncode,
            "output": process.stdout.strip(),
        }
    )
    failed = failed or process.returncode != 0

print(json.dumps({"validator": "all-rc6", "failed": failed, "results": results}, ensure_ascii=False, indent=2))
sys.exit(1 if failed else 0)
