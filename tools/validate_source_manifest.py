from __future__ import annotations

from pathlib import Path
import json
import sys
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools" / "arma_source_manifest.json"
AUDIT = ROOT / "docs" / "ARMA_WIKI_CONTEXT7_AUDIT.md"

REQUIRED_SOURCES = {
    "bohemia-community-wiki": "https://community.bohemia.net/wiki/Category:Scripting_Commands_Arma_3",
    "acemod-arma3-wiki": "https://github.com/acemod/arma3-wiki",
    "stokys-scripting-guide": "https://stokys.github.io/web/",
    "context7-hemtt": "https://context7.com/brettmayson/hemtt",
}
ENGINE_KINDS = {"engine-command", "multiplayer-locality", "network-execution"}
AUTHORITATIVE = {"bohemia-community-wiki", "acemod-arma3-wiki"}
SECONDARY = "stokys-scripting-guide"


def main() -> int:
    errors: list[str] = []
    if not MANIFEST.is_file():
        print(f"Source manifest missing: {MANIFEST}")
        return 1

    try:
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Source manifest is unreadable: {exc}")
        return 1

    if data.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1")
    policy = data.get("policy", {})
    if policy.get("offlineValidation") is not True:
        errors.append("offlineValidation must remain true for deterministic CI")
    if policy.get("engineCommandSemantics") != [
        "bohemia-community-wiki",
        "acemod-arma3-wiki",
    ]:
        errors.append("engineCommandSemantics source order changed")
    if SECONDARY not in policy.get("missionScriptingGuidance", []):
        errors.append("Stokys guide missing from missionScriptingGuidance")

    sources = data.get("sources", [])
    by_id: dict[str, dict[str, object]] = {}
    for source in sources:
        if not isinstance(source, dict):
            errors.append("source entry is not an object")
            continue
        source_id = source.get("id")
        if not isinstance(source_id, str) or not source_id:
            errors.append("source entry has no id")
            continue
        if source_id in by_id:
            errors.append(f"duplicate source id: {source_id}")
        by_id[source_id] = source
        url = source.get("url")
        if not isinstance(url, str) or urlparse(url).scheme != "https":
            errors.append(f"{source_id}: source URL must use HTTPS")

    for source_id, expected_url in REQUIRED_SOURCES.items():
        source = by_id.get(source_id)
        if source is None:
            errors.append(f"missing required source: {source_id}")
        elif source.get("url") != expected_url:
            errors.append(f"{source_id}: unexpected URL {source.get('url')!r}")

    ace = by_id.get("acemod-arma3-wiki", {})
    if ace.get("dataBranch") != "dist":
        errors.append("acemod-arma3-wiki must record parsed data branch 'dist'")
    stokys = by_id.get(SECONDARY, {})
    blocked = set(stokys.get("mustNotOverride", [])) if isinstance(stokys, dict) else set()
    for token in {
        "engine-command-semantics",
        "multiplayer-locality",
        "return-types",
        "network-execution",
    }:
        if token not in blocked:
            errors.append(f"Stokys authority boundary missing: {token}")

    contracts = data.get("contracts", [])
    seen_contracts: set[str] = set()
    for contract in contracts:
        if not isinstance(contract, dict):
            errors.append("contract entry is not an object")
            continue
        contract_id = contract.get("id")
        kind = contract.get("kind")
        source_ids = contract.get("sources", [])
        validators = contract.get("validators", [])
        if not isinstance(contract_id, str) or not contract_id:
            errors.append("contract entry has no id")
            continue
        if contract_id in seen_contracts:
            errors.append(f"duplicate contract id: {contract_id}")
        seen_contracts.add(contract_id)
        if not isinstance(source_ids, list) or not source_ids:
            errors.append(f"{contract_id}: no sources")
            continue
        unknown = [source_id for source_id in source_ids if source_id not in by_id]
        if unknown:
            errors.append(f"{contract_id}: unknown sources {unknown}")
        if kind in ENGINE_KINDS and not (set(source_ids) & AUTHORITATIVE):
            errors.append(f"{contract_id}: engine contract lacks authoritative command source")
        if kind in ENGINE_KINDS and set(source_ids) == {SECONDARY}:
            errors.append(f"{contract_id}: Stokys cannot be sole engine authority")
        if not isinstance(validators, list) or not validators:
            errors.append(f"{contract_id}: no validators")
        for relative in validators:
            if not isinstance(relative, str) or not (ROOT / relative).is_file():
                errors.append(f"{contract_id}: validator missing: {relative!r}")

    if AUDIT.is_file():
        audit_text = AUDIT.read_text(encoding="utf-8", errors="replace")
        for expected_url in REQUIRED_SOURCES.values():
            if expected_url not in audit_text:
                errors.append(f"audit document does not cite {expected_url}")
        for token in (
            "primary",
            "machine-readable",
            "secondary",
            "детерминирован",
        ):
            if token.lower() not in audit_text.lower():
                errors.append(f"audit document misses source-policy token {token!r}")
    else:
        errors.append("audit document missing")

    if errors:
        print("Arma source manifest validation failed:")
        for error in sorted(set(errors)):
            print(f" - {error}")
        return 1

    print("Arma source manifest validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
