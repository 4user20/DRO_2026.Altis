if (!isServer) exitWith {missionNamespace getVariable ["DRO2026_strategicPlan",[]]};
if (missionNamespace getVariable ["DRO2026_strategicPlanBuilt",false]) exitWith {missionNamespace getVariable ["DRO2026_strategicPlan",[]]};
if !(missionNamespace getVariable ["DRO2026_strategicDataInitialized", false]) then {
    [] call DRO2026_fnc_initStrategicOperationData;
};

private _redZones = ["RED_FRONT","RED_OPERATIONAL_DEPTH","RED_REAR","RED_DEEP_REAR","CONTESTED_ZONE"];
private _plan = [];
private _selectCount = {
    params ["_templateKey","_stream"];
    private _template = DRO2026_formationTemplates getOrDefault [_templateKey,createHashMap];
    private _min = _template getOrDefault ["minCount",0];
    private _max = _template getOrDefault ["maxCount",_min];
    _min + floor ([(_max - _min + 1) max 1,_stream,0] call DRO2026_fnc_seededRandom)
};
private _appendType = {
    params ["_planType","_candidateTypes","_zones","_count","_requireRoad","_reservation","_stream"];
    for "_index" from 1 to _count do {
        private _site = [_candidateTypes,_zones,_requireRoad,2200,_reservation,format ["%1_%2",_stream,_index]] call DRO2026_fnc_selectStrategicSite;
        if (_site getOrDefault ["ok",false]) then {
            private _positionATL = +(_site getOrDefault ["positionATL",[]]);
            if (count _positionATL >= 2) then {
                DRO2026_reservedObjectivePositions pushBackUnique _positionATL;
                private _record = createHashMapFromArray [
                    ["id",format ["PLAN_%1_%2",_planType,_index]],
                    ["type",_planType],
                    ["candidateId",_site getOrDefault ["candidateId",""]],
                    ["positionATL",_positionATL],
                    ["positionASL",+(_site getOrDefault ["positionASL",[]])],
                    ["zone",_site getOrDefault ["zone",""]],
                    ["heading",_site getOrDefault ["heading",0]],
                    ["state","VIRTUAL"],
                    ["physicalState","VIRTUAL"],
                    ["selected",true],
                    ["activated",false],
                    ["createdAt",time],
                    ["source",_site getOrDefault ["source",""]]
                ];
                _plan pushBack _record;
            };
        } else {
            ["STRATEGIC","PLAN_SITE_REJECTED",createHashMapFromArray [
                ["type",_planType],["index",_index],["code",_site getOrDefault ["code","NO_CANDIDATE"]]
            ],_planType] call DRO2026_fnc_logStructured;
        };
    };
};

private _s300Count = ["S300_BATTERY","PLAN_S300_COUNT"] call _selectCount;
private _radarCount = ["EARLY_WARNING_RADAR","PLAN_RADAR_COUNT"] call _selectCount;
private _shoradCount = ["SHORAD_SITE","PLAN_SHORAD_COUNT"] call _selectCount;
private _iskanderCount = ["BALLISTIC_MISSILE_SITE","PLAN_ISKANDER_COUNT"] call _selectCount;
private _artilleryCount = ["ARTILLERY_SITE","PLAN_ARTILLERY_COUNT"] call _selectCount;
private _bm35Count = ["BM35_LAUNCH_SITE","PLAN_BM35_COUNT"] call _selectCount;
private _depotCount = ["INDUSTRIAL_LOGISTICS","PLAN_DEPOT_COUNT"] call _selectCount;
private _hqCount = ["COMMAND_LOGISTICS_COMPOUND","PLAN_HQ_COUNT"] call _selectCount;
private _farpCount = ["FARP","PLAN_FARP_COUNT"] call _selectCount;
private _specopsCount = ["SPECIAL_FORCES","PLAN_SPECOPS_COUNT"] call _selectCount;

["S300_BATTERY","S300_BATTERY",["RED_OPERATIONAL_DEPTH","RED_REAR","RED_DEEP_REAR"],_s300Count,true,1300,"PLAN_S300"] call _appendType;
["EARLY_WARNING_RADAR","EARLY_WARNING_RADAR",["RED_REAR","RED_DEEP_REAR"],_radarCount,true,1600,"PLAN_RADAR"] call _appendType;
["SHORAD_SITE","SHORAD_SITE",_redZones,_shoradCount,true,650,"PLAN_SHORAD"] call _appendType;
["BALLISTIC_MISSILE_SITE","BALLISTIC_MISSILE_SITE",["RED_OPERATIONAL_DEPTH","RED_REAR","RED_DEEP_REAR"],_iskanderCount,true,1500,"PLAN_ISKANDER"] call _appendType;
["ARTILLERY_SITE","ARTILLERY_SITE",["RED_FRONT","RED_OPERATIONAL_DEPTH"],_artilleryCount,true,850,"PLAN_ARTILLERY"] call _appendType;
["BM35_LAUNCH_SITE","BM35_LAUNCH_SITE",["RED_REAR","RED_DEEP_REAR"],_bm35Count,true,1000,"PLAN_BM35"] call _appendType;
["INDUSTRIAL_LOGISTICS","INDUSTRIAL_LOGISTICS",["RED_OPERATIONAL_DEPTH","RED_REAR","RED_DEEP_REAR","CONTESTED_ZONE"],_depotCount,true,950,"PLAN_DEPOT"] call _appendType;
["COMMAND_LOGISTICS_COMPOUND","COMMAND_LOGISTICS_COMPOUND",["RED_OPERATIONAL_DEPTH","RED_REAR","RED_DEEP_REAR"],_hqCount,true,1100,"PLAN_HQ"] call _appendType;
["FARP","FARP",["RED_OPERATIONAL_DEPTH","RED_REAR","RED_DEEP_REAR"],_farpCount,true,1500,"PLAN_FARP"] call _appendType;
["SPECIAL_FORCES","COMMAND_LOGISTICS_COMPOUND",["RED_FRONT","RED_OPERATIONAL_DEPTH","CONTESTED_ZONE"],_specopsCount,true,700,"PLAN_SPECOPS"] call _appendType;

missionNamespace setVariable ["DRO2026_strategicPlan",_plan,true];
missionNamespace setVariable ["DRO2026_strategicPlanBuilt",true,true];
DRO2026_operationState set ["strategicPlanCount",count _plan];
DRO2026_operationState set ["strategicPlanSeed",missionNamespace getVariable ["DRO2026_operationSeed",1]];

["STRATEGIC","PLAN_BUILT",createHashMapFromArray [
    ["seed",missionNamespace getVariable ["DRO2026_operationSeed",1]],
    ["entries",count _plan],
    ["s300",_s300Count],["radar",_radarCount],["shorad",_shoradCount],
    ["iskander",_iskanderCount],["artillery",_artilleryCount],["bm35",_bm35Count],
    ["depots",_depotCount],["hq",_hqCount],["farp",_farpCount],["specops",_specopsCount]
],"STRATEGIC_PLAN"] call DRO2026_fnc_logStructured;
_plan
