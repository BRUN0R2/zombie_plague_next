#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <api_json_settings>
#include <zombie_plague_next_const>

#define is_valid_player_alive(%1) (1 <= %1 <= MaxClients && is_user_alive(%1) && is_user_connected(%1))
#define is_valid_player_connected(%1) (1 <= %1 <= MaxClients && is_user_connected(%1))
#define is_valid_player(%1) (1 <= %1 <= MaxClients)

enum
{
	TASK_COUNTDOWN = 1515,
	TASK_HUD_PLAYER_INFO,
	TASK_RESPAWN,
	TASK_NV,
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
}

enum _:eForwards
{
	FW_ROUND_STARTED_POST,
}

enum _:eSettingsConfigs
{
	CONFIG_DEBUG_ON,
	CONFIG_ZOMBIE_ESCAPE_ON,
	CONFIG_DEFAULT_HUMAN_MODEL[32],
	CONFIG_PREFIX_MENUS[32],
	CONFIG_PREFIX_CHAT[32],
}

enum _:ePropsClass
{
	eClassesType:CLASS_PROP_TYPE,
	CLASS_PROP_NAME[64],
	CLASS_PROP_INFO[64],
	CLASS_PROP_MODEL[64],
	CLASS_PROP_MODEL_VIEW[64],
	CLASS_PROP_BODY,
	Float:CLASS_PROP_HEALTH,
	Float:CLASS_PROP_ARMOR,
	Float:CLASS_PROP_SPEED,
	Float:CLASS_PROP_GRAVITY,
	Float:CLASS_PROP_KNOCKBACK,
	CLASS_PROP_CLAW_WEAPONLIST[64],
}

enum _:ePropsGameMode
{
	GAMEMODE_PROP_NAME[32],
	GAMEMODE_PROP_NOTICE[64],
	GAMEMODE_PROP_HUD_COLOR[3],
	GAMEMODE_PROP_CHANCE,
	GAMEMODE_PROP_MIN_PLAYERS,
	Float:GAMEMODE_PROP_ROUND_TIME,
	bool:GAMEMODE_PROP_CHANGE_CLASS,
	eGameModeDeathMatchType:GAMEMODE_PROP_DEATHMATCH,
	Float:GAMEMODE_PROP_RESPAWN_TIME,
}

enum _:eGameRule
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
}

enum _:eUserData
{
	bool:UD_HAS_SELECTED_ZOMBIE_CLASS,
	bool:UD_HAS_SELECTED_HUMAN_CLASS,
	UD_CURRENT_ZOMBIE_CLASS,
	UD_CURRENT_HUMAN_CLASS,
	bool:UD_IS_ZOMBIE,
	bool:UD_IS_FIRST_ZOMBIE,
	UD_PRIMARY_WEAPON,
	UD_SECONDARY_WEAPON,
	Float:UD_CLASS_TIMEOUT,
	Float:UD_LAST_LEAP_TIMEOUT,
	bool:UD_IS_LAST_HUMAN,
	bool:UD_NV_ON,
	Float:UD_NV_SPAM,
}

enum _:eSyncHuds
{
	SYNC_HUD_MAIN,
	SYNC_HUD_PLAYER_INFO
}

new const CS_SOUNDS[][] = { "items/flashlight1.wav", "items/9mmclip1.wav", "player/bhit_helmet-1.wav" };

new xFwSpawn_Pre
new xCvars[eCvars], xSettingsVars[eSettingsConfigs], xMsgSync[eSyncHuds], xUserData[33][eUserData]
new any:xDataGetClass[ePropsClass], any:xDataGetGameMode[ePropsGameMode], any:xDataGetGameRule[eGameRule]

new xDataClassCount, xDataGameModeCount, xFirstClass[2], xClassCount[2]
new Array:aDataClass, Array:aDataGameMode
new xForwards[eForwards], xForwardReturn

