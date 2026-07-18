# Graph Report - .  (2026-07-18)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 203 nodes · 553 edges · 19 communities (15 shown, 4 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 4 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `af3ed02a`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_UI Checkbox Components|UI Checkbox Components]]
- [[_COMMUNITY_Map Marker Icons|Map Marker Icons]]
- [[_COMMUNITY_Lobby Dialog UI|Lobby Dialog UI]]
- [[_COMMUNITY_Faction Selection UI|Faction Selection UI]]
- [[_COMMUNITY_Splash Screen UI|Splash Screen UI]]
- [[_COMMUNITY_Main Menu Settings|Main Menu Settings]]
- [[_COMMUNITY_Faction Selection Dropdowns|Faction Selection Dropdowns]]
- [[_COMMUNITY_Line Drawing Styles|Line Drawing Styles]]
- [[_COMMUNITY_Recon Image Assets|Recon Image Assets]]
- [[_COMMUNITY_Warning Text Elements|Warning Text Elements]]
- [[_COMMUNITY_Environment Settings UI|Environment Settings UI]]
- [[_COMMUNITY_Weather Selection UI|Weather Selection UI]]
- [[_COMMUNITY_Slider Input Controls|Slider Input Controls]]
- [[_COMMUNITY_Initialization Scripts|Initialization Scripts]]
- [[_COMMUNITY_Russian Documentation Files|Russian Documentation Files]]
- [[_COMMUNITY_Dialog Window Base|Dialog Window Base]]
- [[_COMMUNITY_Function Configuration|Function Configuration]]
- [[_COMMUNITY_Russian Changelog|Russian Changelog]]
- [[_COMMUNITY_Russian Voice Transcript|Russian Voice Transcript]]

## God Nodes (most connected - your core abstractions)
1. `sundayText` - 19 edges
2. `DROCheckBoxRemove` - 12 edges
3. `DROCheckBoxSupports` - 12 edges
4. `sundayWarningText` - 12 edges
5. `sundayTitleChoose` - 11 edges
6. `sundayComboPlayerFactions` - 11 edges
7. `sundayComboEnemyFactions` - 11 edges
8. `sundayComboCivFactions` - 11 edges
9. `sundayHeading` - 10 edges
10. `sundayTextMT` - 10 edges

## Surprising Connections (you probably didn't know these)
- `sundayTitleChoose` --inherits--> `sundayHeading`  [EXTRACTED]
  sunday_system/dialogs/dialogsMainMenu.hpp → sunday_system/dialogs/defines.hpp
- `unitTextBG` --inherits--> `sundayText`  [EXTRACTED]
  sunday_system/dialogs/dialogsLobby.hpp → sunday_system/dialogs/defines.hpp
- `sundaySliderWeatherBad` --inherits--> `sundayText`  [EXTRACTED]
  sunday_system/dialogs/dialogsMainMenu.hpp → sunday_system/dialogs/defines.hpp
- `sundayTitleAISize` --inherits--> `sundayText`  [EXTRACTED]
  sunday_system/dialogs/dialogsMainMenu.hpp → sunday_system/dialogs/defines.hpp
- `sundayTitleCivilians` --inherits--> `sundayText`  [EXTRACTED]
  sunday_system/dialogs/dialogsMainMenu.hpp → sunday_system/dialogs/defines.hpp

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Project Documentation** — dro2026_docs_readme_ru, dro2026_docs_config_ru, dro2026_docs_changelog_ru, dro2026_docs_credits_ru, dro2026_docs_optional_mods_ru, dro2026_docs_test_report_ru [INFERRED 0.90]
- **Visual Assets** — images_recon_image, images_recon_image_collection, images_recon_image_notext [INFERRED 0.90]

## Communities (19 total, 4 thin omitted)

### Community 0 - "UI Checkbox Components"
Cohesion: 0.11
Nodes (39): access, linespacing, DROBigButton, CT_BUTTON, DROCheckBoxRemove, CT_CHECKBOXES, ST_CENTER, DROCheckBoxSupports (+31 more)

