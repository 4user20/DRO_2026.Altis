class CfgFunctions
{
    class DRO2026
    {
        tag = "DRO2026";
        class Core
        {
            file = "dro2026\functions\core";
            class preInit {preInit = 1;};
            class initState {};
            class registerAssets {};
            class refreshFactionAssets {};
            class getRoleClass {};
            class isSafeInfantryClass {};
            class sanitizeLegacyPools {};
            class findStrategicPosition {};
            class buildTheaterGraph {};
            class buildCapabilityNetwork {};
            class createNetworkNode {};
            class createNetworkEdge {};
            class changeNetworkNodeStock {};
            class syncNetworkState {};
            class emitEvent {};
            class readEvents {};
            class evaluateOperationPhase {};
            class selectObjectiveOpportunity {};
            class getJammingAtPosition {};
            class getAirWindow {};
            class buildAAR {};
            class getTheaterNode {};
            class createRouteMarkers {};
            class createDroneTeam {};
            class hqVoice {};
            class syncContactMarker {};
            class registerManagedGroup {};
            class findObjectivePos {};
            class createObjectiveRecord {};
            class createSiteRecord {};
            class createContactRecord {};
            class validateSiteRecord {};
            class spawnGuard {};
            class completeObjective {};
            class createFriendlyPositions {};
            class createStrategicInfrastructure {};
            class calculateTerrainAwareAim {};
            class resolveLauncherAmmo {};
            class clientInit {postInit = 1;};
        };
        class AI
        {
            file = "dro2026\functions\ai";
            class initAITransport {};
            class writeAIRequest {};
            class readAIResponses {};
            class buildIntentCandidates {};
            class buildAISnapshot {};
            class validateAIDecision {};
            class commitIntent {};
            class applyStrategicPolicy {};
            class aiResponseListener {};
            class aiOperationDirector {};
            class strategicAIDirector {};
        };
        class Maneuver
        {
            file = "dro2026\functions\maneuver";
            class assignManagedGroupIds {};
            class claimGroupLease {};
        };
        class Directors
        {
            file = "dro2026\functions\directors";
            class startDirectors {};
            class operationDirector {};
            class airDefenceDirector {};
            class relocateDroneTeam {};
            class performanceGovernor {};
            class addContact {};
            class sensorDirector {};
            class enemyFPVDirector {};
            class enemyISRDirector {};
            class longRangeDroneDirector {};
            class friendlyStrikeDirector {};
            class logisticsDirector {};
            class civilTrafficDirector {};
            class civilianIntelDirector {};
            class enemyAirDirector {};
            class reactionDirector {};
            class orderEncirclement {};
        };
        class Objectives
        {
            file = "dro2026\functions\objectives";
            class selectObjective {};
            class objectiveLogisticsHub {};
            class objectiveLogisticsRun {};
            class objectiveArtilleryHunt {};
            class artilleryLoop {};
            class objectiveEWHunt {};
            class objectiveConvoy {};
            class objectiveDroneSite {};
            class objectiveUAVTeam {};
            class objectiveAirDefence {};
            class objectiveISRRecon {};
            class objectiveCutRear {};
        };
        class Support
        {
            file = "dro2026\functions\support";
            class launchFPVStrike {};
            class isFPVExternallyControlled {};
            class calculateFPVLeadPoint {};
            class launchLongRangeStrike {};
            class trackIncomingDrone {};
            class offerFPVControl {};
            class requestFPV {};
            class requestISR {};
            class requestLongRangeSupport {};
            class serverRequestSupport {};
            class supportMessage {};
            class openSupportConsole {};
            class beginSupportTargeting {};
            class requestArtillery {};
            class requestAirSupport {};
            class launchISR {};
            class showStatus {};
        };
    };
};
