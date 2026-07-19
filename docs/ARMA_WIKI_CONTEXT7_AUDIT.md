# RC6 — Context7 + Bohemia Interactive Wiki audit

Дата проверки: 2026-07-20  
Ветка: `fix/post-merge-audit-hardening`  
PR: #7

## Метод

Проверка выполнена по четырём слоям:

1. фактический diff ветки относительно `main`;
2. полный проход по связанным `support`, `directors`, `objectives`, `core` и logistics-путям;
3. официальная Bohemia Interactive Community Wiki для движковых команд и multiplayer locality;
4. Context7-индекс HEMTT для Arma-aware SQF parser/analyzer tooling.

Context7 не содержит полного официального справочника SQF-команд. Поэтому Context7 использован для build/static-analysis tooling, а семантика движка проверена по BI Wiki.

## Использованные первичные источники

- BI Wiki: `createVehicle` / array syntax
  - https://community.bohemia.net/wiki/createVehicle_array
- BI Wiki: `allPlayers`
  - https://community.bohemia.net/wiki/allPlayers
- BI Wiki: Headless Client
  - https://community.bohemia.net/wiki/Arma_3_Headless_Client
- BI Wiki: `isPlayer`
  - https://community.bohemia.net/wiki/isPlayer
- BI Wiki: `remoteExecutedOwner`
  - https://community.bohemia.net/wiki/remoteExecutedOwner
- BI Wiki: `isRemoteExecuted`
  - https://community.bohemia.net/wiki/isRemoteExecuted
- BI Wiki: `remoteExec` / `CfgRemoteExec`
  - https://community.bohemia.net/wiki/remoteExec
  - https://community.bohemia.net/wiki/Arma_3:_CfgRemoteExec
- BI Wiki: multiplayer locality
  - https://community.bohemia.net/wiki/Locality_in_Multiplayer
- BI Wiki: `createVehicleCrew` / `deleteVehicleCrew`
  - https://community.bohemia.net/wiki/createVehicleCrew
  - https://community.bohemia.net/wiki/deleteVehicleCrew
- BI Wiki: `setDir`, `setVectorDirAndUp`, `setVectorDir`
  - https://community.bohemia.net/wiki/setDir
  - https://community.bohemia.net/wiki/setVectorDirAndUp
  - https://community.bohemia.net/wiki/setVectorDir
- BI Wiki: `disableAI`
  - https://community.bohemia.net/wiki/disableAI
- BI Wiki: `doTarget`, `doFire`, `fireAtTarget`
  - https://community.bohemia.net/wiki/doTarget
  - https://community.bohemia.net/wiki/doFire
  - https://community.bohemia.net/wiki/fireAtTarget
- BI Wiki: `triggerAmmo`
  - https://community.bohemia.net/wiki/triggerAmmo
- Context7: HEMTT
  - https://context7.com/brettmayson/hemtt

## Проверочная матрица

| Область | Документированный контракт | Найденный дефект | Исправление |
|---|---|---|---|
| `createVehicle [..., "FLY"]` | `FLY` поднимает аппарат, когда он уже имеет экипаж | самолёты/UAV создавались пустыми, экипаж добавлялся позже | явный `setDir` → `setPosATL/ASL`, затем `createVehicleCrew`; добавлена начальная скорость |
| `allPlayers` | включает HC, virtual curator и spectator | виртуальные клиенты участвовали в sensor, objectives, relocation, logistics и target selection | все server-side выборки RC6 фильтруют `!(_x isKindOf "VirtualMan_F")` |
| `isPlayer` | возвращает `true` для Headless Client | одного `isPlayer` было недостаточно для authority | dispatcher дополнительно отклоняет `VirtualMan_F` |
| `remoteExecutedOwner` | возвращает `0` для HC, SP и вне RE-context | zero-owner мог быть двусмысленным | dedicated server требует нормальный client owner и соответствие `owner _requester` |
| `setVectorDirAndUp` | direction/up должны задавать согласованную ориентацию | pitched direction использовал фиксированный world-up | вычисляется ортонормальный right/up через `vectorCrossProduct` |
| AI pathing | `MOVE/PATH/TARGET/AUTOTARGET` могут конфликтовать с внешним guidance | AI мог перетягивать FPV/long-range trajectory | у vector-guided airframes отключены конфликтующие AI features |
| exact class | перед materialization нужен валидный class/config/side | exact profile мог стать fallback/AUTO | exact FPV/ISR/long-range class теперь fail-closed с refund |
| side config | config `side` должен совпадать с выбранной стороной | INDEPENDENT (`2`) протекал в WEST/EAST через `in [_sideNumber, 2]` | используется точное равенство config side |
| enemy CAS | pool должен соответствовать `enemySide` | director использовал hardcoded `AIR_EAST` | введён `ENEMY_CAS_AIR` из выбранных enemy plane/heli classes |
| target reacquisition | удар должен оставаться связан с разведконтактом | FPV/long-range мог искать произвольный `nearestObjects` | blind retargeting удалён |
| crew lifecycle | `deleteVehicleCrew` следует выполнять там, где vehicle local | уничтоженный аппарат мог оставить crew/group | server-created vehicles чистятся server-side, затем удаляется empty group |
| FP-5 accounting | одна единица должна резервироваться из одного pool | FP-5 списывался из dedicated и общего long-range stock | выделен один `friendlyFP5Stock` reservation path |
| salvo abort | незапущенные airframes не должны теряться | весь пакет списывался до последовательной materialization | остаток salvo возвращает airframe, fuel и aggregate stock |
| ISR failure | pre-launch failure не должен оставлять cooldown | stock мог вернуться, а cooldown остаться | единый `_refundReservation` возвращает stock и сбрасывает cooldown |
| convoy lifecycle | active convoy должен завершаться вместе с delivery | delivery становился delivered/interdicted, convoy оставался `IN_TRANSIT` | синхронизируются финальные статусы, completed crew/group очищаются |
| support categories | UI должен отражать опубликованный catalog | показывались пустые phantom categories | категории строятся по фактическому server catalog |
| contact constructor | вызываемая функция должна быть зарегистрирована | файл существовал, регистрации не было | добавлен `class createContactRecord {};` |
| `.inc` validation | include-fragments являются текстовыми частями общего scope | validator разбирал `.inc` отдельно и создавал ложные ошибки | delimiter-check выполняется после recursive include expansion |
| `fireAtTarget` | weapon parameter является optional | внешний аудит ошибочно считал `[target]` неверным | ложное правило удалено; текущий `doTarget`/`doFire` оставлен валидным |