public plugin_init()
{
	register_plugin("Zombie Plague Next", "1.0", "Wilian M.")
	register_dictionary("common.txt")

	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false)
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", true)
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "CSGameRules_OnRoundFreezeEnd_Pre", false)
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "CBasePlayerWeapon_DefaultDeploy_Pre", false)
	RegisterHookChain(RG_RoundEnd, "RoundEnd_Pre", false)
	RegisterHookChain(RG_CBasePlayer_TraceAttack, "CBasePlayer_TraceAttack_Pre", false)
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre", false)
	RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "CBasePlayer_ResetMaxSpeed_Pre", false)
	RegisterHookChain(RG_CBasePlayer_HasRestrictItem, "RCBasePlayer_HasRestrictItem_Pre", false)
	RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink", false)
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true)
	RegisterHookChain(RG_CBasePlayer_HintMessageEx, "CBasePlayer_HintMessageEx_Pre", false)
	
	register_clcmd("nightvision", "clcmd_nightvision")

	for(new i = 0; i < eSyncHuds; i++)
		xMsgSync[i] = CreateHudSyncObj()

	if(zpn_is_invalid_array(aDataClass))
		set_fail_state("[ZP NEXT] No Classes Founds")

	if(zpn_is_invalid_array(aDataGameMode))
		set_fail_state("[ZP NEXT] No GameModes Founds")

	// FWS
	xForwards[FW_ROUND_STARTED_POST] = CreateMultiForward("zpn_round_started_post", ET_IGNORE, FP_CELL)

	xFirstClass[0] = get_first_class(CLASS_TEAM_TYPE_ZOMBIE)
	xFirstClass[1] = get_first_class(CLASS_TEAM_TYPE_HUMAN)

	xClassCount[0] = count_class(CLASS_TEAM_TYPE_ZOMBIE)
	xClassCount[1] = count_class(CLASS_TEAM_TYPE_HUMAN)

	register_clcmd("chooseteam", "clcmd_changeteam")
	register_clcmd("jointeam", "clcmd_changeteam")

	if (xFwSpawn_Pre)
		unregister_forward(FM_Spawn, xFwSpawn_Pre, false)

	if(xSettingsVars[CONFIG_DEBUG_ON])
	{
		server_print("^n")
		server_print("Classes loaded:")
		new i, text[128]
		
		for(i = 0; i < ArraySize(aDataClass); i++)
		{
			ArrayGetArray(aDataClass, i, xDataGetClass)
			
			text[0] = EOS
			
			add(text, charsmax(text), fmt("Class: %s | ", xDataGetClass[CLASS_PROP_NAME]))
			add(text, charsmax(text), fmt("Info: %s | ", xDataGetClass[CLASS_PROP_INFO]))
			add(text, charsmax(text), fmt("Type: %s | ", xDataGetClass[CLASS_PROP_TYPE] == CLASS_TEAM_TYPE_ZOMBIE ? "Zombie" : "Human"))
			add(text, charsmax(text), fmt("Model: %s | ", xDataGetClass[CLASS_PROP_MODEL]))
			add(text, charsmax(text), fmt("Model View: %s", xDataGetClass[CLASS_PROP_MODEL_VIEW] == EOS ? "--" : fmt("%s", xDataGetClass[CLASS_PROP_MODEL_VIEW])))
			server_print(text)
		}

		server_print("^n")
		server_print("GameModes loaded:")
		
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
	}

	return true
}

public clcmd_nightvision(id)
{
	xUserData[id][UD_NV_ON] = !xUserData[id][UD_NV_ON]
	return PLUGIN_HANDLED
}

public CBasePlayer_HintMessageEx_Pre(const id, const message[], Float:duration, bool:bDisplayIfPlayerDead, bool:bOverride)
{
	SetHookChainReturn(ATYPE_BOOL, false)

	return HC_SUPERCEDE
}

