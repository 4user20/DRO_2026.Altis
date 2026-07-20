# RC6 — Arma command, scripting-guide and tooling audit

Дата проверки: 2026-07-20  
Ветка: `fix/post-merge-audit-hardening`  
PR: #7

## Метод и иерархия источников

Проверка выполняется по пяти слоям:

1. фактический diff ветки относительно `main`;
2. полный проход по связанным `support`, `directors`, `objectives`, `core` и logistics-путям;
3. **primary** command/locality semantics из Bohemia Interactive Community Wiki;
4. **machine-readable** command data из `acemod/arma3-wiki`;
5. **secondary** mission-scripting guidance от Stokys и Context7/HEMTT для parser/build tooling.

Источник и его роль фиксируются в `tools/arma_source_manifest.json`. Проверка manifest выполняется локально и детерминированно: CI не зависит от доступности внешних сайтов. URL и authority boundaries пересматриваются вручную при изменении engine-contract rules.

### Правила авторитетности

- Семантика SQF-команд, locality, return types и network execution берутся из BI Wiki и перепроверяются по parsed command data `acemod/arma3-wiki`.
- Репозиторий ACE хранит данные о командах в пригодном для машинной обработки формате; parsed files публикуются в ветке `dist`.
- Stokys используется для структуры mission scripts, event scripts и учебных примеров. Он **не** может переопределять engine-command semantics, locality, return types или remote execution contracts.
- Context7 не является официальным справочником SQF-команд. Его HEMTT-индекс используется только для Arma-aware parser/analyzer/build tooling.
- Ни один статический источник не заменяет runtime-проверку в Arma 3 и анализ свежего RPT.

## Использованные источники

### Primary engine reference

- Bohemia Interactive Community Wiki — Arma 3 scripting commands:
  - https://community.bohemia.net/wiki/Category:Scripting_Commands_Arma_3
- `createVehicle` / array syntax:
  - https://community.bohemia.net/wiki/createVehicle_array
- `allPlayers`:
  - https://community.bohemia.net/wiki/allPlayers
- Headless Client:
  - https://community.bohemia.net/wiki/Arma_3_Headless_Client
- `isPlayer`:
  - https://community.bohemia.net/wiki/isPlayer
- `remoteExecutedOwner` / `isRemoteExecuted`:
  - https://community.bohemia.net/wiki/remoteExecutedOwner
  - https://community.bohemia.net/wiki/isRemoteExecuted
- `remoteExec` / `CfgRemoteExec`:
  - https://community.bohemia.net/wiki/remoteExec
  - https://community.bohemia.net/wiki/Arma_3:_CfgRemoteExec
- multiplayer locality:
  - https://community.bohemia.net/wiki/Locality_in_Multiplayer
- `createVehicleCrew` / `deleteVehicleCrew` / `deleteGroup`:
  - https://community.bohemia.net/wiki/createVehicleCrew
  - https://community.bohemia.net/wiki/deleteVehicleCrew
  - https://community.bohemia.net/wiki/deleteGroup
- `setDir`, `setVectorDirAndUp`, `setVectorDir`:
  - https://community.bohemia.net/wiki/setDir
  - https://community.bohemia.net/wiki/setVectorDirAndUp
  - https://community.bohemia.net/wiki/setVectorDir
- `disableAI`:
  - https://community.bohemia.net/wiki/disableAI
- `doTarget`, `doFire`, `fireAtTarget`:
  - https://community.bohemia.net/wiki/doTarget
  - https://community.bohemia.net/wiki/doFire
  - https://community.bohemia.net/wiki/fireAtTarget
- `triggerAmmo`:
  - https://community.bohemia.net/wiki/triggerAmmo

### Machine-readable command data

- ACE Mod Arma 3 Wiki:
  - https://github.com/acemod/arma3-wiki
- Parsed command data branch:
  - https://github.com/acemod/arma3-wiki/tree/dist

