#include <amxmodx>
#include <fakemeta>
#include <reapi>

new g_LastSpawnId
new Array:g_SpawnPoints
new bool:g_PlayerGodMode[33]
new Float:g_NextCheck[33]

#define CHECK_INTERVAL 0.1
#define SAFE_DISTANCE 50.0
#define MAX_ATTEMPTS 5

public plugin_precache()
{
    register_plugin("[ZPN] Addon: Spawn Spot Fix Prevent", "1.0", "BRUN0")
    g_SpawnPoints = ArrayCreate(1)
    g_LastSpawnId = 0
}

public plugin_init()
{
    RegisterHookChain(RG_CSGameRules_RestartRound, "@OnRoundRestart", true)
    RegisterHookChain(RG_CSGameRules_GetPlayerSpawnSpot, "@OnGetSpawnSpot", false)
    RegisterHookChain(RG_CBasePlayer_PreThink, "@OnPlayerPreThink", false)
    RegisterHookChain(RG_RoundEnd, "RoundEnd_Pre", false)
    InitializeSpawns()
}

public plugin_end()
{
    ArrayDestroy(g_SpawnPoints)
}

public RoundEnd_Pre(WinStatus:status, ScenarioEventEndRound:event, Float:delay)
{
    for(new i = 1; i <= MaxClients; i++)
    {
        g_PlayerGodMode[i] = false
        g_NextCheck[i] = 0.0
    }
}

@OnRoundRestart() {InitializeSpawns();}

@OnPlayerPreThink(const id)
{
    if(!is_user_alive(id) || !g_PlayerGodMode[id])
        return

    new Float:gametime = get_gametime()
    if(gametime < g_NextCheck[id])
        return

    g_NextCheck[id] = gametime + CHECK_INTERVAL

    static Float:origin[3]
    get_entvar(id, var_origin, origin)

    IsSpawnSafe(id, origin) ? DisableGodMode(id) : TryTeleport(id)
}

@OnGetSpawnSpot(const id)
{
    new TeamName:team = get_member(id, m_iTeam)
    if(team != TEAM_TERRORIST && team != TEAM_CT)
        return HC_CONTINUE

    new spot = FindSpawnSpot(id)
    if(is_nullent(spot))
        return HC_CONTINUE

    new Float:origin[3], Float:angles[3]
    get_entvar(spot, var_origin, origin)
    get_entvar(spot, var_angles, angles)
    origin[2] += 1.0

    set_entvar(id, var_origin, origin)
    set_entvar(id, var_angles, angles)
    set_entvar(id, var_fixangle, 1)

    if(!IsSpawnSafe(id, origin))
    {
        SetGodMode(id)
        TryTeleport(id)
    }

    SetHookChainReturn(ATYPE_INTEGER, spot)
    return HC_SUPERCEDE
}

InitializeSpawns()
{
    if(!ArraySize(g_SpawnPoints))
    {
        AddSpawnsByClass("info_player_start")
        AddSpawnsByClass("info_player_deathmatch")
    }

    new count = ArraySize(g_SpawnPoints)
    set_member_game(m_iSpawnPointCount_Terrorist, count)
    set_member_game(m_iSpawnPointCount_CT, count)
}

AddSpawnsByClass(const classname[])
{
    new ent
    while((ent = rg_find_ent_by_class(ent, classname, true)))
        ArrayPushCell(g_SpawnPoints, ent)
}

bool:IsSpawnSafe(id, Float:origin[3])
{
    for(new i = 1; i <= MaxClients; i++)
    {
        if(!is_user_alive(i) || i == id)
            continue
        
        new Float:playerOrigin[3]
        get_entvar(i, var_origin, playerOrigin)
        
        if(get_distance_f(origin, playerOrigin) < SAFE_DISTANCE)
            return false
    }
    return true
}

SetGodMode(id) if(!g_PlayerGodMode[id])
{
    g_PlayerGodMode[id] = true
    g_NextCheck[id] = get_gametime() + CHECK_INTERVAL
        
    set_entvar(id, var_takedamage, DAMAGE_NO)
    set_entvar(id, var_rendermode, kRenderNormal)
    set_entvar(id, var_renderfx, kRenderFxGlowShell)
    static Float:color[3] = {255.0, 255.0, 0.0}
    set_entvar(id, var_rendercolor, color)
    set_entvar(id, var_renderamt, 100.0)
}

DisableGodMode(id) if(g_PlayerGodMode[id])
{
    g_PlayerGodMode[id] = false
        
    set_entvar(id, var_takedamage, DAMAGE_AIM)
    set_entvar(id, var_rendermode, kRenderNormal)
    set_entvar(id, var_renderfx, kRenderFxNone)
    static Float:color[3] = {255.0, 255.0, 255.0}
    set_entvar(id, var_rendercolor, color)
    set_entvar(id, var_renderamt, 255.0)
}

TryTeleport(id)
{
    new attempts
    new Float:origin[3], Float:angles[3]
    new spawnCount = ArraySize(g_SpawnPoints)
    
    while(attempts < MAX_ATTEMPTS)
    {
        new spot = ArrayGetCell(g_SpawnPoints, random(spawnCount))
        
        if(!is_nullent(spot))
        {
            get_entvar(spot, var_origin, origin)
            get_entvar(spot, var_angles, angles)
            
            if(IsSpotValid(id, origin) && IsSpawnSafe(id, origin))
            {
                origin[2] += 1.0
                set_entvar(id, var_origin, origin)
                set_entvar(id, var_angles, angles)
                set_entvar(id, var_fixangle, 1)
                break
            }
        }
        attempts++
    }
}

FindSpawnSpot(id)
{
    new spawnCount = ArraySize(g_SpawnPoints)
    if(!spawnCount) return 0

    new spot, Float:origin[3]

    for(new i; i < spawnCount; i++) 
    {
        g_LastSpawnId = (g_LastSpawnId + 1) % spawnCount
        spot = ArrayGetCell(g_SpawnPoints, g_LastSpawnId)

        if(!is_nullent(spot))
        {
            get_entvar(spot, var_origin, origin)
            if(IsSpotValid(id, origin))
                break
        }
    }

    return is_nullent(spot) ? 0 : spot
}

bool:IsSpotValid(id, Float:origin[3])
{
    engfunc(EngFunc_TraceHull, origin, origin, 0, HULL_HUMAN, id, 0)
    return !get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen)
}