public CBasePlayer_Killed_Post(const this, pevAttacker, iGib)
{
	ArrayGetArray(aDataGameMode, xDataGetGameRule[GAME_RULE_CURRENT_GAMEMODE], xDataGetGameMode)

	if(xUserData[this][UD_IS_ZOMBIE] && xDataGetGameMode[GAMEMODE_PROP_DEATHMATCH] == GAMEMODE_DEATHMATCH_ONLY_TR)
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
	if(!is_valid_player_alive(this) || is_user_bot(this))
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

public CBasePlayer_TakeDamage_Pre(const this, pevInflictor, pevAttacker, Float:flDamage, bitsDamageType)
{
	if(this == pevAttacker || !is_valid_player_alive(pevAttacker) || !is_valid_player_alive(this))
		return HC_CONTINUE

	if(xUserData[pevAttacker][UD_IS_ZOMBIE] && !xUserData[this][UD_IS_ZOMBIE])
	{
		if(get_num_alive() == 1 && !xCvars[CVAR_LAST_HUMAN_INFECT])
			return HC_CONTINUE

		static Float:armor
		get_entvar(this, var_armorvalue, armor)

		if(armor > 0.0)
		{
			emit_sound(this, CHAN_BODY, CS_SOUNDS[2], 1.0, 0.5, 0, PITCH_NORM)
			
			if(armor - flDamage > 0.0)
				set_entvar(this, var_armorvalue, armor - flDamage)
			else rg_set_user_armor(this, 0, ARMOR_NONE)

			SetHookChainReturn(ATYPE_INTEGER, 0)
			return HC_SUPERCEDE
		}

		set_user_zombie(this, pevAttacker, false)

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

	new classTeam = xUserData[this][UD_IS_ZOMBIE] ? xUserData[this][UD_CURRENT_ZOMBIE_CLASS] : xUserData[this][UD_CURRENT_HUMAN_CLASS]
	ArrayGetArray(aDataClass, classTeam, xDataGetClass)

	new Float:speed = xDataGetClass[CLASS_PROP_SPEED]
	new activeItem = get_member(this, m_pActiveItem)

	if(!is_nullent(activeItem) && xCvars[CVAR_WEAPON_WEIGHT_DISCOUNT_SPEED])
		speed -= float(rg_get_iteminfo(activeItem, ItemInfo_iWeight)) // descontar o peso da arma na velocidade da 'classe'

	set_entvar(this, var_maxspeed, speed)

	return HC_SUPERCEDE
}

public clcmd_changeteam(id)
{
	new any:team = get_member(id, m_iTeam)

	if(team == TEAM_SPECTATOR || team == TEAM_UNASSIGNED)
		return PLUGIN_CONTINUE

	show_menu_game(id)

	return PLUGIN_HANDLED
}

public client_putinserver(id)
{
	reset_user_vars(id)
	set_task_ex(0.1, "xHudPlayerInfo", id + TASK_HUD_PLAYER_INFO, .flags = SetTask_Repeat)

	// add quando jogador seleciona time tmb
	check_game()
}

check_game()
{
	if(get_num_alive(true) <= 1 && xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED])
		rg_round_end(2.0, WINSTATUS_DRAW, ROUND_GAME_RESTART, .trigger = true)
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

	add(txt, charsmax(txt), fmt("» Ammo Packs: 0^n"))
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
	new eClassesType:class_type = eClassesType:str_to_num(info)

	if(count_class(class_type) <= 0)
	{
		client_print_color(id, print_team_red, "%s ^3Nenhuma classe encontrada.", xSettingsVars[CONFIG_PREFIX_CHAT])
		select_class_type(id)
		return
	}

	new user_class

	switch(class_type)
	{
		case CLASS_TEAM_TYPE_ZOMBIE: user_class = UD_CURRENT_ZOMBIE_CLASS;
		case CLASS_TEAM_TYPE_HUMAN: user_class = UD_CURRENT_HUMAN_CLASS;
		default: user_class = UD_CURRENT_ZOMBIE_CLASS;
	}

	new xMenu = menu_create(fmt("%s \ySelecionar classe: %s", xSettingsVars[CONFIG_PREFIX_MENUS], class_type == CLASS_TEAM_TYPE_ZOMBIE ? "\rZombie" : "\yHumano"), "_select_class")

	for(new i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)

		if(xDataGetClass[CLASS_PROP_TYPE] == class_type)
			menu_additem(xMenu, fmt("\w%s \y(\d%s\y)%s", xDataGetClass[CLASS_PROP_NAME], xDataGetClass[CLASS_PROP_INFO], i == xUserData[id][user_class] ? " \r*" : ""), fmt("%d", i))
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
		case CLASS_TEAM_TYPE_ZOMBIE:
		{
			xUserData[id][UD_CURRENT_ZOMBIE_CLASS] = class_id

			if(xCvars[CVAR_CLASS_SELECT_INSTANT])
				set_user_zombie(id, 0, false)
		}

		case CLASS_TEAM_TYPE_HUMAN:
		{
			xUserData[id][UD_CURRENT_HUMAN_CLASS] = class_id

			if(xCvars[CVAR_CLASS_SELECT_INSTANT])
				set_user_human(id, 0)
		}
	}

	client_print_color(id, print_team_default, "%s ^3Vida: ^1%s ^4- ^3Gravidade: ^1%d ^4- ^3Velocidade: ^1%0.0f", xSettingsVars[CONFIG_PREFIX_CHAT], format_number_point(floatround(xDataGetClass[CLASS_PROP_HEALTH])), floatround(xDataGetClass[CLASS_PROP_GRAVITY] * 800.0), xDataGetClass[CLASS_PROP_SPEED])
}

