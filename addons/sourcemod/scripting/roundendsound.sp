/***************************************************************************************

							C O M P I L E  -  O P T I O N S

***************************************************************************************/
#pragma semicolon 1
#pragma newdecls required

/***************************************************************************************

										I N C L U D E S

***************************************************************************************/
#include <sourcemod>
#include <smlib>
#include <cstrike>
#include <multicolors>
#include <clientprefs>

#define MAXMUSIC 32

KeyValues g_KV;
int iLastMusic;
int iMaxMusic;

enum struct Cookie_Forward {
	Handle resenabled;
	Handle resvolume;
}	
Cookie_Forward cookie;

enum struct Music_Volume {
	char sName[64];
	char sPath[128];
	bool bIsValid;
}
Music_Volume music[MAXMUSIC + 1];

EngineVersion eGame;

/***************************************************************************************

							P L U G I N  -  I N F O

***************************************************************************************/
public Plugin myinfo = 
{
	name = "Round-End-Sound",
	author = "MbK",
	description = "Manage sound at end of the round",
	version = "1.0",
	url = "https://github.com/Mbk10201"
};

/***************************************************************************************

									H O O K

***************************************************************************************/

public void OnPluginStart()
{
	eGame = GetEngineVersion();
	
	LoadTranslations("roundendsound.phrases.txt");
	
	/*				COMMANDS			*/
	RegConsoleCmd("sm_res", Command_Res, "Round end sound");
	RegConsoleCmd("sm_roundend", Command_Res, "Round end sound");
	
	/*				HOOK				*/
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
	
	/*----------------------------------Cookies-------------------------------*/
	cookie.resenabled = RegClientCookie("res_enabled", "Enable Round End Sound [ON / OFF]", CookieAccess_Public);
	cookie.resvolume = RegClientCookie("res_volume", "Enable Round End Sound [ON / OFF]", CookieAccess_Public);
	/*------------------------------------------------------------------------*/	
	
	AutoExecConfig(true, "roundendsound");
	
	/*----------------------------------KeyValue------------------------------*/
	g_KV = new KeyValues("RoundEndSound");
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/roundendsound.cfg");	
	if(!g_KV.ImportFromFile(sPath))
		SetFailState("Cant find: %s", sPath);
		
	// Jump into the first subsection
	if (!g_KV.GotoFirstSubKey())
	{
		PrintToServer("ERROR FIRST KEY");
		delete g_KV;
		return;
	}
	
	char sTmp[8];
	do
	{
		if(g_KV.GetSectionName(sTmp, sizeof(sTmp)))
		{
			iMaxMusic++;
			int id = StringToInt(sTmp);
			g_KV.GetString("name", music[id].sName, sizeof(music[].sName));
			g_KV.GetString("path", music[id].sPath, sizeof(music[].sPath));
			music[id].bIsValid = true;
			
			char dl[128];
			Format(dl, sizeof(dl), "sound%s", music[id].sPath);
			AddFileToDownloadsTable(dl);
			
			PrecacheSound(music[id].sPath, true);
		}
	}
	while (g_KV.GotoNextKey());	
	/*-------------------------------------------------------------------------------*/	
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	PlaySound();
	
	return Plugin_Continue;
}

/***************************************************************************************

									C L I E N T

***************************************************************************************/

public void OnClientPutInServer(int client)
{
	char buffer[64];
	GetClientCookie(client, cookie.resvolume, buffer, sizeof(buffer));
	if(strlen(buffer) == 0)
		SetClientCookie(client, cookie.resvolume, "0.5");
		
	GetClientCookie(client, cookie.resenabled, buffer, sizeof(buffer));
	if(StrEqual(buffer, ""))
		SetClientCookie(client, cookie.resenabled, "1");
}

/***************************************************************************************

									C A L L B A C K

***************************************************************************************/

public Action Command_Res(int client, int args)
{
	if(!IsClientValid(client))
		return Plugin_Handled;
		
	MenuRes(client);
		
	return Plugin_Handled;	
}

void MenuRes(int client)
{
	Menu menu = new Menu(Handle_MenuRes);
	menu.SetTitle("Round End Sound");
	
	char sTmp[64];
	GetClientCookie(client, cookie.resenabled, sTmp, sizeof(sTmp));
	if(view_as<bool>(StringToInt(sTmp)))
	{
		Format(sTmp, sizeof(sTmp), "%T", "MenuRes_Disable", client);
		menu.AddItem("disable", sTmp);
	}	
	else
	{
		Format(sTmp, sizeof(sTmp), "%T", "MenuRes_Enable", client);
		menu.AddItem("enable", sTmp);
	}	
	
	Format(sTmp, sizeof(sTmp), "%T", "MenuRes_List", client);
	menu.AddItem("list", sTmp);
	
	GetClientCookie(client, cookie.resvolume, sTmp, sizeof(sTmp));
	Format(sTmp, sizeof(sTmp), "%T", "MenuRes_Volume", client, sTmp);
	menu.AddItem("volume", sTmp);
	
	menu.ExitButton = true;
	menu.Display(client, 10);
}

