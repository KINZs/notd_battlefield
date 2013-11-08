//Author: [NotD] l0calh0st aka Mathew Baltes
//Website: www.notdelite.com

#pragma dynamic 262144 //Increase heap size to allow big plugin
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define TEAM_SPECTATOR 1
#define TEAM_T 2
#define TEAM_CT 3

#define COLOR_T "255 0 0"
#define COLOR_CT "0 0 255"
#define COLOR_DEF "0 255 255"

#define ASSAULT 0
#define MEDIC 1
#define ENGINEER 2
#define SNIPER 3
#define SUPPORT 4
#define PISTOL 5

#define REVIVERADIUS 75
#define FLAGRADIUS 200

#define CTs_Win	 8
#define Terrorists_Win 9

#define MAXFLAGS 5
#define MAXSPAWNS 15

#define COMMANDER 7

//Handles
new Handle:db = INVALID_HANDLE;
new Handle:hRemoveItems = INVALID_HANDLE;
new Handle:hGameConf = INVALID_HANDLE;

//Classes
new classIndex[MAXPLAYERS + 1];
new classIndexPre[MAXPLAYERS + 1];

//Squads
new squadIndex[MAXPLAYERS + 1];
new usmcSquadCount[6];
new mecSquadCount[6];
new usmcCommander;
new usmcArtillery;
new mecCommander;
new mecArtillery;

//Timers
new Handle:repeatTimer;
new Handle:flagTimer;
new Handle:kitTimer;
new Handle:roundTimer;

//MySQL Data
new kills[MAXPLAYERS + 1];
new deaths[MAXPLAYERS + 1];
new score[MAXPLAYERS + 1][6];

//Ragdoll index
new ragdollIndex[MAXPLAYERS + 1];

//Lives
new usmcTickets = 0;
new mecTickets = 0;

new defaultWeapon[MAXPLAYERS + 1][2];

//Bug fixes
new timeLeft[MAXPLAYERS + 1];
new bool:spawnMenuOpen[MAXPLAYERS + 1];
new maxPlayers;
new bool:isLoaded[MAXPLAYERS + 1];

//Base Data
new Float:mecBase[3];
new Float:usmcBase[3];

//flagID Data
new flagID[MAXFLAGS];
new flagEnt[MAXFLAGS];
new String:flagName[MAXFLAGS][32];
new Float:flagVec[MAXFLAGS][3];
new Float:flagPlayerSpawnVec[MAXFLAGS][MAXSPAWNS][3];
new NumOfFlags;
new NumOfSpawns[MAXFLAGS];
new bool:isNotFirstSpawn[MAXPLAYERS + 1];

//Kit data
new kitArray[MAXPLAYERS + 1];

//Upgrade defines
#define CLASSUPGRADE1 1250 // ~50 Kills
#define CLASSUPGRADE2 10000 // ~50 + 150 Kills
#define CLASSUPGRADE3 20000 // ~50 + 100 + 200 Kills
#define CLASSUPGRADE4 40000 // ~50 + 100 + 200 + 400 Kills

#define PISTOLUPGRADE1 1250 // ~50 Kills
#define PISTOLUPGRADE2 7500 // ~150 Kills
#define PISTOLUPGRADE3 15000 // ~250 Kills
#define PISTOLUPGRADE4 23000 // ~350 Kills
#define PISTOLUPGRADE5 33000 // ~350 Kills

//Booleans
new bool:canShootRocket[MAXPLAYERS + 1];
new bool:canShootGrenade[MAXPLAYERS + 1];
new bool:canDropKit[MAXPLAYERS + 1];

//Offsets
new Float:WorldMinHull[3], Float:WorldMaxHull[3];
new vecOriginOffset;

//Spawn Protection
new clientProtected[MAXPLAYERS+1];

//Class Includes
#include "bf/class/assault.inc"
#include "bf/class/engineer.inc"
#include "bf/class/medic.inc"
#include "bf/class/sniper.inc"
#include "bf/class/support.inc"
#include "bf/class/commander.inc"

//Core Includes
#include "bf/events.inc"
#include "bf/hud.inc"
#include "bf/menu.inc"
#include "bf/flag.inc"
#include "bf/stocks.inc"

public Plugin:myinfo = 
{
	name = "NotD Battlefield",
	author = "[NotD] l0calh0st",
	description = "Battlefield Mod for CS:S",
	url = "http://www.notdelite.com"
};