public reset_user_vars(id)
{
	xUserData[id][UD_IS_ZOMBIE] = false
	xUserData[id][UD_IS_FIRST_ZOMBIE] = false
	xUserData[id][UD_HAS_SELECTED_ZOMBIE_CLASS] = false
	xUserData[id][UD_HAS_SELECTED_HUMAN_CLASS] = false
	xUserData[id][UD_CURRENT_ZOMBIE_CLASS] = xFirstClass[0]
	xUserData[id][UD_CURRENT_HUMAN_CLASS] = xFirstClass[1]
	xUserData[id][UD_PRIMARY_WEAPON] = -1
	xUserData[id][UD_SECONDARY_WEAPON] = -1
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
	}

	xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED] = false

	if(zpn_is_invalid_array(aDataGameMode))
		xDataGetGameRule[GAME_RULE_CURRENT_GAMEMODE] = -1
	else xDataGetGameRule[GAME_RULE_CURRENT_GAMEMODE] = 0

	if(xSettingsVars[CONFIG_DEBUG_ON])
		server_print("RoundEnd_Pre: %d - %d - %f", status, event, delay)
}

public CBasePlayerWeapon_DefaultDeploy_Pre(const ent, szViewModel[], szWeaponModel[], iAnim, szAnimExt[], skiplocal)
{
	if(is_nullent(ent))
		return

	new id = get_member(ent, m_pPlayer)
	
	if(xUserData[id][UD_IS_ZOMBIE])
	{
		ArrayGetArray(aDataClass, xUserData[id][UD_CURRENT_ZOMBIE_CLASS], xDataGetClass)
		SetHookChainArg(2, ATYPE_STRING, xDataGetClass[CLASS_PROP_MODEL_VIEW])
		SetHookChainArg(3, ATYPE_STRING, "")
	}
}

public CBasePlayer_Spawn_Post(id)
{
	if(!is_valid_player_alive(id))
		return

	new TeamName:team = get_member(id, m_iTeam)

	if(team != TEAM_TERRORIST && team != TEAM_CT)
		return
	
	if(xSettingsVars[CONFIG_DEBUG_ON])
	{
		if(xUserData[id][UD_IS_ZOMBIE])
			server_print("CBasePlayer_Spawn_Post(id): %n - é zombie", id)

		server_print("CBasePlayer_Spawn_Post(id): %n", id)
	}

	if(!xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED])
	{
		set_user_human(id, 0)
		deploy_weapon(id)

		if(xSettingsVars[CONFIG_DEBUG_ON])
		{
			server_print("^n")
			server_print("!xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED] ")
		}
	}
	else
	{
		if(xUserData[id][UD_IS_ZOMBIE])
			set_user_zombie(id, 0, false)
	}

	if(xUserData[id][UD_PRIMARY_WEAPON] == -1 && !xUserData[id][UD_IS_ZOMBIE])
		select_primary_weapon(id)
	else if(xUserData[id][UD_PRIMARY_WEAPON] != -1)
	{
		get_selected_weapon(id, xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS], xUserData[id][UD_PRIMARY_WEAPON], PRIMARY_WEAPON_SLOT)

		if(xUserData[id][UD_PRIMARY_WEAPON] != -1)
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

	if(xSettingsVars[CONFIG_DEBUG_ON])
	{
		server_print("^n")
		server_print("CSGameRules_RestartRound_Pre")
		server_print("^n")
	}
}

public CSGameRules_RestartRound_Post()
{
	
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
	new gm = random_gamemode()

	if(gm == -1) gm = 0

	ArrayGetArray(aDataGameMode, gm, xDataGetGameMode)

	// se n tiver jogadores, sempre usar gamemode 0 (o primeiro da lista)
	if(xDataGetGameMode[GAMEMODE_PROP_MIN_PLAYERS] < get_num_alive())
		gm = 0

	xDataGetGameRule[GAME_RULE_LAST_GAMEMODE] = gm
	xDataGetGameRule[GAME_RULE_CURRENT_GAMEMODE] = gm
	xDataGetGameRule[GAME_RULE_IS_ROUND_STARTED] = true

	set_hudmessage(0, 255, 255, -1.0, 0.20, 2, 0.3, 3.0, 0.06, 0.06, -1, 0, { 100, 100, 200, 100 })
	ShowSyncHudMsg(0, xMsgSync[SYNC_HUD_MAIN], "%s", xDataGetGameMode[GAMEMODE_PROP_NOTICE])

	ExecuteForward(xForwards[FW_ROUND_STARTED_POST], xForwardReturn, gm)
}

