# RC9 — повторный engine-level аудит по Bohemia Community Wiki

Проверена реализация PR #16 после первого статического CI. Зелёный string-contract validator не считался доказательством корректного поведения движка.

## Исправленные расхождения

1. **POOK root classes.** `pook_96K6_root`, `pook_9K332_Root` и `pook_9K317M2_Root` больше не регистрируются как физические машины. Через `configClasses` находятся только конкретные script-spawnable descendants; `isKindOf [root, CfgVehicles]` проверяет наследование. Root/helper классы отсекаются до `createVehicle`.
2. **Convoy cargo propagation.** Общий resolver принимает явный `cargoType`, а для старых call-sites безопасно выводит `FUEL`/`ARTILLERY_AMMO` из уже side-correct fallback. Специализация использует роли, полученные из `transportFuel`, `transportAmmo` и `transportRepair`, а не только classname.
3. **Fallback validation.** Vanilla fallback проходит тот же side/scope/model/role/blocklist contract, что и registry-класс.
4. **Dynamic simulation.** Для crewed vehicles object dynamic simulation включается до создания экипажа, а group dynamic simulation — после `createVehicleCrew` и `addVehicle`.
5. **Placement.** `setDir` вызывается до `setVehiclePosition`; `findEmptyPosition` обрабатывает `[]` как отказ.
6. **SHORAD disable and rollback.** Лимит `0` больше не превращается в `1`; site активируется только после `validateSiteRecord`, иначе объекты и группы удаляются.
7. **MP header.** Корневой `description.ext` использует `gameType = "Coop"` и публикует `maxPlayers = 8`; это authoritative scenario header override для восьми игровых ролей.

## Основные официальные страницы

- https://community.bohemia.net/wiki/createVehicle
- https://community.bohemia.net/wiki/createVehicleCrew
- https://community.bohemia.net/wiki/addVehicle
- https://community.bohemia.net/wiki/enableDynamicSimulation
- https://community.bohemia.net/wiki/setVehiclePosition
- https://community.bohemia.net/wiki/findEmptyPosition
- https://community.bohemia.net/wiki/configClasses
- https://community.bohemia.net/wiki/isKindOf
- https://community.bohemia.net/wiki/CfgVehicles_Config_Reference
- https://community.bohemia.net/wiki/Description.ext

## Остаточный gate

Статический и Wiki-аудит не заменяет Arma runtime. Нужен свежий dedicated/hosted MP RPT с `[D26T]`, физической проверкой SHORAD, несколькими типами logistics cargo и FPS/soak наблюдением.