public OnPluginStart()
{
	HookEvents();
	new String:error[255];
	db = SQL_DefConnect(error, sizeof(error));
	
	if (db == INVALID_HANDLE)
	{
		PrintToServer("Could not connect: %s", error);
	}
	
	g_Cvar_tntAmount   = CreateConVar("sm_tnt_amount", "3", " Number of tnt packs per player at spawn (max 10)", FCVAR_PLUGIN);	//	g_Cvar_Admins      = CreateConVar("sm_tnt_admins", "0", " Allow Admins only to use tnt", FCVAR_PLUGIN);
	g_Cvar_Enable      = CreateConVar("sm_tnt_enabled", "1", " Enable/Disable the TNT plugin", FCVAR_PLUGIN);
	g_Cvar_Delay       = CreateConVar("sm_tnt_delay", "3.0", " Delay between spawning and making tnt available", FCVAR_PLUGIN);
	//	g_Cvar_Restrict    = CreateConVar("sm_tnt_restrict", "0", " Class to restrict TNT to (see forum thread)", FCVAR_PLUGIN);
	g_Cvar_Mode        = CreateConVar("sm_tnt_mode", "0", " Detonation mode: 0=radio 1=crosshairs 2=timer", FCVAR_PLUGIN);
	g_Cvar_tntDetDelay = CreateConVar("sm_tnt_det_delay", "0.5", " Detonation delay", FCVAR_PLUGIN);
	g_Cvar_PlantDelay  = CreateConVar("sm_tnt_plant_delay", "1", " Delay between planting TNT", FCVAR_PLUGIN);
	
	// commands
	RegConsoleCmd("cheer", Command_ChooseSpecial);
	hGameConf = LoadGameConfigFile("plugin.bf");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "RemoveAllItems");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	hRemoveItems = EndPrepSDKCall();
		
	g_WeaponParent = FindSendPropOffs("CBaseCombatWeapon", "m_hOwnerEntity");

	//Rocket launcher
	hGameConf = LoadGameConfigFile("plugin.bf");
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "Detonate");
	hDetonate = EndPrepSDKCall();
	StartPrepSDKCall(SDKCall_GameRules);
	
	hDamage = CreateConVar("missile_damage", "100.0", "Sets the maximum amount of damage the missiles can do", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED, true, 1.0);
	hRadius = CreateConVar("missile_radius", "350.0", "Sets the explosive radius of the missiles", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED, true, 1.0);
	hSpeed = CreateConVar("missile_speed", "500.0", "Sets the speed of the missiles", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED, true, 100.0 ,true, 10000.0);
	hType = CreateConVar("missile_type", "0", "type of missile to use, 0 = dumb missiles, 1 = homing missiles, 2 = crosshair guided", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED, true, 0.0, true, 2.0);
	hEnable = CreateConVar("missile_enable", "1", "1 enables plugin, 0 disables plugin", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED, true, 0.0, true, 1.0);
	hReplace = CreateConVar("missile_replace", "1", "replace this weapon with missiles, 0 = grenade, 1 = flashbang, 2 = smoke", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED, true, 0.0, true, 2.0);
	hTeam = CreateConVar("missile_team", "0", "which team can use missiles, 0 = any, 1 = only terrorists, 2 = only counter terrorists", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED, true, 0.0, true, 2.0);
	
	NadeDamage = GetConVarFloat(hDamage);
	NadeRadius = GetConVarFloat(hRadius);
	NadeSpeed = GetConVarFloat(hSpeed);
	NadeAllowTeam = GetConVarInt(hTeam) + 1;
	
	SteamSpeed = NadeSpeed / 5.0;
	SteamSpreadSpeed = (NadeSpeed / 20.0) + 20.0;
	SteamJetLength = (NadeSpeed / 20.0) + 10.0;
	SteamRate = NadeSpeed / 2.0;
	
	if (GetConVarInt(hEnable))
	{
		AddNormalSoundHook(NormalSHook:NadeBounce);
		hNadeLoop = CreateTimer(0.1, NadeLoop, INVALID_HANDLE, TIMER_REPEAT);
	}
	
	ReplaceNade = "flashbang_projectile";
	
	HookConVarChange(hDamage, ConVarChange);
	HookConVarChange(hRadius, ConVarChange);
	HookConVarChange(hSpeed, ConVarChange);
	HookConVarChange(hType, ConVarChange);
	HookConVarChange(hEnable, ConVarChange);
	HookConVarChange(hReplace, ConVarChange);
	HookConVarChange(hTeam, ConVarChange);
	HookEntityOutput("game_ui", "PlayerOn", EntPlayerOn);
	HookEntityOutput("game_ui", "PlayerOff", EntPlayerOff);

	//TNT code
	strcopy(g_plant_sound, sizeof(g_plant_sound), "weapons/c4/c4_plant.wav");
}

CleanUp()
{
	new maxent = GetMaxEntities(), String:name[64];
	for (new i=GetMaxClients();i<maxent;i++)
	{
		if ( IsValidEntity(i) )
		{
			if ( IsValidEdict(i) )
			{
				GetEdictClassname(i, name, sizeof(name));
				if ( ( StrContains(name, "weapon_") != -1 || StrContains(name, "item_") != -1 ) && GetEntDataEnt2(i, g_WeaponParent) == -1 )
					AcceptEntityInput(i, "Kill");
			}
		}
	}
}

public Action:RemoveRagdoll(Handle:timer, any:client)
{
	//SQL Variables
	new String:error[255], String:query[255], String:authid[30];
	
	//Initialize:
	if(IsValidEntity(ragdollIndex[client]))
	{
		//RemoveEdict(ragdollIndex[client]);
		AcceptEntityInput(ragdollIndex[client], "Kill");
		ragdollIndex[client] = -1;
	}
	
	if (IsClientConnected(client))
	{
		GetClientAuthString(client, authid, sizeof(authid));
		Format(query, sizeof(query), "UPDATE account_data SET deaths = deaths + 1 WHERE steamid = '%s'", authid);
		if (!SQL_FastQuery(db, query))
		{
			
			SQL_GetError(db, error, sizeof(error));
			PrintToServer("Failed to query (error: %s)", error);
		}
	}
}

public Action:resetRocket(Handle:timer, any:client)
{
	canShootRocket[client] = true;
}

public Action:resetGrenade(Handle:timer, any:client)
{
	canShootGrenade[client] = true;
}

public Action:resetKit(Handle:timer, any:client)
{
	canDropKit[client] = true;
}

public ConVarChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if (cvar == hDamage)
	{
		NadeDamage = StringToFloat(newVal);
	}
	
	else if (cvar == hRadius)
	{
		NadeRadius = StringToFloat(newVal);
	}
	
	else if (cvar == hSpeed)
	{
		NadeSpeed = StringToFloat(newVal);
		
		SteamSpeed = NadeSpeed / 5.0;
		SteamSpreadSpeed = (NadeSpeed / 20.0) + 20.0;
		SteamJetLength = (NadeSpeed / 20.0) + 10.0;
		SteamRate = NadeSpeed / 2.0;
	}
	
	else if (cvar == hEnable)
	{
		switch (StringToInt(newVal))
		{
			case 0:
			{
				CloseHandle(hNadeLoop);
				RemoveNormalSoundHook(NormalSHook:NadeBounce);
				RemoveActiveMissiles();
			}
			case 1:
			{
				AddNormalSoundHook(NormalSHook:NadeBounce);
				hNadeLoop = CreateTimer(0.1, NadeLoop, INVALID_HANDLE, TIMER_REPEAT);
			}
		}
	}
	
	else if (cvar == hReplace)
	{
		switch (StringToInt(newVal))
		{
			case 0:
			{
				RemoveActiveMissiles();
				ReplaceNade = "hegrenade_projectile";
			}
			case 1:
			{
				RemoveActiveMissiles();
				ReplaceNade = "flashbang_projectile";
			}
			case 2:
			{
				RemoveActiveMissiles();
				ReplaceNade = "smokegrenade_projectile";
			}
		}
	}
	
	else if (cvar == hTeam)
	{
		NadeAllowTeam = GetConVarInt(hTeam) + 1;
	}
}

StartTimers()
{
	repeatTimer = CreateTimer(2.0, RepeatTimer, _, TIMER_REPEAT);
	flagTimer = CreateTimer(1.0, FlagLoop, _, TIMER_REPEAT);
	kitTimer = CreateTimer(1.0, KitLoop, _, TIMER_REPEAT);
	roundTimer = CreateTimer(60.0, RoundTimer, _, TIMER_REPEAT);
}

KillTimers()
{
	if (repeatTimer != INVALID_HANDLE)
	{
		KillTimer(repeatTimer);
		repeatTimer = INVALID_HANDLE;
	}
	
	if (flagTimer != INVALID_HANDLE)
	{
		KillTimer(flagTimer);
		flagTimer = INVALID_HANDLE;
	}
	
	if (kitTimer != INVALID_HANDLE)
	{
		KillTimer(kitTimer);
		kitTimer = INVALID_HANDLE;
	}
	if (roundTimer != INVALID_HANDLE)
	{
		KillTimer(roundTimer);
		roundTimer = INVALID_HANDLE;
	}
}

public GetAccountInfo(client)
{
	new String:auth[25];
	new String:error[255];
	GetClientAuthString(client, auth, sizeof(auth));
	decl String:query[255];
	
	Format(query, sizeof(query), "SELECT * FROM account_data WHERE steamid = '%s'", auth);
	new Handle:sqlquery = SQL_Query(db, query);
	
	if (sqlquery == INVALID_HANDLE)
	{
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("Failed to query (error: %s)", error);
		KickClient(client, "[BF] Failed to retrieve account info");
	}
	else if (!SQL_GetRowCount(sqlquery))
	{
		Format(query, sizeof(query), "INSERT INTO account_data (steamid) VALUES('%s')", auth);
		if (!SQL_FastQuery(db, query))
		{
			SQL_GetError(db, error, sizeof(error));
			PrintToServer("Failed to query (error: %s)", error);
		}
		//GetAccountInfo(client);
		PrintToServer("Player data has been inserted for client %d", client);
	}
	else 
	{
		SQL_FetchRow(sqlquery);
		PrintToServer("Player data has been grabbed for client %d", client);
		
		kills[client] = SQL_FetchInt(sqlquery, 2);
		PrintToServer("Client %d kills = %d", client, kills[client]);
		deaths[client] = SQL_FetchInt(sqlquery, 3);
		PrintToServer("Client %d deaths = %d", client, deaths[client]);
		score[client][ASSAULT] = SQL_FetchInt(sqlquery, 4);
		score[client][MEDIC] = SQL_FetchInt(sqlquery, 5);
		score[client][ENGINEER] = SQL_FetchInt(sqlquery, 6);
		score[client][SNIPER] = SQL_FetchInt(sqlquery, 7);
		score[client][SUPPORT] = SQL_FetchInt(sqlquery, 8);
		score[client][PISTOL] = SQL_FetchInt(sqlquery, 9);
		isLoaded[client] = true;
	}
	CloseHandle(sqlquery);
}



