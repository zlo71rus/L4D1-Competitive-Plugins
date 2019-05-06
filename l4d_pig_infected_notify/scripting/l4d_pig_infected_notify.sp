#include <sourcemod>
#include <sdktools>
#include <colors>
#include include/sdkhooks.inc
#undef REQUIRE_PLUGIN
#include <l4d_lib>

#pragma semicolon 1
#define PLUGIN_VERSION "2.3"
#define MAXENTITIES 2048
#define GAMEDATA_FILE "staggersolver"
new Handle:g_hGameConf;
new Handle:g_hIsStaggering;
static bool:surkillboomerboomtank,tankstumblebydoor,tankkillboomerboomhimself,boomerboomtank;
new surclient;
new Tankclient;
#define IsWitch(%0) (g_bIsWitch[%0])
new		bool:	g_bIsWitch[MAXENTITIES];							// Membership testing for fast witch checking

public Plugin:myinfo = 
{
	name = "l4d 豬隊友sm",
	author = "Harry Potter",
	description = "Show who the god teammate boom the Tank, Tank use which weapon(car,pounch,rock) to kill teammates S.I. and Witch , player open door to stun tank",
	version = PLUGIN_VERSION,
	url = "myself"
}

public OnPluginStart()
{
	g_hGameConf = LoadGameConfigFile(GAMEDATA_FILE);
	if (g_hGameConf == INVALID_HANDLE)
		SetFailState("[Stagger Solver] Could not load game config file.");

	StartPrepSDKCall(SDKCall_Player);

	if (!PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "IsStaggering"))
		SetFailState("[Stagger Solver] Could not find signature IsStaggering.");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hIsStaggering = EndPrepSDKCall();
	if (g_hIsStaggering == INVALID_HANDLE)
		SetFailState("[Stagger Solver] Failed to load signature IsStaggering");

	CloseHandle(g_hGameConf);
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("door_open", Event_DoorOpen);
	HookEvent("door_close", Event_DoorClose);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("witch_killed", Event_WitchKilled);
	HookEvent("witch_spawn", Event_WitchSpawn);
}
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{	
	surkillboomerboomtank = false;
	tankstumblebydoor = false;
	tankkillboomerboomhimself = false;
	boomerboomtank = false;
}

public Event_DoorOpen(Handle:event, const String:name[], bool:dontBroadcast)
{
	Tankclient = GetTankClient();
	if(Tankclient == -1)	return;
	
	new Surplayer = GetClientOfUserId(GetEventInt(event, "userid"));
	if(Surplayer<=0||!IsClientConnected(Surplayer) || !IsClientInGame(Surplayer)) return;
	//PrintToChatAll("%N open door",Surplayer);
	CreateTimer(0.75, Timer_TankStumbleByDoorCheck, Surplayer);//tank stumble check
}

public Event_DoorClose(Handle:event, const String:name[], bool:dontBroadcast)
{
	Tankclient = GetTankClient();
	if(Tankclient == -1)	return;
	
	new Surplayer = GetClientOfUserId(GetEventInt(event, "userid"));
	if(Surplayer<=0||!IsClientConnected(Surplayer) || !IsClientInGame(Surplayer)) return;
	//PrintToChatAll("%N close door",Surplayer);
	CreateTimer(0.75, Timer_TankStumbleByDoorCheck, Surplayer);//tank stumble check
}

