#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <updater>
#define REQUIRE_PLUGIN

#define PI 3.1415926535

#define PLUGIN_VERSION "0.2.0"
#define PLUGIN_DESCRIPTION "Tool to assist with speedshot timing and location"
#define UPDATE_URL_BASE "http://raw.github.com/arispoloway/SpeedshotAssist"
#define UPDATE_URL_BRANCH "master"
#define UPDATE_URL_FILE "updatefile.txt"

bool g_bEnabled[MAXPLAYERS+1];
bool g_bLateLoad;

int g_iBeamSprite;
int g_iHaloSprite;

char g_URLMap[256];

public Plugin myinfo = {
	name = "Speedshot Assist",
	author = "nolem, replica",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "http://www.tf2rj.com"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	CreateConVar("sm_speedshotassist_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD).SetString(PLUGIN_VERSION);

	RegConsoleCmd("sm_ssa", cmdSSA);

	Format(g_URLMap, sizeof(g_URLMap), "%s/master/%s", UPDATE_URL_BASE,UPDATE_URL_FILE);
	if (LibraryExists("updater")) {
		Updater_AddPlugin(g_URLMap);
	}

	if (g_bLateLoad) {
		PrintToChatAll("\x01\x03SSA Reloaded");
	}
}

public void Updater_OnPluginUpdated() {
	LogMessage("Speedshot Assist Update complete.");
	ReloadPlugin();
}

public void OnMapStart() {
	g_iBeamSprite = PrecacheModel("materials/sprites/laser.vmt");
	g_iHaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
}

public void OnMapEnd() {
	for (int i = 0; i < MaxClients; i++) {
		g_bEnabled[i] = false;
	}
}

public void OnClientDisconnect(int client) {
	g_bEnabled[client] = false;
}

public Action cmdSSA(int client, int args) {
	if (!client) {
		return Plugin_Handled;
	}

	g_bEnabled[client] = !g_bEnabled[client];
	PrintToChat(client, "\x01[\x03SSA\x01] Speed shot assist\x03 %s", g_bEnabled[client] ? "enabled" : "disabled");
	return Plugin_Handled;
}

public void OnGameFrame() {
	for (int i = 1; i < MaxClients; i++) {
		if (!IsValidClient(i) || !g_bEnabled[i]) {
			continue;
		}

		int client = i;
		float vVelocity[3];
		float vOrigin[3];
		float vEyePos[3];

		GetEntPropVector(client, Prop_Data, "m_vecOrigin", vOrigin);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);

		GetClientEyePosition(client, vEyePos);

		float end = GetEndPosition(client, false);

		if (vVelocity[2] == 0.0 || end >= vOrigin[2]) {
			continue;
		}

		int ticksPlayer = GetTicksTillLand(vVelocity[2], end, vOrigin[2]);
		int ticksRocket = GetTicksTillRocketHit(client);

		float z = vEyePos[2] - end;

		float vLandPoint[3];

		vLandPoint[0] = vOrigin[0] + vVelocity[0]/66.6666666 * (ticksPlayer-3);
		vLandPoint[1] = vOrigin[1] + vVelocity[1]/66.6666666 * (ticksPlayer-3);
		vLandPoint[2] = end;

		DrawTarget(vLandPoint, 7.0, 0.7, client, (ticksRocket < ticksPlayer), (ticksRocket == ticksPlayer));

		float comp = Pow((ticksPlayer)*16.5, 2.0) - Pow(z, 2.0);
		if (comp < 0.0) {
			return;
		}

		DrawCircle(vLandPoint, 50.0, 0.122, client, (ticksRocket < ticksPlayer), (ticksRocket == ticksPlayer));
	}
}

int GetTicksTillRocketHit(int client) {
	float vEyePos[3];
	float vEyeAng[3];
	float vEnd[3];
	GetClientEyePosition(client, vEyePos);
	GetClientEyeAngles(client, vEyeAng);

	TR_TraceRayFilter(vEyePos, vEyeAng, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, client);
	if (TR_DidHit(null)) {
		TR_GetEndPosition(vEnd, null);
	}

	float distance = SquareRoot(Pow(vEnd[0]-vEyePos[0], 2.0) + Pow(vEnd[1]-vEyePos[1], 2.0) + Pow(vEnd[2]-vEyePos[2], 2.0));

	int ticks = RoundToFloor((distance) / 16.5);
	return ticks;
}

int GetTicksTillLand(float vel, float floor, float pos) {
	int ticks;
	float height = pos - floor;

	vel /= 66.66666666;
	vel += 0.09;

	while (height > 0) {
		vel -= 0.18;
		height += vel;
		ticks++;
	}

	return ticks;
}

float GetEndPosition(int client, bool straightDown) {
	float vEyePos[3];
	float vEyeAng[3];
	float vEnd[3];
	GetClientEyePosition(client, vEyePos);

	if (straightDown) {
		vEyeAng[0] = 90.0;
	}
	else {
		GetClientEyeAngles(client, vEyeAng);
	}

	TR_TraceRayFilter(vEyePos, vEyeAng, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, client);
	if (TR_DidHit(null)) {
		TR_GetEndPosition(vEnd, null);
	}

	return vEnd[2];
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask, any data) {
	return (entity > MaxClients);
}

void DrawTarget(float vecLocation[3], float radius, float angleIncr, int client, bool RLessThanP, bool REqualsP) {
	float angle;
	float x;
	float y;

	float pos1[3];
	float pos2[3];

	//Create the start position for the first part of the beam
	pos2 = vecLocation;
	pos2[0] += radius;

	while (angle <= 2 * (PI + angleIncr)) {
		x = radius * Cosine(angle);
		y = radius * Sine(angle);

		pos1 = vecLocation;
		pos1[0] += x;
		pos1[1] += y;

		int RGBA[4];
		RGBA[0] = RLessThanP ? 255 :   0;
		RGBA[1] = RLessThanP ?   0 : 255;
		RGBA[2] = REqualsP   ? 239 :   0;
		RGBA[3] = 255;

		TE_SetupBeamPoints(pos1, pos2, g_iBeamSprite, g_iHaloSprite, 0, 0, 0.1, 5.0, 0.1, 5, 0.0, RGBA, 3);
		TE_SendToClient(client);

		pos2 = pos1;

		angle += angleIncr;
	}
}


void DrawCircle(float vecLocation[3], float radius, float angleIncr, int client, bool RLessThanP, bool REqualsP) {
	float angle;
	float x;
	float y;

	float pos1[3];
	float pos2[3];

	//Create the start position for the first part of the beam
	vecLocation[2] += 5.0;
	pos2 = vecLocation;
	pos2[0] += radius;

	int RGBA[4];
	RGBA[0] = RLessThanP ? 255 :   0;
	RGBA[1] = RLessThanP ?   0 : 255;
	RGBA[2] = REqualsP   ? 239 :   0;
	RGBA[3] = 255;

	while (angle <= 2 * (PI + angleIncr)) {
		x = radius * Cosine(angle);
		y = radius * Sine(angle);

		pos1 = vecLocation;
		pos1[0] += x;
		pos1[1] += y;

		TE_SetupBeamPoints(pos1, pos2, g_iBeamSprite, g_iHaloSprite, 0, 0, 0.1, 15.0, 15.0, 5, 10.0, RGBA, 5);
		TE_SendToClient(client);

		pos2 = pos1;

		angle += angleIncr;
	}
}

bool IsValidClient(int client) {
	return (0 < client <= MaxClients && IsClientInGame(client));
}