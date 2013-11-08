//Author: [NotD] l0calh0st aka Mathew Baltes
//Website: www.notdelite.com

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define MAXFLAGS 5
#define MAXSPAWNS 15

//Variables
new Float:usmcBase[3];
new Float:mecBase[3];
new String:flagName[MAXFLAGS][32];
new Float:flagVec[MAXFLAGS][3];
new Float:flagPlayerSpawnVec[MAXFLAGS][MAXSPAWNS][3];
new NumOfFlags;
new NumOfSpawns[MAXFLAGS];

public OnPluginStart()
{
	RegAdminCmd("bf_add", Command_Add, ADMFLAG_RCON, "Uses the Add System.");
}

public OnMapStart()
{
	NumOfFlags = 0;
}

public Action:Command_Add(client, args)
{	
	new String:arg[3][32];

	if (args < 1)
	{
		PrintToConsole(client, "[BF] Map Data Adder");
		PrintToConsole(client, "--------------------------");
		PrintToConsole(client, "# Commands #");
		PrintToConsole(client, "- bf_add usmcbase 'Adds USMC Base ~ Main Spawn Point'");	
		PrintToConsole(client, "- bf_add mecbase  'Adds MEC Base ~ Main Spawn Point'");
		PrintToConsole(client, "- bf_add flag #name'Adds a flag and the name of the flag'");
		PrintToConsole(client, "- bf_add spawn #flag number 'Adds a player spawn to flag index.'");
		PrintToConsole(client, "- bf_add save 'Saves all of the changes made.");
		
		return Plugin_Handled;
	}
	else if (args < 2)
	{	
		GetCmdArg(1, arg[0], 32);
		
		if (StrEqual(arg[0], "usmcbase"))
		{
			GetClientAbsOrigin(client, usmcBase);
		}
		else if (StrEqual(arg[0], "mecbase"))
		{
			GetClientAbsOrigin(client, mecBase);
		}
		else if (StrEqual(arg[0], "save"))
		{
			SaveFile();	
		}		
		else
		{
			PrintToConsole(client, "[BF] Invalid choice. Type bf_add for a list of commands.");
			return Plugin_Handled;
		}
	}
	else if (args < 3)
	{	
		GetCmdArg(1, arg[0], 32);
		GetCmdArg(2, arg[1], 32);
		
		if (StrEqual(arg[0], "spawn"))
		{
			new flagNum;
			flagNum = StringToInt(arg[1]);
			GetClientAbsOrigin(client, flagPlayerSpawnVec[flagNum][NumOfSpawns[flagNum]]);
			NumOfSpawns[flagNum]++;
		}
		else if (StrEqual(arg[0], "flag"))
		{
			strcopy(flagName[NumOfFlags], 32, arg[1]);
			GetClientAbsOrigin(client, flagVec[NumOfFlags]);
			NumOfFlags++;
		}
		else
		{
			PrintToConsole(client, "[BF] Invalid choice. Type bf_add for a list of commands.");
			return Plugin_Handled;
		}

		return Plugin_Handled;
	}
 
	return Plugin_Handled;
}

public SaveFile()
{
	new String:buffer[64];
	GetCurrentMap(buffer, sizeof(buffer));
	
	new String:path[255];
	Format(path, sizeof(path), "addons/sourcemod/data/bf/maps/%s.txt", buffer);
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

	//USMC Base
	WriteFileLine(file, "\"usmcbase\"");
	WriteFileLine(file, "{");
	WriteFileLine(file, "\"x\" \"%f\"", usmcBase[0]);
	WriteFileLine(file, "\"y\" \"%f\"", usmcBase[1]);
	WriteFileLine(file, "\"z\" \"%f\"", usmcBase[2]);
	WriteFileLine(file, "}");

	//MEC Base
	WriteFileLine(file, "\"mecbase\"");
	WriteFileLine(file, "{");
	WriteFileLine(file, "\"x\" \"%f\"", mecBase[0]);
	WriteFileLine(file, "\"y\" \"%f\"", mecBase[1]);
	WriteFileLine(file, "\"z\" \"%f\"", mecBase[2]);
	WriteFileLine(file, "}");
	
	for (new index = 0; index < NumOfFlags; index++)
	{
		Format(buffer, sizeof(buffer), "\"flag%d\"", index);
		WriteFileLine(file, buffer);
		WriteFileLine(file, "{");
		WriteFileLine(file, "\"name\" \"%s\"", flagName[index]);
		WriteFileLine(file, "\"x\" \"%f\"", flagVec[index][0]);
		WriteFileLine(file, "\"y\" \"%f\"", flagVec[index][1]);
		WriteFileLine(file, "\"z\" \"%f\"", flagVec[index][2]);
		WriteFileLine(file, "}");

		for (new subIndex = 0; subIndex < NumOfSpawns[index]; subIndex++)
		{
			Format(buffer, sizeof(buffer), "\"flag%d_%d\"", index, subIndex);
			WriteFileLine(file, buffer);
			WriteFileLine(file, "{");
			WriteFileLine(file, "\"x\" \"%f\"", flagPlayerSpawnVec[index][subIndex][0]);
			WriteFileLine(file, "\"y\" \"%f\"", flagPlayerSpawnVec[index][subIndex][1]);
			WriteFileLine(file, "\"z\" \"%f\"", flagPlayerSpawnVec[index][subIndex][2]);
			WriteFileLine(file, "}");
		}
	}
	
	WriteFileLine(file, "}");	
	CloseHandle(file);	

	return;
}