public CheckPrimUnlockAnnounce(client, oldScore, newScore)
{
	if (oldScore < CLASSUPGRADE1 && newScore > CLASSUPGRADE1)
	{
		PrintToChat(client, "[BF] Congratulations! You unlocked a new class speciality.");
		PrintToChat(client, "[BF] Press j or 'bind <key> cheer' to use it.");
	}
	else if (oldScore < CLASSUPGRADE2 && newScore > CLASSUPGRADE2)
	{
		PrintToChat(client, "[BF] Congratulations! You unlocked a new primary weapon.");
		PrintToChat(client, "[BF] Type !menu -> Primary Weapon to use it.");
	}
	else if (oldScore < CLASSUPGRADE3 && newScore > CLASSUPGRADE3)
	{
		if (classIndex[client] != MEDIC || classIndex[client] != SUPPORT)
		{
			PrintToChat(client, "[BF] Congratulations! You unlocked a new primary weapon.");
			PrintToChat(client, "[BF] Type !menu -> Primary Weapon to use it.");
		}
		else
		{
			if (classIndex[client] == MEDIC)
			{
				PrintToChat(client, "[BF] Congratulations! You unlocked a new class speciality.");
				PrintToChat(client, "[BF] You are now able to revive peoples!");
				PrintToChat(client, "[BF] Press j or 'bind <key> cheer' while facing a dead body,");
				PrintToChat(client, "[BF] to revive it. Hurry though, you have 15 seconds after they die.");
			}
			else 
			{
				PrintToChat(client, "[BF] Congratulations! You unlocked a new class speciality.");
				PrintToChat(client, "[BF] You have gotten a new pouch which expands your current");
				PrintToChat(client, "[BF] ability to carry grenades from 1 to 3.");
			}
		}
	}
	else if (oldScore < CLASSUPGRADE4 && newScore > CLASSUPGRADE4)
	{
		PrintToChat(client, "[BF] Congratulations! You unlocked a new primary weapon.");
		PrintToChat(client, "[BF] Type !menu -> Primary Weapon to use it.");
	}
}

public CheckSecUnlockAnnounce(client, oldScore, newScore)
{
	if (oldScore < PISTOLUPGRADE1 && newScore > PISTOLUPGRADE1)
	{
		PrintToChat(client, "[BF] Congratulations! You unlocked a new secondary weapon.");
		PrintToChat(client, "[BF] Type !menu -> Secondary Weapon to use it.");
	}
	else if (oldScore < PISTOLUPGRADE2 && newScore > PISTOLUPGRADE2)
	{
		PrintToChat(client, "[BF] Congratulations! You unlocked a new secondary weapon.");
		PrintToChat(client, "[BF] Type !menu -> Secondary Weapon to use it.");
	}
	else if (oldScore < PISTOLUPGRADE3 && newScore > PISTOLUPGRADE3)
	{
		PrintToChat(client, "[BF] Congratulations! You unlocked a new secondary weapon.");
		PrintToChat(client, "[BF] Type !menu -> Secondary Weapon to use it.");
	}
	else if (oldScore < PISTOLUPGRADE4 && newScore > PISTOLUPGRADE4)
	{
		PrintToChat(client, "[BF] Congratulations! You unlocked a new secondary weapon.");
		PrintToChat(client, "[BF] Type !menu -> Secondary Weapon to use it.");
	}
	else if (oldScore < PISTOLUPGRADE5 && newScore > PISTOLUPGRADE5)
	{
		PrintToChat(client, "[BF] Congratulations! You unlocked a new secondary weapon.");
		PrintToChat(client, "[BF] Type !menu -> Secondary Weapon to use it.");
	}
}

CreateKit(client)
{
	new Float:vec[3];
	GetClientAbsOrigin(client, vec);
	
	if (kitArray[client] == 0)
		kitArray[client] = -1;
		
	if (kitArray[client] != -1)
	{
		//RemoveEdict(kitArray[client]);
		if (IsValidEntity(kitArray[client]))
			AcceptEntityInput(kitArray[client], "Kill");
		kitArray[client] = -1;
	}
	
	
	if (classIndex[client] == MEDIC)
	{
		new entityCount = GetEntityCount();
		
		if (entityCount > GetMaxEntities())
			return;
		
		kitArray[client] = CreateEntityByName("prop_dynamic_override");
		//DispatchKeyValue(kitArray[client], "solid","0");
		DispatchKeyValue(kitArray[client], "model", "models/items/healthkit.mdl");
		DispatchSpawn(kitArray[client]);
		SetEntPropEnt(kitArray[client], Prop_Send, "m_hOwnerEntity", client);
		TeleportEntity(kitArray[client], vec, NULL_VECTOR, NULL_VECTOR);
	}
	else if (classIndex[client] == SUPPORT)
	{
		new entityCount = GetEntityCount();
		
		if (entityCount > GetMaxEntities())
			return;
		
		kitArray[client] = CreateEntityByName("prop_dynamic_override");
		//DispatchKeyValue(kitArray[client], "solid","0");
		DispatchKeyValue(kitArray[client], "model", "models/items/boxmrounds.mdl");
		DispatchSpawn(kitArray[client]);
		SetEntPropEnt(kitArray[client], Prop_Send, "m_hOwnerEntity", client);
		TeleportEntity(kitArray[client], vec, NULL_VECTOR, NULL_VECTOR);
	}
}

