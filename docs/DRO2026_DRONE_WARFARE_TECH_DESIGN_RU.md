# DRO2026 — Drone Warfare / Recon / Logistics: технический дизайн

## 1. Архитектурный вердикт

Современный слой миссии построен как серверно-авторитетная надстройка над исходным DRO. Сервер владеет резервами, контактами, capability nodes, логистическими jobs, mission records, созданием объектов и проверкой support-запросов. Клиент отвечает только за UI, выбор цели, локальное подключение UAV Terminal и отображение результата.

Система не заменяет исходный Dynamic Recon Ops flow и не требует optional drone addons. Drongo's Drone Tweaks (DDT), KVN и другие моды подключаются через feature detection и адаптер; при их отсутствии сохраняется deterministic fallback.

## 2. Источник истины и locality

| Подсистема | Источник истины | Где выполняется |
|---|---|---|
| Capability network и node stocks | `DRO2026_networkNodes` | сервер |
| Контакты и uncertainty | `DRO2026_contacts` | сервер; клиент получает отображение |
| Support request и idempotency | `DRO2026_processedSupportRequests` | сервер |
| Drone mission records / flight authority | mission namespace и object variables | сервер |
| Logistics jobs | `DRO2026_logisticsJobs` | сервер |
| Dynamic objectives | `DRO2026_dynamicTasks` | сервер через Task Framework |
| Выбор точки/объекта и UI | локальный клиент | клиент |
| UAV Terminal connection | локальный клиент, затем server acknowledgement | владелец игрока |
| DDT deployment adapter | bounded central scheduler | сервер |

Публичные функции используют типизированный `params`. `CfgRemoteExec` работает в allow-list режиме (`mode = 1`). Новые server endpoints разрешены только на сервере, а client response/control endpoints — только на клиентах.

## 3. Support request DTO

`DRO2026_fnc_normalizeSupportRequest` нормализует вход в HashMap:

```text
requestId, channel, requesterNetId, requesterUid,
assetId, assetClass, count,
targetMode, targetPositionASL, targetObjectNetId, contactId,
sourceMode, sourceNodeId, sourceGroupNetId,
controlMode, createdAt
```

Сервер не доверяет присланному requester object. `DRO2026_fnc_resolveRemoteRequester` сопоставляет `remoteExecutedOwner` с живым non-HC player object, `owner`, UID и netId. Повторный `requestId` возвращает сохранённый результат без повторного списания.

Результат всегда структурирован:

```text
ok, code, message, requestId, data
```

Резерв списывается до materialization. Если spawn/crew/site/manual-terminal precondition не выполнены, незапущенная часть транзакции возвращается.

## 4. Contact schema

`DRO2026_fnc_createContactRecord` создаёт только полностью валидную запись schema 3:

```text
id: STRING
subjectNetId: STRING
subjectObject: OBJECT
subjectType: STRING
side: SIDE
state: SUSPECTED | DETECTED | IDENTIFIED | CONFIRMED | LOST | EXPIRED | DESTROYED
positionASL: ARRAY<NUMBER>
uncertaintyRadius: NUMBER
uncertaintyGrowthPerMinute: NUMBER
confidence: NUMBER
lastSeenAt: NUMBER
lastUpdatedAt: NUMBER
sourceNodeId: STRING
sourceSensorId: STRING
```

Object и netId не смешиваются. `DRO2026_fnc_resolveContactSubject` восстанавливает object через `objectFromNetId`, player UID, site/entity registry. Повреждённая запись помещается в `DRO2026_contactQuarantine` и один раз логируется как `[D26][CONTACT][INVALID_RECORD]`, не обрывая общий sensor tick.

## 5. Capability node и физические компоненты

`DRO2026_fnc_createSiteRecord` хранит schema 3, `positionASL`, `roadAnchorNetId`, stocks, capabilities и component map. Новый component damage применяется только к записям с `componentManaged = true`; legacy DRO sites продолжают использовать прежние object refs.

Компоненты:

```text
crew, guards, launchers, antennas, terminals,
generators, stocks, transports, camouflage, staticProps
```

Последствия:

- launcher loss блокирует `launch`;
- antenna/radar loss снижает `detect`/`relay` и network targeting;
- terminal loss блокирует `control`;
- transport loss блокирует быструю `relocate`;
- generator loss переводит узел в degraded mode;
- stock prop loss один раз уменьшает authoritative stock;
- потеря guards сама по себе не уничтожает узел.

## 6. Flight state machine и authority

Состояния fixed-wing миссии:

