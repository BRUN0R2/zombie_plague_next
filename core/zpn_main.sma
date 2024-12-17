#pragma compress 1
#pragma dynamic 65536

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <regex>
#include <api_json_settings>
#include <zombie_plague_next_const>

#define is_valid_player_alive(%1) (1 <= %1 <= MaxClients && is_user_alive(%1) && is_user_connected(%1))
#define is_valid_player_connected(%1) (1 <= %1 <= MaxClients && is_user_connected(%1))
#define is_valid_player(%1) (1 <= %1 <= MaxClients)

const MAX_LEVEL = 10000

enum
{
	TASK_COUNTDOWN = 1515,
	TASK_HUD_PLAYER_INFO,
	TASK_RESPAWN,
	TASK_NV,
	TASK_FROZEN,
}

enum _:eCvars
{
	CVAR_START_DELAY,
	CVAR_LAST_HUMAN_INFECT,
	CVAR_WEAPON_WEIGHT_DISCOUNT_SPEED,
	CVAR_CLASS_SELECT_INSTANT,
	Float:CVAR_CLASS_SELECT_INSTANT_TIMEOUT,
	CVAR_RESPAWN_IN_LAST_H,
	CVAR_DEFAULT_NV_H[12],
	CVAR_DEFAULT_NV_Z[12],
	P_CVAR_DEFAULT_NV_H,
	P_CVAR_DEFAULT_NV_Z,
	Float:CVAR_DMG_DEALT_REACHED,
	CVAR_DMG_DEALT_REWARD,
}

enum _:eForwards
{
	FW_ROUND_STARTED_POST,
	FW_HUMANIZED_PRE,
	FW_HUMANIZED_POST,
	FW_INFECTED_PRE,
	FW_INFECTED_POST,
	FW_INFECT_ATTEMPT,
	FW_ITEM_SELECTED_POST,
}

enum _:eSettingsConfigs
{
	CONFIG_DEBUG_ON,
	CONFIG_ZOMBIE_ESCAPE_ON,
	CONFIG_DEFAULT_HUMAN_MODEL[32],
	CONFIG_PREFIX_MENUS[32],
	CONFIG_PREFIX_CHAT[32],
}

enum _:ePropClasses
{
	eClassTypes:CLASS_PROP_TYPE,
	CLASS_PROP_NAME[64],
	CLASS_PROP_CUSTOM_NAME[64],
	CLASS_PROP_INFO[64],
	CLASS_PROP_MODEL[64],
	CLASS_PROP_MODEL_VIEW[64],
	CLASS_PROP_BODY,
	CLASS_PROP_SKIN,
	Float:CLASS_PROP_HEALTH,
	Float:CLASS_PROP_ARMOR,
	Float:CLASS_PROP_SPEED,
	Float:CLASS_PROP_GRAVITY,
	Float:CLASS_PROP_KNOCKBACK,
	CLASS_PROP_CLAW_WEAPONLIST[64],
	CLASS_PROP_FIND_NAME[32],
	CLASS_PROP_NV_COLOR[9],
	CLASS_PROP_NV_COLOR_CONVERTED[3],
	bool:CLASS_PROP_HIDE_MENU,
	bool:CLASS_PROP_UPDATE_HITBOX,
	CLASS_PROP_BLOOD_COLOR,
	bool:CLASS_PROP_SILENT_FOOTSTEPS,
	CLASS_PROP_MODEL_INDEX,
	CLASS_PROP_LIMIT,
	CLASS_PROP_LEVEL
}

enum _:ePropGameModes
{
	GAMEMODE_PROP_NAME[32],
	GAMEMODE_PROP_NOTICE[64],
	GAMEMODE_PROP_HUD_COLOR[9],
	GAMEMODE_PROP_HUD_COLOR_CONVERTED[3],
	GAMEMODE_PROP_CHANCE,
	GAMEMODE_PROP_MIN_PLAYERS,
	Float:GAMEMODE_PROP_ROUND_TIME,
	bool:GAMEMODE_PROP_CHANGE_CLASS,
	eGameModeDeathMatchTypes:GAMEMODE_PROP_DEATHMATCH,
	Float:GAMEMODE_PROP_RESPAWN_TIME,
	GAMEMODE_PROP_FIND_NAME[32]
}

enum _:ePropItems
{
	ITEM_PROP_NAME[32],
	ITEM_PROP_COST,
	eItemTeams:ITEM_PROP_TEAM,
	ITEM_PROP_LIMIT_PLAYER_PER_ROUND,
	ITEM_PROP_LIMIT_MAX_PER_ROUND,
	ITEM_PROP_LIMIT_PER_MAP,
	ITEM_PROP_MIN_ZOMBIES,
	bool:ITEM_PROP_ALLOW_BUY_SPECIAL_MODS,
	ITEM_PROP_FLAG,
}

enum _:eGameRules
{
	GAME_RULE_CURRENT_GAMEMODE,
	bool:GAME_RULE_IS_ROUND_STARTED,
	GAME_RULE_COUNTDOWN,
	Array:GAME_RULE_USELESS_ENTITIES,
	Array:GAME_RULE_PRIMARY_WEAPONS,
	Array:GAME_RULE_SECONDARY_WEAPONS,
	GAME_RULE_LAST_GAMEMODE,
	GAME_RULE_DEFAULT_NV_H[3],
	GAME_RULE_DEFAULT_NV_Z[3],
	Array:GAME_RULE_FROZEN_HIT_SOUNDS
}

enum _:eUserData
{
	UD_CURRENT_SELECTED_ZOMBIE_CLASS,
	UD_CURRENT_SELECTED_HUMAN_CLASS,
	bool:UD_IS_ZOMBIE,
	bool:UD_IS_FIRST_ZOMBIE,
	UD_PRIMARY_WEAPON,
	UD_SECONDARY_WEAPON,
	Float:UD_CLASS_TIMEOUT,
	Float:UD_LAST_LEAP_TIMEOUT,
	bool:UD_IS_LAST_HUMAN,
	bool:UD_NV_ON,
	Float:UD_NV_SPAM,
	UD_AMMO_PACKS,
	Float:UD_DMG_DEALT,
	UD_NEXT_ZOMBIE_CLASS,
	UD_NEXT_HUMAN_CLASS,
	UD_CURRENT_TEMP_ZOMBIE_CLASS,
	UD_CURRENT_TEMP_HUMAN_CLASS,
	UD_LEVEL,
	bool:UD_IS_FREEZED,
}

enum _:eSyncHuds
{
	SYNC_HUD_MAIN,
	SYNC_HUD_PLAYER_INFO
}

new const CS_SOUNDS[][] = { "items/flashlight1.wav", "items/9mmclip1.wav", "player/bhit_helmet-1.wav" };

new xDataClassCount, xDataGameModeCount, xDataItemCount, xFirstClass[2], xClassCount[2], xItemCount[2]
new Array:aDataClass, Array:aDataGameMode, Array:aDataItem, Array:aIndexClassesZombies, Array:aIndexClassesHumans
new xForwards[eForwards], xForwardReturn, xFwIntParam[12]

new xMsgScoreAttrib, xFwSpawn_Pre, defaultIndexPlayer
new xCvars[eCvars], xSettingsVars[eSettingsConfigs], xMsgSync[eSyncHuds], xUserData[33][eUserData]
new xDataGetGameRule[eGameRules]

public plugin_init()
{
	register_plugin("Zombie Plague Next", "1.0", "Wilian M.")
	register_dictionary("common.txt")

	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false)
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", true)
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "CSGameRules_OnRoundFreezeEnd_Pre", false)
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Pre", false)
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "CBasePlayerWeapon_DefaultDeploy_Pre", false)
	RegisterHookChain(RG_RoundEnd, "RoundEnd_Pre", false)
	RegisterHookChain(RG_CBasePlayer_TraceAttack, "CBasePlayer_TraceAttack_Pre", false)
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre", false)
	RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "CBasePlayer_ResetMaxSpeed_Pre", false)
	RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "CBasePlayer_ResetMaxSpeed_Post", true)
	RegisterHookChain(RG_CBasePlayer_HasRestrictItem, "RCBasePlayer_HasRestrictItem_Pre", false)
	RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink", false)
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true)
	RegisterHookChain(RG_HandleMenu_ChooseAppearance, "HandleMenu_ChooseAppearance_Post", true)

	register_clcmd("nightvision", "clcmd_nightvision")
	register_clcmd("say f", "ffff")

	for(new i = 0; i < eSyncHuds; i++)
		xMsgSync[i] = CreateHudSyncObj()

	if(zpn_is_invalid_array(aDataClass))
		set_fail_state("[ZP NEXT] No Classes Founds")

	if(zpn_is_invalid_array(aDataGameMode))
		set_fail_state("[ZP NEXT] No GameModes Founds")

	// FWS
	xForwards[FW_ROUND_STARTED_POST] = CreateMultiForward("zpn_round_started_post", ET_IGNORE, FP_CELL)
	xForwards[FW_INFECTED_PRE] = CreateMultiForward("zpn_user_infected_pre", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	xForwards[FW_INFECTED_POST] = CreateMultiForward("zpn_user_infected_post", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	xForwards[FW_INFECT_ATTEMPT] = CreateMultiForward("zpn_user_infect_attempt", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL)
	xForwards[FW_HUMANIZED_PRE] = CreateMultiForward("zpn_user_humanized_pre", ET_IGNORE, FP_CELL, FP_CELL)
	xForwards[FW_HUMANIZED_POST] = CreateMultiForward("zpn_user_humanized_post", ET_IGNORE, FP_CELL, FP_CELL)
	xForwards[FW_ITEM_SELECTED_POST] = CreateMultiForward("zpn_item_selected_post", ET_IGNORE, FP_CELL, FP_CELL)

	xMsgScoreAttrib = get_user_msgid("ScoreAttrib")

	xFirstClass[0] = get_first_class(CLASS_TEAM_TYPE_ZOMBIE)
	xFirstClass[1] = get_first_class(CLASS_TEAM_TYPE_HUMAN)

	xClassCount[0] = count_class(CLASS_TEAM_TYPE_ZOMBIE)
	xClassCount[1] = count_class(CLASS_TEAM_TYPE_HUMAN)

	xItemCount[0] = count_item(ITEM_TEAM_ZOMBIE)
	xItemCount[1] = count_item(ITEM_TEAM_HUMAN)

	register_clcmd("chooseteam", "clcmd_changeteam")
	register_clcmd("jointeam", "clcmd_changeteam")

	if (xFwSpawn_Pre)
		unregister_forward(FM_Spawn, xFwSpawn_Pre, false)

	if(xSettingsVars[CONFIG_DEBUG_ON])
	{
		server_print("^n")
		server_print("Classes loaded: %d", ArraySize(aDataClass))
		new i, text[128]
		
		new xDataGetClass[ePropClasses]
		for(i = 0; i < ArraySize(aDataClass); i++)
		{
			ArrayGetArray(aDataClass, i, xDataGetClass)
			
			text[0] = EOS
			
			add(text, charsmax(text), fmt("Class: %s | ", xDataGetClass[CLASS_PROP_NAME]))
			add(text, charsmax(text), fmt("Info: %s | ", xDataGetClass[CLASS_PROP_INFO]))
			add(text, charsmax(text), fmt("Type: %s | ", xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_ZOMBIE ? "Zombie" : xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_ZOMBIE_SPECIAL ? "Zombie Special" : xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_HUMAN_SPECIAL ? "Human Special" : "Human"))
			add(text, charsmax(text), fmt("Model: %s | ", xDataGetClass[CLASS_PROP_MODEL]))
			add(text, charsmax(text), fmt("Model View: %s", xDataGetClass[CLASS_PROP_MODEL_VIEW] == EOS ? "--" : fmt("%s", xDataGetClass[CLASS_PROP_MODEL_VIEW])))
			server_print(text)
		}

		server_print("^n")
		server_print("GameModes loaded: %d", ArraySize(aDataGameMode))
		
		new xDataGetGameMode[ePropGameModes]
		for(i = 0; i < ArraySize(aDataGameMode); i++)
		{
			ArrayGetArray(aDataGameMode, i, xDataGetGameMode)

			text[0] = EOS
			
			add(text, charsmax(text), fmt("GameMode: %s | ", xDataGetGameMode[GAMEMODE_PROP_NAME]))
			add(text, charsmax(text), fmt("Chance: %d | ", xDataGetGameMode[GAMEMODE_PROP_CHANCE]))
			add(text, charsmax(text), fmt("Min Players: %d | ", xDataGetGameMode[GAMEMODE_PROP_MIN_PLAYERS]))
			add(text, charsmax(text), fmt("Round Time: %0.1f", xDataGetGameMode[GAMEMODE_PROP_ROUND_TIME]))

			server_print(text)
		}

		server_print("^n")
		server_print("Items loaded: %d", ArraySize(aDataItem))

		new xDataGetItem[ePropItems]
		for(i = 0; i < ArraySize(aDataItem); i++)
		{
			ArrayGetArray(aDataItem, i, xDataGetItem)

			text[0] = EOS
			
			add(text, charsmax(text), fmt("Item: %s | ", xDataGetItem[ITEM_PROP_NAME]))
			add(text, charsmax(text), fmt("Cost: %d | ", xDataGetItem[ITEM_PROP_COST]))
			add(text, charsmax(text), fmt("Team: %s", xDataGetItem[ITEM_PROP_TEAM] == ITEM_TEAM_ZOMBIE ? "z" : "h"))
			server_print(text)
		}

		server_print("^n^n")
	}

	get_classes_index()
}

public ffff(id)
{
	set_user_frozen(id, 2.0, false)
}

public HandleMenu_ChooseAppearance_Post(const this, const slot)
{
	if(!is_valid_player_connected(this))
		return

	if((1 <= slot <= 4 || slot == 6))
		check_game()
}

public clcmd_nightvision(id)
{
	xUserData[id][UD_NV_ON] = !xUserData[id][UD_NV_ON]
	return PLUGIN_HANDLED
}

public CBasePlayer_Killed_Post(const this, pevAttacker, iGib)
{
	new xDataGetGameMode[ePropGameModes]
	ArrayGetArray(aDataGameMode, xDataGetGameRule[GAME_RULE_CURRENT_GAMEMODE], xDataGetGameMode)

	if(xUserData[this][UD_IS_ZOMBIE] && xDataGetGameMode[GAMEMODE_PROP_DEATHMATCH] == GAMEMODE_DEATHMATCH_ONLY_TR && xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED])
	{
		remove_task(this + TASK_RESPAWN)
		set_task_ex(xDataGetGameMode[GAMEMODE_PROP_RESPAWN_TIME], "respawn_user", this + TASK_RESPAWN)
	}
}

