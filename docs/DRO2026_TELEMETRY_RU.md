# DRO2026 — встроенная телеметрия миссии

Телеметрия пишет в RPT строки с префиксом `[D26T]`. Она наблюдает только состояние и объекты, которыми управляет DRO2026, и не записывает покадровое движение всей карты.

## Режимы

- `OFF` — встроенная телеметрия выключена.
- `BASIC` — все события `DRO2026_fnc_emitEvent`, запросы поддержки, запуски, возвраты ресурсов, смены фаз, уничтожения и MP lifecycle.
- `VERBOSE` — BASIC плюс дельты managed vehicles, groups, sites, network nodes и contacts. Это режим по умолчанию для текущей отладочной сборки.
- `TRACE` — более частые снимки и меньшие координатные buckets. Использовать для короткого воспроизведения конкретного бага.

Переключение на сервере без перезапуска:

```sqf
missionNamespace setVariable ["DRO2026_TELEMETRY_MODE", "TRACE", true];
```

Возврат к обычной диагностике:

```sqf
missionNamespace setVariable ["DRO2026_TELEMETRY_MODE", "VERBOSE", true];
```

Отключение:

```sqf
missionNamespace setVariable ["DRO2026_TELEMETRY_MODE", "OFF", true];
```

## Ручная отметка бага

В момент, когда визуально замечена проблема:

```sqf
["FP1 начал ходить по кругу"] call DRO2026_fnc_telemetryMark;
```

С дополнительными данными:

```sqf
[
    "FPV не появился после клика",
    player,
    createHashMapFromArray [["expectedClass","AUTO"],["ui","FPV"]]
] call DRO2026_fnc_telemetryMark;
```

## Что попадает в RPT

- каждый mission-owned event и его `sourceId`/payload;
- accepted/rejected support requests и requestId;
- reservations, materialization, launches, guidance handoff/recovery/finish;
- изменения stocks и ресурсов;
- contact state/BDA/confidence/uncertainty крупными дельтами;
- network node status, state-machine state, emissions и stocks;
- site state, physical state и число живых компонентов;
- managed group waypoint/type/command/behaviour/combat mode;
- managed vehicle damage/fuel/canMove/canFire/locality/owner/crew/flight authority;
- убийство и удаление DRO-owned entities;
- подключения/отключения игроков и завершение MP;
- минутный world/performance snapshot и число событий каждого типа за интервал.

## Ограничение нагрузки

- нет `EachFrame` handler;
- нет сканирования `allVehicles`;
- цикл работает раз в 10 секунд;
- обходятся только bounded DRO collections;
- одинаковые payload подавляются, но любое изменение state/signature пишется сразу;
- в VERBOSE позиция квантуется по 500 м, в TRACE — по 100 м;
- число отслеживаемых entities ограничено `DRO2026_TELEMETRY_MAX_TRACKED_ENTITIES`;
- `diag_activeSQFScripts` в лог не разворачивается: записывается только количество.

Mission event handlers локальны машине, на которой зарегистрированы, поэтому authoritative world telemetry запускается на сервере. `diag_tickTime` используется для timestamp/rate limiting, а `diag_fps` — только в редких снимках производительности.