```text
PLANNED → RESERVED → SPAWNING → PREPARING → LAUNCHING
→ CLIMB → ENROUTE → INGRESS → SEARCH/LOITER
→ TERMINAL → IMPACT | RTB | LOST | ABORTED
```

Единственный writer поля authority — `DRO2026_fnc_setFlightAuthority`:

```text
ARMA_AI | DRONE_TWEAKS | FPV_TERMINAL | PLAYER | NONE
```

Переход увеличивает revision и пишет structured event. Fixed-wing macro route создаётся `DRO2026_fnc_buildWaypointFlightPlan` через `MOVE`, `LOITER`, `DESTROY` и явный `setCurrentWaypoint`. Постоянный `setVelocity` на маршевом участке не используется. Terminal guidance ограничен коротким участком, timeout и cleanup. Projectile/fallback classes без полноценного vehicle AI остаются отдельным детерминированным adapter path.

DDT не запускает свои all-machine scanners: DRO server scheduler выбирает группы и вызывает только разрешённые публичные DDT hooks. KVN/fibre FPV определяется registry/inheritance и игнорирует RF/EW, но сохраняет физический damage/collision/range lifecycle.

## 7. Ручное управление UAV

1. Сервер materialize UAV и crew.
2. Mission record хранит requester UID/netId, source node и authorized controller.
3. Только целевой клиент получает `DRO2026_fnc_offerFPVControl`.
4. Клиент проверяет UAV Terminal.
5. Локально выполняются `enableUAVConnectability` и `connectTerminalToUAV`.
6. Результат проверяется через `getConnectedUAV` / `UAVControl`.
7. Клиент подтверждает серверу через `DRO2026_fnc_confirmUAVControl`.

`setOwner` для UAV AI не используется.

## 8. Logistics state machine

```text
CREATED → QUEUED → ASSEMBLING → ENROUTE → ARRIVED
→ TRANSFERRING → RETURNING → COMPLETE
                         ↘ FAILED | DESTROYED
```

`DRO2026_fnc_logisticsDirector` — один централизованный manager. Он ограничивает jobs отдельно для каждой стороны, резервирует source stock, materialize 1–2 cargo vehicles и escort, строит road-aware route и меняет destination stock только после прибытия живого cargo vehicle.

Виртуального пополнения по ETA нет. Materialization failure возвращает резерв сразу. Уничтоженный convoy резерв не возвращает. Если destination уничтожен в пути, convoy переходит в `RETURNING`; cargo возвращается source node только после физического возвращения.

`DRO2026_fnc_transferLogisticsCargo` проверяет поддержку ammo/fuel/repair cargo и locality перед изменением vehicle/turret state.

## 9. Резервы

`DRO2026_ReserveMultiplier = 3.0` применяется один раз через `DRO2026_fnc_applyReserveMultiplier` к initial/max/node/theatre stock. Флаг `DRO2026_reserveMultiplierApplied` не допускает повторного умножения. Стоимость единичного запуска и потери не умножается.

ISR разделяется по pool key: small quad, tactical, long-range, reusable/expendable и MALE/HALE при наличии соответствующих class descriptors.

## 10. Enemy recon-strike и dynamic tasks

Enemy director получает цели только через contact/belief model. Свежесть, confidence и uncertainty определяют разрешение strike mission. Player/HQ/site не раскрываются автоматически.

`DRO2026_PrimaryObjectiveCount` ограничен диапазоном `1..5`. Дополнительно может существовать до двух dynamic tasks, создаваемых только из событий контакта/логистики/удара. На стадии suspected используется uncertainty area; точный marker допустим только после подтверждения. Mobile contact update обновляет task location.

Hostage/hostile-civilian paths удалены из modern selection. Civilian layer остаётся ambient и proximity/dynamic-simulation managed.

## 11. Asset/interceptor adapters

`DRO2026_fnc_buildAssetDescriptors` хранит отдельно:

```text
vehicleClass, launcherClass, weaponClass,
muzzleName, magazineClass, ammoClass,
roles, capabilities, airMuzzles
```

P1-Sun/Sting и другие optional families обнаруживаются по реальным config entries. `DRO2026_fnc_dumpAssetClass` формирует diagnostic dump CfgVehicles/weapons/magazines/ammo/turrets/sensors/muzzles. Display name не используется как ID.

Interceptor request разрешается только для живого hostile UAV object и совместимого air-capable muzzle/ammo. Функция использует `reveal`, `doTarget`, `aimedAtTarget`, `canFire` и `fireAtTarget` с фактическим muzzle. Несовместимость возвращает `NO_COMPATIBLE_WEAPON` до расхода ресурса.

## 12. Cleanup и производительность