public Action:KitLoop(Handle:timer)
{
	new kitIndex = -1;
	new kitOwner = -1;
	new Float:origin[3];
	new Float:targetVec[3];
	new ownerTeam = -1;

	while ((kitIndex = FindEntityByClassname(kitIndex, "prop_dynamic")) != -1)
	{
		if (IsValidEntity(kitIndex))
		{
			kitOwner = GetEntPropEnt(kitIndex, Prop_Send, "m_hOwnerEntity");
			if (kitOwner > 0)
			{
				
				if (!IsPlayerAlive(kitOwner))
				{
					if (kitIndex != -1)
					{
						//RemoveEdict(kitIndex);
						AcceptEntityInput(kitIndex, "Kill");
						kitArray[kitOwner] = -1;
					}
				}
				else
				{
					ownerTeam = GetClientTeam(kitOwner);
					GetEntPropVector(kitIndex, Prop_Data, "m_vecOrigin", origin);
					//PrintToServer("Origin %f %f %f", origin[0], origin[1], origin[2]);
					for (new x = 1; x < maxPlayers + 1; x++)
					{
						if (!IsValidEdict(x))
							continue;

						if (!IsClientInGame(x))
							continue;
					
						if (!IsPlayerAlive(x))
							continue;

						if (ownerTeam != GetClientTeam(x))
							continue;

						GetClientAbsOrigin(x, targetVec);
						
						if (GetVectorDistance(origin, targetVec) < 200)
						{
							if (classIndex[kitOwner] == MEDIC)
							{
								new clientHP = GetClientHealth(x);
								
								if (clientHP < 100)
								{
									SetEntityHealth(x, clientHP + 2);
								}
								else
								{
									if (clientHP > 100)
										SetEntityHealth(x, 100);
								}
								score[kitOwner][MEDIC] += 2;
							}
							else if (classIndex[kitOwner] == SUPPORT)
							{
								PrintToServer("Client should be getting ammo");
								new weaponid;
								new String:weaponname[25];
								weaponid = GetPlayerWeaponSlot(x, 0);
								GetEdictClassname(weaponid, weaponname, sizeof(weaponname));
								SetWeaponAmmo(x, GetWeaponAmmoOffset(weaponname), GetWeaponAmmo(x, GetWeaponAmmoOffset(weaponname)) + 5);
								weaponid = GetPlayerWeaponSlot(x, 1);
								GetEdictClassname(weaponid, weaponname, sizeof(weaponname));
								SetWeaponAmmo(x, GetWeaponAmmoOffset(weaponname), GetWeaponAmmo(x, GetWeaponAmmoOffset(weaponname)) + 5);
								if (tntAmount[x] < 3)
									tntAmount[x]++;
								if (rocketAmount[x] < 3)
									rocketAmount[x]++;
								if (grenadeAmount[x] < 3)
									grenadeAmount[x]++;
								score[kitOwner][SUPPORT] += 2;
							}
						}
					}
				}
			}
		}
	}
}

public Action:RepeatTimer(Handle:timer)
{
	UpdateHud();
	return Plugin_Continue;
}

public Action:RoundTimer(Handle:timer)
{	
	if (GetFlagOwner(0) == 3 && flagID[0] == 100)
		mecTickets--;
	if (GetFlagOwner(1) == 3 && flagID[1] == 100)
		mecTickets--;
	if (GetFlagOwner(2) == 3 && flagID[2] == 100)
		mecTickets--;
	if (GetFlagOwner(0) == 2 && flagID[0] == -100)
		usmcTickets--;
	if (GetFlagOwner(1) == 2 && flagID[1] == -100)
		usmcTickets--;
	if (GetFlagOwner(2) == 2 && flagID[2] == -100)
		usmcTickets--;
		
	if (usmcArtillery != 0)
		usmcArtillery--;
	if (mecArtillery != 0)
		mecArtillery--;
		
	//Debug info
	new index, currStatic, currPhysicOverride, currDynamicOverride, currPhysic, currDynamic;
	new currentEnts = GetEntityCount();
	new maxEnts = GetMaxEntities();
	LogMessage("[BF] There are currently [%d/%d] entities in the server", currentEnts, maxEnts);
	
	while ((index = FindEntityByClassname(index, "prop_static")) != -1)
	{
		if (IsValidEntity(index))
		{
			currStatic++;
		}
	}
	while ((index = FindEntityByClassname(index, "prop_dynamic_override")) != -1)
	{
		if (IsValidEntity(index))
		{
			currDynamicOverride++;
		}
	}
	while ((index = FindEntityByClassname(index, "prop_physics_override")) != -1)
	{
		if (IsValidEntity(index))
		{
			currPhysicOverride++;
		}
	}
	while ((index = FindEntityByClassname(index, "prop_physics")) != -1)
	{
		if (IsValidEntity(index))
		{
			currPhysic++;
		}
	}
	while ((index = FindEntityByClassname(index, "prop_dynamic")) != -1)
	{
		if (IsValidEntity(index))
		{
			currDynamic++;
		}
	}
	LogMessage("[BF] Physics: %d Physics-O: %d Dynamic: %d Dynamic-O: %d Static: %d", currPhysic, currPhysicOverride, currDynamic, currDynamicOverride, currStatic);
	
	if (currentEnts > 1500)
	{
		SaveEdictInfo(currentEnts);
	}
	
	RemoveActiveMissiles();
}

public SaveEdictInfo(NumOfEnts)
{
	new String:buffer[64];
	GetCurrentMap(buffer, sizeof(buffer));
	
	new String:path[255];
	Format(path, sizeof(path), "addons/sourcemod/data/bf/crash/%s.txt", buffer);
	Format(buffer, sizeof(buffer), "\"%s\"", buffer);

	if (FileExists(path))
	{	
		DeleteFile(path);
	}
	
	new Handle:file = OpenFile(path, "wt");
	if (file == INVALID_HANDLE)
	{
		LogError("Could not open spawn point file \"%s\" for writing.", path);
		return;
	}	

	WriteFileLine(file, buffer);
	WriteFileLine(file, "{");

	for (new index = 1; index < NumOfEnts; index++)
	{
		GetEdictClassname(index, buffer, sizeof(buffer));
		WriteFileLine(file, buffer);
	}
	
	WriteFileLine(file, "}");	
	CloseHandle(file);	

	return;
}