public int Handle_MenuRes(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param, info, sizeof(info));
		
		if(StrEqual(info, "disable"))
		{
			SetClientCookie(client, cookie.resenabled, "0");
			MenuRes(client);
		}	
		else if(StrEqual(info, "enable"))
		{
			SetClientCookie(client, cookie.resenabled, "1");
			MenuRes(client);
		}	
		else if(StrEqual(info, "list"))
		{
			Menu menu1 = new Menu(Handle_MenuRes);
			menu1.SetTitle("Round End Sound - List");
			
			for(int i = 1; i <= iMaxMusic; i++)
			{
				menu1.AddItem("", music[i].sName, ITEMDRAW_DISABLED);
			}	
			
			menu1.ExitButton = true;
			menu1.ExitBackButton = true;
			menu1.Display(client, 10);
		}
		else if(StrEqual(info, "volume"))
		{
			char sTmp[64];
			GetClientCookie(client, cookie.resvolume, sTmp, sizeof(sTmp));
			
			float value = StringToFloat(sTmp);
			if(value == 1.0)
				SetClientCookie(client, cookie.resvolume, "0.1");
			else
			{
				value += 0.1;
				Format(sTmp, sizeof(sTmp), "%0.1f", value);
				SetClientCookie(client, cookie.resvolume, sTmp);
			}	
			
			MenuRes(client);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if(param == MenuCancel_ExitBack)
			MenuRes(client);
	}		
	else if (action == MenuAction_End)
		delete menu;
		
	return 0;
}

/***************************************************************************************

									F U N C T I O N S

***************************************************************************************/

void PlaySound()
{
	int random = GetRandomInt(1, iMaxMusic);
	while(iLastMusic == random)
		random = GetRandomInt(1, iMaxMusic);
	
	iLastMusic = random;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientValid(i))
			continue;
		char sTmp[128];
		GetClientCookie(i, cookie.resenabled, sTmp, sizeof(sTmp));
		
		if(view_as<bool>(StringToInt(sTmp)))
		{
			Format(sTmp, sizeof(sTmp), "%T", "RoundEndSound_Tchat", i, music[random].sName);
			CPrintToChat(i, sTmp);
			Format(sTmp, sizeof(sTmp), "%T", "RoundEndSound_Hud", i, music[random].sName);
			
			if(eGame == Engine_CSGO)
				ShowSurvivalHUD(i, 10, sTmp, sizeof(sTmp));
			else
				ShowSimpleHud(i, 10, sTmp, sizeof(sTmp));
			
			GetClientCookie(i, cookie.resvolume, sTmp, sizeof(sTmp));
			
			ClientCommand(i, "playgamesound Music.StopAllMusic");
			PrecacheSound(music[random].sPath);
			EmitSoundToClient(i, music[random].sPath, -2, 0, 0, 0, StringToFloat(sTmp));
		}	
	}	
}

stock void ShowSimpleHud(int client, int duration, const char[] format, any...)
{
    static char formatted_message[1024];
    VFormat(formatted_message, sizeof(formatted_message), format, 4);
    
    ShowHudMsg(client, formatted_message, 0, 255, 0, -1.0, 0.5, view_as<float>(duration));
}

stock void ShowSurvivalHUD(int client, int duration, const char[] format, any...)
{
    static char formatted_message[1024];
    VFormat(formatted_message, sizeof(formatted_message), format, 4);
    
    Event event = CreateEvent("show_survival_respawn_status", true);
    if (event == null)
        return;
    
    event.SetString("loc_token", formatted_message);
    event.SetInt("duration", duration);
    event.SetInt("userid", -1);
    
    if (0 < client <= MaxClients)
    {
        event.FireToClient(client);
        event.Cancel();
    }
    else
        event.Fire();
}

stock bool IsClientValid(int client = -1, bool bAlive = false) 
{
	return MaxClients >= client > 0 && IsClientConnected(client) && !IsFakeClient(client) && IsClientInGame(client) && (!bAlive || IsPlayerAlive(client)) ? true : false;
}

stock void ShowHudMsg(int client, char[] message, int r, int g, int b, float x, float y, float timeout) 
{
	SetHudTextParams(x, y, timeout, r, g, b, 255, 0, 0.0, 0.0, 0.0);
	ShowHudText(client, -1, message);
}