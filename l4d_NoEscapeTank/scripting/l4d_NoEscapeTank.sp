#include <sourcemod>
#include <sdktools>
#include <left4downtown>

#define		NET_TAG					"[NoEscTank]"

static 		Handle:g_hEnableNoEscTank, bool:g_bEnableNoEscTank;

new			bool:g_bVehicleIncoming;

public Plugin:myinfo = 
{
	name = "L4D Score/Team Manager",
	author = "Harry Potter",
	description = "No Tank Spawn as the rescue vehicle is coming",
	version = "1.0",
	url = "http://forums.alliedmods.net/showthread.php?t=87759"
}

public OnPluginStart()
{
	g_hEnableNoEscTank	= CreateConVar("no_escape_tank", "1", "Removes tanks which spawn as the rescue vehicle arrives on finales.", _, true, 0.0, true, 1.0);
	HookEvent("finale_escape_start", NET_ev_FinaleEscStart, EventHookMode_PostNoCopy);
	HookEvent("round_start", 	NET_ev_RoundStart, EventHookMode_PostNoCopy);
	
	HookConVarChange(g_hEnableNoEscTank, _NET_Enable_CvarChange);
	Update_NET_EnableConVar();
}

public NET_ev_FinaleEscStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	//if(IsTankProhibit()) return;
	if (!g_bEnableNoEscTank) return;

	g_bVehicleIncoming = true;
}

public NET_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bVehicleIncoming = false;
}

// left4downtown
public Action:L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3])
{
	if(g_bEnableNoEscTank && g_bVehicleIncoming)
	{
		//PrintToChatAll("Blocking tank spawn...");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public _NET_Enable_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_NET_EnableConVar();
}

static Update_NET_EnableConVar()
{
	g_bEnableNoEscTank = GetConVarBool(g_hEnableNoEscTank);
}
/*
static bool:IsTankProhibit()//犧牲最後一關
{
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);
	return StrEqual(sMap, "l4d_river03_port");
}*/
