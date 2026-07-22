# DRO 2026 — forensic remediation после RPT 2026-07-21

Дата: 2026-07-22  
Базовая ветка: `main` после слияния PR #13  
Входные материалы:

- `DRO2026_RPT_AUDIT_2026-07-21`
- `DRO2026_RPT_AUDIT_2026-07-21_EXPANDED`

## Иерархия источников

1. Официальная Bohemia Interactive Community Wiki — нормативная база по командам и engine semantics.
2. `acemod/arma3-wiki` — активный вспомогательный индекс/зеркало для перекрёстной проверки.
3. `Archeron-Studios/ArmaWiki-github-io` — архивирован; не используется как нормативный источник.
4. `mrPIONEER/platforma-arma3` — только референс организации SP/COOP-контента, радио, брифинга и постановки задач. Код, аудио и иные assets не переносятся без подтверждённой лицензии.

Основные ссылки Bohemia:

- https://community.bohemia.net/wiki/Waypoints
- https://community.bohemia.net/wiki/waypointAttachObject
- https://community.bohemia.net/wiki/CfgWeapons_Config_Reference
- https://community.bohemia.net/wiki/compatibleMagazines
- https://community.bohemia.net/wiki/weaponsTurret
- https://community.bohemia.net/wiki/magazinesTurret
- https://community.bohemia.net/wiki/fireAtTarget
- https://community.bohemia.net/wiki/aimedAtTarget

## Подтверждённые дефекты и исправления

### P0 — FPV-запрос падал на несовместимом типе аргумента

RPT фиксировал `Тип Строка, ожидался Объект` в `fn_requestFPV.sqf`. UI передавал class id четвёртым positional-аргументом, а handler типизировал этот слот как `Object`.

Исправлено:

- `beginSupportTargeting` формирует единый `HashMap`-контракт;
- `requestFPV` нормализует `HashMap`, legacy position `Array` и catalog `String`;
- неверная форма запроса возвращает `INVALID_REQUEST_SHAPE`, а не engine-level params exception;
- добавлены `requestId`, `FPV_REQUEST_ACCEPTED` и `FPV_LAUNCH_ABORTED`;
- списание stock остаётся после всех проверок источника, контакта, лимита и класса.

### P0 — spatial `DESTROY` выбирал непредсказуемую цель

Bohemia прямо предупреждает: пространственный `DESTROY` без прикреплённого объекта может выбрать произвольный ближайший объект и даже участника собственной группы.

Исправлено:

- `DESTROY` создаётся только при наличии живого `_targetObject`;
- waypoint прикрепляется через `waypointAttachObject`;
- позиционные strike/intercept маршруты заканчиваются `MOVE`;
- terminal guidance / explicit `doTarget` + `fireAtTarget` остаются владельцами финального поражения;
- событие `POSITIONAL_STRIKE_ROUTE` позволяет проверить отсутствие скрытого targetless `DESTROY`.

### P0 — ОТРК не находил боеприпас

Старый resolver читал только верхнеуровневый `magazines[]` у оружия. Модовые пусковые часто используют muzzle subclasses и magazine wells.

Исправлено:

- обход inherited vehicle weapons;
- чтение `muzzles[]`;
- рекурсивное чтение `magazines[]`;
- `compatibleMagazines weapon` и `compatibleMagazines [weapon, muzzle]`;
- scoring реального missile/rocket/bomb/shell ammo;
- fail-closed исключение smoke/flare/chaff/fake/dummy/horn/countermeasure;
- если launcher остаётся script-only или addon не публикует штатное ammo в config, запуск по-прежнему блокируется честным `NO_LAUNCHER_AMMO`.

## Что намеренно не маскируется

Следующие пункты требуют нового runtime RPT с тем же modset:

- конкретный источник `Wrong weapon selection` / `Bad weapon selected`;
- POOK script-only launch API, если класс не предоставляет штатную config-цепочку weapon → magazine → ammo;
- полноценная транзакция SHORAD `planned → materialized → grouped → registered`;
- S-300 topology и radar-role classification;
- внешние `[DEBUG] FIRED`, PiR, ARI_AO и particle expression errors;
- model/selection/shadow warnings сторонних assets.

Миссия не должна придумывать неизвестные addon function names или считать внешний эффект собственным launcher API.

## Runtime acceptance matrix

### FPV

1. Открыть панель поддержки.
2. Проверить `FPV_AUTO`, `FPV_MANUAL`, `FPV_CLASS_AUTO:*`, `FPV_CLASS_MANUAL:*`.
3. Для каждого запроса получить один `requestId`.
4. Убедиться в наличии `FPV_REQUEST_ACCEPTED`.
5. Не должно быть `Тип Строка, ожидался Объект`.
6. При отмене до materialization stock должен вернуть только не запущенный остаток.

### Waypoints

1. Выполнить минимум 10 long-range strikes и 5 interceptor missions.
2. В RPT не должно быть `Destroy waypoint not linked to a target`.
3. Для positional strike должны появляться `POSITIONAL_STRIKE_ROUTE` с `terminalWaypoint=MOVE`.
4. Для реального object target допускается `DESTROY`, но только с attached object.

### ОТРК

1. Найти `BALLISTIC_STATUS`.
2. При config-backed launcher должны быть непустые `launcherClass` и `ammoClass`.
3. При script-only addon блокировка должна остаться `NO_LAUNCHER_AMMO`, без списания stock.
4. При успешном запуске должны последовательно появиться:
   - `BALLISTIC_LAUNCH_PREPARING`;
   - фактическая materialization strategic munition;
   - `STRATEGIC_STRIKE_ORDERED`;
   - stock decrement ровно на один missile и одну fuel unit;
   - displacement или явный relocation failure.

### Производительность

1. Прогон 60–120 минут.
2. Отдельно подсчитать mission errors и external-addon errors.
3. Найти источник `[DEBUG] FIRED`; цель — не более одного агрегированного диагностического события на окно, а не тысячи строк.
4. Сравнить server FPS, active groups, vehicles, drones и director tick durations.

## Контент и озвучка

В миссии уже существует очередная система HQ-озвучки и набор русских реплик `dro2026/audio/racia2`. Поэтому этот P0 PR не копирует содержимое `platforma-arma3` и не смешивает runtime fixes с большим контентным импортом.

Следующий безопасный content PR:

- добавить priority/dedupe/cooldown для radio queue;
- связать strategic events, logistics, SHORAD/S-300, OTRK и BDA с репликами;
- добавить subtitle-only fallback для отсутствующих `.ogg`;
- оформить speaker/callsign profiles;
- добавить briefing/map cinematic templates собственной реализации;
- новые аудиофайлы принимать только с явным provenance и лицензией.

## Статическая проверка

```bash
python3 tools/validate_all_rc6.py
```

Новый этап `validate_rpt_forensic_contracts.py` проверяет:

- единый FPV HashMap contract;
- legacy shape normalization;
- request correlation;
- запрет targetless `DESTROY`;
- muzzle/magazine-well-aware ammo resolution;
- запрет выбора smoke/fake/countermeasure ammo.
