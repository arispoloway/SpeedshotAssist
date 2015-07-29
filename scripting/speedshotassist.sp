#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <updater>
#define REQUIRE_PLUGIN

#define PI 3.1415926535
#define UPDATE_URL_BASE "http://raw.github.com/arispoloway/SpeedshotAssist"
#define UPDATE_URL_BRANCH "master"
#define UPDATE_URL_FILE   "updatefile.txt"

#define PLUGIN_VERSION "0.1.1"

new String:g_URLMap[256] = "";

public Plugin:myinfo = {
	name = "Speedshot Assist",
	author = "nolem",
	description = "Will assist with speedshot timing and location",
	version = "PLUGIN_VERSION",
	url = "http://www.tf2rj.com"
};

new bool:enabled[33];

new g_BeamSprite;
new g_HaloSprite;

public OnPluginStart(){

	RegConsoleCmd("sm_ssa", Command_SpeedshotToggle);
	g_BeamSprite = PrecacheModel("materials/sprites/laser.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo01.vmt");

	Format(g_URLMap,sizeof(g_URLMap),"%s/master/%s",UPDATE_URL_BASE,UPDATE_URL_FILE);
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(g_URLMap);
	} else {
		LogMessage("Updater plugin not found.");
	}

}

public OnClientDisconnect(client){
	enabled[client] = false;
}

public Updater_OnPluginUpdated()
{
	LogMessage("Speedshot Assist Update complete.");
	ReloadPlugin();
}