public Action:Timer_TankStumbleByDoorCheck(Handle:timer, any:client)
{
	if(Tankclient<0 || !IsClientConnected(Tankclient) ||!IsClientInGame(Tankclient)) return;
	//PrintToChatAll("判定");
	if (SDKCall(g_hIsStaggering, Tankclient) && !surkillboomerboomtank && !tankstumblebydoor && !tankkillboomerboomhimself && !boomerboomtank)//tank在暈眩 by door
	{
		CPrintToChatAll("{green}[TS] {olive}%N {default}used door to stumble {green}Tank{default}.",client);
		tankstumblebydoor = true;
		CreateTimer(3.0,COLD_DOWN,_);
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsWitch(GetEventInt(event, "attackerentid")) && victim != 0 && IsClientConnected(victim) && IsClientInGame(victim) && GetClientTeam(victim) == 3 )
	{
		if(!IsFakeClient(victim))//真人特感 player
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS]{default} {red}Witch {default}killed teammate.");
		}
		else
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS]{default} {red}Witch {default}killed AI teammate.");
		}
		return;
	}
	
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	decl String:weapon[20];
	GetEventString(event, "weapon", weapon, sizeof(weapon));//殺死人的武器名稱
	decl String:victimname[8];
	GetEventString(event, "victimname", victimname, sizeof(victimname));
	//PrintToChatAll("attacker: %d - victim: %d - weapon:%s - victimname:%s",attacker,victim,weapon,victimname);
	if((attacker == 0 || attacker == victim)
	&& victim != 0 && IsClientConnected(victim) && IsClientInGame(victim) && GetClientTeam(victim) == 3)//特感自殺
	{
		decl String:kill_weapon[20];

		if(StrEqual(weapon,"entityflame")||StrEqual(weapon,"env_fire"))//地圖的自然火
			kill_weapon = "killed by fire";
		else if(StrEqual(weapon,"trigger_hurt"))//跳樓 跳海 地圖火 都有可能
			kill_weapon = "killed by map";
		else if(StrEqual(weapon,"inferno"))//玩家丟的火
			return;
		else if(StrEqual(weapon,"trigger_hurt_g"))//跳樓 跳海 地圖火 都有可能
			kill_weapon = "killed himself";
		else if(StrEqual(weapon,"prop_physics")||StrEqual(weapon, "prop_car_alarm"))//玩車殺死自己
			kill_weapon = "killed by toy";
		else if(StrEqual(weapon,"pipe_bomb")||StrEqual(weapon,"prop_fuel_barr"))//自然的爆炸(土製炸彈 砲彈 瓦斯罐)
			kill_weapon = "killed by boom";
		else if(StrEqual(weapon,"world"))//玩家使用指令kill 殺死特感
			return;
		else kill_weapon = "killed by server";	//卡住了 由伺服器自動處死特感
			
		if(GetEntProp(victim, Prop_Send, "m_zombieClass") == 5)//Tank suicide
		{
			if(!IsFakeClient(victim))//真人SI player
			{
				for (new i = 1; i < MaxClients; i++)
					if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
						CPrintToChat(i,"{green}[TS] {green}Tank is {olive}%s{default}.",kill_weapon);
			}
			else
			{
				for (new i = 1; i < MaxClients; i++)
					if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
						CPrintToChat(i,"{green}[TS] {green}Tank is {olive}%s{default}.",kill_weapon);
			}
		}
		else if(GetEntProp(victim, Prop_Send, "m_zombieClass") == 2)
			CreateTimer(0.2, Timer_BoomerSuicideCheck, victim);//boomer suicide check	
		else
			if(!IsFakeClient(victim))//真人SI player
			{
				for (new i = 1; i < MaxClients; i++)
					if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
						CPrintToChat(i,"{green}[TS] {red}%N{default} is {olive}%s{default}.",victim,kill_weapon);
			}
			else
			{
				for (new i = 1; i < MaxClients; i++)
					if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
						CPrintToChat(i,"{green}[TS] {red}AI{default} is {olive}%s{default}.",kill_weapon);
			}
	
		return;
	}
	else if (attacker==0 && victim == 0 && StrEqual(victimname,"Witch"))//Witch自己不知怎的自殺了
	{
		for (new i = 1; i < MaxClients; i++)
			if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
				CPrintToChat(i,"{green}[TS] {red}Witch{default} {olive}gone{default}.");
	}
	
	Tankclient = GetTankClient();
	if(Tankclient == -1)	return;
	
	if( StrEqual(victimname,"Witch") && PlayerIsTank(attacker) )
	{
		decl String:Tank_weapon[20];
		if(StrEqual(weapon,"tank_claw"))
			Tank_weapon = "One-Punch";
		else if(StrEqual(weapon,"tank_rock"))
			Tank_weapon = "Rock-Stone";
		else if(StrEqual(weapon,"prop_physics"))
			Tank_weapon = "Toy";
		
		if(!IsFakeClient(attacker))//真人Tank player
		{	for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] Tank {default}uses {olive}%s {default}to terminate {red}Witch{default}.",Tank_weapon);
		}
		else
		{	for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] Tank {default}uses {olive}%s {default}to terminate {red}Witch{default}.",Tank_weapon);
		}
		return;
	}
	
	if ( victim == 0 || !IsClientConnected(victim)||!IsClientInGame(victim)) return;
	new victimteam = GetClientTeam(victim);
	new victimzombieclass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		
	if (victimteam == 3)//infected dead
	{	
		if(attacker != 0 && IsClientConnected(attacker) && IsClientInGame(attacker))//someone kill infected
		{
			new attackerteam = GetClientTeam(attacker);
			if(attackerteam == 2 && victimzombieclass == 2)//sur kill Boomer
			{
				surclient = attacker;
				CreateTimer(0.2, Timer_SurKillBoomerCheck, victim);//sur kill Boomer check	
			}
			else if (PlayerIsTank(attacker))//Tank kill infected
			{
				decl String:Tank_weapon[25];
				//Tank weapon
				if(StrEqual(weapon,"tank_claw"))
					Tank_weapon = "punches";
				else if(StrEqual(weapon,"tank_rock"))
					Tank_weapon = "smashes";
				else if(StrEqual(weapon,"prop_physics"))
					Tank_weapon = "plays toy to kill";
				else if(StrEqual(weapon, "prop_car_alarm"))
					Tank_weapon = "plays alarm car to kill";
					
				//Tank kill boomer
				if(victimzombieclass == 2)
				{
					new Handle:h_Pack;
					CreateDataTimer(0.2,Timer_TankKillBoomerCheck,h_Pack);//tank kill Boomer check
					WritePackCell(h_Pack, victim);
					WritePackString(h_Pack, Tank_weapon);
				}
				else if(victimzombieclass == 1||victimzombieclass == 3)//Tank kill teammates S.I. (Hunter,Smoker)	
				{
					if(!IsFakeClient(victim))//真人SI player
					{	for (new i = 1; i < MaxClients; i++)
							if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
								CPrintToChat(i,"{green}[TS] {green}Tank {olive}%s {default}teammate.",Tank_weapon);
					}
					else
					{
						for (new i = 1; i < MaxClients; i++)
							if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
								CPrintToChat(i,"{green}[TS] {green}Tank {olive}%s {default}AI teammate.",Tank_weapon);
					}
				}
			}
		}
	}
}
public Action:Timer_SurKillBoomerCheck(Handle:timer, any:client)
{
	if(Tankclient<0 || !IsClientConnected(Tankclient) ||!IsClientInGame(Tankclient)) return;
	if(client<0 || !IsClientConnected(client) ||!IsClientInGame(client)) return;
	
	if(SDKCall(g_hIsStaggering, Tankclient) && !surkillboomerboomtank && !tankstumblebydoor && !tankkillboomerboomhimself && !boomerboomtank)//tank在暈眩
	{
		if(!IsFakeClient(client))//真人boomer player
			CPrintToChatAll("{green}[TS] {olive}%N {default}kills {red}%N{default}'s Boomer to stumble {green}Tank{default}.",surclient, client);
		else
			CPrintToChatAll("{green}[TS] {olive}%N {default}kills {red}AI {default}Boomer to stumble {green}Tank{default}.",surclient);
		surkillboomerboomtank=true;
		CreateTimer(3.0,COLD_DOWN,_);
	}
}

