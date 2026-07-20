# DRO2026 Asset Role Registry

## Purpose

The registry separates platform, launcher, weapon, muzzle, magazine and ammo identities. A display name is never used as an ID, and a vehicle class is never passed where Arma expects a weapon, muzzle or ammo class.

## Descriptor schema

```text
id
vehicleClass
launcherClass
weaponClass
muzzleName
magazineClass
ammoClass
roles[]
capabilities[]
airMuzzles[]
sensorComponents[]
side
sourcePatch
available
```

`DRO2026_fnc_buildAssetDescriptors` builds the cache once after faction and optional-addon resolution. `DRO2026_fnc_invalidateAssetRegistry` is the only supported rebuild trigger.

## Role rules

### ISR

A class receives ISR/sensor/laser capability only when verified config sensors/turrets/weapons expose it. Shahed/Geran are not automatically ISR. FP-2 without camera/sensor config is not labelled sensor/laser capable.

Pools are separated into small quad, tactical, long-range, reusable/expendable and MALE/HALE categories through `DRO2026_fnc_getISRPoolKey`.

### FPV

AP, AT, TI and fibre roles are explicit metadata. Fibre detection uses verified registry entries, inheritance from `frtz_drone_kvn_base_F` / `frtz_KVN_Base`, or the strict KVN class pattern. It does not depend on displayName.

The generated KVN candidate matrix covers:

```text
frtz_{B|O|I}_KVN_{AP|AT|AP_TI|AT_TI}{|_20KM|_25KM}
matching _Bag classes
frtz_Item_KVN_* metadata
```

Only classes confirmed through `isClass` are exposed as available.

### Long-range strike / loitering munition / decoy

These remain separate roles. A multimission class may expose several roles only if its real config supports them. Native warhead/ammo adapters are preferred; there is no generic MK82/Titan substitution.

### Interceptor

Each interceptor descriptor includes:

```text
canEngage
engagementRange
altitudeEnvelope
weaponMuzzles
airMuzzles
requiresLock
maxShots
launchMode
```

`airMuzzles` is derived from actual turret weapons/magazines/ammo and air-target capability. `DRO2026_fnc_requestInterceptor` rejects the request before reservation/materialization when no compatible muzzle exists.

## P1-Sun / Sting diagnostics

No classname is inferred from a display name. At runtime:

1. enumerate matching `CfgVehicles` candidates;
2. inspect turrets and inherited weapons;
3. inspect muzzles and magazines;
4. resolve magazine ammo;
5. inspect lock/air-target properties and sensors;
6. publish only compatible descriptors.

`DRO2026_fnc_dumpAssetClass` produces a structured diagnostic containing vehicles, weapons, magazines, ammo, turrets, sensors and available muzzles. Missing optional classes are logged and skipped without fallback to a fictitious string.

## Cache and publication

- registry build is guarded by an initialized flag;
- support catalog publication is separate from legacy `customSupports`;
- `customSupports` remains a de-duplicated array of non-empty strings;
- structured entries live in the DRO2026 catalog/maps;
- invalid/nil/object/nested-array entries are rejected before UI publication.

## Runtime availability

Static validation proves schema separation and feature-detection paths, not the actual user's loaded modset. The exact available list must be captured from the Arma runtime/RPT with the intended mod collection.
