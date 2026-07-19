from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
commands = [
    [sys.executable, str(ROOT / "tools" / "validate_rc6.py"), *sys.argv[1:]],
    [sys.executable, str(ROOT / "tools" / "validate_ai_integration.py")],
]
failed = False
for command in commands:
    result = subprocess.run(command, cwd=ROOT, check=False)
    failed = failed or result.returncode != 0
raise SystemExit(1 if failed else 0)
