from pathlib import Path
import json, sys
ROOT=Path(__file__).resolve().parents[1]
read=lambda p:(ROOT/p).read_text(encoding='utf-8')
checks=[]
def check(name,ok,detail): checks.append({'name':name,'ok':bool(ok),'detail':detail})
cfg=read('dro2026/CfgFunctions.hpp')
selector=read('dro2026/functions/core/fn_selectConvoyClass.sqf')
shorad=read('dro2026/functions/core/fn_materializeStrategicSHORAD.sqf')
infra=read('dro2026/functions/core/fn_createStrategicInfrastructure.sqf')
sanitize=read('dro2026/functions/core/fn_sanitizeLegacyPools.sqf')
layered=read('dro2026/functions/core/fn_spawnLayeredAA.sqf')
point=read('dro2026/functions/core/fn_spawnPointDefenceGroup.sqf')
role_selector=read('dro2026/functions/core/fn_getSideRoleClass.sqf')
role_contract=read('dro2026/functions/core/fn_isAssetAllowedForRole.sqf')
mission=read('mission.sqm')
check('functions registered','class selectConvoyClass {};' in cfg and 'class materializeStrategicSHORAD {};' in cfg,'new helpers must be compiled')
check('convoy prefers modded', 'count _specializedModded > 0' in selector and 'count _modded > 0' in selector and 'vanillaFallback' in selector,'vanilla is fallback only')
check('cargo specialization','case "FUEL"' in selector and 'ARTILLERY_AMMO' in selector,'cargo type should influence class choice')
check('convoy roles use selector','CONVOY_CARGO_' in role_selector and 'CONVOY_ESCORT_' in role_selector and 'DRO2026_fnc_selectConvoyClass' in role_selector,'all convoy callers pass through the central role resolver')
check('personnel transport accepted for logistics','TRANSPORT_PERSONNEL' in role_contract.split('case "LOGISTICS_POOL"')[1],'valid cargo-bed transports must not be rejected after selection')
check('shorad plan materialized','DRO2026_fnc_materializeStrategicSHORAD' in infra and 'SHORAD_FORMATION_MATERIALIZED' in shorad,'virtual plan must create bounded physical layers')
check('shorad bounded','(_maxSites max 1) min 4' in shorad,'physical SHORAD sites remain bounded')
check('broken external classes blocked','b_afougf_old_ZU23' in sanitize and 'B_UAArmy_CAT1A2_01' in sanitize,'known CBA warning storms are quarantined')
check('aa consumers honor blocklist','DRO2026_runtimeBlockedVehicleClasses' in layered and 'DRO2026_runtimeBlockedVehicleClasses' in point,'all AA materializers reject quarantined classes')
check('mp header matches roles','maxPlayers=8;' in mission,'mission declares eight available roles')
failed=[c for c in checks if not c['ok']]
print(json.dumps({'validator':'runtime-telemetry-remediation','passed':len(checks)-len(failed),'total':len(checks),'checks':checks},ensure_ascii=False,indent=2))
sys.exit(1 if failed else 0)