public respawn_user(this)
{
	this -= TASK_RESPAWN

	if(!is_user_connected(this)) { remove_task(this + TASK_RESPAWN); return; }

	if(!is_user_alive(this))
		rg_round_respawn(this)
}

public CBasePlayer_PreThink(const this)
{
	if(!is_valid_player_alive(this))
		return

	if(xUserData[this][UD_NV_ON] && xUserData[this][UD_NV_SPAM] < get_gametime())
		set_user_nv(this)
	
	xUserData[this][UD_NV_SPAM] = get_gametime() + 0.001

	if(xUserData[this][UD_LAST_LEAP_TIMEOUT] > get_gametime())
		return

	if(!(get_entvar(this, var_button) & (IN_JUMP | IN_DUCK) == (IN_JUMP | IN_DUCK)))
		return

	if(!(get_entvar(this, var_flags) & FL_ONGROUND) || get_user_speed(this) < 80)
		return

	static Float:velocity[3]

	velocity_by_aim(this, 500, velocity) // force
	velocity[2] = 300.0 // height

	set_entvar(this, var_velocity, velocity)
	xUserData[this][UD_LAST_LEAP_TIMEOUT] = get_gametime() + 5.0
}

public CBasePlayer_TakeDamage_Pre(const victim, pevInflictor, attacker, Float:flDamage, bitsDamageType)
{
	if(victim == attacker || !is_valid_player_alive(attacker) || !is_valid_player_alive(victim) || !xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED])
		return HC_CONTINUE

	// is human
	if(!xUserData[attacker][UD_IS_ZOMBIE] && xUserData[victim][UD_IS_ZOMBIE])
	{
		xUserData[attacker][UD_DMG_DEALT] += flDamage

		while(xUserData[attacker][UD_DMG_DEALT] >= xCvars[CVAR_DMG_DEALT_REACHED])
		{
			xUserData[attacker][UD_DMG_DEALT] = 0.0
			xUserData[attacker][UD_AMMO_PACKS] += xCvars[CVAR_DMG_DEALT_REWARD]
		}
	}

	// is zombie
	if(xUserData[attacker][UD_IS_ZOMBIE] && !xUserData[victim][UD_IS_ZOMBIE])
	{
		if(get_num_alive() == 1 && !xCvars[CVAR_LAST_HUMAN_INFECT])
			return HC_CONTINUE

		static Float:armor
		get_entvar(victim, var_armorvalue, armor)

		if(armor > 0.0)
		{
			emit_sound(victim, CHAN_BODY, CS_SOUNDS[2], 1.0, 0.5, 0, PITCH_NORM)
			
			if(armor - flDamage > 0.0)
				set_entvar(victim, var_armorvalue, armor - flDamage)
			else rg_set_user_armor(victim, 0, ARMOR_NONE)

			SetHookChainReturn(ATYPE_INTEGER, 0)
			return HC_SUPERCEDE
		}
		
		if(xUserData[victim][UD_NEXT_ZOMBIE_CLASS] != -1)
		{
			xUserData[victim][UD_CURRENT_SELECTED_ZOMBIE_CLASS] = xUserData[victim][UD_NEXT_ZOMBIE_CLASS]
			xUserData[victim][UD_NEXT_ZOMBIE_CLASS] = -1
		}

		set_user_zombie(victim, attacker, false)

		if(get_num_alive() == 0 && xCvars[CVAR_LAST_HUMAN_INFECT])
			rg_round_end(2.0, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN, .trigger = true)
	}

	if(get_num_alive() == 1)
	{
		new last_human = get_first_human_id()
		
		if(last_human != -1 && !xUserData[last_human][UD_IS_LAST_HUMAN])
		{
			xUserData[last_human][UD_IS_LAST_HUMAN] = true
			//server_print("ultimo humano: %n", last_human)
		}
	}

	return HC_CONTINUE
}

public CBasePlayer_TraceAttack_Pre(const this, pevAttacker, Float:flDamage, Float:vecDir[3], tracehandle, bitsDamageType)
{
	if(this == pevAttacker)
		return
	
}

public CBasePlayer_ResetMaxSpeed_Pre(const this)
{
	if(!is_valid_player_alive(this))
		return HC_CONTINUE

	new classTeam = xUserData[this][UD_IS_ZOMBIE] ? xUserData[this][UD_CURRENT_SELECTED_ZOMBIE_CLASS] : xUserData[this][UD_CURRENT_SELECTED_HUMAN_CLASS]
	new xDataGetClass[ePropClasses]
	ArrayGetArray(aDataClass, classTeam, xDataGetClass)

	new Float:speed = xDataGetClass[CLASS_PROP_SPEED]
	new activeItem = get_member(this, m_pActiveItem)

	if(!is_nullent(activeItem) && xCvars[CVAR_WEAPON_WEIGHT_DISCOUNT_SPEED])
		speed -= float(rg_get_iteminfo(activeItem, ItemInfo_iWeight))

	set_entvar(this, var_maxspeed, speed)

	return HC_SUPERCEDE
}

public CBasePlayer_ResetMaxSpeed_Post(const this)
{
	if(is_valid_player_alive(this) && xUserData[this][UD_IS_FREEZED])
		set_entvar(this, var_maxspeed, 1.0)
}

public clcmd_changeteam(id)
{
	if(is_user_bot(id))
		return PLUGIN_CONTINUE
		
	new any:team = get_member(id, m_iTeam)

	if(team == TEAM_SPECTATOR || team == TEAM_UNASSIGNED)
		return PLUGIN_CONTINUE

	show_menu_game(id)

	return PLUGIN_HANDLED
}

public client_putinserver(id)
{
	reset_user_vars(id)

	if(!is_user_bot(id) && !is_user_hltv(id))
		set_task_ex(0.1, "xHudPlayerInfo", id + TASK_HUD_PLAYER_INFO, .flags = SetTask_Repeat)

	check_game()
}

public xHudPlayerInfo(id)
{
	id -= TASK_HUD_PLAYER_INFO

	if(!is_user_connected(id)) { remove_task(id + TASK_HUD_PLAYER_INFO); return; }
	
	if(!is_user_alive(id))
		return

	static txt[256]; txt[0] = EOS

	set_hudmessage(0, 255, 255, 0.03, 0.2, 0, 0.0, 0.0, 0.1, 0.1)

	add(txt, charsmax(txt), fmt("» Modo: %s^n", get_gamemode_name()))
	add(txt, charsmax(txt), fmt("» Classe: %s^n", get_class_name(id)))
	add(txt, charsmax(txt), fmt("» Vida: %s^n", format_number_point(floatround(get_entvar(id, var_health)))))

	if(!xUserData[id][UD_IS_ZOMBIE])
		add(txt, charsmax(txt), fmt("» Colete: %d^n", get_entvar(id, var_armorvalue)))

	add(txt, charsmax(txt), fmt("» Ammo Packs: %s^n", format_number_point(xUserData[id][UD_AMMO_PACKS])))
	add(txt, charsmax(txt), fmt("» Velocidade: %d", get_user_speed(id)))

	ShowSyncHudMsg(id, xMsgSync[SYNC_HUD_PLAYER_INFO], txt)
}

public show_menu_game(id)
{
	new xMenu = menu_create(fmt("%s \yZombie Plague Next", xSettingsVars[CONFIG_PREFIX_MENUS]), "_show_menu_game")

	menu_additem(xMenu, "Selecionar Armas")
	menu_additem(xMenu, "Loja De Itens")
	menu_additem(xMenu, "Selecionar Classes^n")
	menu_additem(xMenu, "\yAdministração")

	menu_setprop(xMenu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
	menu_setprop(xMenu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
	menu_setprop(xMenu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))
	menu_display(id, xMenu)
}

public _show_menu_game(id, menu, item)
{
	if(!is_user_connected(id))
		return

	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return
	}
	
	switch(item)
	{
		case 0:
		{
			xUserData[id][UD_PRIMARY_WEAPON] = -1
			xUserData[id][UD_SECONDARY_WEAPON] = -1
			select_primary_weapon(id)
		}

		case 1:
		{
			buy_items(id)
		}

		case 2:
		{
			select_class_type(id)
		}

		case 3:
		{
			client_print(id, 3, "admin")
		}
	}
}

public buy_items(id)
{
	new xDataGetItem[ePropItems]
	new eItemTeams:itemTeam = xUserData[id][UD_IS_ZOMBIE] ? ITEM_TEAM_ZOMBIE : ITEM_TEAM_HUMAN
	new countCheck = itemTeam == ITEM_TEAM_ZOMBIE ? xItemCount[0] : xItemCount[1]

	new xMenu = menu_create(fmt("%s \yLoja de Itens", xSettingsVars[CONFIG_PREFIX_MENUS]), "_buy_items")
	
	if(countCheck <= 0)
	{
		client_print_color(id, print_team_red, "%s ^3Nenhum item encontrado.", xSettingsVars[CONFIG_PREFIX_CHAT])
		return
	}

	for(new i = 0; i < ArraySize(aDataItem); i++)
	{
		ArrayGetArray(aDataItem, i, xDataGetItem)

		if(xDataGetItem[ITEM_PROP_TEAM] == itemTeam)
			menu_additem(xMenu, fmt("\w%s \y(\d%s\y)", xDataGetItem[ITEM_PROP_NAME], format_number_point(xDataGetItem[ITEM_PROP_COST])), fmt("%d", i))
	}

	menu_setprop(xMenu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
	menu_setprop(xMenu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
	menu_setprop(xMenu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))
	menu_display(id, xMenu)
}

public _buy_items(id, menu, item)
{
	if(!is_user_connected(id))
		return

	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return
	}

	new info[4]
	menu_item_getinfo(menu, item, .info = info, .infolen = charsmax(info))

	new item_index = str_to_num(info)
	new xDataGetItem[ePropItems]

	ArrayGetArray(aDataItem, item_index, xDataGetItem)

	if(xUserData[id][UD_IS_ZOMBIE] && xDataGetItem[ITEM_PROP_TEAM] == ITEM_TEAM_HUMAN)
		return
	
	if(xUserData[id][UD_AMMO_PACKS] < xDataGetItem[ITEM_PROP_COST])
	{
		buy_items(id)
		client_print_color(id, print_team_red, "%s ^3Você não tem ^4Ammo Packs ^3suficiente.", xSettingsVars[CONFIG_PREFIX_CHAT])
		return
	}

	ExecuteForward(xForwards[FW_ITEM_SELECTED_POST], xForwardReturn, id, item_index)
}

public select_class_type(id)
{
	new xMenu = menu_create(fmt("%s \yEscolha a raça", xSettingsVars[CONFIG_PREFIX_MENUS]), "_select_class_type")

	menu_additem(xMenu, fmt("Zombie \y(\d%d classes\y)", xClassCount[0]), fmt("%d", CLASS_TEAM_TYPE_ZOMBIE))
	menu_additem(xMenu, fmt("Humano \y(\d%d classes\y)", xClassCount[1]), fmt("%d", CLASS_TEAM_TYPE_HUMAN))

	menu_setprop(xMenu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))
	menu_display(id, xMenu)
}