public OnClientPostAdminCheck(client)
{	
	isLoaded[client] = false;
	clientProtected[client] = false;
	squadIndex[client] = -1;
	classIndex[client] = 1; //Default Assault
	defaultWeapon[client][0] = 0;
	defaultWeapon[client][1] = 0;
	score[client][ASSAULT] = 0;
	score[client][MEDIC] = 0;
	score[client][ENGINEER] = 0;
	score[client][SNIPER] = 0;
	score[client][SUPPORT] = 0;
	score[client][PISTOL] = 0;
	kills[client] = 0;
	deaths[client] = 0;
	
	for (new i = GetConVarInt(g_Cvar_tntAmount); i > 0 ; i--)
	{
		if (tnt_entity[client][i] != 0)
		{
			CreateTimer(2.0, RemoveTNT, tnt_entity[client][i]);
			tnt_entity[client][i] = 0;
		}
	}
	
	GetAccountInfo(client);
	
	SetDefaultWeapon(client);
	
	if (isLoaded[client])
	{
		tntAmount[client] = 3;
		rocketAmount[client] = 3;
		grenadeAmount[client] = 3;
		canShootGrenade[client] = true;
		canShootRocket[client] = true;
		canDropKit[client] = true;
		timeLeft[client] = 10;
		spawnMenuOpen[client] = false;
	}
}

public OnClientDisconnect(client)
{	
	for (new i = GetConVarInt(g_Cvar_tntAmount); i > 0 ; i--)
	{
		if (tnt_entity[client][i] != 0)
		{
			CreateTimer(2.0, RemoveTNT, tnt_entity[client][i]);
			tnt_entity[client][i] = 0;
		}
	}
	
	if (usmcCommander == client)
		usmcCommander = -1;
	else if (mecCommander == client)
		mecCommander = -1;
		
	isLoaded[client] = false;
	clientProtected[client] = false;
	isNotFirstSpawn[client] = false;
}

public SetDefaultWeapon(client)
{
	if (classIndexPre[client] == ASSAULT)
	{
		if (score[client][ASSAULT] > CLASSUPGRADE4)
			defaultWeapon[client][0] = 7;
		else if (score[client][ASSAULT] > CLASSUPGRADE3)
			defaultWeapon[client][0] = 1;
		else if (score[client][ASSAULT] > CLASSUPGRADE2)
			defaultWeapon[client][0] = 3;
		else
			defaultWeapon[client][0] = 0;
	}
	else if (classIndexPre[client] == MEDIC)
	{
		if (score[client][MEDIC] > CLASSUPGRADE4)
			defaultWeapon[client][0] = 15;
		else if (score[client][MEDIC] > CLASSUPGRADE2)
			defaultWeapon[client][0] = 13;
		else
			defaultWeapon[client][0] = 12;
	}
	else if (classIndexPre[client] == ENGINEER)
	{
		if (score[client][ENGINEER] > CLASSUPGRADE4)
			defaultWeapon[client][0] = 8;
		else if (score[client][ENGINEER] > CLASSUPGRADE2)
			defaultWeapon[client][0] = 11;
		else
			defaultWeapon[client][0] = 10;
	}
	else if (classIndexPre[client] == SNIPER)
	{
		if (score[client][SNIPER] > CLASSUPGRADE4)
			defaultWeapon[client][0] = 4;
		else if (score[client][SNIPER] > CLASSUPGRADE3)
			defaultWeapon[client][0] = 5;
		else if (score[client][SNIPER] > CLASSUPGRADE2)
			defaultWeapon[client][0] = 9;
		else
			defaultWeapon[client][0] = 2;
	}
	else if (classIndexPre[client] == SUPPORT)
	{
		if (score[client][SUPPORT] > CLASSUPGRADE4)
			defaultWeapon[client][0] = 17;
		else if (score[client][SUPPORT] > CLASSUPGRADE2)
			defaultWeapon[client][0] = 16;
		else
			defaultWeapon[client][0] = 14;
	}
	
	//Pistols
	if (score[client][PISTOL] > PISTOLUPGRADE5)
		defaultWeapon[client][1] = 22;
	else if (score[client][PISTOL] > PISTOLUPGRADE4)
		defaultWeapon[client][1] = 21;
	else if (score[client][PISTOL] > PISTOLUPGRADE3)
		defaultWeapon[client][1] = 23;
	else if (score[client][PISTOL] > PISTOLUPGRADE2)
		defaultWeapon[client][1] = 20;
	else if (score[client][PISTOL] > PISTOLUPGRADE1)
		defaultWeapon[client][1] = 19;
	else
		defaultWeapon[client][1] = 18;
}

public SpawnPlayerOnSquadee(client, target)
{
	new Float:vec[3];
	
	if (IsPlayerAlive(target))
	{
		CS_RespawnPlayer(client);
		GetClientAbsOrigin(target, vec);
		TeleportEntity(client, vec, NULL_VECTOR, NULL_VECTOR);
	}
	else
	{
		PrintToChat(client, "[BF] Player is no longer alive. Please choose another.");
		Menu_SpawnOnSquad(client);
	}
}

public SpawnBaseLocation(client, location)
{
	new randNum;	
	
	CS_RespawnPlayer(client);
	
	if (location == -1)
	{
		new clientTeam = GetClientTeam(client);
		if (clientTeam == 2)
		{
			TeleportEntity(client, mecBase, NULL_VECTOR, NULL_VECTOR);
		}
		else if (clientTeam == 3)
		{
			TeleportEntity(client, usmcBase, NULL_VECTOR, NULL_VECTOR);
		}
		
		//Enable Protection on the Client
		new String:serverCmd[100];
		Format(serverCmd, sizeof(serverCmd), "sm_god #%d 1", GetClientUserId(client));
		ServerCommand(serverCmd);
		clientProtected[client] = 1;
		PrintToChat(client, "[BF] You have spawn protection.");
		
		CreateTimer(5.0, timer_PlayerProtect, client);
	}
	else if (location >= 0)
	{
		randNum = GetRandomInt(0, NumOfSpawns[location]);
		//Teleport player to a random spawn point
		TeleportEntity(client, flagPlayerSpawnVec[location][randNum], NULL_VECTOR, NULL_VECTOR);
	}
}

