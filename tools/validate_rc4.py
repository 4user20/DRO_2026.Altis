from pathlib import Path

_validator = Path(__file__).with_name("validate_rc6.py")
exec(compile(_validator.read_text(encoding="utf-8"), str(_validator), "exec"))
