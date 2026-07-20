# RC6 launch, site and lifecycle audit

Дата сверки: 2026-07-20.

## Иерархия источников

1. **Bohemia Interactive Community Wiki** — первичный источник по engine commands, locality, ownership и сетевому выполнению.
2. **`acemod/arma3-wiki` (`dist`)** — machine-readable mirror сигнатур и описаний Arma 3 commands.
3. **Arma 3 Scripting Guide by David Stocek** — вторичный источник по структуре миссии, event scripts и организации SQF; не переопределяет BI semantics/locality/return types.
4. **Context7 HEMTT** — только tooling reference для parser/analyze/build integration.

Машиночитаемая политика: `tools/arma_source_manifest.json`.

## Site identity

Каждая долговечная физическая площадка создаётся через `DRO2026_fnc_createSiteRecord`, проходит `DRO2026_fnc_validateSiteRecord` и получает стабильный `id`.

`DRO2026_fnc_isSiteOperational` перечитывает фактическую запись из `DRO2026_sites` по этому `id` и отклоняет:

- отсутствующую запись;
- `DESTROYED`, `DISABLED`, `CANCELLED`, `COMPLETED`;
- `RELOCATING`, если caller не разрешил уже начатой операции продолжить guidance;
- terminal `physicalState`;
- площадку с погибшим оператором.

Новые airframes нельзя materialize из relocating/terminal site. Уже стартовавший FPV может сохранить guidance во время переезда расчёта; уже стартовавший дальний аппарат автономен.

## Reservation и materialization

События разделены семантически:

- `DRONE_LAUNCH_RESERVED` — stock/slot зарезервирован, но физический аппарат ещё не гарантирован;
- `DRONE_LAUNCHED` — объект и, если требуется, совместимый crew реально созданы;
- `DRONE_RECOVERED` / `DRONE_LOST` — итог ISR recovery lifecycle.

`DRONE_LAUNCHED` выпускается только launcher-функциями после успешной materialization:

- `fn_launchFPVStrike.sqf`;
- `fn_launchLongRangeStrike.sqf`;
- `fn_launchISR.sqf` для ISR.

Request/director-код не имеет права объявлять reservation фактическим запуском.

## FPV

- manual, friendly automation и enemy director выбирают live contact и operational site;
- salvo повторно проверяет mission ending, operator, site и contact перед каждым аппаратом;
- незапущенный хвост возвращается в stock;
- отдельный launcher возвращает единицу stock при materialization failure;
- relocation counter увеличивается только после фактического `DRONE_LAUNCHED`, а не при reservation;
- новый запуск из `RELOCATING` site запрещён;
- уже стартовавший FPV допускает guidance при relocation, но прекращается при terminal site/operator state;
- `setDir` не смешивается с `setVectorDirAndUp`.

## Long-range

- manual и director paths резервируют stock только после class/profile/contact/site preflight;
- named/exact class остаётся side-correct;
- каждый airframe salvo повторно проверяет source site, operator, node и live subject;
- незапущенный хвост возвращается;
- airframe или штатный ammo-projectile публикует actual launch только после реального `createVehicle`;
- после materialization аппарат автономен и не удаляется из-за последующего изменения source-site status;
- coordinate-only player designation остаётся допустимой целью; physical/site subject обязан пройти common live-subject resolver.

## ISR

- request привязан к stable `siteId`;
- stock резервируется до materialization и возвращается при pre-launch failure;
- успешный launch не означает автоматического возврата airframe;
- `friendlyISRStock` восстанавливается только после фактического достижения recovery radius до deadline;
- потеря UAV, operator/site failure или mission ending формируют `DRONE_LOST`;
- HC/`VirtualMan_F` не участвует в observation и safety/player selection.

## Objective и strategic site lifecycle

- canonical objectives используют schema site records, `siteId`, rollback и terminal status;
- failed adapter не загрязняет global objective history;
- retry использует локальный список попыток;
- stale selected opportunity очищается;
- отсутствующий/terminal capability не считается активным;
- deterministic fallback сначала выбирает active physical node, затем vanilla-materializable adapter;
- после исчерпания четырёх разных adapters публикуется `OBJECTIVE_SELECTION_EXHAUSTED`, а не фиктивный `CUT_REAR` по мёртвому HQ.

## AAR и status

AAR schema 3 различает:

- launch reservations;
- actual launch events;
- FPV / long-range / friendly ISR / enemy ISR launch counts;
- ISR recovered/lost;
- cancelled nodes and deliveries;
- objective materialization failures/exhaustion.

Status query привязан к `remoteExecutedOwner` и `owner requester`; spoofed, virtual и wrong-side callers отклоняются.

## Детерминированные gates

```bash
python3 tools/validate_all_rc6.py
python3 tools/validate_all_rc6.py --rpt /path/to/new.rpt
```

Canonical runner включает:

- source manifest;
- BI/ACE command contracts;
- side/faction contracts;
- orientation contracts;
- runtime transactions;
- group lifecycle;
- site lifecycle;
- status/AAR authority;
- launch reservation/materialization.

Static gates не заменяют Arma runtime. Перед `Ready for review` обязательны SP, hosted MP, dedicated MP, Headless Client slot и свежий RPT с `-showScriptErrors`.