public _select_class_type(id, menu, item)
{
	if(!is_user_connected(id))
		return

	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return
	}

	new info[4]
	menu_item_getinfo(menu, item, .info = info, .infolen = charsmax(info))
	new eClassTypes:class_type = eClassTypes:str_to_num(info)

	if(xClassCount[_:class_type]<= 0)
	{
		client_print_color(id, print_team_red, "%s ^3Nenhuma classe encontrada.", xSettingsVars[CONFIG_PREFIX_CHAT])
		select_class_type(id)
		return
	}

	new xMenu = menu_create(fmt("%s \ySelecionar classe: %s", xSettingsVars[CONFIG_PREFIX_MENUS], class_type == CLASS_TEAM_TYPE_ZOMBIE ? "\rZombie" : "\yHumano"), "_select_class")
	new xDataGetClass[ePropClasses]

	for(new i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)

		if(xDataGetClass[CLASS_PROP_TYPE] == class_type && !xDataGetClass[CLASS_PROP_HIDE_MENU])
			menu_additem(xMenu, fmt("\w%s \y(\d%s\y)%s", xDataGetClass[CLASS_PROP_NAME], xDataGetClass[CLASS_PROP_INFO], i == get_current_class_index(id, class_type) ? " \r*" : ""), fmt("%d", i))
	}

	menu_setprop(xMenu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
	menu_setprop(xMenu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
	menu_setprop(xMenu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))
	menu_display(id, xMenu)
}

public _select_class(id, menu, item)
{
	if(!is_user_connected(id))
		return

	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return
	}

	new info[4]
	menu_item_getinfo(menu, item, .info = info, .infolen = charsmax(info))

	new class_id = str_to_num(info)
	new xDataGetClass[ePropClasses]
	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	if(xCvars[CVAR_CLASS_SELECT_INSTANT] && xUserData[id][UD_CLASS_TIMEOUT] > get_gametime())
	{
		client_print_color(id, print_team_default, "%s ^3Espere: ^4%.0f ^3segundos para alterar de classe novamente.", xSettingsVars[CONFIG_PREFIX_CHAT], xUserData[id][UD_CLASS_TIMEOUT] - get_gametime())
		return
	}
	
	if(!xCvars[CVAR_CLASS_SELECT_INSTANT])
	{
		client_print_color(id, print_team_default, "%s ^3Sua nova classe ao reaparecer será: ^4%s^1.", xSettingsVars[CONFIG_PREFIX_CHAT], xDataGetClass[CLASS_PROP_NAME])
	}
	else
	{
		client_print_color(id, print_team_default, "%s ^3Agora sua classe é: ^4%s^1.", xSettingsVars[CONFIG_PREFIX_CHAT], xDataGetClass[CLASS_PROP_NAME])
		xUserData[id][UD_CLASS_TIMEOUT] = get_gametime() + xCvars[CVAR_CLASS_SELECT_INSTANT_TIMEOUT]
	}

	switch(xDataGetClass[CLASS_PROP_TYPE])
	{
		// case CLASS_TEAM_TYPE_ZOMBIE_SPECIAL:
		// {
		// 	xUserData[id][UD_CURRENT_SELECTED_ZOMBIE_CLASS] = class_id
		// }

		case CLASS_TEAM_TYPE_ZOMBIE:
		{
			if(xCvars[CVAR_CLASS_SELECT_INSTANT])
			{
				xUserData[id][UD_NEXT_ZOMBIE_CLASS] = -1
				xUserData[id][UD_CURRENT_SELECTED_ZOMBIE_CLASS] = class_id

				if(xUserData[id][UD_IS_ZOMBIE])
					set_user_zombie(id, 0, false)
			}
			else
			{
				xUserData[id][UD_NEXT_ZOMBIE_CLASS] = class_id
			}
		}

		case CLASS_TEAM_TYPE_HUMAN:
		{
			if(xCvars[CVAR_CLASS_SELECT_INSTANT])
			{
				xUserData[id][UD_NEXT_HUMAN_CLASS] = -1
				xUserData[id][UD_CURRENT_SELECTED_HUMAN_CLASS] = class_id

				if(!xUserData[id][UD_IS_ZOMBIE])
					set_user_human(id)
			}
			else
			{
				xUserData[id][UD_NEXT_HUMAN_CLASS] = class_id
			}
		}
	}

	client_print_color(id, print_team_default, "%s ^3Vida: ^1%s ^4- ^3Gravidade: ^1%d ^4- ^3Velocidade: ^1%0.0f", xSettingsVars[CONFIG_PREFIX_CHAT], format_number_point(floatround(xDataGetClass[CLASS_PROP_HEALTH])), floatround(xDataGetClass[CLASS_PROP_GRAVITY] * 800.0), xDataGetClass[CLASS_PROP_SPEED])
}

public reset_user_vars(id)
{
	xUserData[id][UD_IS_ZOMBIE] = false
	xUserData[id][UD_IS_FIRST_ZOMBIE] = false
	xUserData[id][UD_CURRENT_SELECTED_ZOMBIE_CLASS] = xFirstClass[0]
	xUserData[id][UD_CURRENT_SELECTED_HUMAN_CLASS] = xFirstClass[1]
	xUserData[id][UD_CURRENT_TEMP_ZOMBIE_CLASS] = -1
	xUserData[id][UD_CURRENT_TEMP_HUMAN_CLASS] = -1
	xUserData[id][UD_PRIMARY_WEAPON] = -1
	xUserData[id][UD_SECONDARY_WEAPON] = -1
	xUserData[id][UD_NEXT_ZOMBIE_CLASS] = -1
	xUserData[id][UD_NEXT_HUMAN_CLASS] = -1
	xUserData[id][UD_CLASS_TIMEOUT] = get_gametime()
	xUserData[id][UD_LAST_LEAP_TIMEOUT] = get_gametime()
}

public RoundEnd_Pre(WinStatus:status, ScenarioEventEndRound:event, Float:delay)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!is_user_connected(i))
			continue

		xUserData[i][UD_CLASS_TIMEOUT] = get_gametime()
		xUserData[i][UD_LAST_LEAP_TIMEOUT] = get_gametime()
		xUserData[i][UD_DMG_DEALT] = 0.0

		set_task_ex(0.1, "remove_user_frozen", i + TASK_FROZEN)
	}

	xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED] = false

	if(zpn_is_invalid_array(aDataGameMode))
		xDataGetGameRule[GAME_RULE_CURRENT_GAMEMODE] = -1
	else xDataGetGameRule[GAME_RULE_CURRENT_GAMEMODE] = 0
}

public CBasePlayerWeapon_DefaultDeploy_Pre(const ent, szViewModel[], szWeaponModel[], iAnim, szAnimExt[], skiplocal)
{
	if(is_nullent(ent))
		return

	new id = get_member(ent, m_pPlayer)
	
	if(xUserData[id][UD_IS_ZOMBIE] && get_member(ent, m_iId) == WEAPON_KNIFE)
	{
		new class_id, xDataGetClass[ePropClasses]
		class_id = xUserData[id][UD_CURRENT_TEMP_ZOMBIE_CLASS] != -1 ? xUserData[id][UD_CURRENT_TEMP_ZOMBIE_CLASS] : xUserData[id][UD_CURRENT_SELECTED_ZOMBIE_CLASS]
		ArrayGetArray(aDataClass, class_id, xDataGetClass)

		SetHookChainArg(2, ATYPE_STRING, xDataGetClass[CLASS_PROP_MODEL_VIEW])
		SetHookChainArg(3, ATYPE_STRING, "")
	}
}

public CBasePlayer_Spawn_Pre(id)
{
	if(!is_valid_player_connected(id))
		return

	new TeamName:team = get_member(id, m_iTeam)

	if(team != TEAM_TERRORIST && team != TEAM_CT)
		return

	if(team != TEAM_CT && !xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED])
		rg_set_user_team(id, TEAM_CT)
}

public CBasePlayer_Spawn_Post(id)
{
	if(!is_valid_player_alive(id))
		return

	new TeamName:team = get_member(id, m_iTeam)

	if(team != TEAM_TERRORIST && team != TEAM_CT)
		return
	
	if(!xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED])
	{
		set_user_human(id)
		deploy_weapon(id)
	}
	else
	{
		if(xUserData[id][UD_IS_ZOMBIE])
		{
			if(xUserData[id][UD_NEXT_ZOMBIE_CLASS] != -1)
			{
				xUserData[id][UD_CURRENT_SELECTED_ZOMBIE_CLASS] = xUserData[id][UD_NEXT_ZOMBIE_CLASS]
				xUserData[id][UD_NEXT_ZOMBIE_CLASS] = -1
				set_user_zombie(id, 0, false)
			}
			else set_user_zombie(id, 0, false)
		}
		else
		{
			if(xUserData[id][UD_NEXT_HUMAN_CLASS] != -1)
			{
				xUserData[id][UD_CURRENT_SELECTED_HUMAN_CLASS] = xUserData[id][UD_NEXT_HUMAN_CLASS]
				xUserData[id][UD_NEXT_HUMAN_CLASS] = -1
				set_user_human(id)
			}
			else set_user_human(id)
		}
	}

	if(xUserData[id][UD_PRIMARY_WEAPON] == -1 && !xUserData[id][UD_IS_ZOMBIE])
		select_primary_weapon(id)
	else if(xUserData[id][UD_PRIMARY_WEAPON] != -1 && !xUserData[id][UD_IS_ZOMBIE])
	{
		get_selected_weapon(id, xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS], xUserData[id][UD_PRIMARY_WEAPON], PRIMARY_WEAPON_SLOT)

		if(xUserData[id][UD_SECONDARY_WEAPON] != -1)
			get_selected_weapon(id, xDataGetGameRule[GAME_RULE_SECONDARY_WEAPONS], xUserData[id][UD_SECONDARY_WEAPON], PISTOL_SLOT)
	}
}

public RCBasePlayer_HasRestrictItem_Pre(const this, ItemID:item, ItemRestType:typ)
{
	if(!is_valid_player_alive(this))
		return HC_CONTINUE

	if(xUserData[this][UD_IS_ZOMBIE])
	{
		SetHookChainReturn(ATYPE_BOOL, true)

		return HC_SUPERCEDE
	}

	return HC_CONTINUE
}

public select_primary_weapon(id)
{
	if(xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED])
	{
		client_print_color(id, print_team_red, "%s ^3Seleção de armas resetadas! ^1Espere o fim da rodada.", xSettingsVars[CONFIG_PREFIX_CHAT])
		return
	}

	new xMenu = menu_create(fmt("%s \ySelecionar arma primária", xSettingsVars[CONFIG_PREFIX_MENUS]), "_select_primary_weapon")
	static xWpn[32]

	for(new i = 0; i < ArraySize(xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS]); i++)
	{
		ArrayGetString(xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS], i, xWpn, charsmax(xWpn))
		mb_strtotitle(xWpn[7])
		menu_additem(xMenu, xWpn[7], fmt("%d", i))
	}

	menu_setprop(xMenu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
	menu_setprop(xMenu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
	menu_setprop(xMenu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))
	menu_display(id, xMenu)
}

public _select_primary_weapon(id, menu, item)
{
	if(xUserData[id][UD_IS_ZOMBIE])
		return

	if(!is_user_connected(id))
		return

	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return
	}
	
	new xInfo[11], xWpnArrayIndex
	menu_item_getinfo(menu, item, _, xInfo, charsmax(xInfo))
	xWpnArrayIndex = str_to_num(xInfo)
	xUserData[id][UD_PRIMARY_WEAPON] = xWpnArrayIndex
	
	get_selected_weapon(id, xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS], xWpnArrayIndex, PRIMARY_WEAPON_SLOT)
	select_secondary_weapon(id)
}

public select_secondary_weapon(id)
{
	new xMenu = menu_create(fmt("%s \ySelecionar arma secundária", xSettingsVars[CONFIG_PREFIX_MENUS]), "_select_secondary_weapon")
	static xWpn[32]

	for(new i = 0; i < ArraySize(xDataGetGameRule[GAME_RULE_SECONDARY_WEAPONS]); i++)
	{
		ArrayGetString(xDataGetGameRule[GAME_RULE_SECONDARY_WEAPONS], i, xWpn, charsmax(xWpn))
		mb_strtotitle(xWpn[7])
		menu_additem(xMenu, xWpn[7], fmt("%d", i))
	}

	menu_setprop(xMenu, MPROP_NEXTNAME, fmt("%L", id, "MORE"))
	menu_setprop(xMenu, MPROP_BACKNAME, fmt("%L", id, "BACK"))
	menu_setprop(xMenu, MPROP_EXITNAME, fmt("%L", id, "EXIT"))
	menu_display(id, xMenu)
}

public _select_secondary_weapon(id, menu, item)
{
	if(xUserData[id][UD_IS_ZOMBIE])
		return

	if(!is_user_connected(id))
		return

	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return
	}
	
	new xInfo[11], xWpnArrayIndex
	menu_item_getinfo(menu, item, _, xInfo, charsmax(xInfo))
	xWpnArrayIndex = str_to_num(xInfo)
	xUserData[id][UD_SECONDARY_WEAPON] = xWpnArrayIndex

	get_selected_weapon(id, xDataGetGameRule[GAME_RULE_SECONDARY_WEAPONS], xWpnArrayIndex, PISTOL_SLOT)
}

