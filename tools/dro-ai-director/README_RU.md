# DRO2026 AI Director — AI sidecar

Dependency-free Node.js 20 sidecar, адаптированный из архитектурных идей MIT Commander-архива.

## Назначение

- читает `DROAI_out.ini`, созданный SQF через INIDBI2;
- нормализует compact snapshot RC6;
- вызывает OpenAI-compatible API;
- валидирует только allowlisted candidate/policy;
- пишет решение в `DROAI_in.ini`;
- ведёт `logs/decisions.ndjson`;
- не блокирует heartbeat во время API-вызова;
- имеет coalescing tactical snapshot и circuit breaker.

## Запуск

```bash
cp DROAI-config.example.cfg DROAI-config.cfg
# заполнить endpoint/model/key или задать DROAI_* переменные
npm test
npm run check
npm run doctor
npm start
```

Для mock-проверки:

```bash
DROAI_MOCK=true npm start
```

## Важное

Runtime Arma/Proton всё ещё требует отдельной проверки на целевой машине. Перед включением `HYBRID` сначала использовать `OBSERVE` и проверить RPT/NDJSON.

Transport использует INIDBI2. Windows Arma под Proton может загрузить Windows extension, но это должно быть проверено на целевой машине. Native Linux dedicated потребует совместимого transport adapter.