public plugin_precache()
{
	new i
	for(i = 0; i < sizeof(CS_SOUNDS); i++) engfunc(EngFunc_PrecacheSound, CS_SOUNDS[i])

	aDataClass = ArrayCreate(ePropsClass)
	aDataGameMode = ArrayCreate(ePropsGameMode)

	bind_pcvar_num(create_cvar("zpn_delay", "15", .has_min = true, .min_val = 1.0), xCvars[CVAR_START_DELAY])
	bind_pcvar_num(create_cvar("zpn_class_select_instant", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_CLASS_SELECT_INSTANT])
	bind_pcvar_float(create_cvar("zpn_class_select_instant_timeout", "30", .has_min = true, .min_val = 10.0, .has_max = true, .max_val = 500.0), xCvars[CVAR_CLASS_SELECT_INSTANT_TIMEOUT])
	bind_pcvar_num(create_cvar("zpn_last_human_infect", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_LAST_HUMAN_INFECT])
	bind_pcvar_num(create_cvar("zpn_weapon_weight_discount_speed", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_WEAPON_WEIGHT_DISCOUNT_SPEED])
	//bind_pcvar_num(create_cvar("zpn_respawn_in_last_human", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0), xCvars[CVAR_RESPAWN_IN_LAST_H])
	bind_pcvar_string(create_cvar("zpn_default_nv_h", "#00bbff", .flags = FCVAR_NOEXTRAWHITEPACE), xCvars[CVAR_DEFAULT_NV_H], charsmax(xCvars[CVAR_DEFAULT_NV_H]))
	bind_pcvar_string(create_cvar("zpn_default_nv_z", "#27e30e", .flags = FCVAR_NOEXTRAWHITEPACE), xCvars[CVAR_DEFAULT_NV_Z], charsmax(xCvars[CVAR_DEFAULT_NV_Z]))

	new bool:parse_nv
	parse_nv = parse_hex_color(xCvars[CVAR_DEFAULT_NV_H], xDataGetGameRule[GAME_RULE_DEFAULT_NV_H])

	if(!parse_nv)
	{
		xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][0] = xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][1] = 0
		xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][2] = 100
	}

	server_print("Parse Color H: %d %d %d - %s", xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][0], xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][1], xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][2], xCvars[CVAR_DEFAULT_NV_H])

	parse_nv = parse_hex_color(xCvars[CVAR_DEFAULT_NV_Z], xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z])

	if(!parse_nv)
	{
		xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][0] = 100
		xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][1] = xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][2] = 0
	}

	server_print("Parse Color Z: %d %d %d - %s", xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][0], xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][1], xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][2], xCvars[CVAR_DEFAULT_NV_Z])

	if(!json_setting_get_int(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Enable Debug", xSettingsVars[CONFIG_DEBUG_ON]))
	{
		xSettingsVars[CONFIG_DEBUG_ON] = 1
		json_setting_set_int(PATH_SETTINGS_CONFIG, SETTINGS_SECTION_CONFIG, "Enable Debug", 1)
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
	ArrayDestroy(xDataGetGameRule[GAME_RULE_USELESS_ENTITIES])
	ArrayDestroy(xDataGetGameRule[GAME_RULE_PRIMARY_WEAPONS])
	ArrayDestroy(xDataGetGameRule[GAME_RULE_SECONDARY_WEAPONS])
}

public plugin_natives()
{
	register_library("zombie_plague_next")

	register_native("zpn_class_init", "_zpn_class_init")
	register_native("zpn_class_get_prop", "_zpn_class_get_prop")
	register_native("zpn_class_set_prop", "_zpn_class_set_prop")

	register_native("zpn_gamemode_init", "_zpn_gamemode_init")
	register_native("zpn_gamemode_get_prop", "_zpn_gamemode_get_prop")
	register_native("zpn_gamemode_set_prop", "_zpn_gamemode_set_prop")

	register_native("zpn_set_user_zombie", "_zpn_set_user_zombie")
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

public _zpn_gamemode_init(plugin_id, param_nums)
{
	new key = (++xDataGameModeCount - 1)

	xDataGetGameMode[GAMEMODE_PROP_NAME] = EOS
	xDataGetGameMode[GAMEMODE_PROP_NOTICE] = EOS
	xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR] = { 255, 255, 255 }
	xDataGetGameMode[GAMEMODE_PROP_CHANCE] = -1
	xDataGetGameMode[GAMEMODE_PROP_MIN_PLAYERS] = 1
	xDataGetGameMode[GAMEMODE_PROP_ROUND_TIME] = 2.0
	xDataGetGameMode[GAMEMODE_PROP_CHANGE_CLASS] = false
	xDataGetGameMode[GAMEMODE_PROP_DEATHMATCH] = GAMEMODE_DEATHMATCH_DISABLED
	xDataGetGameMode[GAMEMODE_PROP_RESPAWN_TIME] = -1.0

	ArrayPushArray(aDataGameMode, xDataGetGameMode)

	return key
}

public any:_zpn_gamemode_get_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataGameMode))
		return false

	enum { arg_gamemode_id = 1, arg_prop, arg_value, arg_len }

	new gamemode_id = get_param(arg_gamemode_id)
	new prop = get_param(arg_prop)

	ArrayGetArray(aDataGameMode, gamemode_id, xDataGetGameMode)

	switch(ePropsGameModeRegisters:prop)
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

	ArrayGetArray(aDataGameMode, gamemode_id, xDataGetGameMode)

	switch(ePropsGameModeRegisters:prop)
	{
		case GAMEMODE_PROP_REGISTER_NAME: get_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NAME], charsmax(xDataGetGameMode[GAMEMODE_PROP_NAME]))
		case GAMEMODE_PROP_REGISTER_NOTICE: get_string(arg_value, xDataGetGameMode[GAMEMODE_PROP_NOTICE], charsmax(xDataGetGameMode[GAMEMODE_PROP_NOTICE]))
		case GAMEMODE_PROP_REGISTER_HUD_COLOR: xDataGetGameMode[GAMEMODE_PROP_HUD_COLOR] = get_param_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_CHANCE: xDataGetGameMode[GAMEMODE_PROP_CHANCE] = get_param_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_MIN_PLAYERS: xDataGetGameMode[GAMEMODE_PROP_MIN_PLAYERS] = get_param_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_ROUND_TIME: xDataGetGameMode[GAMEMODE_PROP_ROUND_TIME] = get_float_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_CHANGE_CLASS: xDataGetGameMode[GAMEMODE_PROP_CHANGE_CLASS] = bool:get_param_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_DEATHMATCH: xDataGetGameMode[GAMEMODE_PROP_DEATHMATCH] = eGameModeDeathMatchType:get_param_byref(arg_value)
		case GAMEMODE_PROP_REGISTER_RESPAWN_TIME: xDataGetGameMode[GAMEMODE_PROP_RESPAWN_TIME] = get_float_byref(arg_value)
		default: return false
	}

	ArraySetArray(aDataGameMode, gamemode_id, xDataGetGameMode)
	
	return true
}