//Player Protection Expires
public Action:timer_PlayerProtect(Handle:timer, any:client)
{
				//Disable Protection on the Client
				clientProtected[client] = false;
				new String:serverCmd[100];
				Format(serverCmd, sizeof(serverCmd), "sm_god #%d 0", GetClientUserId(client));
				ServerCommand(serverCmd);
				PrintToChat(client, "[BF] You no longer have spawn protection.");
}

public CheckPrimaryWeaponAvailability(&Handle:menu, client)
{
	if (classIndex[client] == ASSAULT)
	{
		AddMenuItem(menu, "weapon_galil", "IDF Defender");
		if (score[client][ASSAULT] >= CLASSUPGRADE2)
			AddMenuItem(menu, "weapon_sg552", "SG 552 Rifle");
		if (score[client][ASSAULT] >= CLASSUPGRADE3)
			AddMenuItem(menu, "weapon_ak47", "AK-47 Rifle");
		if (score[client][ASSAULT] >= CLASSUPGRADE4)
			AddMenuItem(menu, "weapon_m4a1", "M4A1 Rifle");
	}
	else if (classIndex[client] == MEDIC)
	{
		AddMenuItem(menu, "weapon_mac10", "MAC 10 SMG");
		//Heal CLASSUPGRADE1
		if (score[client][MEDIC] >= CLASSUPGRADE2)
			AddMenuItem(menu, "weapon_tmp", "Schmidt Machine Pistol");
		//Revive CLASSUPGRADE3

		if (score[client][MEDIC] >= CLASSUPGRADE4)
			AddMenuItem(menu, "weapon_ump45", "UMP 45 SMG");
	}
	else if (classIndex[client] == ENGINEER)
	{
		AddMenuItem(menu, "weapon_m3", "M3 Shotgun");
		//CLASSUPGRADE1 - Build Props
		if (score[client][ENGINEER] >= CLASSUPGRADE2)
			AddMenuItem(menu, "weapon_xm1014", "XM1014 Shotgun");
		if (score[client][ENGINEER] >= CLASSUPGRADE3)
			AddMenuItem(menu, "weapon_aug", "Bullpup Rifle");
		if (score[client][ENGINEER] >= CLASSUPGRADE4)
			AddMenuItem(menu, "weapon_famas", "Clarion 5.56");
	}
	else if (classIndex[client] == SNIPER)
	{
		AddMenuItem(menu, "weapon_scout", "Schmidt Scout");
		//CLASSUPGRADE1 - Tripmines
		if (score[client][SNIPER] >= CLASSUPGRADE2)
			AddMenuItem(menu, "weapon_sg550", "SG 550 Rifle");
		if (score[client][SNIPER] >= CLASSUPGRADE3)
			AddMenuItem(menu, "weapon_g3sg1", "G3SG1 Rifle");
		if (score[client][SNIPER] >= CLASSUPGRADE4)
			AddMenuItem(menu, "weapon_awp", "Magnum Sniper Rifle");
	}
	
	else if (classIndex[client] == SUPPORT)
	{
		AddMenuItem(menu, "weapon_mp5navy", "MP5 Navy SMG");
		//CLASSUPGRADE1 - Give Ammo
		if (score[client][SUPPORT] >= CLASSUPGRADE2)
			AddMenuItem(menu, "weapon_p90", "FN P90 SMG");
		//CLASSUPGRADE3 - 3 HeGrenades
		if (score[client][SUPPORT] >= CLASSUPGRADE4)
			AddMenuItem(menu, "weapon_m249", "M249 LMG");
	}

}

public CheckSecondWeaponAvailability(&Handle:menu, client)
{	
	AddMenuItem(menu, "weapon_glock", "Glock");
	if (score[client][PISTOL] >= PISTOLUPGRADE1)
		AddMenuItem(menu, "weapon_usp", "USP");
	if (score[client][PISTOL] >= PISTOLUPGRADE2)
		AddMenuItem(menu, "weapon_p228", "P228");
	if (score[client][PISTOL] >= PISTOLUPGRADE3)
		AddMenuItem(menu, "weapon_fiveseven", "Five-Seven");
	if (score[client][PISTOL] >= PISTOLUPGRADE4)
		AddMenuItem(menu, "weapon_deagle", "Desert Eagle");
	if (score[client][PISTOL] >= PISTOLUPGRADE5)
		AddMenuItem(menu, "weapon_elite", "Dualies");
}

UpdateRespawn()
{
	//Added in a quick timeleft loop for players, so they cant get spawn menu unless spawnable.
	for (new index = 1; index < maxPlayers + 1; index++)
	{
		if (!IsClientConnected(index))
			continue;
		if (!IsClientInGame(index))
			continue;
		if (!IsValidEdict(index))
			continue;
		if (IsPlayerAlive(index))
			continue;
		
		new clientTeam = GetClientTeam(index);
		
		if (clientTeam == TEAM_CT || clientTeam == TEAM_T)
		{
		
			if (timeLeft[index] > 0)
			{
				PrintCenterText(index, "You will respawn in %d.", timeLeft[index]);
				timeLeft[index]--;
			}
			else
			{
				if (spawnMenuOpen[index] == false)
				{
					CancelClientMenu(index);
					Menu_Spawn(index);
					spawnMenuOpen[index] = true;
				}
			}
		}
	}
}

