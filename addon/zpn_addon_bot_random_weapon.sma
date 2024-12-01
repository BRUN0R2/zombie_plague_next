#include <amxmodx>
#include <reapi>
#include <zombie_plague_next>

#include <api_custom_weapons>

#define PLUGIN  "[ZPN] Bot Random Weapons"
#define VERSION "1.0"
#define AUTHOR  "BRUN0"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
}

public CBasePlayer_Spawn_Post(id)
{
	if(!is_user_bot(id) || zpn_is_user_zombie(id))
		return

	CW_weapon_rd_give(id)
}