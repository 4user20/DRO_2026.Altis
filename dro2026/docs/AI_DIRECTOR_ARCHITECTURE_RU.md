# DRO 2026 RC6 — внешний AI Director

## Статус

Интеграция является опциональным bounded decision layer поверх существующей capability-network архитектуры. Мир, Contacts v2, ресурсы, hard limits и физическое исполнение остаются server-owned SQF.

```text
RC6 world state + Contacts v2 + event log
        -> buildIntentCandidates
        -> compact snapshot через INIDBI2
        -> Node.js sidecar
        -> Laguna / NVIDIA NIM / MiniMax
        -> candidate ID + bounded modifiers
        -> SQF sequence/candidate validation
        -> currentIntent
        -> существующие capability directors
```

LLM не получает права возвращать SQF, classnames, координаты, `createVehicle`, waypoint-команды или прямые изменения network state.

## Режимы

- `OFF` — транспорт и API не влияют на выбор; используется deterministic OODA.
- `OBSERVE` — режим по умолчанию. Snapshot отправляется наружу, решение логируется, но gameplay использует deterministic winner.
- `HYBRID` — свежее валидное решение может выбрать только ID из текущего candidate set. Timeout, stale sequence, неизвестный ID, отсутствие INIDBI2/sidecar или ошибка провайдера приводят к deterministic fallback.

Режим задаётся до запуска директоров:

```sqf
DRO2026_AI_MODE = "OBSERVE";
```

Не включать `HYBRID`, пока не пройден runtime checklist.

## Tactical flow

`DRO2026_fnc_buildIntentCandidates` строит только действия, которые уже допустимы по состоянию узлов, контактов и доктрины:

- `FPV_ATTACK`;
- `ARTILLERY_FIRE`;
- `LONG_RANGE_ATTACK`;
- `REINFORCE`;
- `ROUTE_ADAPT`.

Каждый candidate имеет стабильный ID для конкретного `snapshotSequence`. Sidecar возвращает:

- `EXECUTE` и существующий candidate ID;
- `HOLD` на 15–90 секунд;
- `USE_DETERMINISTIC`.

После ответа SQF повторно валидирует sequence и candidate ID. Реальные директоры затем повторно проверяют stocks, cooldown, contact confidence/BDA, физические лимиты и состояние capability node.

## Strategic flow

Редкий strategic request создаётся не чаще `DRO2026_AI_STRATEGIC_INTERVAL` и после крупных событий:

- `PHASE_CHANGED`;
- `NETWORK_NODE_DESTROYED`;
- `SITE_DESTROYED`;
- `DELIVERY_INTERDICTED`.

Модель может изменить только bounded policy:

- doctrine из существующего allowlist;
- desired tempo;
- recon/strike pressure;
- reserve commitment;
- logistics priority;
- recovery bias;
- pause after major attack;
- короткий список приоритетов.

Policy имеет TTL. Она влияет только на utility candidates и не повышает hard limits.

## Sidecar

`tools/dro-ai-director` — dependency-free Node.js 20 CommonJS service. Он:

- читает точные INI keys, а не «последнюю строку»;
- коалесцирует tactical jobs;
- не блокирует heartbeat во время API-запроса;
- поддерживает generic OpenAI-compatible endpoints;
- имеет tactical/strategic/narrative profiles;
- проверяет structured output;
- ограничивает очередь и возраст job;
- выполняет retry/fallback provider;
- открывает circuit breaker после повторных ошибок;
- пишет `logs/decisions.ndjson` без API keys.

## INIDBI2 transport

Mission использует два файла в INIDBI2 db directory:

```text
DROAI_out.ini  # SQF -> Node
DROAI_in.ini   # Node -> SQF
```

Каждая запись имеет уникальный key. Node подтверждает обработанные outbound keys через `ack-out`; SQF удаляет их только после подтверждения.

Отсутствие `OO_INIDBI` не является фатальной ошибкой. AI transport отключается, а operation loop продолжает deterministic selection.

## Maneuver leases

Managed groups получили стабильные IDs и command lease metadata. Это предотвращает перезапись waypoint другим директором. В текущем PR LLM не управляет группами напрямую; lease foundation предназначен для будущего отдельного bounded maneuver executor.

## Clean-room FPV delta

Из стороннего PBO исходный код не копировался. Добавлены только независимо реализованные идеи:

- обнаружение ручного UAV/Zeus control;
- lead point по live velocity или Contacts v2 `velocityEstimate`;
- attenuation по confidence, uncertainty и channel quality.

Упреждение остаётся входом в существующий terrain-aware controller. Запрещены глобальный `allUnits` target search, 20 Hz `doMove`, `forceSpeed 150`, attached explosive stacks и обход stocks/physical limits.