### Secondary mission-scripting guide

- Arma 3 Scripting Guide by David Stocek:
  - https://stokys.github.io/web/
- Advanced/event-script overview:
  - https://stokys.github.io/web/ba/index.html

### Parser/build tooling

- Context7 HEMTT index:
  - https://context7.com/brettmayson/hemtt

## Проверочная матрица

| Область | Документированный контракт | Найденный дефект | Исправление |
|---|---|---|---|
| `createVehicle [..., "FLY"]` | empty airframe не должен полагаться только на special placement | aircraft/UAV создавались пустыми и могли падать до нормальной инициализации | explicit ATL/ASL position, initial velocity и crew validation |
| `allPlayers` | содержит HC/virtual clients | HC участвовал в sensor, objective, relocation, logistics и target selection | все server-side выборки фильтруют `VirtualMan_F` |
| `isPlayer` / remote owner | HC может проходить как player, owner может быть нулевым | одного `isPlayer` недостаточно для support authority | virtual rejection, dedicated owner range и binding к `owner _requester` |
| vector orientation | direction/up должны образовывать согласованный frame | pitched direction использовал fixed world-up; `setDir` смешивался с vector orientation | ортонормальный right/up через cross product; vector-guided object не получает `setDir` |
| exact class | materialization должна быть fail-closed | exact profile мог перейти в AUTO/fallback | catalog + config + side validation и refund |
| side config | class side обязан совпадать с выбранной стороной | GUER сваливался в EAST или протекал в другие pools | `WEST`/`EAST`/`GUER` roles и единый `getSideRoleClass` |
| crew/group lifecycle | server-local vehicle cleanup должен удалить crew и empty group | failed materialization оставлял group/object state | atomic factories и rollback для HQ, AA, drone teams, artillery, CAS и convoys |
| target lifecycle | strike должен оставаться связан с live subject/BDA | duplicated resolver расходился между directors | единый `isLiveContactSubject`, включая `CANCELLED` |
| FPV accounting | failed airframe и unlaunched tail возвращают reservation | enemy FPV терял node stock при materialization failure | individual node refund + salvo-tail refund |
| long-range accounting | airframe/fuel резервируются per launch | пакет списывался заранее без полной повторной проверки | live subject/node/operator check перед каждым airframe |
| CAS package | каждый ещё не запущенный sortie должен возвращаться | второй борт мог стартовать после mission ending/потери цели | preflight перед каждым aircraft и tail refund |
| artillery loop | long-lived loop обязан завершаться с mission | background loop мог продолжить fire/relocation | mission-ending guards во всех wait/while phases |
| convoy objective | dispatch/materialization/delivery должны быть одной транзакцией | refund, site state и physical cleanup расходились | validated site, `CANCELLED`/`INTERDICTED`/`DELIVERED`, rollback и cleanup |
| virtual logistics | physical site должен завершаться вместе с delivery | stale `LOGISTICS_RUN` оставался ACTIVE после cleanup | delivery хранит siteRecord и переводит его в `COMPLETED`/`DESTROYED`/`DISABLED` |
| support categories | UI должен отражать server catalog | показывались phantom categories | список строится только из опубликованного catalog |
| `.inc` validation | include-fragment проверяется в parent preprocessing scope | отдельный parse давал ложные ошибки | recursive include expansion до delimiter scan |
| `fireAtTarget` | weapon parameter optional | внешний аудит считал `[target]` invalid | ложное правило удалено; текущий `doTarget`/`doFire` допустим |

## Изменённые runtime-контуры

### Support

- `fn_serverRequestSupport.sqf`
- `fn_launchFPVStrike.sqf`
- `fn_launchISR.sqf`
- `fn_launchLongRangeStrike.sqf`
- `fn_requestFPV.sqf`
- `fn_requestAirSupport.sqf`
- `fn_requestArtillery.sqf`
- `fn_requestLongRangeSupport.sqf`
- `fn_openSupportConsole.sqf`