TerminateRound(winningTeam)
{
	ServerCommand("mp_ignore_round_win_conditions 0");
	
	if (winningTeam == TEAM_T)
	{
		ServerCommand("sm_slay @ct");
	}
	else if (winningTeam == TEAM_CT)
	{
		ServerCommand("sm_slay @t");
	}
}

LoadMapValues()
{
	new String:mapName[64], String:flagIndex[32];

	GetCurrentMap(mapName, sizeof(mapName));

	new Handle:kv = CreateKeyValues(mapName);
	Format(mapName, sizeof(mapName), "addons/sourcemod/data/bf/maps/%s.txt", mapName);
	FileToKeyValues(kv, mapName);	
	
	//Loading map data

	if (KvJumpToKey(kv, "usmcbase"))
	{
		usmcBase[0] = KvGetFloat(kv, "x");
		usmcBase[1] = KvGetFloat(kv, "y");
		usmcBase[2] = KvGetFloat(kv, "z");
	}
	else
		SetFailState("No USMC Base");
		
	KvRewind(kv);
	
	if (KvJumpToKey(kv, "mecbase"))
	{
		mecBase[0] = KvGetFloat(kv, "x");
		mecBase[1] = KvGetFloat(kv, "y");
		mecBase[2] = KvGetFloat(kv, "z");
	}
	else
		SetFailState("No MEC Base");
	
	KvRewind(kv);
	
	//Grab base flags
	for (new index = 0; index < MAXFLAGS; index++)
	{
		Format(flagIndex, sizeof(flagIndex), "flag%d", index);
		
		if (KvJumpToKey(kv, flagIndex))
		{
			LogMessage(flagIndex);
			KvGetString(kv, "name", flagName[index], 32);
			flagVec[index][0] = KvGetFloat(kv, "x");
			flagVec[index][1] = KvGetFloat(kv, "y");
			flagVec[index][2] = KvGetFloat(kv, "z");
			NumOfFlags++;
			KvRewind(kv);
		}
	}
	LogMessage("The number of flags for this level: %d", NumOfFlags);

	//Grab base spawns
	for (new index = 0; index < NumOfFlags; index++)
	{
		Format(flagIndex, sizeof(flagIndex), "flag%d", index);

		for (new subIndex = 0; subIndex < MAXSPAWNS; subIndex++)
		{
			Format(flagIndex, sizeof(flagIndex), "flag%d_%d", index, subIndex);
			PrintToServer(flagIndex);
			if (KvJumpToKey(kv, flagIndex))
			{
				flagPlayerSpawnVec[index][subIndex][0] = KvGetFloat(kv, "x");
				flagPlayerSpawnVec[index][subIndex][1] = KvGetFloat(kv, "y");
				flagPlayerSpawnVec[index][subIndex][2] = KvGetFloat(kv, "z");
				NumOfSpawns[index]++;
				KvRewind(kv);
			}
			else 
			{
				//No more spawns for that flag.
				continue;
			}
		}
		LogMessage("The number of spawns for flag %d is %d", index, NumOfSpawns[index]);
	}
	
	CloseHandle(kv);
}

public Action:Command_ChooseSpecial(client, args)
{
	if (GetClientTeam(client) != 1 && IsPlayerAlive(client))
	{
		if (classIndex[client] == ASSAULT && score[client][ASSAULT] > CLASSUPGRADE1)
		{
			if (grenadeAmount[client] > 0 && canShootGrenade[client])
			{
				CreateGrenadeClient(client);
				grenadeAmount[client]--;
				canShootGrenade[client] = false;
				CreateTimer(1.0, resetGrenade, client);
				PrintToChat(client, "[SM] Grenades left: %i", grenadeAmount[client]);
			}
		}
		else if (classIndex[client] == SNIPER && score[client][SNIPER] > CLASSUPGRADE1)
			tnt(client);
		else if (classIndex[client] == MEDIC && score[client][MEDIC] > CLASSUPGRADE1)
		{
			if (canDropKit[client])
			{
				CreateKit(client);
				canDropKit[client] = false;
				CreateTimer(5.0, resetKit, client);
			}
			else
				PrintToChat(client, "[BF] You cannot drop a kit at the moment.");
			
			if (classIndex[client] == MEDIC && score[client][MEDIC] > CLASSUPGRADE3)
				CommandRevive(client);
		}
		else if (classIndex[client] == SUPPORT && score[client][SUPPORT] > CLASSUPGRADE1)
		{
			if (canDropKit[client])
			{
				CreateKit(client);
				canDropKit[client] = false;
				CreateTimer(5.0, resetKit, client);
			}
			else
				PrintToChat(client, "[BF] You cannot drop a kit at the moment.");
		}
		else if (classIndex[client] == ENGINEER && score[client][ENGINEER] > CLASSUPGRADE1)
		{
			if (rocketAmount[client] > 0 && canShootRocket[client] && tntPlanted[client] < 3)
			{
				CreateGrenadeClient(client);
				rocketAmount[client]--;
				canShootRocket[client] = false;
				CreateTimer(1.0, resetRocket, client);
				PrintToChat(client, "[SM] Rockets left: %i", rocketAmount[client]);
			}
		}
	}
	return Plugin_Handled;
}