public get_selected_weapon(const id, Array:WpnType, const xWpnArrayIndex, const InventorySlotType:slot)
{
	if(xUserData[id][UD_IS_ZOMBIE])
		return

	new xWpn[32]
	ArrayGetString(WpnType, xWpnArrayIndex, xWpn, charsmax(xWpn))

	if(rg_has_item_by_name(id, xWpn))
		return

	rg_drop_items_by_slot(id, slot)
	rg_give_item(id, xWpn)

	if(!rg_find_weapon_bpack_by_name(id, "weapon_knife"))
		rg_give_item(id, "weapon_knife")

	new WeaponIdType:xWpnIdType = rg_get_weapon_info(xWpn, WI_ID)
	new xWpnBpAmmo = rg_get_weapon_info(xWpnIdType, WI_MAX_ROUNDS)
	rg_set_user_bpammo(id, xWpnIdType, xWpnBpAmmo)
}

public CSGameRules_RestartRound_Pre()
{
	xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED] = false
}

public CSGameRules_RestartRound_Post()
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!is_user_connected(i))
			continue

		set_task_ex(0.1, "remove_user_frozen", i + TASK_FROZEN)
	}

	update_users_next_class()
}

public CSGameRules_OnRoundFreezeEnd_Pre()
{
	if(xDataGetGameRule[GAME_RULE_CURRENT_GAMEMODE] == -1)
	{
		server_print("[ZP NEXT] No gamemodes found.")
		return
	}

	xDataGetGameRule[GAME_RULE_COUNTDOWN] = xCvars[CVAR_START_DELAY]
	remove_task(TASK_COUNTDOWN)
	set_task_ex(0.0, "xStartCountDown", TASK_COUNTDOWN)
}

public xStartCountDown()
{
	if(xDataGetGameRule[GAME_RULE_COUNTDOWN] <= 0)
	{
		xInitRound()
		remove_task(TASK_COUNTDOWN)
		return
	}

	set_hudmessage(255, 0, 0, -1.0, 0.30, 2, 0.3, 1.0, 0.05, 0.05, -1, 0, { 100, 200, 50, 100 })
	ShowSyncHudMsg(0, xMsgSync[SYNC_HUD_MAIN], "Rodada inicia em: %d", xDataGetGameRule[GAME_RULE_COUNTDOWN])

	if(xDataGetGameRule[GAME_RULE_COUNTDOWN] <= 10)
	{
		static nword[20]
		num_to_word(xDataGetGameRule[GAME_RULE_COUNTDOWN], nword, charsmax(nword))
		client_cmd(0, "spk sound/vox/%s.wav", nword)
	}

	xDataGetGameRule[GAME_RULE_COUNTDOWN] --
	set_task_ex(1.0, "xStartCountDown", TASK_COUNTDOWN)
}

public xInitRound()
{
	update_users_next_class()

	new gm = random_gamemode()

	if(gm == -1) gm = 0

	new xDataGetGameMode[ePropGameModes]
	ArrayGetArray(aDataGameMode, gm, xDataGetGameMode)

	if(xDataGetGameMode[GAMEMODE_PROP_MIN_PLAYERS] < get_num_alive())
		gm = 0

	xDataGetGameRule[GAME_RULE_LAST_GAMEMODE] = gm
	xDataGetGameRule[GAME_RULE_CURRENT_GAMEMODE] = gm
	xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED] = true

	set_hudmessage(xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR_CONVERTED][0], xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR_CONVERTED][1], xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR_CONVERTED][2], -1.0, 0.20, 2, 0.3, 3.0, 0.06, 0.06, -1, 0, { 100, 100, 200, 100 })
	ShowSyncHudMsg(0, xMsgSync[SYNC_HUD_MAIN], "%s", xDataGetGameMode[GAMEMODE_PROP_NOTICE])

	ExecuteForward(xForwards[FW_ROUND_STARTED_POST], xForwardReturn, gm)
}

public plugin_precache()
{
	new i
	for(i = 0; i < sizeof(CS_SOUNDS); i++) engfunc(EngFunc_PrecacheSound, CS_SOUNDS[i])

	defaultIndexPlayer = precache_model("models/player.mdl")

	aDataClass = ArrayCreate(ePropClasses, 0)
	aDataGameMode = ArrayCreate(ePropGameModes, 0)
	aDataItem = ArrayCreate(ePropItems, 0)

	aIndexClassesZombies = ArrayCreate(1, 0)
	aIndexClassesHumans = ArrayCreate(1, 0)

	bind_pcvar_num(create_cvar("zpn_delay", "15", .has_min = true, .min_val = 1.0), xCvars[CVAR_START_DELAY])
	bind_pcvar_num(create_cvar("zpn_class_select_instant", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_CLASS_SELECT_INSTANT])
	bind_pcvar_float(create_cvar("zpn_class_select_instant_timeout", "30", .has_min = true, .min_val = 10.0, .has_max = true, .max_val = 500.0), xCvars[CVAR_CLASS_SELECT_INSTANT_TIMEOUT])
	bind_pcvar_num(create_cvar("zpn_last_human_infect", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_LAST_HUMAN_INFECT])
	bind_pcvar_num(create_cvar("zpn_weapon_weight_discount_speed", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_WEAPON_WEIGHT_DISCOUNT_SPEED])
	//bind_pcvar_num(create_cvar("zpn_respawn_in_last_human", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_RESPAWN_IN_LAST_H])
	bind_pcvar_float(create_cvar("zpn_ap_dmg_reached", "1000", .has_min = true, .min_val = 50.0, .has_max = true, .max_val = 5000.0), xCvars[CVAR_DMG_DEALT_REACHED])
	bind_pcvar_num(create_cvar("zpn_ap_dmg_reward", "1", .has_min = true, .min_val = 1.0, .has_max = true, .max_val = 1000.0), xCvars[CVAR_DMG_DEALT_REWARD])

	bind_pcvar_string(xCvars[P_CVAR_DEFAULT_NV_H] = create_cvar("zpn_default_nv_h", "#00bbff", .flags = FCVAR_NOEXTRAWHITEPACE), xCvars[CVAR_DEFAULT_NV_H], charsmax(xCvars[CVAR_DEFAULT_NV_H]))
	bind_pcvar_string(xCvars[P_CVAR_DEFAULT_NV_Z] = create_cvar("zpn_default_nv_z", "#27e30e", .flags = FCVAR_NOEXTRAWHITEPACE), xCvars[CVAR_DEFAULT_NV_Z], charsmax(xCvars[CVAR_DEFAULT_NV_Z]))
	hook_cvar_change(xCvars[P_CVAR_DEFAULT_NV_H], "cvar_nightvision_changed"); hook_cvar_change(xCvars[P_CVAR_DEFAULT_NV_Z], "cvar_nightvision_changed")

	new bool:parse_nv
	parse_nv = parse_hex_color(xCvars[CVAR_DEFAULT_NV_H], xDataGetGameRule[GAME_RULE_DEFAULT_NV_H])

	if(!parse_nv)
	{
		xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][0] = xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][1] = 0
		xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][2] = 100
	}

	parse_nv = parse_hex_color(xCvars[CVAR_DEFAULT_NV_Z], xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z])

	if(!parse_nv)
	{
		xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][0] = 100
		xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][1] = xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][2] = 0
	}

	if(!json_setting_get_int(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Enable Debug", xSettingsVars[CONFIG_DEBUG_ON]))
	{
		xSettingsVars[CONFIG_DEBUG_ON] = 0
		json_setting_set_int(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Enable Debug", 0)
	}

	if(!json_setting_get_int(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Enable Zombie Escape", xSettingsVars[CONFIG_ZOMBIE_ESCAPE_ON]))
	{
		xSettingsVars[CONFIG_ZOMBIE_ESCAPE_ON] = 0
		json_setting_set_int(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Enable Zombie Escape", 0)
	}

	if(!json_setting_get_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Prefix Chat", xSettingsVars[CONFIG_PREFIX_CHAT], charsmax(xSettingsVars[CONFIG_PREFIX_CHAT])))
	{
		xSettingsVars[CONFIG_PREFIX_CHAT] = "!y[!gZP!y]"
		json_setting_set_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Prefix Chat", "!y[!gZP!y]")
	}

	update_prefix_color(xSettingsVars[CONFIG_PREFIX_CHAT], charsmax(xSettingsVars[CONFIG_PREFIX_CHAT]))

	if(!json_setting_get_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Prefix Menus", xSettingsVars[CONFIG_PREFIX_MENUS], charsmax(xSettingsVars[CONFIG_PREFIX_MENUS])))
	{
		xSettingsVars[CONFIG_PREFIX_MENUS] = "!y[!rZP!y]"
		json_setting_set_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Prefix Menus", "!y[!rZP!y]")
	}

	update_prefix_color(xSettingsVars[CONFIG_PREFIX_MENUS], charsmax(xSettingsVars[CONFIG_PREFIX_MENUS]), true)

	if(!json_setting_get_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Default Human Model", xSettingsVars[CONFIG_DEFAULT_HUMAN_MODEL], charsmax(xSettingsVars[CONFIG_DEFAULT_HUMAN_MODEL])))
	{
		xSettingsVars[CONFIG_DEFAULT_HUMAN_MODEL] = "sas"
		json_setting_set_string(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Default Human Model", "sas")
	}

	xDataGetGameRule[GAME_RULE_USELESS_ENTITIES] = ArrayCreate(64, 0)

	if(!json_setting_get_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Useless Entities", xDataGetGameRule[GAME_RULE_USELESS_ENTITIES]))
	{
		new const uselessEntities[][] =
		{
			"func_bomb_target",
			"info_bomb_target",
			"info_vip_start",
			"func_vip_safetyzone",
			"func_escapezone",
			"func_hostage_rescue",
			"info_hostage_rescue",
			"hostage_entity",
			"armoury_entity",
			"player_weaponstrip",
			"game_player_equip",
			"env_fog",
			"env_rain",
			"env_snow",
			"monster_scientist",
			"item_longjump",
			"game_text",
		}

		for(new i = 0; i < sizeof(uselessEntities); i++)
			ArrayPushString(xDataGetGameRule[GAME_RULE_USELESS_ENTITIES], uselessEntities[i])

		json_setting_set_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Useless Entities", xDataGetGameRule[GAME_RULE_USELESS_ENTITIES])
	}

	if (!zpn_is_invalid_array(xDataGetGameRule[GAME_RULE_USELESS_ENTITIES]))
		xFwSpawn_Pre = register_forward(FM_Spawn, "Spawn_Pre", false)

	xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS] = ArrayCreate(32, 0)

	if(!json_setting_get_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Primary Weapons", xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS]))
	{
		ArrayPushString(xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS], "weapon_famas")
		ArrayPushString(xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS], "weapon_galil")
		ArrayPushString(xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS], "weapon_ak47")
		ArrayPushString(xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS], "weapon_m4a1")
		json_setting_set_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Primary Weapons", xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS])
	}

	xDataGetGameRule[GAME_RULE_SECONDARY_WEAPONS] = ArrayCreate(32, 0)

	if(!json_setting_get_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Secondary Weapons", xDataGetGameRule[GAME_RULE_SECONDARY_WEAPONS]))
	{
		ArrayPushString(xDataGetGameRule[GAME_RULE_SECONDARY_WEAPONS], "weapon_p228")
		ArrayPushString(xDataGetGameRule[GAME_RULE_SECONDARY_WEAPONS], "weapon_usp")
		ArrayPushString(xDataGetGameRule[GAME_RULE_SECONDARY_WEAPONS], "weapon_deagle")
		ArrayPushString(xDataGetGameRule[GAME_RULE_SECONDARY_WEAPONS], "weapon_elite")
		json_setting_set_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Secondary Weapons", xDataGetGameRule[GAME_RULE_SECONDARY_WEAPONS])
	}

	xDataGetGameRule[GAME_RULE_FROZEN_HIT_SOUNDS] = ArrayCreate(64, 0)

	if(!json_setting_get_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Frozen Hit Sounds", xDataGetGameRule[GAME_RULE_FROZEN_HIT_SOUNDS]))
	{
		new const sounds[][] =
		{
			"zpn/frozen_hit1.wav",
			"zpn/frozen_hit2.wav",
		}

		for(new i = 0; i < sizeof(sounds); i++)
			ArrayPushString(xDataGetGameRule[GAME_RULE_FROZEN_HIT_SOUNDS], sounds[i])

		json_setting_set_string_arr(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Frozen Hit Sounds", xDataGetGameRule[GAME_RULE_FROZEN_HIT_SOUNDS])
	}

	new sound[64]
	for(new i = 0; i < ArraySize(xDataGetGameRule[GAME_RULE_FROZEN_HIT_SOUNDS]); i++)
	{
		ArrayGetString(xDataGetGameRule[GAME_RULE_FROZEN_HIT_SOUNDS], i, sound, charsmax(sound))
		
		if(zpn_is_null_string(sound))
			continue

		if(file_exists(sound)) precache_sound(sound)
	}
}

public cvar_nightvision_changed(pcvar, const old_value[], const new_value[])
{
	new bool:parse_nv

	if(pcvar == xCvars[P_CVAR_DEFAULT_NV_H])
	{
		parse_nv = parse_hex_color(new_value, xDataGetGameRule[GAME_RULE_DEFAULT_NV_H])

		if(!parse_nv)
		{
			xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][0] = xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][1] = 0
			xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][2] = 100
		}
	}

	if(pcvar == xCvars[P_CVAR_DEFAULT_NV_Z])
	{
		parse_nv = parse_hex_color(new_value, xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z])

		if(!parse_nv)
		{
			xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][0] = 100
			xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][1] = xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][2] = 0
		}
	}
}

public Spawn_Pre(this)
{
	new classname[32]; get_entvar(this, var_classname, classname, charsmax(classname))

	if(ArrayFindString(xDataGetGameRule[GAME_RULE_USELESS_ENTITIES], classname) != -1)
	{
		forward_return(FMV_CELL, -1)
		return FMRES_SUPERCEDE
	}

	return FMRES_IGNORED
}

public plugin_end()
{
	ArrayDestroy(aDataClass)
	ArrayDestroy(aDataGameMode)
	ArrayDestroy(aDataItem)
	ArrayDestroy(aIndexClassesZombies)
	ArrayDestroy(aIndexClassesHumans)
	ArrayDestroy(xDataGetGameRule[GAME_RULE_USELESS_ENTITIES])
	ArrayDestroy(xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS])
	ArrayDestroy(xDataGetGameRule[GAME_RULE_SECONDARY_WEAPONS])
	ArrayDestroy(xDataGetGameRule[GAME_RULE_FROZEN_HIT_SOUNDS])
}

public plugin_natives()
{
	register_library("zombie_plague_next")

	register_native("zpn_class_init", "_zpn_class_init")
	register_native("zpn_class_get_prop", "_zpn_class_get_prop")
	register_native("zpn_class_set_prop", "_zpn_class_set_prop")
	register_native("zpn_class_random_class_id", "_zpn_class_random_class_id")
	register_native("zpn_class_find", "_zpn_class_find")

	register_native("zpn_gamemode_init", "_zpn_gamemode_init")
	register_native("zpn_gamemode_get_prop", "_zpn_gamemode_get_prop")
	register_native("zpn_gamemode_set_prop", "_zpn_gamemode_set_prop")
	register_native("zpn_gamemode_find", "_zpn_gamemode_find")
	register_native("zpn_gamemode_current", "_zpn_gamemode_current")

	register_native("zpn_item_init", "_zpn_item_init")
	register_native("zpn_item_get_prop", "_zpn_item_get_prop")
	register_native("zpn_item_set_prop", "_zpn_item_set_prop")

	register_native("zpn_set_user_zombie", "_zpn_set_user_zombie")
	register_native("zpn_is_user_zombie", "_zpn_is_user_zombie")
	register_native("zpn_is_user_zombie_special", "_zpn_is_user_zombie_special")
	register_native("zpn_print_color", "_zpn_print_color")
	register_native("zpn_set_fw_param_int", "_zpn_set_fw_param_int")
	register_native("zpn_is_round_started", "_zpn_is_round_started")
	register_native("zpn_get_user_selected_class", "_zpn_get_user_selected_class")
	register_native("zpn_send_weapon_deploy", "_zpn_send_weapon_deploy")
}

public _zpn_send_weapon_deploy(plugin_id, param_nums)
{
	if(param_nums != 1)
		return false

	new id = get_param(1)
	deploy_weapon(id)

	return true
}

public _zpn_gamemode_current(plugin_id, param_nums)
{
	return xDataGetGameRule[GAME_RULE_CURRENT_GAMEMODE]
}

public bool:_zpn_is_round_started(plugin_id, param_nums)
{
	return xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED]
}