### Community 1 - "Map Marker Icons"
Cohesion: 0.11
Nodes (33): icon, ActiveMarker, Bunker, Bush, BusStop, Chapel, Church, Command (+25 more)

### Community 2 - "Lobby Dialog UI"
Cohesion: 0.25
Nodes (24): DROBasicButton, DRO_lobbyDialog, action, font, h, idc, idd, movingenable (+16 more)

### Community 3 - "Faction Selection UI"
Cohesion: 0.29
Nodes (20): RscControlsGroup, AddFactionsGroup, action, h, text, w, x, InfoGroup (+12 more)

### Community 4 - "Splash Screen UI"
Cohesion: 0.15
Nodes (16): RscPicture, DRO_facade, DRO_splash, fade, font, h, idc, idd (+8 more)

### Community 5 - "Main Menu Settings"
Cohesion: 0.33
Nodes (15): RscControlsGroupNoScrollbars, RscMapControl, AnimalsSwitchButton, CivsSwitchButton, DynSimSwitchButton, idc, y, mapBox (+7 more)

### Community 6 - "Faction Selection Dropdowns"
Cohesion: 0.44
Nodes (9): DROCombo, onLBSelChanged, rowHeight, sundayCBDay, sundayCBMonth, sundayComboCivFactions, sundayComboEnemyFactions, sundayComboPlayerFactions (+1 more)

### Community 7 - "Line Drawing Styles"
Cohesion: 0.33
Nodes (6): lineDistanceMin, lineLengthMin, lineWidthThick, lineWidthThin, LineMarker, textureComboBoxColor

### Community 8 - "Recon Image Assets"
Cohesion: 0.40
Nodes (5): CREDITS_RU, Dynamic Recon Ops 2026, Recon Image Logo, Recon Image Collection, Recon Image No Text

### Community 9 - "Warning Text Elements"
Cohesion: 0.40
Nodes (5): size, fade, type, sundayWarningText, CT_STRUCTURED_TEXT

### Community 10 - "Environment Settings UI"
Cohesion: 0.60
Nodes (5): EnvironmentGroup, font, sizeEx, sundayTitleDay, sundayTitleMonth

### Community 11 - "Weather Selection UI"
Cohesion: 0.40
Nodes (5): style, sundaySliderWeatherBad, ST_RIGHT, sundayTitleChoose, ST_CENTER

### Community 12 - "Slider Input Controls"
Cohesion: 0.67
Nodes (4): onSliderPosChanged, sundaySliderAISize, sundaySliderWeather, sundaySlider

### Community 14 - "Russian Documentation Files"
Cohesion: 0.67
Nodes (3): OPTIONAL_MODS_RU, README_RU, TEST_REPORT_RU

### Community 15 - "Dialog Window Base"
Cohesion: 0.67
Nodes (3): idd, movingenable, sundayDialog

## Knowledge Gaps
- **33 isolated node(s):** `CfgFunctions`, `CT_STATIC`, `ST_CENTER`, `CT_STATIC`, `ST_LEFT` (+28 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `sundayText` connect `UI Checkbox Components` to `Map Marker Icons`, `Lobby Dialog UI`, `Faction Selection UI`, `Warning Text Elements`, `Environment Settings UI`, `Weather Selection UI`?**
  _High betweenness centrality (0.311) - this node is a cross-community bridge._
- **Why does `sundayTitlePic` connect `Faction Selection UI` to `Splash Screen UI`, `Main Menu Settings`?**
  _High betweenness centrality (0.143) - this node is a cross-community bridge._
- **What connects `CfgFunctions`, `CT_STATIC`, `ST_CENTER` to the rest of the system?**
  _33 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `UI Checkbox Components` be split into smaller, more focused modules?**
  _Cohesion score 0.10931174089068826 - nodes in this community are weakly interconnected._
- **Should `Map Marker Icons` be split into smaller, more focused modules?**
  _Cohesion score 0.11051693404634581 - nodes in this community are weakly interconnected._