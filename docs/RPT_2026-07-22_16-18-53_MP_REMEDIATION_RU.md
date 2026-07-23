# DRO2026 — разбор MP RPT `Arma3_x64_2026-07-22_16-18-53.rpt`

Дата анализа: 2026-07-22.

## Итог

Последний multiplayer-прогон начинается в 17:25:16 и завершается отказом процесса в 17:45:36. Внутри последнего запуска находится 1857 строк RPT. Простое количество строк `Error`/`Warning` нельзя считать количеством независимых багов: большая часть сообщений повторяется сотни раз из-за одного сломанного config или event handler.

В логе подтверждены отдельные mission-owned дефекты DRO2026 и отдельные ошибки внешних addons.

## Подтверждённые mission-owned дефекты

### 1. Позиционный дальний удар сам превращался в несуществующий object-contact

В 17:33:28 записано:

```text
[D26][CONTACT][INVALID_RECORD] id=P_15128_17244_PLAYER reason=SUBJECT_UNRESOLVED
[DRO2026] Отменена не запущенная часть salvo AUTO: возвращено 3
```

Причина: `fn_createContactRecord.sqf` назначал ID позиционной метки как `subjectId`, хотя физического объекта или network node не существовало. `fn_resolveContactSubject.sqf` пытался разрешить этот ID как объект, объявлял запись недействительной и блокировал весь залп.

Исправление:

- введён `subjectMode=POSITION_ONLY`;
- designation ID отделён от `subjectId` и `subjectNetId`;
- позиционная цель получает TTL и проходит отдельную проверку координат/срока жизни;
- чистый MAP_POINT больше не требует физического объекта.

### 2. FPV MAP_POINT фактически не поддерживался

`fn_requestFPV.sqf` принимал позицию, но затем искал только уже существующий контакт с достаточной confidence в радиусе 320 м. При отсутствии такого контакта FPV не materialize. Причина отказа в старой версии не попадала в structured telemetry, поэтому в RPT отсутствовали `FPV_REQUEST_REJECTED` и точный code.

Исправление:

- MAP_POINT создаёт transient `POSITION_ONLY` contact;
- CONTACT mode по-прежнему требует реальный разрешаемый контакт;
- добавлены `FPV_REQUEST_ACCEPTED` и `FPV_REQUEST_REJECTED` с requestId/code;
- при отсутствии forward FPV site разрешён operational `FRIENDLY_DRONE_SITE` в пределах support radius;
- для fiber-optic класса применяется увеличенный предел источника.

### 3. Сервер отправлял клиенту ложный `ACCEPTED`

`fn_serverRequestSupport.sqf` вызывал long-range handler, игнорировал его результат и всегда создавал новый успешный result. Игрок мог получить подтверждение, хотя реальный handler уже отменил запрос и вернул stock.

Исправление: dispatcher возвращает фактический HashMap-result `fn_requestLongRangeSupport.sqf`.

### 4. Дальний аппарат одновременно управлялся AI и vector-controller

Подтверждённый lifecycle последнего FP-1:

```text
17:36:51 NONE -> ARMA_AI, reason=WAYPOINT_MACRO_ROUTE
17:36:51 POSITIONAL_STRIKE_ROUTE, terminalWaypoint=MOVE
17:39:31 ARMA_AI -> FPV_TERMINAL, reason=FINAL_INGRESS
```

При handoff отключался только `PATH`. При этом сохранялись:

- `MOVE`;
- `TARGET`;
- `AUTOTARGET`;
- FSM;
- все старые waypoints группы.

Одновременно каждые ~0.28 секунды скрипт задавал `setVectorDirAndUp` и `setVelocity`. Это нарушало single-flight-authority contract.

Исправление:

- при переходе в terminal guidance удаляются старые waypoints;
- на локальном driver отключаются MOVE/PATH/TARGET/AUTOTARGET/FSM;
- после handoff остаётся один vector-controller;
- добавлены terminal start/recovery/finish events.

### 5. Terminal aim мог переключаться между несколькими точками

`fn_calculateTerrainAwareAim.sqf` каждый tick заново выбирал левый или правый terrain detour. Long-range terminal controller дополнительно передавал lateral noise `18`, меняющийся от `diag_tickTime`.

Исправление:

- для macro guidance введена hysteresis выбранной стороны обхода;
- committed terminal ingress вызывает terrain aim с `lateralNoise=0` и `allowLateralAvoidance=false`;
- препятствие проходится увеличением ASL-clearance, а не постоянной сменой боковой точки.

### 6. Не было bounded terminal-progress watchdog

Старый controller имел только общий timeout и 45-секундный terminal deadline без результата. Теперь:

- отслеживается лучшая достигнутая дистанция;
- после 10 секунд без прогресса включается один recovery interval;
- ещё через 8 секунд без прогресса mission завершается `NO_TERMINAL_PROGRESS`;
- всегда пишется `LONG_RANGE_GUIDANCE_FINISHED` с итогом и позициями.

### 7. FPV stuck recovery использовал запрещённый AI path

`fn_launchFPVStrike.sqf` отключал MOVE/PATH, но `fn_fpvAttackController.sqf` при застревании вызывал `doMove`. Команда либо не могла помочь, либо снова смешивала flight owners.

Исправление: recovery выполняется только временной vector aim point и имеет событие `FPV_VECTOR_RECOVERY`.

### 8. Mission selector выбрал известный сломанный vehicle config

В 17:29:53 миссия создала:

```text
DRO: spawning insert vehicle B_UAArmy_CAT1A2_01 ... with 6 roles
```

После этого CBA записал 596 сообщений:

```text
Vehicle B_UAArmy_CAT1A2_01 has invalid gun configs on turret [0]
```

Это внешний config-дефект addon-класса, но DRO не должен продолжать выбирать доказанно сломанный asset. Класс добавлен в конфигурируемый runtime quarantine `DRO2026_runtimeBlockedVehicleClasses` и удаляется из legacy pools до insertion.

### 9. S-300 не проходил атомарную materialization

В 17:30:00:

```text
FORMATION_REJECTED radar=false launchers=2 reason=INCOMPLETE_S300_BATTERY
```

Старый лог не позволял определить, отсутствовал класс, не создался объект или failed crew/locality.

Исправление:

- для `S300_F_UCG` требуется конкретный fire-control radar `S300_RS_F_UCG`, а не произвольный EARLY_WARNING_RADAR;
- добавлены component-level события create/validate/failure;
- rejection содержит launcher/radar class, created и validated counts;
- transaction по-прежнему полностью откатывается при неполной батарее.

### 10. POOK 9K720 существовал физически, но ammo resolver не видел runtime turret state

Последний запуск четыре раза сообщил `NO_LAUNCHER_AMMO`; по всему RPT таких записей 12. Во всех случаях:

```text
launcherClass=pook_9K720_OPFOR
physicalLaunchers=1
ammoClass=""
launches=0
```

Исправление:

- resolver принимает class или physical object;
- если передан class, он ищет совпадающий live/local managed launcher;
- считывает `allTurrets`, `weaponsTurret` и `magazinesAllTurrets`;
- runtime magazine с положительным ammo count имеет приоритет над class-only discovery;
- smoke/flare/countermeasure/fake/horn по-прежнему запрещены;
- `compatibleMagazines` остаётся только дополнительным источником.

Это улучшение требует нового RPT: если POOK использует полностью script-only payload и не публикует магазин в turret state, потребуется отдельный addon adapter, а не выдуманный classname/API.

## Финальный hang/crash

Последнее нормальное mission event перед отказом:

```text
17:39:31 ARMA_AI -> FPV_TERMINAL, vehicle=2:4989, reason=FINAL_INGRESS
```

Далее:

- 17:39:41 — внешний `[DEBUG] FIRED`;
- 17:39:44 — два отсутствующих ARI_AO nuclear scripts;
- до 17:39:49 продолжается CBA invalid-turret spam;
- с 17:40:00 начинается watchdog `No alive in 10000 ms`;
- процесс заканчивается `Exception code: 80000101`.

Временная связь с FP-1 terminal handoff сильная, и в mission code найден реальный конфликт двух flight controllers. Однако без symbolized minidump нельзя доказать, что именно он один вызвал native engine fault: в том же окне активны ошибки внешних addons.

## Повторяющиеся сообщения последнего запуска

| Группа | Количество |
|---|---:|
| `B_UAArmy_CAT1A2_01 invalid gun configs` | 596 |
| внешний `[DEBUG] FIRED` | 217 |
| watchdog `No alive` | 69 |
| `Backpack with given name: [] not found` | 18 |
| MK82 cloudlet expression | 8 |
| `NO_LAUNCHER_AMMO` | 4 |
| ARI_AO missing nuclear script | 2 |
| positional long-range routes | 2 |
| `SUBJECT_UNRESOLVED` map designation | 1 |
| incomplete S-300 battery | 1 |

Это не 918 независимых багов. Это несколько root causes, создающих сотни повторных строк.

## Внешние addon-проблемы, не исправляемые удалением чужого кода

- CBA warning для `B_UAArmy_CAT1A2_01` — broken vehicle turret config; DRO теперь исключает класс.
- `[DEBUG] FIRED` отсутствует в mission repository; источник — addon Fired handler.
- `ARI_AO/scripts/nuclear/fnc/checkNukeDropped.sqf not found` — отсутствующий файл внешнего addon.
- `mk82_explosion_01/02` expression errors — внешний particle config.
- `camPos2` в `frtz_FP1_B` — внешний sound/config issue.
- backpack/model/shadow warnings — config/model issues addons.

Запрещено лечить это через `removeAllEventHandlers`, поскольку это ломает CBA/ACE/RHS и другие моды.

## Runtime acceptance для следующего запуска

1. Hosted MP с тем же modset и `-showScriptErrors`.
2. FPV AUTO и exact class по пустой точке карты: должен появиться `POSITION_ONLY_ACTIVE`, затем `FPV_REQUEST_ACCEPTED`, `DRONE_LAUNCH_RESERVED`, physical object и `FPV_GUIDANCE_FINISHED`.
3. Long-range AUTO x3 по пустой точке: не должно быть `SUBJECT_UNRESOLVED`; три launch reservations или точный structured reject/refund.
4. FP1 и FP2: один `FINAL_INGRESS`, затем `LONG_RANGE_TERMINAL_STARTED` и terminal result; отсутствие циклической смены нескольких координат.
5. Не менее 10 terminal strikes без `No alive` watchdog.
6. Проверить, что `B_UAArmy_CAT1A2_01` не появляется в insertion pool.
7. S-300: component-level telemetry должна показать конкретную причину либо complete battery.
8. POOK 9K720: `BALLISTIC_STATUS.ammoClass` должен быть непустым, либо runtime telemetry должна доказать script-only launcher и необходимость adapter.
9. Новый RPT прогнать:

```bash
python3 tools/validate_all_rc6.py --rpt /path/to/new/Arma3_x64.rpt
```

До этого изменения имеют статус `READY_FOR_RUNTIME_TEST`, а не `RUNTIME_VERIFIED`.