public _zpn_class_find(plugin_id, param_nums)
{
	if(param_nums != 1)
		return 0

	static findName[32]; findName[0] = EOS;
	get_string(1, findName, charsmax(findName))

	new find = -1
	new xDataGetClass[ePropClasses]

	for(new i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)
		
		if(zpn_is_null_string(xDataGetClass[CLASS_PROP_FIND_NAME]))
			continue

		if(equal(xDataGetClass[CLASS_PROP_FIND_NAME], findName))
			find = i

		if(find != -1)
			break
	}

	return find
}

public _zpn_gamemode_find(plugin_id, param_nums)
{
	if(param_nums != 1)
		return 0

	static findName[32]; findName[0] = EOS;
	get_string(1, findName, charsmax(findName))

	new find = -1
	new xDataGetGameMode[ePropGameModes]

	for(new i = 0; i < ArraySize(aDataGameMode); i++)
	{
		ArrayGetArray(aDataGameMode, i, xDataGetGameMode)
		
		if(zpn_is_null_string(xDataGetGameMode[GAMEMODE_PROP_FIND_NAME]))
			continue

		if(equal(xDataGetGameMode[GAMEMODE_PROP_FIND_NAME], findName))
			find = i

		if(find != -1)
			break
	}

	return find
}

public _zpn_class_random_class_id(plugin_id, param_nums)
{
	if(param_nums != 1)
		return 0

	new eClassTypes:type = eClassTypes:get_param(1)
	new random_index

	switch(type)
	{
		case CLASS_TEAM_TYPE_ZOMBIE: random_index = ArrayGetCell(aIndexClassesZombies, random_num(0, ArraySize(aIndexClassesZombies) -1))
		case CLASS_TEAM_TYPE_HUMAN: random_index = ArrayGetCell(aIndexClassesHumans, random_num(0, ArraySize(aIndexClassesHumans) -1))
		default: random_index =  ArrayGetCell(aIndexClassesZombies, 0)
	}

	return random_index
}

public _zpn_set_fw_param_int(plugin_id, param_nums)
{
	if(param_nums != 2)
		return

	xFwIntParam[get_param(1)] = get_param(2)
}

public _zpn_print_color(plugin_id, param_nums)
{
	new id = get_param(1)
	new sender = get_param(2)

	static msg[192]; msg[0] = EOS;

	if(param_nums == 3) get_string(3, msg, charsmax(msg))
	else vdformat(msg, charsmax(msg), 3, 4)

	return client_print_color(id, sender, "%s %s", xSettingsVars[CONFIG_PREFIX_CHAT], msg)
}

public bool:_zpn_is_user_zombie(plugin_id, param_nums)
{
	if(param_nums != 1)
		return false

	new id = get_param(1)

	if(!is_user_connected(id))
		return false

	return xUserData[id][UD_IS_ZOMBIE]
}

public bool:_zpn_is_user_zombie_special(plugin_id, param_nums)
{
	if(param_nums != 1)
		return false

	new id = get_param(1)

	if(!is_user_connected(id))
		return false

	new class_id = xUserData[id][UD_CURRENT_TEMP_ZOMBIE_CLASS] != -1 ? xUserData[id][UD_CURRENT_TEMP_ZOMBIE_CLASS] : xUserData[id][UD_CURRENT_SELECTED_ZOMBIE_CLASS]
	new xDataGetClass[ePropClasses]
	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	return (xUserData[id][UD_IS_ZOMBIE] && xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_ZOMBIE_SPECIAL)
}

public _zpn_get_user_selected_class(plugin_id, param_nums)
{
	if(param_nums != 3)
		return 0

	new id = get_param(1)

	if(!is_user_connected(id))
		return 0

	new eClassTypes:type = eClassTypes:get_param(2)
	new bool:check_temp = bool:get_param(3)

	return get_current_class_index(id, type, check_temp)
}

public bool:_zpn_set_user_zombie(plugin_id, param_nums)
{
	if(param_nums != 3)
		return false

	new id = get_param(1)
	new attacker = get_param(2)
	new bool:set_first = bool:get_param(3)

	return set_user_zombie(id, attacker, set_first)
}

public _zpn_item_init(plugin_id, param_nums)
{
	new index = (++xDataItemCount - 1)
	new xDataGetItem[ePropItems]

	xDataGetItem[ITEM_PROP_NAME] = EOS
	xDataGetItem[ITEM_PROP_COST] = 0
	xDataGetItem[ITEM_PROP_TEAM] = ITEM_TEAM_HUMAN
	xDataGetItem[ITEM_PROP_LIMIT_PLAYER_PER_ROUND] = 0
	xDataGetItem[ITEM_PROP_LIMIT_MAX_PER_ROUND] = 0
	xDataGetItem[ITEM_PROP_LIMIT_PER_MAP] = 0
	xDataGetItem[ITEM_PROP_MIN_ZOMBIES] = 0
	xDataGetItem[ITEM_PROP_ALLOW_BUY_SPECIAL_MODS] = false
	xDataGetItem[ITEM_PROP_FLAG] = ADMIN_ALL

	ArrayPushArray(aDataItem, xDataGetItem)

	return index
}

public any:_zpn_item_get_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataItem))
		return false

	enum { arg_item_id = 1, arg_prop, arg_value, arg_len }

	new item_id = get_param(arg_item_id)
	new prop = get_param(arg_prop)

	new xDataGetItem[ePropItems]
	ArrayGetArray(aDataItem, item_id, xDataGetItem)

	switch(ePropItemRegisters:prop)
	{
		case ITEM_PROP_REGISTER_NAME: set_string(arg_value, xDataGetItem[ITEM_PROP_NAME], get_param_byref(arg_len))
		case ITEM_PROP_REGISTER_COST: return xDataGetItem[ITEM_PROP_COST]
		case ITEM_PROP_REGISTER_TEAM: return xDataGetItem[ITEM_PROP_TEAM]
		case ITEM_PROP_REGISTER_LIMIT_PLAYER_PER_ROUND: return xDataGetItem[ITEM_PROP_LIMIT_PLAYER_PER_ROUND]
		case ITEM_PROP_REGISTER_LIMIT_MAX_PER_ROUND: return xDataGetItem[ITEM_PROP_LIMIT_MAX_PER_ROUND]
		case ITEM_PROP_REGISTER_LIMIT_PER_MAP: return xDataGetItem[ITEM_PROP_LIMIT_PER_MAP]
		case ITEM_PROP_REGISTER_MIN_ZOMBIES: return xDataGetItem[ITEM_PROP_MIN_ZOMBIES]
		case ITEM_PROP_REGISTER_ALLOW_BUY_SPECIAL_MODS: return xDataGetItem[ITEM_PROP_ALLOW_BUY_SPECIAL_MODS]
		case ITEM_PROP_REGISTER_FLAG: return xDataGetItem[ITEM_PROP_FLAG]
		default: return false
	}

	return true
}

public any:_zpn_item_set_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataItem))
		return false

	enum { arg_item_id = 1, arg_prop, arg_value }

	new item_id = get_param(arg_item_id)
	new prop = get_param(arg_prop)

	new xDataGetItem[ePropItems]
	ArrayGetArray(aDataItem, item_id, xDataGetItem)

	switch(ePropItemRegisters:prop)
	{
		case ITEM_PROP_REGISTER_NAME: get_string(arg_value, xDataGetItem[ITEM_PROP_NAME], charsmax(xDataGetItem[ITEM_PROP_NAME]))
		case ITEM_PROP_REGISTER_COST: xDataGetItem[ITEM_PROP_COST] = get_param_byref(arg_value)
		case ITEM_PROP_REGISTER_TEAM: xDataGetItem[ITEM_PROP_TEAM] = eItemTeams:get_param_byref(arg_value)
		case ITEM_PROP_REGISTER_LIMIT_PLAYER_PER_ROUND: xDataGetItem[ITEM_PROP_LIMIT_PLAYER_PER_ROUND] = get_param_byref(arg_value)
		case ITEM_PROP_REGISTER_LIMIT_MAX_PER_ROUND: xDataGetItem[ITEM_PROP_LIMIT_MAX_PER_ROUND] = get_param_byref(arg_value)
		case ITEM_PROP_REGISTER_LIMIT_PER_MAP: xDataGetItem[ITEM_PROP_LIMIT_PER_MAP] = get_param_byref(arg_value)
		case ITEM_PROP_REGISTER_MIN_ZOMBIES: xDataGetItem[ITEM_PROP_MIN_ZOMBIES] = get_param_byref(arg_value)
		case ITEM_PROP_REGISTER_ALLOW_BUY_SPECIAL_MODS: xDataGetItem[ITEM_PROP_ALLOW_BUY_SPECIAL_MODS] = bool:get_param_byref(arg_value)
		case ITEM_PROP_REGISTER_FLAG: xDataGetItem[ITEM_PROP_FLAG] = get_param_byref(arg_value)
		default: return false
	}

	ArraySetArray(aDataItem, item_id, xDataGetItem)
	
	return true
}