public _zpn_class_init(plugin_id, param_nums)
{
	new key = (++xDataClassCount - 1)

	xDataGetClass[CLASS_PROP_TYPE] = CLASS_TEAM_TYPE_ZOMBIE
	xDataGetClass[CLASS_PROP_NAME] = EOS
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

	ArrayPushArray(aDataClass, xDataGetClass)

	return key
}

public any:_zpn_class_get_prop(plugin_id, param_nums)
{
	if(zpn_is_invalid_array(aDataClass))
		return false

	enum { arg_class_id = 1, arg_prop, arg_value, arg_len }

	new class_id = get_param(arg_class_id)
	new prop = get_param(arg_prop)

	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	switch(ePropsClassRegisters:prop)
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

	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	switch(ePropsClassRegisters:prop)
	{
		case CLASS_PROP_REGISTER_TYPE: xDataGetClass[CLASS_PROP_TYPE] = eClassesType:get_param_byref(arg_value)
		case CLASS_PROP_REGISTER_NAME: get_string(arg_value, xDataGetClass[CLASS_PROP_NAME], charsmax(xDataGetClass[CLASS_PROP_NAME]))
		case CLASS_PROP_REGISTER_INFO: get_string(arg_value, xDataGetClass[CLASS_PROP_INFO], charsmax(xDataGetClass[CLASS_PROP_INFO]))
		case CLASS_PROP_REGISTER_MODEL:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_MODEL], charsmax(xDataGetClass[CLASS_PROP_MODEL]))

			if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_MODEL]))
				precache_player_model(xDataGetClass[CLASS_PROP_MODEL])
		}
		case CLASS_PROP_REGISTER_MODEL_VIEW:
		{
			get_string(arg_value, xDataGetClass[CLASS_PROP_MODEL_VIEW], charsmax(xDataGetClass[CLASS_PROP_MODEL_VIEW]))

			if(!zpn_is_null_string(xDataGetClass[CLASS_PROP_MODEL_VIEW]))
				precache_model(xDataGetClass[CLASS_PROP_MODEL_VIEW])
		}
		case CLASS_PROP_REGISTER_BODY: xDataGetClass[CLASS_PROP_BODY] = get_param_byref(arg_value)
		case CLASS_PROP_REGISTER_HEALTH: xDataGetClass[CLASS_PROP_HEALTH] = get_float_byref(arg_value)
		case CLASS_PROP_REGISTER_ARMOR: xDataGetClass[CLASS_PROP_ARMOR] = get_float_byref(arg_value)
		case CLASS_PROP_REGISTER_SPEED: xDataGetClass[CLASS_PROP_SPEED] = get_float_byref(arg_value)
		case CLASS_PROP_REGISTER_GRAVITY: xDataGetClass[CLASS_PROP_GRAVITY] = get_float_byref(arg_value)
		case CLASS_PROP_REGISTER_KNOCKBACK: xDataGetClass[CLASS_PROP_KNOCKBACK] = get_float_byref(arg_value)
		case CLASS_PROP_REGISTER_CLAW_WEAPONLIST: get_string(arg_value, xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST], charsmax(xDataGetClass[CLASS_PROP_CLAW_WEAPONLIST]))
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

