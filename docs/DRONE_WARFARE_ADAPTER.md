# DRO 2026 Drone Warfare Adapter

## Architecture

This is an adapter, not a copy of Drongo's Drone Tweaks (DDT). The mission does not include PBO source and never replaces a `DDT_fnc_*` function.

DRO owns group selection, quotas, side/faction rules, server locality, contact fusion/decay, downstream AI Director decisions, clean-room one-off FPV control and EW semantics. DDT, when loaded, owns backpack/item recognition, deployment/materialization and recon/loiter/FPV/bomber/RTB behavior.

## Reference audit

Clean-room references:

- `DrongosDroneTweaks(1).pbo`: `0c38acdf8d9d6f4a55704f87e2ce276413d11e363426758011ce6214ce4a662f`
- `fn_fpvLogic(1).sqf`: `f6ca01bc0c62bdc350358a63528accd2cd917fc4fd8ed22679b6ab335c2155b1`
- `fn_initModule(1).sqf`: `7b1f2c13f61ac60834fdbd64cbcc462370ab953d34db5bcf36189102d6ac36c9`

Confirmed in the supplied DDT build:

- detection uses `CfgPatches >> DrongosDroneTweaks` and readiness uses `ddtReady`;
- deployed UAVs receive `ddtTasked = true`;
- target helpers use actual `targets [true, range]` knowledge;
- startup lists `DRA_UAV_01_0`, while `AI_FPV.sqf` checks `DRA_UAV_01_O`;
- `AR2_FPV/config.txt` is not included by root `config.cpp`;
- post-init starts deploy loops on every machine and the recon/attack loops have no `isServer` guard.

To preserve locality without changing DDT, native DDT group scanners are kept inert with an empty public `ddtDeploySides`. `DRO2026_fnc_dispatchDDTDrones` calls DDT's compiled deploy and AI functions only on the server and only for DRO-selected groups.

## Optional class registry

`DRO2026_fnc_initializeDroneRegistry` verifies `CfgVehicles`, `CfgWeapons` and `CfgMagazines`. Missing mods are skipped without an RPT error. The supplied DDT PBO defines behavior/modules, not the referenced drone assets, so static inspection cannot truthfully label optional KVN/Crocus/UAFPV/Mavic/Switchblade/WS/DRA classes as loaded.

Runtime availability is exposed as:

```sqf
DRO2026_availableDroneClasses
```

The registry covers all `frtz_{B|O|I}_KVN_{AP|AT|AP_TI|AT_TI}{|_20KM|_25KM}` vehicles, matching `_Bag` carriers, `frtz_Item_KVN_*`, and optional roots `frtz_drone_kvn_base_F` / `frtz_KVN_Base`. It also verifies DDT candidates, tries `DRA_UAV_01_O` before compatibility fallback `DRA_UAV_01_0`, and uses abandoned `DDT_AR2_FPV_AP_backpack_O` only when `isClass` succeeds.

`frtz_Item_*` classes are retained as registry/intel metadata. They are not issued to DDT groups unless the external DDT build exposes an explicit item-to-vehicle conversion; verified `_Bag` classes with a valid `assembleTo` remain the safe deployment path.

## Configuration and fallback

The adapter waits for `ddtReady` with a finite timeout. DDT absent or timed out means the existing DRO fallback remains active. Cycle/range settings are only filled when missing unless `DRO2026_DDT_OVERRIDE_SETTINGS = true`.

Unassigned UAV takeover is disabled by default and cannot be enabled while the clean-room fallback is active. DDT's native jammer directly disconnects terminals, drains fuel and destroys crew without a fiber-optic hook; the adapter disables DDT jammer-pack recognition by default and lets DRO own EW. `DRO2026_fnc_getJammingAtPosition` explicitly returns zero for KVN/fiber-optic platforms, while physical damage, collision, hard-kill and cleanup remain effective.

## Intel and infoshare

Contacts are created only from actual `targets` and `knowsAbout`, then fused into the existing `DRO2026_contacts` model. Sources include `UAV_RECON`, `UAV_FPV`, `UAV_BOMBER`, `UAV_FIBEROPTIC_AP`, `UAV_FIBEROPTIC_AT`, `UAV_FIBEROPTIC_TI`, `INFOSHARE` and `GROUND_AI`. Existing sensor decay removes stale precision.

Dynamic infoshare is bounded by side, radius, live radio operators, simulation state and a per-cycle cap. Shared knowledge/confidence is degraded.

## Clean-room FPV fallback

`DRO2026_fnc_fpvAttackController` is server scheduled per drone. It uses namespaced state, target velocity prediction, smooth terrain-aware descent, external-control yield, stuck recovery and bounded final detonation. It refuses `ddtTasked` UAVs. KVN platforms bypass RF/EW degradation but remain physically destructible.

## Validation

```bash
python tools/validate_all_rc6.py
```

The canonical gate now includes Drone Warfare contracts, recursive SQF/include checks, registration/call checks, side/locality/orientation checks, launch materialization checks and stale RC-path checks. Arma 3 runtime and RPT testing remain required for DDT-present and DDT-absent modsets.