public _zpn_gamemode_init(plugin_id, param_nums)
{
	new xDataGetGameMode[ePropGameModes]
	new index = (++xDataGameModeCount - 1)

	xDataGetGameMode[GAMEMODE_PROP_NAME] = EOS
	xDataGetGameMode[GAMEMODE_PROP_NOTICE] = EOS
	xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR] = EOS
	xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR_CONVERTED] = { 255, 255, 255 }
	xDataGetGameMode[GAMEMODE_PROP_CHANCE] = -1
	xDataGetGameMode[GAMEMODE_PROP_MIN_PLAYERS] = 1
	xDataGetGameMode[GAMEMODE_PROP_ROUND_TIME] = 2.0
	xDataGetGameMode[GAMEMODE_PROP_CHANGE_CLASS] = false
	xDataGetGameMode[GAMEMODE_PROP_DEATHMATCH] = GAMEMODE_DEATHMATCH_DISABLED
	xDataGetGameMode[GAMEMODE_PROP_RESPAWN_TIME] = -1.0
	xDataGetGameMode[GAMEMODE_PROP_FIND_NAME] = EOS

	ArrayPushArray(aDataGameMode, xDataGetGameMode)

	return index
}

public any:_zpn_gamemode_get_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataGameMode))
		return false

	enum { arg_gamemode_id = 1, arg_prop, arg_value, arg_len }

	new gamemode_id = get_param(arg_gamemode_id)
	new prop = get_param(arg_prop)

	new xDataGetGameMode[ePropGameModes]
	ArrayGetArray(aDataGameMode, gamemode_id, xDataGetGameMode)

	switch(ePropGameModeRegisters:prop)
	{
		case GAMEMODE_PROP_REGISTER_NAME: set_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NAME], get_param_byref(arg_len))
		case GAMEMODE_PROP_REGISTER_NOTICE: set_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NOTICE], get_param_byref(arg_len))
		case GAMEMODE_PROP_REGISTER_HUD_COLOR: return xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR]
		case GAMEMODE_PROP_REGISTER_CHANCE: return xDataGetGameMode[GAMEMODE_PROP_CHANCE]
		case GAMEMODE_PROP_REGISTER_MIN_PLAYERS: return xDataGetGameMode[GAMEMODE_PROP_MIN_PLAYERS]
		case GAMEMODE_PROP_REGISTER_ROUND_TIME: return Float:xDataGetGameMode[GAMEMODE_PROP_ROUND_TIME]
		case GAMEMODE_PROP_REGISTER_CHANGE_CLASS: return bool:xDataGetGameMode[GAMEMODE_PROP_CHANGE_CLASS]
		case GAMEMODE_PROP_REGISTER_DEATHMATCH: return xDataGetGameMode[GAMEMODE_PROP_DEATHMATCH]
		case GAMEMODE_PROP_REGISTER_RESPAWN_TIME: return xDataGetGameMode[GAMEMODE_PROP_RESPAWN_TIME]
		case GAMEMODE_PROP_REGISTER_FIND_NAME: set_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_FIND_NAME], get_param_byref(arg_len))
		default: return false
	}

	return true
}

public any:_zpn_gamemode_set_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataGameMode))
		return false

	enum { arg_gamemode_id = 1, arg_prop, arg_value }

	new gamemode_id = get_param(arg_gamemode_id)
	new prop = get_param(arg_prop)

	new xDataGetGameMode[ePropGameModes]
	ArrayGetArray(aDataGameMode, gamemode_id, xDataGetGameMode)

	switch(ePropGameModeRegisters:prop)
	{
		case GAMEMODE_PROP_REGISTER_NAME: get_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NAME], charsmax(xDataGetGameMode[GAMEMODE_PROP_NAME]))
		case GAMEMODE_PROP_REGISTER_NOTICE: get_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NOTICE], charsmax(xDataGetGameMode[GAMEMODE_PROP_NOTICE]))
		case GAMEMODE_PROP_REGISTER_HUD_COLOR:
		{
			get_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR], charsmax(xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR]))

			if(!zpn_is_null_string(xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR]))
				parse_hex_color(xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR], xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR_CONVERTED])
		}
		case GAMEMODE_PROP_REGISTER_CHANCE: xDataGetGameMode[GAMEMODE_PROP_CHANCE] = get_param_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_MIN_PLAYERS: xDataGetGameMode[GAMEMODE_PROP_MIN_PLAYERS] = get_param_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_ROUND_TIME: xDataGetGameMode[GAMEMODE_PROP_ROUND_TIME] = get_float_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_CHANGE_CLASS: xDataGetGameMode[GAMEMODE_PROP_CHANGE_CLASS] = bool:get_param_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_DEATHMATCH: xDataGetGameMode[GAMEMODE_PROP_DEATHMATCH] = eGameModeDeathMatchTypes:get_param_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_RESPAWN_TIME: xDataGetGameMode[GAMEMODE_PROP_RESPAWN_TIME] = get_float_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_FIND_NAME: get_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_FIND_NAME], charsmax(xDataGetGameMode[GAMEMODE_PROP_FIND_NAME]))
		default: return false
	}

	ArraySetArray(aDataGameMode, gamemode_id, xDataGetGameMode)
	
	return true
}

public _zpn_class_init(plugin_id, param_nums)
{
	if(param_nums != 2)
		return -1

	new xDataGetClass[ePropClasses]
	new index = (++xDataClassCount - 1)

	get_string(1, xDataGetClass[CLASS_PROP_NAME], charsmax(xDataGetClass[CLASS_PROP_NAME]))
	xDataGetClass[CLASS_PROP_TYPE] = eClassTypes:get_param(2)

	xDataGetClass[CLASS_PROP_CUSTOM_NAME] = EOS
	xDataGetClass[CLASS_PROP_INFO] = EOS
	xDataGetClass[CLASS_PROP_MODEL] = EOS
	xDataGetClass[CLASS_PROP_MODEL_VIEW] = EOS
	xDataGetClass[CLASS_PROP_BODY] = -1
	xDataGetClass[CLASS_PROP_HEALTH] = 100.0
	xDataGetClass[CLASS_PROP_ARMOR] = 0.0
	xDataGetClass[CLASS_PROP_SPEED] = 240.0
	xDataGetClass[CLASS_PROP_GRAVITY] = 1.0
	xDataGetClass[CLASS_PROP_KNOCKBACK] = 1.0
	xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST] = EOS
	xDataGetClass[CLASS_PROP_FIND_NAME] = EOS
	xDataGetClass[CLASS_PROP_NV_COLOR] = EOS
	xDataGetClass[CLASS_PROP_NV_COLOR_CONVERTED] = { 255, 255, 255 }
	xDataGetClass[CLASS_PROP_HIDE_MENU] = false
	xDataGetClass[CLASS_PROP_UPDATE_HITBOX] = false
	xDataGetClass[CLASS_PROP_BLOOD_COLOR] = -1
	xDataGetClass[CLASS_PROP_LIMIT] = 0
	xDataGetClass[CLASS_PROP_LEVEL] = 0

	ArrayPushArray(aDataClass, xDataGetClass)

	return index
}