public Action:Timer_TankKillBoomerCheck(Handle:timer, Handle:h_Pack)
{
	if(Tankclient<0 || !IsClientConnected(Tankclient) ||!IsClientInGame(Tankclient)) return;
	
	decl String:Tank_weapon[128];
	new client;
	
	ResetPack(h_Pack);
	client = ReadPackCell(h_Pack);
	ReadPackString(h_Pack, Tank_weapon, sizeof(Tank_weapon));
	
	if(client<0 || !IsClientConnected(client) ||!IsClientInGame(client)) return;
	
	if(SDKCall(g_hIsStaggering, Tankclient) && !surkillboomerboomtank && !tankstumblebydoor && !tankkillboomerboomhimself && !boomerboomtank)//tank在暈眩
	{
		if(!IsFakeClient(client))//真人SI player
		{	for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] {green}Tank {olive}%s {red}%N{default}'s Boomer to stumble {default}himself.",Tank_weapon,client);
		}
		else	
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] {green}Tank {olive}%s {red}AI {default}Boomer to stumble {default}himself.",Tank_weapon);
		}
		tankkillboomerboomhimself = true;
		CreateTimer(3.0,COLD_DOWN,_);
	}
	else
	{
		if(!IsFakeClient(client))//真人SI player
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] {green}Tank {olive}%s {default}Boomer.",Tank_weapon);
		}
		else
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] {green}Tank {olive}%s {default}AI Boomer.",Tank_weapon);
		}
	}
}