public OnMapStart(){
	g_BeamSprite = PrecacheModel("materials/sprites/laser.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
}

public Action:Command_SpeedshotToggle(client,args){

	//duh
	if( !client ){
		ReplyToCommand(client, "No rcon idiot");
		return Plugin_Handled;
	}
	enabled[client] = !enabled[client];

	if(enabled[client]){
		PrintToChat(client, "Speedshot Assist Enabled");
	}else{
		PrintToChat(client, "Speedshot Assist Disabled");
	}

	return Plugin_Continue;

}

public OnGameFrame(){

	for(new i = 0; i < 33; i++){
		if(enabled[i]){
			new client = i;
			decl Float:v[3];
			decl Float:l[3];
			decl Float:e[3];
			decl bool:d;
			//new at = 0;

			decl b;

			GetEntPropVector(client, Prop_Data, "m_vecOrigin", l);
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", v);

			GetClientEyePosition(client, e);

			b = GetClientButtons(client);

			if(b & IN_DUCK){
				d=true;
			}
			//if(b & IN_ATTACK){
			//	at = 1;
			//}


			new Float:h = GetEndPosition(client, false);
			if(v[2] != 0.0){
				if(h < l[2]){
					new ticks_player = GetTicksTillLand(v[2], h, l[2], d);
					new ticks_rocket = GetTicksTillRocketHit(client);
					//PrintToChat(client, "%d %d %d", ticks_player, ticks_rocket, at);

					new Float:radius;
					new Float:z = e[2] - h;

					new Float:comp = Pow((ticks_player)*16.5, 2.0) - Pow(z,2.0);
					if(comp < 0.0){
						return;
					}

					radius = SquareRoot(comp);

					new Float:pos[3];
					pos[0] = l[0];
					pos[1] = l[1];
					pos[2] = h;

					DrawCircle(pos, radius, 0.13, client);

					new Float:landPoint[3];

					landPoint[2] = h;

					landPoint[0] = l[0] + v[0]/66.6666666 * (ticks_player-3);
					landPoint[1] = l[1] + v[1]/66.6666666 * (ticks_player-3);

					DrawTarget(landPoint, 3.5, 0.7, client);



				}
			}

				
		}
	}


}




GetTicksTillRocketHit(client){
	decl Float:s[3], Float:a[3], Float:e[3];
	GetClientEyePosition(client, s);
	GetClientEyeAngles(client, a);
	TR_TraceRayFilter(s, a, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, client);
	if (TR_DidHit(INVALID_HANDLE)){
		TR_GetEndPosition(e, INVALID_HANDLE);
	}

	new Float:distance = SquareRoot( Pow(e[0]-s[0], 2.0) + Pow(e[1]-s[1], 2.0) + Pow(e[2]-s[2], 2.0)  );

	new ticks = RoundToFloor((distance) / 16.5);
	return ticks;

}

GetTicksTillLand(Float:vel, Float:floor, Float:pos, bool:crouched){
	new ticks = 0;
	new Float:height = pos - floor;

	vel /= 66.66666666;
	vel += 0.09

	while(height > 0){
		vel -= 0.18;
		height += vel;
		ticks++;
	}
	return ticks;

}



Float:GetEndPosition(client, bool:straightDown){
	decl Float:start[3], Float:angle[3], Float:end[3];
	GetClientEyePosition(client, start);
	if(straightDown){
		angle[0] = 90.0;
	}else{
		GetClientEyeAngles(client, angle);
	}
	TR_TraceRayFilter(start, angle, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, client);
	if (TR_DidHit(INVALID_HANDLE)){
		TR_GetEndPosition(end, INVALID_HANDLE);
	}
	//PrintToServer("%f", end[2]);
	return end[2];
}

//I have no idea what this does I stole this too
public bool:TraceEntityFilterPlayer(entity, contentsMask, any:data){
	return entity > MaxClients;
}


stock DrawTarget(Float:vecLocation[3], Float:radius, Float:angleIncr, client) 
{ 
    new Float:angle=0.0, Float:x, Float:y; 
     
    new Float:pos1[3]; 
    new Float:pos2[3]; 
         
    //Create the start position for the first part of the beam 
    pos2[0] = vecLocation[0] + radius; 
    pos2[1] = vecLocation[1]; 
    pos2[2] = vecLocation[2]; 
     
    while (angle <= 2 * (PI + angleIncr)) 
    {              
        x = radius * Cosine(angle); 
        y = radius * Sine(angle); 
         
        pos1[0] = vecLocation[0] + x; 
        pos1[1] = vecLocation[1] + y; 
        pos1[2] = vecLocation[2]; 

        TE_SetupBeamPoints(pos1, pos2, g_BeamSprite, g_HaloSprite, 0, 0, 0.1, Float:5.0, Float:0.1, 5, 0.0, {0,255,0,255}, 3); 
        TE_SendToClient(client);
        //TE_SendToAll();
         
        pos2[0] = pos1[0]; 
        pos2[1] = pos1[1]; 
        pos2[2] = pos1[2]; 
         
        angle += angleIncr; 
    } 
}  


stock DrawCircle(Float:vecLocation[3], Float:radius, Float:angleIncr, client) 
{ 
    new Float:angle=0.0, Float:x, Float:y; 
     
    new Float:pos1[3]; 
    new Float:pos2[3]; 
         
    //Create the start position for the first part of the beam 
    pos2[0] = vecLocation[0] + radius; 
    pos2[1] = vecLocation[1]; 
    pos2[2] = vecLocation[2]; 
     
    while (angle <= 2 * (PI + angleIncr)) 
    {              
        x = radius * Cosine(angle); 
        y = radius * Sine(angle); 
         
        pos1[0] = vecLocation[0] + x; 
        pos1[1] = vecLocation[1] + y; 
        pos1[2] = vecLocation[2]; 

        TE_SetupBeamPoints(pos1, pos2, g_BeamSprite, g_HaloSprite, 0, 0, 0.1, Float:5.0, Float:0.1, 5, 0.0, {255,0,255,255}, 3); 
        TE_SendToClient(client);
        //TE_SendToAll();
         
        pos2[0] = pos1[0]; 
        pos2[1] = pos1[1]; 
        pos2[2] = pos1[2]; 
         
        angle += angleIncr; 
    } 
}  