public any:_zpn_class_get_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataClass))
		return false

	enum { arg_class_id = 1, arg_prop, arg_value, arg_len }

	new class_id = get_param(arg_class_id)
	new prop = get_param(arg_prop)

	new xDataGetClass[ePropClasses]
	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	switch(ePropClassRegisters:prop)
	{
		case CLASS_PROP_REGISTER_TYPE: return xDataGetClass[CLASS_PROP_TYPE]
		case CLASS_PROP_REGISTER_NAME: set_string(arg_value, xDataGetClass[CLASS_PROP_NAME], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_INFO: set_string(arg_value, xDataGetClass[CLASS_PROP_INFO], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_MODEL: set_string(arg_value, xDataGetClass[CLASS_PROP_MODEL], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_MODEL_VIEW: set_string(arg_value, xDataGetClass[CLASS_PROP_MODEL_VIEW], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_BODY: return xDataGetClass[CLASS_PROP_BODY]
		case CLASS_PROP_REGISTER_HEALTH: return xDataGetClass[CLASS_PROP_HEALTH]
		case CLASS_PROP_REGISTER_ARMOR: return xDataGetClass[CLASS_PROP_ARMOR]
		case CLASS_PROP_REGISTER_SPEED: return xDataGetClass[CLASS_PROP_SPEED]
		case CLASS_PROP_REGISTER_GRAVITY: return xDataGetClass[CLASS_PROP_GRAVITY]
		case CLASS_PROP_REGISTER_KNOCKBACK: return xDataGetClass[CLASS_PROP_KNOCKBACK]
		case CLASS_PROP_REGISTER_CLAW_WEAPONLIST: return set_string(arg_value, xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_SKIN: return xDataGetClass[CLASS_PROP_SKIN]
		case CLASS_PROP_REGISTER_FIND_NAME: set_string(arg_value, xDataGetClass[CLASS_PROP_FIND_NAME], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_NV_COLOR: set_string(arg_value, xDataGetClass[CLASS_PROP_NV_COLOR], get_param_byref(arg_len))
		case CLASS_PROP_REGISTER_HIDE_MENU: return bool:xDataGetClass[CLASS_PROP_HIDE_MENU]
		case CLASS_PROP_REGISTER_UPDATE_HITBOX: return bool:xDataGetClass[CLASS_PROP_UPDATE_HITBOX]
		case CLASS_PROP_REGISTER_BLOOD_COLOR: return xDataGetClass[CLASS_PROP_BLOOD_COLOR]
		case CLASS_PROP_REGISTER_SILENT_FOOTSTEPS: return bool:xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS]
		case CLASS_PROP_REGISTER_LIMIT: return xDataGetClass[CLASS_PROP_LIMIT]
		case CLASS_PROP_REGISTER_LEVEL: return xDataGetClass[CLASS_PROP_LEVEL]
		default: return false
	}

	return true
}

public any:_zpn_class_set_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataClass))
		return false

	enum { arg_class_id = 1, arg_prop, arg_value }

	new class_id = get_param(arg_class_id)
	new prop = get_param(arg_prop)

	new xDataGetClass[ePropClasses]
	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	static class_section[64]; class_section[0] = EOS
	static class_section_final[64]; class_section_final[0] = EOS

	copy(xDataGetClass[CLASS_PROP_CUSTOM_NAME], charsmax(xDataGetClass[CLASS_PROP_CUSTOM_NAME]), xDataGetClass[CLASS_PROP_NAME])
	create_slug(xDataGetClass[CLASS_PROP_NAME], class_section, charsmax(class_section))
	formatex(class_section_final, charsmax(class_section_final), "%s.%s", get_section_class(xDataGetClass[CLASS_PROP_TYPE]), class_section)

	if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "name", xDataGetClass[CLASS_PROP_CUSTOM_NAME], charsmax(xDataGetClass[CLASS_PROP_CUSTOM_NAME])))
		json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "name", xDataGetClass[CLASS_PROP_CUSTOM_NAME])

	switch(ePropClassRegisters:prop)
	{
		case CLASS_PROP_REGISTER_INFO:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_INFO], charsmax(xDataGetClass[CLASS_PROP_INFO]))

			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "description", xDataGetClass[CLASS_PROP_INFO], charsmax(xDataGetClass[CLASS_PROP_INFO])))
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "description", xDataGetClass[CLASS_PROP_INFO])
		}
		case CLASS_PROP_REGISTER_MODEL:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_MODEL], charsmax(xDataGetClass[CLASS_PROP_MODEL]))

			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "model", xDataGetClass[CLASS_PROP_MODEL], charsmax(xDataGetClass[CLASS_PROP_MODEL])))
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "model", xDataGetClass[CLASS_PROP_MODEL])

			if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_MODEL]))
				xDataGetClass[CLASS_PROP_MODEL_INDEX] = precache_player_model(xDataGetClass[CLASS_PROP_MODEL])
		}
		case CLASS_PROP_REGISTER_MODEL_VIEW:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_MODEL_VIEW], charsmax(xDataGetClass[CLASS_PROP_MODEL_VIEW]))

			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "model_view", xDataGetClass[CLASS_PROP_MODEL_VIEW], charsmax(xDataGetClass[CLASS_PROP_MODEL_VIEW])))
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "model_view", xDataGetClass[CLASS_PROP_MODEL_VIEW])

			if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_MODEL_VIEW]))
				precache_model(xDataGetClass[CLASS_PROP_MODEL_VIEW])
		}
		case CLASS_PROP_REGISTER_BODY:
		{
			xDataGetClass[CLASS_PROP_BODY] = get_param_byref(arg_value)

			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "body", xDataGetClass[CLASS_PROP_BODY], false))
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "body", xDataGetClass[CLASS_PROP_BODY], false)
		}
		case CLASS_PROP_REGISTER_SKIN:
		{
			xDataGetClass[CLASS_PROP_SKIN] = get_param_byref(arg_value)

			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "skin", xDataGetClass[CLASS_PROP_SKIN], false))
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "skin", xDataGetClass[CLASS_PROP_SKIN], false)
		}
		case CLASS_PROP_REGISTER_HEALTH:
		{
			xDataGetClass[CLASS_PROP_HEALTH] = get_float_byref(arg_value)
	
			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "health", xDataGetClass[CLASS_PROP_HEALTH]))
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "health", xDataGetClass[CLASS_PROP_HEALTH])
		}
		case CLASS_PROP_REGISTER_SPEED:
		{
			xDataGetClass[CLASS_PROP_SPEED] = get_float_byref(arg_value)

			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "speed", xDataGetClass[CLASS_PROP_SPEED]))
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "speed", xDataGetClass[CLASS_PROP_SPEED])
		}
		case CLASS_PROP_REGISTER_ARMOR:
		{
			xDataGetClass[CLASS_PROP_ARMOR] = get_float_byref(arg_value)

			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "armor", xDataGetClass[CLASS_PROP_ARMOR]))
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "armor", xDataGetClass[CLASS_PROP_ARMOR])
		}
		case CLASS_PROP_REGISTER_GRAVITY:
		{
			xDataGetClass[CLASS_PROP_GRAVITY] = get_float_byref(arg_value)

			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "gravity", xDataGetClass[CLASS_PROP_GRAVITY]))
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "gravity", xDataGetClass[CLASS_PROP_GRAVITY])
		}
		case CLASS_PROP_REGISTER_KNOCKBACK:
		{
			xDataGetClass[CLASS_PROP_KNOCKBACK] = get_float_byref(arg_value)

			if(!json_setting_get_float(PATH_SETTINGS_CLASSES, class_section_final, "knockback", xDataGetClass[CLASS_PROP_KNOCKBACK]))
				json_setting_set_float(PATH_SETTINGS_CLASSES, class_section_final, "knockback", xDataGetClass[CLASS_PROP_KNOCKBACK])
		}
		case CLASS_PROP_REGISTER_CLAW_WEAPONLIST:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST], charsmax(xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST]))

			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "claw_weapon_list", xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST], charsmax(xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST])))
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "claw_weapon_list", xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST])
		}
		case CLASS_PROP_REGISTER_FIND_NAME:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_FIND_NAME], charsmax(xDataGetClass[CLASS_PROP_FIND_NAME]))

			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "find_name", xDataGetClass[CLASS_PROP_FIND_NAME], charsmax(xDataGetClass[CLASS_PROP_FIND_NAME])))
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "find_name", xDataGetClass[CLASS_PROP_FIND_NAME])
		}
		case CLASS_PROP_REGISTER_NV_COLOR:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_NV_COLOR], charsmax(xDataGetClass[CLASS_PROP_NV_COLOR]))

			if(!json_setting_get_string(PATH_SETTINGS_CLASSES, class_section_final, "nv_color", xDataGetClass[CLASS_PROP_NV_COLOR], charsmax(xDataGetClass[CLASS_PROP_NV_COLOR])))
				json_setting_set_string(PATH_SETTINGS_CLASSES, class_section_final, "nv_color", xDataGetClass[CLASS_PROP_NV_COLOR])

			if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_NV_COLOR]))
				parse_hex_color(xDataGetClass[CLASS_PROP_NV_COLOR], xDataGetClass[CLASS_PROP_NV_COLOR_CONVERTED])
		}
		case CLASS_PROP_REGISTER_HIDE_MENU:
		{
			xDataGetClass[CLASS_PROP_HIDE_MENU] = bool:get_param_byref(arg_value)

			if(!json_setting_get_bool(PATH_SETTINGS_CLASSES, class_section_final, "hide_class_in_menu", xDataGetClass[CLASS_PROP_HIDE_MENU]))
				json_setting_set_bool(PATH_SETTINGS_CLASSES, class_section_final, "hide_class_in_menu", xDataGetClass[CLASS_PROP_HIDE_MENU])
		}
		case CLASS_PROP_REGISTER_UPDATE_HITBOX:
		{
			xDataGetClass[CLASS_PROP_UPDATE_HITBOX] = bool:get_param_byref(arg_value)

			if(!json_setting_get_bool(PATH_SETTINGS_CLASSES, class_section_final, "update_hitbox", xDataGetClass[CLASS_PROP_UPDATE_HITBOX]))
				json_setting_set_bool(PATH_SETTINGS_CLASSES, class_section_final, "update_hitbox", xDataGetClass[CLASS_PROP_UPDATE_HITBOX])
		}
		case CLASS_PROP_REGISTER_BLOOD_COLOR:
		{
			xDataGetClass[CLASS_PROP_BLOOD_COLOR] = get_param_byref(arg_value)

			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "blood_color", xDataGetClass[CLASS_PROP_BLOOD_COLOR], false))
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "blood_color", xDataGetClass[CLASS_PROP_BLOOD_COLOR], false)
		}
		case CLASS_PROP_REGISTER_SILENT_FOOTSTEPS:
		{
			xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS] = bool:get_param_byref(arg_value)

			if(!json_setting_get_bool(PATH_SETTINGS_CLASSES, class_section_final, "silent_footsteps", xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS]))
				json_setting_set_bool(PATH_SETTINGS_CLASSES, class_section_final, "silent_footsteps", xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS])
		}
		case CLASS_PROP_REGISTER_LIMIT:
		{
			xDataGetClass[CLASS_PROP_LIMIT] = clamp(get_param_byref(arg_value), 0, MAX_LEVEL)

			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "limit", xDataGetClass[CLASS_PROP_LIMIT], false))
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "limit", xDataGetClass[CLASS_PROP_LIMIT], false)
		}
		case CLASS_PROP_REGISTER_LEVEL:
		{
			xDataGetClass[CLASS_PROP_LEVEL] = clamp(get_param_byref(arg_value), 0, MAX_LEVEL)

			if(!json_setting_get_int(PATH_SETTINGS_CLASSES, class_section_final, "level", xDataGetClass[CLASS_PROP_LEVEL], false))
				json_setting_set_int(PATH_SETTINGS_CLASSES, class_section_final, "level", xDataGetClass[CLASS_PROP_LEVEL], false)
		}
		default: return false
	}

	ArraySetArray(aDataClass, class_id, xDataGetClass)

	return true
}

public precache_player_model(const modelname[])
{
	static longname[128], index
	formatex(longname, charsmax(longname), "models/player/%s/%s.mdl", modelname, modelname)
	index = precache_model(longname)

	copy(longname[strlen(longname)-4], charsmax(longname) - (strlen(longname)-4), "T.mdl")

	if(file_exists(longname))
		precache_model(longname)

	return index
}

public bool:set_user_zombie(this, infector, bool:set_first)
{
	if(zpn_is_invalid_array(aDataClass))
		return false

	if(!is_valid_player_alive(this))
		return false

	xFwIntParam[1] = -1
	xFwIntParam[2] = -1
	xFwIntParam[3] = -1

	new class_id = xUserData[this][UD_CURRENT_SELECTED_ZOMBIE_CLASS]

	ExecuteForward(xForwards[FW_INFECT_ATTEMPT], xForwardReturn, this, infector, class_id)

	if(xForwardReturn >= ZPN_RETURN_HANDLED)
		return false

	ExecuteForward(xForwards[FW_INFECTED_PRE], xForwardReturn, this, infector, class_id)

	if(xFwIntParam[1] != -1) this = xFwIntParam[1]
	if(xFwIntParam[2] != -1) infector = xFwIntParam[2]
	if(xFwIntParam[3] != -1) class_id = xFwIntParam[3]

	xUserData[this][UD_CURRENT_TEMP_ZOMBIE_CLASS] = class_id

	new xDataGetClass[ePropClasses]
	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	xUserData[this][UD_IS_ZOMBIE] = true
	xUserData[this][UD_IS_FIRST_ZOMBIE] = set_first

	rg_remove_item(this, "weapon_shield")
	rg_drop_items_by_slot(this, PRIMARY_WEAPON_SLOT)
	rg_drop_items_by_slot(this, PISTOL_SLOT)
	rg_remove_items_by_slot(this, GRENADE_SLOT)
	rg_give_item(this, "weapon_knife")

	if(xDataGetClass[CLASS_PROP_BLOOD_COLOR] != -1) set_member(this, m_bloodColor, clamp(xDataGetClass[CLASS_PROP_BLOOD_COLOR], 0, 255))
	if(xDataGetClass[CLASS_PROP_BODY] != -1) set_entvar(this, var_body, xDataGetClass[CLASS_PROP_BODY])
	if(xDataGetClass[CLASS_PROP_SKIN] != -1) set_entvar(this, var_skin, xDataGetClass[CLASS_PROP_SKIN])

	rg_set_user_team(this, TEAM_TERRORIST)
	rg_set_user_model(this, xDataGetClass[CLASS_PROP_MODEL], xDataGetClass[CLASS_PROP_UPDATE_HITBOX])

	if(xDataGetClass[CLASS_PROP_UPDATE_HITBOX])
	{
		set_member(this, m_modelIndexPlayer, xDataGetClass[CLASS_PROP_MODEL_INDEX])
		set_entvar(this, var_modelindex, xDataGetClass[CLASS_PROP_MODEL_INDEX])
	}
	else
	{
		set_member(this, m_modelIndexPlayer, defaultIndexPlayer)
		set_entvar(this, var_modelindex, defaultIndexPlayer)
	}

	set_entvar(this, var_health, xDataGetClass[CLASS_PROP_HEALTH])
	set_entvar(this, var_max_health, xDataGetClass[CLASS_PROP_HEALTH])
	set_entvar(this, var_gravity, xDataGetClass[CLASS_PROP_GRAVITY])
	set_entvar(this, var_armorvalue, floatround(xDataGetClass[CLASS_PROP_ARMOR]))
	set_entvar(this, var_maxspeed, xDataGetClass[CLASS_PROP_SPEED])
	rg_set_user_footsteps(this, xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS])
	deploy_weapon(this)

	make_deathmsg(infector, this, 0, "teammate")
	rg_set_score_attrib(this, false)

	ExecuteForward(xForwards[FW_INFECTED_POST], xForwardReturn, this, infector, class_id)

	return true
}

public set_user_human(this)
{
	if(zpn_is_invalid_array(aDataClass))
		return

	if(!is_valid_player_alive(this))
		return

	xFwIntParam[1] = -1
	xFwIntParam[2] = -1

	new class_id = xUserData[this][UD_CURRENT_SELECTED_HUMAN_CLASS]

	ExecuteForward(xForwards[FW_HUMANIZED_PRE], xForwardReturn, this, class_id)

	if(xFwIntParam[1] != -1) this = xFwIntParam[1]
	if(xFwIntParam[2] != -1) class_id = xFwIntParam[2]

	xUserData[this][UD_CURRENT_TEMP_HUMAN_CLASS] = class_id

	new xDataGetClass[ePropClasses]
	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	xUserData[this][UD_IS_ZOMBIE] = false
	xUserData[this][UD_IS_LAST_HUMAN] = false

	static model[64]; model[0] = EOS
	
	if(zpn_is_null_string(xDataGetClass[CLASS_PROP_MODEL]))
		copy(model, charsmax(model), xSettingsVars[CONFIG_DEFAULT_HUMAN_MODEL])
	else copy(model, charsmax(model), xDataGetClass[CLASS_PROP_MODEL])
	
	if(xDataGetClass[CLASS_PROP_BLOOD_COLOR] != -1) set_member(this, m_bloodColor, clamp(xDataGetClass[CLASS_PROP_BLOOD_COLOR], 0, 255))
	if(xDataGetClass[CLASS_PROP_BODY] != -1) set_entvar(this, var_body, xDataGetClass[CLASS_PROP_BODY])
	if(xDataGetClass[CLASS_PROP_SKIN] != -1) set_entvar(this, var_skin, xDataGetClass[CLASS_PROP_SKIN])

	rg_set_user_team(this, TEAM_CT)
	rg_set_user_model(this, model, xDataGetClass[CLASS_PROP_UPDATE_HITBOX])
	rg_set_user_footsteps(this, xDataGetClass[CLASS_PROP_SILENT_FOOTSTEPS])

	if(xDataGetClass[CLASS_PROP_UPDATE_HITBOX])
	{
		set_member(this, m_modelIndexPlayer, xDataGetClass[CLASS_PROP_MODEL_INDEX])
		set_entvar(this, var_modelindex, xDataGetClass[CLASS_PROP_MODEL_INDEX])
	}
	else
	{
		set_member(this, m_modelIndexPlayer, defaultIndexPlayer)
		set_entvar(this, var_modelindex, defaultIndexPlayer)
	}
	
	rg_set_score_attrib(this, false)

	new armor = 0

	if(xDataGetClass[CLASS_PROP_ARMOR] > 0)
		armor = floatround(xDataGetClass[CLASS_PROP_ARMOR])

	set_entvar(this, var_health, xDataGetClass[CLASS_PROP_HEALTH])
	set_entvar(this, var_max_health, xDataGetClass[CLASS_PROP_HEALTH])
	set_entvar(this, var_gravity, xDataGetClass[CLASS_PROP_GRAVITY])
	set_entvar(this, var_armorvalue, armor)
	set_entvar(this, var_maxspeed, xDataGetClass[CLASS_PROP_SPEED])

	ExecuteForward(xForwards[FW_HUMANIZED_POST], xForwardReturn, this, class_id)
}