public bool:set_user_zombie(this, attacker, bool:set_first)
{
	if(zpn_is_invalid_array(aDataClass))
		return false

	if(!is_valid_player_alive(this))
		return false

	ArrayGetArray(aDataClass, xUserData[this][UD_CURRENT_ZOMBIE_CLASS], xDataGetClass)
	xUserData[this][UD_IS_ZOMBIE] = true
	xUserData[this][UD_IS_FIRST_ZOMBIE] = set_first

	rg_drop_items_by_slot(this, PRIMARY_WEAPON_SLOT)
	rg_drop_items_by_slot(this, PISTOL_SLOT)
	rg_drop_items_by_slot(this, GRENADE_SLOT)
	rg_give_item(this, "weapon_knife")
	rg_set_user_team(this, TEAM_TERRORIST)
	rg_set_user_model(this, xDataGetClass[CLASS_PROP_MODEL])

	if(xDataGetClass[CLASS_PROP_BODY] != -1)
		set_entvar(this, var_body, xDataGetClass[CLASS_PROP_BODY])

	set_entvar(this, var_health, xDataGetClass[CLASS_PROP_HEALTH])
	set_entvar(this, var_max_health, xDataGetClass[CLASS_PROP_HEALTH])
	set_entvar(this, var_gravity, xDataGetClass[CLASS_PROP_GRAVITY])
	set_entvar(this, var_armorvalue, floatround(xDataGetClass[CLASS_PROP_ARMOR]))
	set_entvar(this, var_maxspeed, xDataGetClass[CLASS_PROP_SPEED])
	deploy_weapon(this)

	if(xSettingsVars[CONFIG_DEBUG_ON])
		server_print("%n virou zombie, class id: %d - health: %0.1f - model: %s - v_model: %s", this, xUserData[this][UD_CURRENT_ZOMBIE_CLASS], xDataGetClass[CLASS_PROP_HEALTH], xDataGetClass[CLASS_PROP_MODEL], xDataGetClass[CLASS_PROP_MODEL_VIEW])
	
	return true
}

