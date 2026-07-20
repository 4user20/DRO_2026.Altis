# DRO2026 — матрица проверки Drone Warfare / Recon / Logistics

Обозначения: **PASS** — выполнено в текущей среде; **PENDING RUNTIME** — требует Arma 3 stable/dedicated и свежий RPT; **N/A** — инструмент недоступен.

## Статические проверки

| Проверка | Результат | Подтверждение |
|---|---|---|
| Python compileall | PASS | `python -m compileall -q tools` |
| Git whitespace/conflict preflight | PASS | `git diff --check` |
| Canonical validator | PASS | `python tools/validate_all_rc6.py` |
| Stages | PASS | 7/7, exit code 0 |
| Registered function files | PASS | 132/132 |
| Missing/unregistered calls | PASS | 0 |
| Include/delimiter errors | PASS | 0 |
| Critical/semantic findings | PASS | 0 |
| Single flight authority writer | PASS | только `fn_setFlightAuthority.sqf` |
| Remote execution allow-list | PASS | `CfgRemoteExec mode = 1`, no `mode = 2` |
| Virtual logistics ETA mutation | PASS | отсутствует |
| Hostile/POW modern entry points | PASS | отсутствуют в selectors/generator |
| HEMTT | N/A | unavailable/unconfigured |

## P0/P1 regression

| Сценарий | Статический статус | Runtime |
|---|---|---|
| requester ownership / `remoteExecutedOwner` | PASS | PENDING RUNTIME |
| malformed support DTO rejected | PASS | PENDING RUNTIME |
| duplicate `requestId` idempotent | PASS | PENDING RUNTIME |
| `isLiveContactSubject` never compares STRING to OBJECT | PASS | PENDING RUNTIME |
| invalid contact quarantined once | PASS | PENDING RUNTIME/RPT |
| no null/nested legacy support categories | PASS | PENDING UI |
| P1-Sun descriptor uses actual config/muzzle/ammo | PASS | PENDING MODSET |
| no hostile civilian inventory path | PASS | PENDING RPT |

## Runtime configurations

Все строки ниже требуют запуска:

| Конфигурация | Статус |
|---|---|
| Singleplayer | PENDING RUNTIME |
| Hosted MP | PENDING RUNTIME |
| Dedicated + 1 client | PENDING RUNTIME |
| Dedicated + multiple clients | PENDING RUNTIME |
| JIP | PENDING RUNTIME |
| Respawn | PENDING RUNTIME |
| Baseline modset | PENDING RUNTIME |
| Full user modset | PENDING RUNTIME |
| Without DDT | PENDING RUNTIME |
| Without FP-1/FP-2 addon | PENDING RUNTIME |
| Competing FPV mods / authority guard | PENDING RUNTIME |

## Support и multi-launch

Обязательные ручные сценарии:

- 10 последовательных FPV-запросов;
- map point, look point, contact и nearest capable group;
- AUTO/MANUAL;
- count 1/2/3/5/10;
- уникальный mission ID и stagger каждого аппарата;
- отказ без stock/range/terminal/compatible class;
- refund только незапущенной части;
- disconnect/death manual controller;
- player/Zeus terminal authority не оспаривается AI/DDT.

Статические reservation, unique-ID, stagger, tail-refund и authority contracts: **PASS**. Фактические spawn/collision/UI/RPT: **PENDING RUNTIME**.

## Flight

Проверить видео и RPT:

1. физическая пусковая/катапульта;
2. аппарат materialize в корректном transform;
3. crew создаётся на правильной locality;
4. CLIMB/MOVE route;
5. LOITER с явным выходом через `setCurrentWaypoint`;
6. короткий terminal segment;
7. отсутствие длительного vector-bank;
8. RTB/impact/lost cleanup.

Waypoint/authority static contracts: **PASS**. Engine physics: **PENDING RUNTIME**.

## Interceptors

- AUTO выбирает наиболее опасный живой hostile UAV;
- manual принимает конкретный object/netId;
- friendly/уничтоженная цель исключается;
- фактический air-capable muzzle найден;
- `reveal` выполняется на owner machine;
- `aimedAtTarget`/`canFire` предшествуют `fireAtTarget`;
- фиксируются MISS/KILL/LOST_TARGET/OUT_OF_RANGE/NO_COMPATIBLE_WEAPON.

Static adapter: **PASS**. P1-Sun/Sting actual addon tests: **PENDING RUNTIME**.

## Enemy recon-strike

Проверить:

- friendly HQ не раскрывается заранее;
- enemy ISR формирует search pattern;
- contact confidence/uncertainty меняются от наблюдения;
- strike разрешён только по свежему belief;
- player group атакуется только после подтверждения;
- lost contact деградирует в search/abort;
- incoming strike создаёт defence task.

Contact/belief schema: **PASS**. End-to-end AI behaviour: **PENDING RUNTIME**.

## Logistics

Для обеих сторон:

- ammo/fuel/repair/UAV demand;
- source reservation;
- 1–2 cargo vehicles и escort;
- staging и road route;
- no teleport/no ETA stock mutation;
- transfer только после прибытия живого vehicle;
- returning/refund при уничтоженном destination;
- no refund при уничтоженном convoy;
- several jobs до per-side limit;
- exhausted warehouse;
- destination destroyed enroute.

Physical-only transaction contract: **PASS**. AI road pathing/cargo locality/RPT: **PENDING RUNTIME**.

## Objectives и civilians

- выбор 1..5 primary objectives;
- пять целей без дублей;
- максимум две dynamic tasks;
- suspected marker не точный;
- mobile contact обновляет task;
- convoy/incoming strike/site relocation события;
- no POW/hostage/hostile civilian;
- ambient civilians только около settlements;
- reaction/despawn не видны игроку.

Selection/static contracts: **PASS**. Gameplay presentation/performance: **PENDING RUNTIME**.

## Performance comparison

В текущей среде engine benchmark не выполнялся. На runtime записать baseline и новую сборку:

```text
startup duration
diag_fps / diag_fpsMin
diag_activeSQFScripts
allUnits / vehicles / groups
active contacts / drone missions / logistics jobs / dynamic tasks
registry build count / support catalog publication count
```

Acceptance: нет per-site/per-object infinite loops, повторной registry build, повторной catalog publication, зависших guidance scripts и stale mission objects.

## RPT acceptance

Свежий RPT должен содержать ноль ошибок:

```text
fn_requestFPV
fn_isLiveContactSubject
fn_createContactRecord
addSupports / null category
P1Sun mapping
civilian inventory
remoteExec denied
undefined variable
expression error
watchdog freeze
```