public set_user_frozen(this, Float:time, bool:reset_time)
{
	new Float:vecVelocity[3]
	get_entvar(this, var_velocity, vecVelocity)

	for(new i = 0; i < 3; i++)
		vecVelocity[i] *= 0.5

	xUserData[this][UD_IS_FREEZED] = true

	set_entvar(this, var_velocity, vecVelocity)
	set_entvar(this, var_iuser3, get_entvar(this, var_iuser3) | PLAYER_PREVENT_JUMP)
	set_member(this, m_bIsDefusing, true)
	rg_reset_maxspeed(this)

	if(reset_time && task_exists(this + TASK_FROZEN))
		remove_task(this + TASK_FROZEN)
	
	if(!task_exists(this + TASK_FROZEN))
		set_task_ex(floatclamp(time, 0.1, 60.0), "remove_user_frozen", this + TASK_FROZEN)
}

public remove_user_frozen(this)
{
	this -= TASK_FROZEN

	if(!is_user_connected(this)) { remove_task(this + TASK_FROZEN); return; }

	xUserData[this][UD_IS_FREEZED] = false

	set_entvar(this, var_iuser3, get_entvar(this, var_iuser3) & ~PLAYER_PREVENT_JUMP)
	set_member(this, m_bIsDefusing, false)
	rg_reset_maxspeed(this)

	if(task_exists(this + TASK_FROZEN))
		remove_task(this + TASK_FROZEN)
}

public set_user_nv(id)
{
	static Float:o[3]; get_entvar(id, var_origin, o)
	static rgb[3]
	
	rgb[0] = 0; rgb[1] = 0; rgb[2] = 0
	get_user_nv_color(id, rgb)

	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, .player = id)
	write_byte(TE_DLIGHT)
	write_coord_f(o[0])
	write_coord_f(o[1])
	write_coord_f(o[2])
	write_byte(40) // radius
	write_byte(rgb[0])
	write_byte(rgb[1])
	write_byte(rgb[2])
	write_byte(1) // life
	write_byte(0) // decay
	message_end()
}

get_user_nv_color(id, outRgb[3])
{
	static class_id; class_id = xUserData[id][UD_IS_ZOMBIE] ? xUserData[id][UD_CURRENT_SELECTED_ZOMBIE_CLASS] : xUserData[id][UD_CURRENT_SELECTED_HUMAN_CLASS]
	static xDataGetClass[ePropClasses]
	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_NV_COLOR]))
	{
		outRgb[0] = xDataGetClass[CLASS_PROP_NV_COLOR_CONVERTED][0]
		outRgb[1] = xDataGetClass[CLASS_PROP_NV_COLOR_CONVERTED][1]
		outRgb[2] = xDataGetClass[CLASS_PROP_NV_COLOR_CONVERTED][2]
	}
	else
	{
		outRgb[0] = xUserData[id][UD_IS_ZOMBIE] ? xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][0] : xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][0]
		outRgb[1] = xUserData[id][UD_IS_ZOMBIE] ? xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][1] : xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][1]
		outRgb[2] = xUserData[id][UD_IS_ZOMBIE] ? xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][2] : xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][2]
	}
}

get_user_speed(const this)
{
	static Float:velocity[3]; get_entvar(this, var_velocity, velocity)
	return floatround(vector_length(velocity))
}

get_gamemode_name()
{
	static gm[64]; gm[0] = EOS

	new xDataGetGameMode[ePropGameModes]
	ArrayGetArray(aDataGameMode, xDataGetGameRule[GAME_RULE_LAST_GAMEMODE], xDataGetGameMode)

	if(!xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED])
		copy(gm, charsmax(gm), "--")
	else if(zpn_is_null_string(xDataGetGameMode[GAMEMODE_PROP_NAME]))
		copy(gm, charsmax(gm), "--")
	else copy(gm, charsmax(gm), xDataGetGameMode[GAMEMODE_PROP_NAME])

	return gm
}

get_class_name(const this)
{
	static class[64], class_id

	if(xUserData[this][UD_IS_ZOMBIE])
		class_id = xUserData[this][UD_CURRENT_TEMP_ZOMBIE_CLASS] != -1 ? xUserData[this][UD_CURRENT_TEMP_ZOMBIE_CLASS] : xUserData[this][UD_CURRENT_SELECTED_ZOMBIE_CLASS]
	else class_id = xUserData[this][UD_CURRENT_TEMP_HUMAN_CLASS] != -1 ? xUserData[this][UD_CURRENT_TEMP_HUMAN_CLASS] : xUserData[this][UD_CURRENT_SELECTED_HUMAN_CLASS]
	
	new xDataGetClass[ePropClasses]
	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	if(zpn_is_null_string(xDataGetClass[CLASS_PROP_CUSTOM_NAME]))
		copy(class, charsmax(class), "--")
	else copy(class, charsmax(class), xDataGetClass[CLASS_PROP_CUSTOM_NAME])

	return class
}

get_first_class(eClassTypes:class_type)
{
	new class_id = 0
	new xDataGetClass[ePropClasses]

	for(new i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)

		if(xDataGetClass[CLASS_PROP_TYPE] == class_type)
		{
			class_id = i
			break
		}
	}

	return class_id
}

get_first_human_id()
{
	new index = -1

	for(new id = 1; id <= MaxClients; id++)
	{
		if(is_user_alive(id) && !xUserData[id][UD_IS_ZOMBIE])
		{
			index = id
			break
		}
	}

	return index
}

get_num_alive(bool:zombies = false)
{
	static c, id
	c = 0
	id = 0

	for(id = 1; id <= MaxClients; id++) if(is_user_alive(id) && (zombies ? xUserData[id][UD_IS_ZOMBIE] : !xUserData[id][UD_IS_ZOMBIE])) c++
	return c
}

deploy_weapon(const this)
{
	new activeItem = get_member(this, m_pActiveItem)
	if(!is_nullent(activeItem)) ExecuteHamB(Ham_Item_Deploy, activeItem)
}

update_prefix_color(string[], len, bool:menu = false)
{
	if(menu)
	{
		replace_string(string, len, "!y", "\y")
		replace_string(string, len, "!d", "\d")
		replace_string(string, len, "!r", "\r")
		replace_string(string, len, "!w", "\w")
	}
	else
	{
		replace_string(string, len, "!y", "^1")
		replace_string(string, len, "!t", "^3")
		replace_string(string, len, "!g", "^4")
	}
}

format_number_point(const number)
{
	static count, i, str[32], str2[32], len
	count = 0; len = 0; i = 0; str[0] = EOS; str2[0] = EOS;

	num_to_str(number, str, charsmax(str))
	len = strlen(str)

	for(i = 0; i < len; i++)
	{
		if(i != 0 && ((len - i) %3 == 0))
		{
			add(str2, charsmax(str2), ".", 1)
			count++
			add(str2[i+count], 1, str[i], 1)
		}
		else add(str2[i+count], 1, str[i], 1)
	}
	
	return str2
}

check_game()
{
	if(get_num_alive(true) <= 0 && xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED])
		rg_round_end(2.0, WINSTATUS_DRAW, ROUND_GAME_RESTART, .trigger = true)
}

count_item(eItemTeams:item_team)
{
	new count = 0
	new xDataGetItem[ePropItems]

	for(new i = 0; i < ArraySize(aDataItem); i++)
	{
		ArrayGetArray(aDataItem, i, xDataGetItem)
		if(xDataGetItem[ITEM_PROP_TEAM] == item_team) count ++;
	}

	return count
}

count_class(eClassTypes:class_type)
{
	new count = 0
	new xDataGetClass[ePropClasses]

	for(new i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)
		if(xDataGetClass[CLASS_PROP_TYPE] == class_type) count ++;
	}

	return count
}

get_section_class(eClassTypes:type)
{
	static section[64]; section[0] = EOS

	switch(type)
	{
		case CLASS_TEAM_TYPE_ZOMBIE: copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_ZOMBIE)
		case CLASS_TEAM_TYPE_ZOMBIE_SPECIAL: copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_ZOMBIE_SP)
		case CLASS_TEAM_TYPE_HUMAN: copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_HUMAN)
		case CLASS_TEAM_TYPE_HUMAN_SPECIAL: copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_HUMAN_SP)
		default: copy(section, charsmax(section), SETTINGS_SECTION_CLASSES_ZOMBIE)
	}

	return section
}

get_current_class_index(id, eClassTypes:type, bool:check_temp = false)
{
	static class_type; class_type = 0

	switch(type)
	{
		case CLASS_TEAM_TYPE_ZOMBIE: class_type = check_temp ? UD_CURRENT_TEMP_ZOMBIE_CLASS : UD_CURRENT_SELECTED_ZOMBIE_CLASS
		case CLASS_TEAM_TYPE_HUMAN: class_type = check_temp ? UD_CURRENT_TEMP_HUMAN_CLASS : UD_CURRENT_SELECTED_HUMAN_CLASS
		default: class_type = UD_CURRENT_SELECTED_ZOMBIE_CLASS
	}
	
	return xUserData[id][class_type]
}

random_gamemode()
{
	new gm = -1, i
	new totalChance = 0
	new xDataGetGameMode[ePropGameModes]

	for(i = 0; i < ArraySize(aDataGameMode); i++)
	{
		ArrayGetArray(aDataGameMode, i, xDataGetGameMode)
		totalChance += xDataGetGameMode[GAMEMODE_PROP_CHANCE]
	}

	new randomNumber = random_num(1, totalChance)
	new accumulatedChance = 0

	for(i = 0; i < ArraySize(aDataGameMode); i++)
	{
		ArrayGetArray(aDataGameMode, i, xDataGetGameMode)
		accumulatedChance += xDataGetGameMode[GAMEMODE_PROP_CHANCE]

		if(randomNumber <= accumulatedChance)
			gm = i

		if(gm != -1)
			break
	}

	return gm
}

get_classes_index()
{
	new xDataGetClass[ePropClasses]
	for(new i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)

		if(xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_ZOMBIE)
			ArrayPushCell(aIndexClassesZombies, i)
		else if(xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_HUMAN)
			ArrayPushCell(aIndexClassesHumans, i)
	}
}

update_users_next_class()
{
	for(new id = 1; id <= MaxClients; id++)
	{
		if(!is_user_connected(id))
			continue

		// estou com duvida nisso
		xUserData[id][UD_CURRENT_TEMP_ZOMBIE_CLASS] = -1
		xUserData[id][UD_CURRENT_TEMP_HUMAN_CLASS] = -1

		if(xUserData[id][UD_NEXT_ZOMBIE_CLASS] != -1)
		{
			xUserData[id][UD_CURRENT_SELECTED_ZOMBIE_CLASS] = xUserData[id][UD_NEXT_ZOMBIE_CLASS]
			xUserData[id][UD_NEXT_ZOMBIE_CLASS] = -1
		}

		if(xUserData[id][UD_NEXT_HUMAN_CLASS] != -1)
		{
			xUserData[id][UD_CURRENT_SELECTED_HUMAN_CLASS] = xUserData[id][UD_NEXT_HUMAN_CLASS]
			xUserData[id][UD_NEXT_HUMAN_CLASS] = -1
		}
	}
}

rg_set_score_attrib(this, bool:dead = false)
{
	message_begin(MSG_BROADCAST, xMsgScoreAttrib)
	write_byte(this)
	write_byte(dead ? 1 : 0)
	message_end()
}

bool:parse_hex_color(const hexColor[], rgb[3])
{
	if (hexColor[0] != '#' || strlen(hexColor) != 7)
	return false

	for (new i = 0; i < 3; i++)
		rgb[i] = (__parse_hex_color(hexColor[1 + i * 2]) * 16 + __parse_hex_color(hexColor[2 + i * 2]))

	return true
}

__parse_hex_color(const c)
{
	return (c >= '0' && c <= '9') ? (c - '0') : (c >= 'a' && c <= 'f') ? (10 + c - 'a') : (c >= 'A' && c <= 'F') ? (10 + c - 'A') : 0
}

stock create_slug(const input[], output[], maxlen)
{
	new Regex:rx_slug = regex_compile("[^^a-z0-9]+|^^-+|-+$|[áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ]")
	new replaced[256]

	copy(replaced, charsmax(replaced), input)
	strtolower(replaced)

	regex_replace(rx_slug, replaced, charsmax(replaced), "-")
	copy(output, maxlen, replaced)

	regex_free(rx_slug)

	return strlen(output)
A') : 0