public Action:Timer_BoomerSuicideCheck(Handle:timer, any:client)
{	
	if(client<0 || !IsClientConnected(client) ||!IsClientInGame(client)) return;
	
	Tankclient = GetTankClient();
	if(Tankclient<0 || !IsClientConnected(Tankclient) ||!IsClientInGame(Tankclient))
	{
		if(!IsFakeClient(client))//真人boomer player
		{	for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] {red}%N{default}'s Boomer exploded.",client);
		}
		else
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] {red}AI {default}Boomer exploded.");
		}
		return;
	}
	
	if (SDKCall(g_hIsStaggering, Tankclient) && !surkillboomerboomtank && !tankstumblebydoor && !tankkillboomerboomhimself && !boomerboomtank)//tank在暈眩
	{
		if(!IsFakeClient(client))//真人boomer player
		{	for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] {default}Player {red}%N{default}'s Boomer stumbles {green}Tank{default}.",client);
		}
		else
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] {default}{red}AI {default}Boomer stumbles {green}Tank{default}.");
		}
		boomerboomtank = true;
		CreateTimer(3.0,COLD_DOWN,_);
	}
	else
	{
		if(!IsFakeClient(client))//真人boomer player
		{	for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] {red}%N{default}'s Boomer exploded.",client);
		}
		else
		{
			for (new i = 1; i < MaxClients; i++)
				if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] {red}AI {default}Boomer exploded.");
		}
	}
}

static GetTankClient()
{
	for (new client = 1; client <= MaxClients; client++)
		if(	PlayerIsTank(client) )//Tank player
			return  client;
	return -1;
}

stock bool:PlayerIsTank(client)
{
	if(client != 0 && IsClientConnected(client) && IsClientInGame(client) && IsInfectedAlive(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 5) 
		return true;
	return false;
}

public Action:COLD_DOWN(Handle:timer,any:client)
{
	surkillboomerboomtank = false;
	tankstumblebydoor = false;
	tankkillboomerboomhimself = false;
	boomerboomtank = false;
}

public Event_WitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bIsWitch[GetEventInt(event, "witchid")] = false;
	
}
public Event_WitchSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bIsWitch[GetEventInt(event, "witchid")] = true;
}
public OnMapStart()
{
	for (new i = MaxClients + 1; i < MAXENTITIES; i++) g_bIsWitch[i] = false;
}