- один logistics manager;
- один dynamic objective manager;
- один performance snapshot loop;
- DDT dispatch и intel — bounded periodic passes;
- component damage оценивается central network sync;
- нет отдельного бесконечного watcher на каждый radar/site;
- guidance loops имеют timeout и ownership guard;
- завершение миссии прерывает scheduled phases и очищает mission objects/groups.

При `DRO2026_PERF_TELEMETRY = true` раз в 60 секунд пишутся FPS, active scripts, units, vehicles, groups, contacts, drone missions, logistics jobs и dynamic tasks.

## 13. Ссылки на BI Wiki

- [`params`](https://community.bohemia.net/wiki/params)
- [Locality in Multiplayer](https://community.bohemia.net/wiki/Locality_in_Multiplayer)
- [Arma 3: Remote Execution](https://community.bohemia.net/wiki/Arma_3:_Remote_Execution)
- [`remoteExec`](https://community.bohemia.net/wiki/remoteExec), [`remoteExecCall`](https://community.bohemia.net/wiki/remoteExecCall), [`remoteExecutedOwner`](https://community.bohemia.net/wiki/remoteExecutedOwner)
- [CfgRemoteExec](https://community.bohemia.net/wiki/Arma_3:_CfgRemoteExec)
- [`connectTerminalToUAV`](https://community.bohemia.net/wiki/connectTerminalToUAV), [`enableUAVConnectability`](https://community.bohemia.net/wiki/enableUAVConnectability), [`getConnectedUAV`](https://community.bohemia.net/wiki/getConnectedUAV), [`UAVControl`](https://community.bohemia.net/wiki/UAVControl)
- [`createVehicleCrew`](https://community.bohemia.net/wiki/createVehicleCrew)
- [`addWaypoint`](https://community.bohemia.net/wiki/addWaypoint), [`setWaypointType`](https://community.bohemia.net/wiki/setWaypointType), [`setCurrentWaypoint`](https://community.bohemia.net/wiki/setCurrentWaypoint), [`setWaypointLoiterType`](https://community.bohemia.net/wiki/setWaypointLoiterType), [`setWaypointLoiterRadius`](https://community.bohemia.net/wiki/setWaypointLoiterRadius), [`setWaypointLoiterAltitude`](https://community.bohemia.net/wiki/setWaypointLoiterAltitude)
- [`nearestLocations`](https://community.bohemia.net/wiki/nearestLocations), [`locationPosition`](https://community.bohemia.net/wiki/locationPosition), [`nearRoads`](https://community.bohemia.net/wiki/nearRoads), [`roadAt`](https://community.bohemia.net/wiki/roadAt), [`roadsConnectedTo`](https://community.bohemia.net/wiki/roadsConnectedTo), [`BIS_fnc_findSafePos`](https://community.bohemia.net/wiki/BIS_fnc_findSafePos), [`setVehiclePosition`](https://community.bohemia.net/wiki/setVehiclePosition)
- [Task Framework](https://community.bohemia.net/wiki/Arma_3:_Task_Framework), [`BIS_fnc_taskCreate`](https://community.bohemia.net/wiki/BIS_fnc_taskCreate)
- [`reveal`](https://community.bohemia.net/wiki/reveal), [`targetKnowledge`](https://community.bohemia.net/wiki/targetKnowledge), [`fireAtTarget`](https://community.bohemia.net/wiki/fireAtTarget), [`aimedAtTarget`](https://community.bohemia.net/wiki/aimedAtTarget), [`canFire`](https://community.bohemia.net/wiki/canFire)
- [`setAmmoCargo`](https://community.bohemia.net/wiki/setAmmoCargo), [`setFuelCargo`](https://community.bohemia.net/wiki/setFuelCargo), [`setRepairCargo`](https://community.bohemia.net/wiki/setRepairCargo), [`setVehicleAmmoDef`](https://community.bohemia.net/wiki/setVehicleAmmoDef), [`turretLocal`](https://community.bohemia.net/wiki/turretLocal)
- [Dynamic Simulation](https://community.bohemia.net/wiki/Arma_3:_Dynamic_Simulation), [Mission Optimisation](https://community.bohemia.net/wiki/Mission_Optimisation), [`diag_codePerformance`](https://community.bohemia.net/wiki/diag_codePerformance)

## 14. Непроверенные runtime-границы

Статический contract gate не заменяет Arma runtime. В данной среде не выполнялись SP/hosted/dedicated/JIP/RPT, фактическое подключение optional P1-Sun/KVN/FP-1 классов и видео flight tests. HEMTT отсутствует/не настроен. Эти пункты остаются обязательным post-merge runtime gate.