## Изменённые runtime-контуры

### Support

- `fn_serverRequestSupport.sqf`
- `fn_launchFPVStrike.sqf`
- `fn_launchISR.sqf`
- `fn_launchLongRangeStrike.sqf`
- `fn_requestAirSupport.sqf`
- `fn_requestLongRangeSupport.sqf`
- `fn_openSupportConsole.sqf`

### Directors

- `fn_enemyAirDirector.sqf`
- `fn_enemyISRDirector.sqf`
- `fn_friendlyStrikeDirector.sqf`
- `fn_longRangeDroneDirector.sqf`
- `fn_sensorDirector.sqf`
- `fn_logisticsDirector.sqf`
- `fn_relocateDroneTeam.sqf`

### Core / objectives

- `fn_refreshFactionAssets.sqf`
- `fn_publishSupportCatalog.sqf`
- `fn_objectiveISRRecon.sqf`
- `CfgFunctions.hpp`

## Validators

### 1. Full BI Wiki contract sweep

```bash
python3 tools/validate_arma_wiki_contracts.py
```

Проверяет:

- все `dro2026/**/*.sqf` с server-side `allPlayers`;
- empty `FLY` materialization;
- fixed `[0,0,1]` для pitched `setVectorDirAndUp`;
- cross-side leakage;
- authority, exact-class routing, cleanup и refund contracts.

### 2. Общий RC6 validator

```bash
python3 tools/validate_rc6.py
```

Проверяет:

- recursive include expansion;
- delimiter balance;
- регистрацию `CfgFunctions`;
- запрещённые legacy payload injections;
- contact/state/objective/logistics/ROE contracts;
- запускает full BI Wiki contract sweep.

### 3. RPT stabilization

```bash
python3 tools/validate_rc6_rpt_stabilization.py --rpt /path/to/new.rpt
```

Проверяет базовый validator и ищет в RPT:

- undefined variables;
- expression/type mismatch;
- network state regressions;
- Fired-handler spam;
- watchdog freeze.

### 4. HEMTT

Context7 подтверждает наличие HEMTT SQF parser/analyzer и CLI checks. В validator добавлен опциональный gate:

```bash
python3 tools/validate_rc6.py --require-hemtt
```

Он станет обязательным после добавления корректного `.hemtt/project.toml`. Создавать фиктивную HEMTT-конфигурацию только ради зелёной проверки не следует.

## CfgRemoteExec

Строгий `CfgRemoteExec` не добавлен в этот PR.

Причина:

- default operation mode допускает remote execution для backward compatibility;
- mission-level whitelist имеет приоритет над mod config;
- ACE/RHS и другие моды могут иметь собственные remote functions;
- неполный whitelist способен превратить корректный runtime fix в массовую регрессию.

При этом критический client → server support endpoint защищён внутри самой функции через requester type, virtual-client rejection, owner binding, catalog validation и payload validation.

Рекомендуемый следующий отдельный security-проход:

1. собрать runtime inventory всех remote functions/commands в SP, hosted MP, dedicated MP и HC;
2. импортировать mod `CfgRemoteExec`;
3. включить mission `mode = 1`;
4. разрешить только подтверждённые functions/commands с точными `allowedTargets`;
5. повторить ACE/RHS compatibility run.

## Что нельзя подтвердить статически

Даже полный source/documentation audit не доказывает:

- существование и корректную физику каждого класса из установленных модов;
- фактическую turret/weapon compatibility конкретных самолётов;
- устойчивость AI pilot pathing на конкретной карте;
- hit/explosion поведение custom ammo;
- locality после подключения игрока к UAV terminal;
- отсутствие scheduler stalls под реальной нагрузкой;
- чистоту RPT после 30–45 минут игры.

Поэтому PR остаётся draft до runtime-проверки.

## Обязательный runtime gate

1. SP с `-showScriptErrors`.
2. Hosted MP.
3. Dedicated server.
4. Dedicated + Headless Client slot.
5. Exact ISR по каждому опубликованному классу.
6. FPV auto/manual, уничтожение operator до запуска.
7. Long-range 1/3/10, частичный salvo abort.
8. FP-5 stock/use counter.
9. Enemy ISR → strategic contact → enemy strike.
10. Friendly и enemy CAS materialization/egress.
11. Virtual → physical → delivered/interdicted logistics lifecycle.
12. Новый RPT через оба validator-а.
