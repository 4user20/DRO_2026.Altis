# Runtime checklist AI Director

## Статически подтверждено

- `main` при начале работы совпадал с `ca3261237b534283173a4f62c13ac324802d1a22`;
- AI functions зарегистрированы;
- старый и новый operation director не запускаются одновременно;
- default mode — `OBSERVE`;
- candidate ID и snapshot sequence проверяются повторно в SQF;
- timeout/offline/invalid result имеют deterministic fallback;
- API URLs/keys отсутствуют в mission SQF;
- sidecar не имеет runtime npm dependencies;
- Node self-test, syntax check, mock doctor и INI end-to-end пройдены;
- clean-room FPV helpers не используют `allUnits`, `forceSpeed 150`, `doMove` или `attachTo`;
- operation hard limits не изменены.

## Требует Arma runtime

1. Запуск без INIDBI2 и отсутствие mission-breaking errors.
2. Запуск с INIDBI2 под текущим Proton prefix.
3. OBSERVE: snapshots и decisions без влияния на выбор intent.
4. HYBRID: accepted candidate из текущего set.
5. Reject неизвестного candidate ID.
6. Reject stale sequence после изменения состояния.
7. Provider timeout и отключение sidecar во время боя.
8. Tactical API: Laguna XS 2.1 endpoint/model ID.
9. Strategic API: NVIDIA NIM/Nemotron endpoint/model ID и structured output.
10. MiniMax как fallback/narrative profile.
11. FPV lead против движущейся машины и пехоты.
12. Terrain avoidance после применения lead point.
13. UAV Terminal handoff и возврат автопилота.
14. Zeus remote-control detection.
15. LLM salvo 1–3 с ограничением stocks/slots.
16. Forced relocation только для валидного LLM modifier.
17. Длительная миссия: INI growth, cleanup, heartbeat, memory и FPS.

## Артефакты runtime-проверки

К PR/отчёту приложить:

- `arma3_x64_*.rpt`;
- последние строки `tools/dro-ai-director/logs/decisions.ndjson`;
- sanitized `DROAI-config.cfg` без ключей;
- `DROAI_in.ini` и `DROAI_out.ini` после короткого прогона;
- FPS до/после;
- точные Proton launch options и версия INIDBI2.
