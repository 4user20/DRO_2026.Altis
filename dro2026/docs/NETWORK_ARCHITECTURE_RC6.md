# DRO 2026 RC6 — capability-network architecture

Runtime version: `1.5.0-rc6-capability-network`.

## Core rule

The mission world owns capabilities. Objectives do not own the world.

```text
Theater layout
  -> capability nodes and supply edges
  -> contacts / beliefs / events
  -> doctrine and operation intents
  -> tactical directors materialize actions
  -> objective adapters expose relevant effects to legacy task UI
```

Legacy AO, faction selection, weather, player setup and task UI are retained. The `dro2026` layer is server-owned.

## State ownership

Server-owned:

- `DRO2026_theaterLayout` — geography only;
- `DRO2026_networkNodes` — persistent capability records;
- `DRO2026_networkEdges` — supply relationships;
- `DRO2026_contacts` — PLAYER/ENEMY belief records;
- `DRO2026_eventLog` — bounded operational history;
- `DRO2026_actionIntents` and `DRO2026_currentIntent` — OODA decisions;
- `DRO2026_operationState` — phase, doctrine, alert and score;
- `DRO2026_supplyLanes` — virtual/physical deliveries.

Clients own UI only: HQ voice, markers, incoming-drone warnings, UAV terminal actions and rendered status.

## Capability nodes

Initial enemy network:

- `NODE_ENEMY_HQ` — command and replacements;
- `NODE_LOGISTICS_01` — source stocks and delivery dispatch;
- `NODE_ARTILLERY_01` — artillery ammunition and mobility;
- `NODE_FPV_FORWARD_01` — FPV kits, batteries and relocation;
- `NODE_DRONE_REAR_01` — long-range drones and fuel;
- `NODE_EW_01` — local jamming and emissions;
- `NODE_AA_LONG_01` — long-range radar, channels and missile stock;
- `NODE_AA_SHORAD_01` — point defence and missile stock.

A node survives physical cleanup. Physical references may disappear, but logical status and `destroyedAt` remain available for phase calculation, recovery and AAR.

## Supply graph

Edges contain `from`, `to`, cargo types, capacity, travel time, route, risk, interdiction pressure and delivery schedule.

Cargo types currently used:

- `ARTILLERY_AMMO`;
- `FPV_KITS`;
- `LONG_RANGE_DRONES`;
- `FUEL`;
- `BATTERIES`;
- `EW_BATTERIES`;
- `AA_MISSILES`;
- `RADAR_PARTS`;
- `INFANTRY_REPLACEMENTS`;
- `MEDICAL`.

A delivery starts virtually. It materializes only near a player or a relevant player contact and only while the physical convoy budget permits it. Arrival credits only the destination node. Interdiction raises edge risk, delays the next delivery and increases escort level.

## Contacts v2

Compatibility fields `position` and `kind` remain, but the canonical fields are:

- `positionMean`;
- `uncertaintyRadius`;
- `confidence`;
- `classification`;
- `sources` and `sourceQuality`;
- `velocityEstimate`;
- `bdaState`;
- `falseContactProbability`;
- optional `subjectId` linking the contact to a network node.

Source profiles have different confidence decay and uncertainty growth. Supported sources include visual observation, AI knowledge, micro/tactical/HALE UAV, ELINT, civilian reports and counterbattery estimates.

BDA states:

```text
DETECTED
CONFIRMED
ENGAGED
PROBABLY_DISABLED
PROBABLY_DESTROYED
CONFIRMED_DESTROYED
```

Destroyed contacts are retained for AAR instead of being deleted immediately.

## EW, AA and air window

EW is spatial. Jamming depends on emitter mode, distance, terrain masking and jammer component health. ISR may provoke a temporary `BURST` emission and receive an uncertain ELINT contact.

AA uses real Arma sensors and weapons. The logical controller tracks:

- `emissionState`;
- `trackingChannels`;
- `activeTracks`;
- node `AA_MISSILES` stock;
- real `Fired` events.

Decoys occupy tracks and expose emissions. Air support evaluates `PERMISSIVE`, `CONTESTED` or `CLOSED` from AA, EW, weather, friendly proximity and civilian risk.

## Operation phases and intents

Phases:

```text
RECON -> DISRUPTION -> EXPLOITATION -> COUNTERATTACK
```

Transitions are derived from intelligence quality, alert and network health.

Doctrine profiles weight candidate actions:

- `DRONE_HEAVY`;
- `ARTILLERY_HEAVY`;
- `DEFENSIVE_NETWORK`;
- `MOBILE_RESERVES`.

The operation director proposes one intent at a time:

- `FPV_ATTACK`;
- `ARTILLERY_FIRE`;
- `LONG_RANGE_ATTACK`;
- `REINFORCE`;
- `ROUTE_ADAPT`.

Tactical directors execute the intent only if contacts, node status, stocks, cooldowns and physical budgets still allow it.

## Objective adapter contract

`objective*.sqf` files remain compatible with legacy task UI. They must:

1. materialize or observe an existing network node/edge;
2. place `nodeId`, `edgeId`, `cargoType` or `deliveryId` in objective metadata;
3. complete an effect rather than apply unrelated global fixed penalties;
4. emit an operation event;
5. never delete strategic history.

## Validation

Use either command; the old entrypoint delegates to RC6:

```bash
python3 tools/validate_rc6.py
python3 tools/validate_rc4.py
```

Optional RPT scan:

```bash
python3 tools/validate_rc6.py --rpt /path/to/arma3_x64_*.rpt
```

The validator checks function registration, includes/delimiters, faction safety, server authority, persistent sites, Contacts v2/BDA, state-driven objective selection, artillery causality, node logistics, EW/AA and support ROE.

## Runtime test priority

1. start mission with a large mod preset and `-showScriptErrors`;
2. verify network creation and no undefined variables;
3. provoke EW with ISR and confirm an uncertainty ellipse;
4. intercept a delivery and verify only its destination stock is denied;
5. launch decoys and observe AA emission/missile events;
6. verify CAS aborts if the air window closes;
7. verify enemy artillery never fires from exact server-local player coordinates;
8. destroy a capability and confirm it remains in AAR as `DESTROYED`.
