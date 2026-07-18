# Graph Report - .  (2026-07-18)

## Corpus Check
- 268 files · ~0 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 268 nodes · 1681 edges · 27 communities (22 shown, 5 thin omitted)
- Extraction: 42% EXTRACTED · 58% INFERRED · 0% AMBIGUOUS · INFERRED: 980 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]

## God Nodes (most connected - your core abstractions)
1. `bis_fnc_tasksetstate` - 38 edges
2. `bis_fnc_randomint` - 37 edges
3. `bis_fnc_getcfgdata` - 34 edges
4. `bis_fnc_findsafepos` - 31 edges
5. `bis_fnc_groupfromnetid` - 28 edges
6. `bis_fnc_dirto` - 27 edges
7. `bis_fnc_relpos` - 26 edges
8. `bis_fnc_randomindex` - 14 edges
9. `bis_fnc_settask` - 13 edges
10. `bis_fnc_sortby` - 12 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (27 total, 5 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.31
Nodes (20): bis_fnc_ambientanimcombat, bis_fnc_buildingpositions, bis_fnc_consolidatearray, bis_fnc_findoverwatch, bis_fnc_findsafepos, bis_fnc_getcfgdata, bis_fnc_getcfgisclass, bis_fnc_isbuildingenterable (+12 more)

### Community 2 - "Community 2"
Cohesion: 0.11
Nodes (12): bis_fnc_addcommmenuitem, bis_fnc_addrespawnposition, bis_fnc_ambientflyby, bis_fnc_dirto, bis_fnc_groupfromnetid, bis_fnc_randompos, bis_fnc_relpos, bis_fnc_showsubtitle (+4 more)

### Community 3 - "Community 3"
Cohesion: 0.12
Nodes (18): bis_fnc_allturrets, bis_fnc_arraypop, bis_fnc_arrayshuffle, bis_fnc_baseweapon, bis_fnc_error, bis_fnc_findinpairs, bis_fnc_getturrets, bis_fnc_instring (+10 more)

### Community 4 - "Community 4"
Cohesion: 0.15
Nodes (14): bis_fnc_ambientanim, bis_fnc_arsenal, bis_fnc_arsenal_cam, bis_fnc_deletetask, bis_fnc_logformat, bis_fnc_logformatserver, bis_fnc_mp, bis_fnc_rsclayer (+6 more)

### Community 5 - "Community 5"
Cohesion: 0.21
Nodes (11): bis_fnc_destroycity, bis_fnc_drawao, bis_fnc_endmission, bis_fnc_endmissionserver, bis_fnc_holdactionadd, bis_fnc_respawntickets, bis_fnc_sharedobjectives, bis_fnc_sortby (+3 more)

### Community 6 - "Community 6"
Cohesion: 0.31
Nodes (6): bis_fnc_addstackedeventhandler, bis_fnc_monthdays, bis_fnc_nearestposition, bis_fnc_removestackedeventhandler, bis_fnc_setovercast, bis_fnc_setppeffecttemplate

### Community 7 - "Community 7"
Cohesion: 0.36
Nodes (4): bis_fnc_settask, bis_fnc_taskchildren, bis_fnc_taskcreate, bis_fnc_taskreal

### Community 8 - "Community 8"
Cohesion: 0.29
Nodes (6): bis_fnc_itemtype, bis_fnc_setpitchbank, bis_fnc_sidetype, bis_fnc_vectorfromxtoy, bis_fnc_vectormultiply, bis_fnc_weaponsentitytype

## Knowledge Gaps
- **39 isolated node(s):** `bis_fnc_rsclayer`, `bis_fnc_logformat`, `bis_fnc_tasksettype`, `bis_fnc_typetext2`, `bis_fnc_sharedobjectives` (+34 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `bis_fnc_rsclayer`, `bis_fnc_logformat`, `bis_fnc_tasksettype` to the rest of the system?**
  _39 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.10574712643678161 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.12315270935960591 - nodes in this community are weakly interconnected._
- **Should `Community 4` be split into smaller, more focused modules?**
  _Cohesion score 0.1476923076923077 - nodes in this community are weakly interconnected._