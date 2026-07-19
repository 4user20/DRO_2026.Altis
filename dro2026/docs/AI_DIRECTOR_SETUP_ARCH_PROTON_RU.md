# Настройка AI Director на Arch Linux / Steam Proton

## 1. Требования

- Node.js 20 или новее;
- npm;
- INIDBI2, загружаемый конкретной сборкой Arma 3;
- Windows Arma 3 под Proton либо совместимый dedicated setup;
- endpoint и API key хотя бы одного OpenAI-compatible provider.

Факт загрузки INIDBI2 под конкретным Proton prefix нельзя подтвердить статически. Проверяйте RPT.

## 2. Настройка sidecar

```bash
cd tools/dro-ai-director
cp DROAI-config.example.cfg DROAI-config.cfg
$EDITOR DROAI-config.cfg
npm test
npm run check
npm run doctor
npm start
```

`DROAI-config.cfg` и `logs/` исключены из Git. Не размещайте ключи в mission/PBO.

Можно использовать environment variables, например:

```bash
export DROAI_TACTICAL_BASE_URL='https://provider.example/v1'
export DROAI_TACTICAL_API_KEY='...'
export DROAI_TACTICAL_MODEL='poolside/Laguna-XS-2.1'
export DROAI_STRATEGIC_BASE_URL='https://integrate.api.nvidia.com/v1'
export DROAI_STRATEGIC_API_KEY='...'
export DROAI_STRATEGIC_MODEL='nvidia/nemotron-3-ultra-550b-a55b'
npm start
```

Фактический model ID всегда сверяйте с `/v1/models` своего провайдера.

## 3. INI folder

Sidecar пытается найти `@INIDBI2/db` рядом с собой. Надёжнее задать абсолютный путь:

```ini
iniFolder=/absolute/path/to/@INIDBI2/db
```

или:

```bash
export DROAI_INI_FOLDER='/absolute/path/to/@INIDBI2/db'
```

После старта должны появиться:

```text
DROAI_in.ini
DROAI_out.ini
```

## 4. Первый запуск — только OBSERVE

В `fn_preInit.sqf` default уже установлен:

```sqf
DRO2026_AI_MODE = "OBSERVE";
```

Запустите sidecar до миссии, затем миссию с `-showScriptErrors`. Проверьте:

- в RPT нет undefined AI functions;
- появляется `AI_BACKEND_ONLINE`;
- `DROAI_out.ini` получает snapshot;
- `DROAI_in.ini` получает `decision`;
- Node пишет accepted decision в NDJSON;
- intent всё равно имеет `selectionSource=DETERMINISTIC_OBSERVE`;
- без sidecar миссия продолжает создавать intents.

## 5. HYBRID

Переключать только после успешного OBSERVE прогона:

```sqf
DRO2026_AI_MODE = "HYBRID";
```

Проверить отдельно:

- valid candidate становится `selectionSource=LLM`;
- неизвестный candidate ID отклоняется;
- stale sequence отклоняется;
- timeout создаёт deterministic intent;
- отключение sidecar во время миссии не останавливает бой;
- FPV salvo остаётся в пределах stocks, slots и hard max.

## 6. Проверки репозитория

```bash
python3 tools/validate_rc6.py
python3 tools/validate_ai_integration.py
# либо общий wrapper:
python3 tools/validate_rc6_with_ai.py

cd tools/dro-ai-director
npm test
npm run check
npm run doctor
```

## 7. Диагностика

### Backend offline

- проверить абсолютный `iniFolder`;
- проверить, создаёт ли Arma `DROAI_out.ini`;
- проверить загрузку INIDBI2 в RPT;
- проверить права на запись каталога;
- проверить, что mission и Node смотрят в один db directory.

### Provider timeout

- уменьшить reasoning/max tokens;
- проверить endpoint/model ID;
- временно включить `mock=true`;
- оставить `OBSERVE` до стабилизации;
- смотреть `logs/decisions.ndjson`.

### Proton

Windows-версия Arma под Proton обычно ожидает Windows extension. Конкретная совместимость INIDBI2 зависит от Proton prefix, параметров запуска и расположения DLL. Этот PR не содержит доказательства runtime-совместимости и не должен описываться как полностью проверенный под Proton без RPT-прогона.