public set_user_human(this, attacker)
{
	if(zpn_is_invalid_array(aDataClass))
		return

	if(!is_valid_player_alive(this))
		return

	ArrayGetArray(aDataClass, xUserData[this][UD_CURRENT_HUMAN_CLASS], xDataGetClass)
	xUserData[this][UD_IS_ZOMBIE] = false
	xUserData[this][UD_IS_LAST_HUMAN] = false

	static model[64]
	if(zpn_is_null_string(xDataGetClass[CLASS_PROP_MODEL]))
		copy(model, charsmax(model), xSettingsVars[CONFIG_DEFAULT_HUMAN_MODEL])
	else copy(model, charsmax(model), xDataGetClass[CLASS_PROP_MODEL])

	if(xDataGetClass[CLASS_PROP_BODY] != -1)
		set_entvar(this, var_body, xDataGetClass[CLASS_PROP_BODY])

	rg_set_user_model(this, model)
	rg_set_user_team(this, TEAM_CT)

	new armor = 0

	if(xDataGetClass[CLASS_PROP_ARMOR] > 0)
		armor = floatround(xDataGetClass[CLASS_PROP_ARMOR])

	set_entvar(this, var_armorvalue, armor)
	set_entvar(this, var_maxspeed, xDataGetClass[CLASS_PROP_SPEED])

	if(xSettingsVars[CONFIG_DEBUG_ON])
		server_print("%n virou humano, class id: %d - health: %0.1f - model: %s - armor: %d", this, xUserData[this][UD_CURRENT_HUMAN_CLASS], xDataGetClass[CLASS_PROP_HEALTH], xDataGetClass[CLASS_PROP_MODEL], armor)
}

public set_user_nv(id)
{
	static Float:o[3]; get_entvar(id, var_origin, o)

	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, .player = id)
	write_byte(TE_DLIGHT)
	write_coord_f(o[0])
	write_coord_f(o[1])
	write_coord_f(o[2])
	write_byte(40) // radius
	write_byte(xUserData[id][UD_IS_ZOMBIE] ? xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][0] : xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][0])
	write_byte(xUserData[id][UD_IS_ZOMBIE] ? xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][1] : xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][1])
	write_byte(xUserData[id][UD_IS_ZOMBIE] ? xDataGetGameRule[GAME_RULE_DEFAULT_NV_Z][2] : xDataGetGameRule[GAME_RULE_DEFAULT_NV_H][2])
	write_byte(1) // life
	write_byte(0) // decay
	message_end()
}

get_user_speed(const this)
{
	static Float:velocity[3]; get_entvar(this, var_velocity, velocity)
	return floatround(vector_length(velocity))
}

get_gamemode_name()
{
	static gm[64]
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
	static class[64], class_id; class_id = xUserData[this][UD_IS_ZOMBIE] ? xUserData[this][UD_CURRENT_ZOMBIE_CLASS] : xUserData[this][UD_CURRENT_HUMAN_CLASS]
	ArrayGetArray(aDataClass, class_id, xDataGetClass)

	if(zpn_is_null_string(xDataGetClass[CLASS_PROP_NAME]))
		copy(class, charsmax(class), "--")
	else copy(class, charsmax(class), xDataGetClass[CLASS_PROP_NAME])

	return class
}

get_first_class(eClassesType:class_type)
{
	new class_id = 0
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

	count = 0
	len = 0
	i = 0
	count = 0
	str[0] = EOS
	str2[0] = EOS

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

count_class(eClassesType:class_type)
{
	new count = 0
	for(new i = 0; i < ArraySize(aDataClass); i++)
	{
		ArrayGetArray(aDataClass, i, xDataGetClass)
		if(xDataGetClass[CLASS_PROP_TYPE] == class_type) count ++;
	}

	return count
}

random_gamemode()
{
	new gm = -1, i
	new totalChance = 0

	for(i = 0; i < ArraySize(aDataGameMode); i++)
		ArrayGetArray(aDataGameMode, i, xDataGetGameMode), totalChance += xDataGetGameMode[GAMEMODE_PROP_CHANCE];

	new randomNumber = random_num(1, totalChance)
	new accumulatedChance = 0

	for(i = 0; i < ArraySize(aDataGameMode); i++)
	{
		ArrayGetArray(aDataGameMode, i, xDataGetGameMode), accumulatedChance += xDataGetGameMode[GAMEMODE_PROP_CHANCE];

		if(randomNumber <= accumulatedChance)
			gm = i

		if(gm != -1)
			break
	}

	return gm
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