### Directors

- `fn_enemyAirDirector.sqf`
- `fn_enemyISRDirector.sqf`
- `fn_enemyFPVDirector.sqf`
- `fn_friendlyStrikeDirector.sqf`
- `fn_longRangeDroneDirector.sqf`
- `fn_sensorDirector.sqf`
- `fn_logisticsDirector.sqf`
- `fn_relocateDroneTeam.sqf`

### Core / objectives

- side helpers and side role resolver;
- strategic HQ/AA/drone/artillery materializers;
- canonical live-contact resolver;
- objective adapters for AA, artillery, EW, drone/FPV, ISR and logistics;
- transactional convoy objective;
- `CfgFunctions.hpp` registrations.

## Validators

### Canonical command

```bash
python3 tools/validate_all_rc6.py
```

It must run:

1. `validate_source_manifest.py` — source provenance and authority boundaries;
2. `validate_arma_wiki_contracts.py` — BI/ACE command contracts;
3. `validate_side_contracts.py` — WEST/EAST/GUER isolation;
4. `validate_orientation_contracts.py` — vector frame and no mixed orientation APIs;
5. `validate_runtime_transactions.py` — reservation, rollback, site and group lifecycle;
6. `validate_rc6.py` — recursive includes, delimiters, registrations and broader RC6 contracts;
7. optional RPT scan when `--rpt` is supplied.

### Source provenance

```bash
python3 tools/validate_source_manifest.py
```

Проверяет:

- наличие BI Wiki, `acemod/arma3-wiki`, Stokys и Context7;
- HTTPS и фиксированные canonical URLs;
- branch `dist` для parsed ACE data;
- запрет использовать Stokys как единственный engine authority;
- существование validator-файлов, связанных с каждым contract;
- наличие source policy в этом audit-документе.

### HEMTT

```bash
python3 tools/validate_all_rc6.py --require-hemtt
```

HEMTT становится обязательным только после добавления настоящего `.hemtt/project.toml`. Фиктивный project только ради зелёной проверки запрещён.

## `CfgRemoteExec`

Строгий mission-level whitelist не добавлен в этот PR. Неполный whitelist может перекрыть ACE/RHS mod configs и вызвать более тяжёлую MP-регрессию. Critical client → server support endpoint защищён внутри функции через type/virtual/owner/catalog/payload validation.

Отдельный security-проход должен:

1. собрать runtime inventory remote functions/commands в SP, hosted MP, dedicated MP и HC;
2. учесть mod `CfgRemoteExec`;
3. добавить точные `allowedTargets`;
4. повторить ACE/RHS compatibility run.

## Что нельзя подтвердить статически

Даже source-backed audit не доказывает:

- наличие и физику каждого mod classname;
- turret/weapon compatibility конкретных aircraft;
- AI pathing на карте;
- custom ammo hit/explosion behavior;
- locality после UAV Terminal handoff;
- отсутствие scheduler stalls;
- чистоту RPT после 30–45 минут.

## Обязательный runtime gate

1. SP с `-showScriptErrors`.
2. Hosted MP.
3. Dedicated server.
4. Dedicated + Headless Client slot.
5. WEST/EAST/RESISTANCE faction combinations.
6. Exact ISR по каждому опубликованному class.
7. FPV auto/manual, operator death и partial salvo abort.
8. Long-range 1/3/10 и BDA/subject cancellation.
9. FP-5 stock/use counter.
10. Enemy ISR → strategic contact → enemy strike.
11. Friendly/enemy CAS materialization, abort и egress.
12. AA missile depletion.
13. Virtual → physical → delivered/interdicted/cancelled logistics lifecycle.
14. `python3 tools/validate_all_rc6.py --rpt /path/to/new.rpt`.

PR остаётся draft до runtime/RPT проверки.
