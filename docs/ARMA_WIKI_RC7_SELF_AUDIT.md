# DRO 2026 RC7 — self-audit по официальной Arma 3 Community Wiki

Дата аудита: 2026-07-20  
PR: `#11`  
Ветка: `feat/rc6-strategic-operational-layer`

## Область проверки

Повторно проверены изменённые контракты:

- ATL / AGL / ASL и безопасное размещение;
- контактная схема и жизненный цикл;
- `exitWith` и завершение миссии;
- locality создания экипажа и управления техникой;
- артиллерийские команды и координаты цели;
- формирование С-300;
- детерминированный генератор;
- логистические колонны;
- task-state spelling.

## Официальные источники

- [ATLToASL](https://community.bohemia.net/wiki/ATLToASL)
- [AGLToASL](https://community.bohemia.net/wiki/AGLToASL)
- [ASLToAGL](https://community.bohemia.net/wiki/ASLToAGL)
- [locationPosition](https://community.bohemia.net/wiki/locationPosition)
- [exitWith](https://community.bohemia.net/wiki/exitWith)
- [createVehicleCrew](https://community.bohemia.net/wiki/createVehicleCrew)
- [addVehicle](https://community.bohemia.net/wiki/addVehicle)
- [doArtilleryFire](https://community.bohemia.net/wiki/doArtilleryFire)
- [getArtilleryETA](https://community.bohemia.net/wiki/getArtilleryETA)
- [inRangeOfArtillery](https://community.bohemia.net/wiki/inRangeOfArtillery)
- [findEmptyPosition](https://community.bohemia.net/wiki/findEmptyPosition)
- [Number](https://community.bohemia.net/wiki/Number)
- [BIS_fnc_taskSetState](https://community.bohemia.net/wiki/BIS_fnc_taskSetState)

## Найденные ошибки и исправления

### 1. Неправильная конвертация ATL через `AGLToASL`

`getPosATL`, дорожные позиции и результаты `BIS_fnc_findSafePos` использовались как ATL, но преобразовывались через `AGLToASL`.

Исправлено:

- добавлен `DRO2026_fnc_normalizePositionASL`;
- ATL преобразуется через `ATLToASL`;
- AGL преобразуется через `AGLToASL` только при явном `positionSpace = "AGL"`;
- `locationPosition` нормализуется на поверхность, поскольку его Z может быть отрицательным относительно поверхности;
- validator запрещает возврат старых выражений `AGLToASL _positionATL`, `AGLToASL _fallback` и `AGLToASL _sideOffset`.

### 2. ATL-контакты сохранялись как `positionASL`

`fn_addContact` обычно получал `getPosATL`, но сохранял массив под ключом `positionASL` без преобразования.

Исправлено:

- вход контакта имеет явный `positionSpace`;
- внутренняя схема контакта хранит только ASL;
- fusion, velocity estimate, uncertainty и last-known position работают в одном пространстве;
- BDA больше не перезаписывает lifecycle state значениями `DETECTED` / `CONFIRMED`.

### 3. Смешивались `netId` объекта и устойчивый `NODE_*`

`networkNodeId` мог попадать в поле `subjectNetId`, хотя это не Arma network object ID.

Исправлено:

- `targetNetId` / `subjectNetId` содержат только `netId` физического объекта;
- `stableSubjectId` / `subjectId` содержат `NODE_*`, site ID или другой устойчивый идентификатор;
- direct long-range contacts передают все schema-4 аргументы без смещения параметров.

### 4. `exitWith` не останавливал `endMission.sqf`

`exitWith` находился внутри `then`-scope. Он прекращал только вложенный блок, после чего выполнялись blackout и `BIS_fnc_endMission*`.

Исправлено:

- вложенный scope только устанавливает `_deferEnd`;
- основной scope выполняет `if (_deferEnd) exitWith {};`;
- отсутствующие network nodes блокируют endgame, а не считаются уничтоженными.

### 5. Фазы могли перескочить несколько стадий за один вызов

Последовательность независимых `if` могла провести операцию через несколько фаз за один evaluation tick.

Исправлено:

- переходы выполняются через `switch _oldPhase`;
- за один вызов возможен максимум один обычный phase transition;
- `ENDGAME` остаётся отдельным fail-closed gate.

### 6. `createVehicleCrew` не назначал технику группе

Согласно Wiki, команда создаёт экипаж, но не добавляет машину в assigned vehicles группы.

Исправлено:

- `DRO2026_fnc_crewManagedVehicle` проверяет locality и вызывает `_group addVehicle _vehicle`;
- после объединения экипажей convoy director назначает каждую грузовую и escort-машину итоговой группе;
- cleanup выполняется только владельцем локального объекта.

### 7. Артиллерия получала ASL вместо PositionAGL

Контакты теперь корректно хранятся в ASL, но `doArtilleryFire` ожидает PositionAGL и локальный артиллерийский объект.

Исправлено:

- fire solution преобразуется `ASLToAGL`;
- проверяются `local _arty`, `getArtilleryETA >= 0`, `inRangeOfArtillery` и положительное число выстрелов;
- stock списывается только после валидного решения и вызова fire command.

### 8. Геометрия С-300 не гарантировала фактические расстояния

Шаблонное spacing использовалось как радиус от центра, а не попарное расстояние между ПУ. Радар выбирался независимо.

Исправлено:

- две ПУ размещаются симметрично с заданным попарным spacing;
- вычисляется и сохраняется `launcherPairDistance`;
- радар проходит фактическую минимальную дистанцию до каждой ПУ;
- SHORAD размещается относительно батареи;
- неполная восточная батарея С-300 откатывается целиком.

### 9. Seeded RNG использовал слишком большие целые

Старый LCG создавал промежуточные значения вне точного целочисленного диапазона single-precision `Number` SQF.

Исправлено:

- modulus `65521`;
- multiplier `251` и increment `13849`;
- промежуточная арифметика остаётся ниже `2^24`;
- независимые stream states сохраняют воспроизводимость подсистем.

### 10. Road preference была фактически road requirement

Candidate sites с флагом road preference исключались при отсутствии дороги даже для систем, которым дорога не обязательна.

Исправлено:

- `_requireRoad` остаётся жёстким условием только для колонн и обязательных дорожных ролей;
- `_roadPreferred` влияет на score и offset, но не уничтожает валидный radar / artillery / HQ candidate.

## Проверка

Каноническая команда:

```bash
python3 tools/validate_all_rc6.py
```

`validate_strategic_operational_contracts.py` теперь отдельно проверяет:

- правильные ATL / AGL / ASL converters;
- отсутствие вложенного endgame `exitWith`;
- lifecycle/BDA separation;
- object `netId` / stable subject ID separation;
- artillery AGL/locality/ETA contract;
- convoy `addVehicle` contract;
- S-300 spacing diagnostics;
- single-precision-safe seeded RNG;
- исправленные direct-contact argument positions.

## Непроверяемое без Arma runtime

Static validation не доказывает:

- реальную доступность классов текущего modset;
- поведение сторонних PBO;
- отсутствие `Wrong weapon selection` в новом RPT;
- фактическую баллистику модовой артиллерии;
- navmesh/road AI поведение конкретных машин;
- runtime FPS и продолжительность 60–120 минут.

Эти пункты остаются обязательным игровым gate перед merge.
