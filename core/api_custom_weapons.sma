#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <api_custom_weapons_const>

#define PLUGIN  "[API] Custom Weapons"
#define VERSION "1.0"
#define AUTHOR  "BRUN0"

enum _:eWeaponProps
{
	WEAPON_PROP_HANDLE[64],
	WEAPON_PROP_REFERENCE[64],
	WEAPON_PROP_WEAPONLIST[64],
	WEAPON_PROP_ANIM_EXTENSION[64],
	GiveType:WEAPON_PROP_GIVE_TYPE,
	WEAPON_PROP_SLOT,
	WEAPON_PROP_MODEL_V[64],
	WEAPON_PROP_MODEL_P[64],
	WEAPON_PROP_MODEL_W[64],
	Float:WEAPON_PROP_DAMAGE_GENERIC,
	Float:WEAPON_PROP_DAMAGE_HEAD,
	Float:WEAPON_PROP_DAMAGE_CHEST,
	Float:WEAPON_PROP_DAMAGE_STOMACH,
	Float:WEAPON_PROP_DAMAGE_ARMS,
	Float:WEAPON_PROP_DAMAGE_LEGS,
	WEAPON_PROP_ANIM_DUMMY,
	WEAPON_PROP_MAX_CLIP,
	WEAPON_PROP_MAX_AMMO,
	Float:WEAPON_PROP_RELOAD_TIME,
	bool:WEAPON_PROP_CAN_DROP,
}

new Array:aDataWeapon
new Trie:aWeaponsMap

new any:aDataTemp[eWeaponProps]
new Array:g_rgWeapons[CW_Data]

enum _:Function
{
	Function_PluginId,
	Function_FunctionId,
}

new xDataWeaponCount
new Float:g_NextPlayerUpdate[MAX_PLAYERS + 1]

public plugin_precache()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	aDataWeapon = ArrayCreate(eWeaponProps, 0)
	aWeaponsMap = TrieCreate()
	xDataWeaponCount = 0

	for (new i = 0; i < _:CW_Data; ++i) if (!g_rgWeapons[CW_Data:i])
		g_rgWeapons[CW_Data:i] = ArrayCreate(1, 1);
}

public plugin_init()
{
	if (cw_invalid_array(aDataWeapon))
		set_fail_state("[API Weapons] No Weapons Founds")

	register_forward(FM_UpdateClientData, "FM_Player_Update_Data_Post", true)

	RegisterHookChain(RG_CBasePlayer_Observer_IsValidTarget, "CBasePlayer_Observer_IsValidTarget_Post", true)

	RegisterHookChain(RG_CBasePlayer_AddPlayerItem, "CBasePlayer_AddPlayerItem_Post", true)
	RegisterHookChain(RG_CBasePlayerWeapon_SendWeaponAnim, "CBasePlayerWeapon_SendWeaponAnim_Pre", false)
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "CBasePlayerWeapon_DefaultDeploy_Pre", false)
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "CBasePlayerWeapon_DefaultReload_Pre", false)
	RegisterHookChain(RG_CWeaponBox_SetModel, "CWeaponBox_SetModel_Pre", false)
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre", false)

	new IND, WEAPON_REFERENCE[64]

	for (IND = 1; IND < MAX_WEAPONS - 1; IND++)
	{
		if ((1 << IND) & ((1 << CSW_GLOCK) | (1 << CSW_C4)))
			continue

		rg_get_weapon_info(WeaponIdType:IND, WI_NAME, WEAPON_REFERENCE, charsmax(WEAPON_REFERENCE))

		RegisterHam(Ham_Spawn,					WEAPON_REFERENCE,	"HamHook_Weapon_Spawn_Post", .Post = true)
		RegisterHam(Ham_Weapon_WeaponIdle,		WEAPON_REFERENCE,	"HamHook_Weapon_WeaponIdle_Pre", .Post = false)
		RegisterHam(Ham_Weapon_PrimaryAttack,	WEAPON_REFERENCE,	"HamHook_Weapon_PrimaryAttack_Pre", .Post = false)
		RegisterHam(Ham_Weapon_SecondaryAttack,	WEAPON_REFERENCE,	"HamHook_Weapon_SecondaryAttack_Pre", .Post = false)
		RegisterHam(Ham_CS_Item_CanDrop,		WEAPON_REFERENCE,	"HamHook_Weapon_CanDrop_pre", .Post = false)
	}
}

public plugin_natives()
{
	register_library("api_custom_weapons")

	register_native("CW_weapon_init", "_CW_weapon_init")
	register_native("CW_weapon_get_var", "_CW_weapon_get_var")
	register_native("CW_weapon_set_var", "_CW_weapon_set_var")

	register_native("CW_weapon_bind", "_CW_weapon_bind")

	register_native("CW_weapon_find", "_CW_weapon_find")
	register_native("CW_weapon_give", "_CW_weapon_give")

	register_native("CW_weapon_rd_give", "_CW_weapon_rd_give")
}

public plugin_end()
{
	for (new iHandler = 0; iHandler < xDataWeaponCount; ++iHandler)
	{
		new Array:irgBindings = GetData(iHandler, CW_Data_Bindings);
		ArrayDestroy(irgBindings);
	}

	for (new i = 0; i < _:CW_Data; ++i) {
		ArrayDestroy(Array:g_rgWeapons[CW_Data:i]);
	}

	ArrayDestroy(aDataWeapon)
	TrieDestroy(aWeaponsMap)
}

public client_putinserver(id)
{
	g_NextPlayerUpdate[id] = 0.0
}

public FM_Player_Update_Data_Post(const id, const send_weapons, const cd_handle)
{
	if (!is_user_connected(id)) {
		return
	}

	static pTarget, pActiveItem, Float:flLastEventCheck
	pTarget = (get_entvar(id, var_iuser1)) ? get_entvar(id, var_iuser2) : id

	if (!is_user_alive(pTarget)) {
		return
	}

	static Float:pGameTime; pGameTime = get_gametime()
	pActiveItem = get_member(pTarget, m_pActiveItem)
	if (is_nullent(pActiveItem)) {
		return
	}

	if (!IsWeaponValid(pActiveItem))
		return

	static pArrayIndex; 
	pArrayIndex = GetWeaponArrayId(pActiveItem)

	if (pArrayIndex < 0) 
		return

	ArrayGetArray(aDataWeapon, pArrayIndex, aDataTemp)

	if (!is_user_alive(id) && g_NextPlayerUpdate[id] && g_NextPlayerUpdate[id] <= pGameTime)
	{
		ExecuteBindedFunction(WEAPON_BIND_ANIM_SPEC_IDLE, pActiveItem)
		g_NextPlayerUpdate[id] = 0.0
	}

	set_cd(cd_handle, CD_flNextAttack, pGameTime + 0.001)

	flLastEventCheck = get_member(pActiveItem, m_flLastEventCheck)

	if (!flLastEventCheck)
	{
		set_cd(cd_handle, CD_WeaponAnim, aDataTemp[WEAPON_PROP_ANIM_DUMMY])
		return
	}

	if (flLastEventCheck <= pGameTime)
	{
		set_member(pActiveItem, m_flLastEventCheck, 0.0)
		ExecuteBindedFunction(WEAPON_BIND_ANIM_DEPLOY, pActiveItem)
	}
}

public CBasePlayer_Observer_IsValidTarget_Post(const eObserver, const eTarget, bool:bSameTeam)
{
	if (GetHookChainReturn(ATYPE_INTEGER) != eTarget)
		return

	static pActiveItem;
	pActiveItem = get_member(eTarget, m_pActiveItem)

	if (is_nullent(pActiveItem))
		return

	if (!IsWeaponValid(pActiveItem))
		return

	g_NextPlayerUpdate[eObserver] = get_gametime() + 0.1
}

public _CW_weapon_init(plugin_id, param_nums)
{
	enum { ArgHandler = 1 }
	new xDataGetWeapon[eWeaponProps]
	new pIndex = (++xDataWeaponCount - 1)

	xDataGetWeapon[WEAPON_PROP_HANDLE] = EOS

	get_string(ArgHandler, 
	xDataGetWeapon[WEAPON_PROP_HANDLE],
	charsmax(xDataGetWeapon[WEAPON_PROP_HANDLE]));

	for (new iParam = 0; iParam < _:CW_Data; ++iParam) {
		ArrayPushCell(Array:g_rgWeapons[CW_Data:iParam], 0)
	}

	TrieSetCell(aWeaponsMap, xDataGetWeapon[WEAPON_PROP_HANDLE], pIndex)

	InitWeaponBindings(pIndex)

	xDataGetWeapon[WEAPON_PROP_REFERENCE] = EOS
	xDataGetWeapon[WEAPON_PROP_WEAPONLIST] = EOS
	xDataGetWeapon[WEAPON_PROP_ANIM_EXTENSION] = EOS

	xDataGetWeapon[WEAPON_PROP_GIVE_TYPE] = GT_DROP_AND_REPLACE

	xDataGetWeapon[WEAPON_PROP_SLOT] = CW_INVALID

	xDataGetWeapon[WEAPON_PROP_MODEL_V] = EOS
	xDataGetWeapon[WEAPON_PROP_MODEL_P] = EOS
	xDataGetWeapon[WEAPON_PROP_MODEL_W] = EOS

	xDataGetWeapon[WEAPON_PROP_DAMAGE_GENERIC] = CW_INVALID_DAMAGE
	xDataGetWeapon[WEAPON_PROP_DAMAGE_HEAD] =	 CW_INVALID_DAMAGE
	xDataGetWeapon[WEAPON_PROP_DAMAGE_CHEST] =	 CW_INVALID_DAMAGE
	xDataGetWeapon[WEAPON_PROP_DAMAGE_STOMACH] = CW_INVALID_DAMAGE
	xDataGetWeapon[WEAPON_PROP_DAMAGE_ARMS] =	 CW_INVALID_DAMAGE
	xDataGetWeapon[WEAPON_PROP_DAMAGE_LEGS] =	 CW_INVALID_DAMAGE

	xDataGetWeapon[WEAPON_PROP_ANIM_DUMMY] = 0

	xDataGetWeapon[WEAPON_PROP_MAX_CLIP] = 60
	xDataGetWeapon[WEAPON_PROP_MAX_AMMO] = 240

	xDataGetWeapon[WEAPON_PROP_RELOAD_TIME] = -1.0
	xDataGetWeapon[WEAPON_PROP_CAN_DROP] = false

	ArrayPushArray(aDataWeapon, xDataGetWeapon)

	return pIndex
}

public any:_CW_weapon_get_var(plugin_id, param_nums)
{
	if (cw_invalid_array(aDataWeapon))
		return false

	enum { arg_weapon_id = 1, arg_prop, arg_value, arg_len }

	new weapon_id = get_param(arg_weapon_id)
	new prop = get_param(arg_prop)

	new xDataGetWeapon[eWeaponProps]
	ArrayGetArray(aDataWeapon, weapon_id, xDataGetWeapon)

	switch(eVarWeapon:prop)
	{
		case WEAPON_VAR_HANDLE: set_string(arg_value, xDataGetWeapon[WEAPON_PROP_HANDLE], get_param_byref(arg_len))
		case WEAPON_VAR_REFERENCE: set_string(arg_value, xDataGetWeapon[WEAPON_PROP_REFERENCE], get_param_byref(arg_len))
		case WEAPON_VAR_WEAPONLIST: set_string(arg_value, xDataGetWeapon[WEAPON_PROP_WEAPONLIST], get_param_byref(arg_len))
		case WEAPON_VAR_ANIM_EXTENSION: set_string(arg_value, xDataGetWeapon[WEAPON_PROP_ANIM_EXTENSION], get_param_byref(arg_len))
		case WEAPON_VAR_GIVE_TYPE:
		{
			return GiveType:xDataGetWeapon[WEAPON_PROP_GIVE_TYPE]
		}
		case WEAPON_VAR_SLOT:
		{
			return xDataGetWeapon[WEAPON_PROP_SLOT]
		}
		case WEAPON_VAR_V_MODEL: set_string(arg_value, xDataGetWeapon[WEAPON_PROP_MODEL_V], get_param_byref(arg_len))
		case WEAPON_VAR_P_MODEL: set_string(arg_value, xDataGetWeapon[WEAPON_PROP_MODEL_P], get_param_byref(arg_len))
		case WEAPON_VAR_W_MODEL: set_string(arg_value, xDataGetWeapon[WEAPON_PROP_MODEL_W], get_param_byref(arg_len))
		case WEAPON_VAR_DAMAGE_GENERIC:
		{
			return Float:xDataGetWeapon[WEAPON_PROP_DAMAGE_GENERIC]
		}
		case WEAPON_VAR_DAMAGE_HEAD:
		{
			return Float:xDataGetWeapon[WEAPON_PROP_DAMAGE_HEAD]
		}
		case WEAPON_VAR_DAMAGE_CHEST:
		{
			return Float:xDataGetWeapon[WEAPON_PROP_DAMAGE_CHEST]
		}
		case WEAPON_VAR_DAMAGE_STOMACH:
		{
			return Float:xDataGetWeapon[WEAPON_PROP_DAMAGE_STOMACH]
		}
		case WEAPON_VAR_DAMAGE_ARMS:
		{
			return Float:xDataGetWeapon[WEAPON_PROP_DAMAGE_ARMS]
		}
		case WEAPON_VAR_DAMAGE_LEGS:
		{
			return Float:xDataGetWeapon[WEAPON_PROP_DAMAGE_LEGS]
		}
		case WEAPON_VAR_ANIM_DUMMY:
		{
			return xDataGetWeapon[WEAPON_PROP_ANIM_DUMMY]
		}
		case WEAPON_VAR_MAX_CLIP:
		{
			return xDataGetWeapon[WEAPON_PROP_MAX_CLIP]
		}
		case WEAPON_VAR_MAX_AMMO:
		{
			return xDataGetWeapon[WEAPON_PROP_MAX_AMMO]
		}
		case WEAPON_VAR_RELOAD_TIME:
		{
			return Float:xDataGetWeapon[WEAPON_PROP_RELOAD_TIME]
		}
		case WEAPON_VAR_CAN_DROP:
		{
			return bool:xDataGetWeapon[WEAPON_PROP_CAN_DROP]
		}

		default: { return false; }
	}

	return true
}

public any:_CW_weapon_set_var(plugin_id, param_nums)
{
	if (cw_invalid_array(aDataWeapon))
		return false

	enum { arg_weapon_id = 1, arg_prop, arg_value }

	new weapon_id = get_param(arg_weapon_id)
	new prop = get_param(arg_prop)

	new xDataGetWeapon[eWeaponProps]
	ArrayGetArray(aDataWeapon, weapon_id, xDataGetWeapon)

	switch(eVarWeapon:prop)
	{
		case WEAPON_VAR_HANDLE: get_string(arg_value, xDataGetWeapon[WEAPON_PROP_HANDLE], charsmax(xDataGetWeapon[WEAPON_PROP_HANDLE]))
		case WEAPON_VAR_REFERENCE: get_string(arg_value, xDataGetWeapon[WEAPON_PROP_REFERENCE], charsmax(xDataGetWeapon[WEAPON_PROP_REFERENCE]))
		case WEAPON_VAR_WEAPONLIST:
		{
			get_string(arg_value, xDataGetWeapon[WEAPON_PROP_WEAPONLIST], charsmax(xDataGetWeapon[WEAPON_PROP_WEAPONLIST]))
		
			if (!cw_null_string(xDataGetWeapon[WEAPON_PROP_WEAPONLIST]))
			{
				UTIL_PrecacheWeaponList(xDataGetWeapon[WEAPON_PROP_WEAPONLIST])
				register_clcmd(xDataGetWeapon[WEAPON_PROP_WEAPONLIST], "Command_SelectWeapon", weapon_id);
			}
		}
		case WEAPON_VAR_ANIM_EXTENSION: get_string(arg_value, xDataGetWeapon[WEAPON_PROP_ANIM_EXTENSION], charsmax(xDataGetWeapon[WEAPON_PROP_ANIM_EXTENSION]))
		
		case WEAPON_VAR_GIVE_TYPE:
		{
			xDataGetWeapon[WEAPON_PROP_GIVE_TYPE] = GiveType:get_param_byref(arg_value)
		}
		case WEAPON_VAR_SLOT:
		{
			xDataGetWeapon[WEAPON_PROP_SLOT] = get_param_byref(arg_value)
		}
		case WEAPON_VAR_V_MODEL:
		{
			get_string(arg_value, xDataGetWeapon[WEAPON_PROP_MODEL_V], charsmax(xDataGetWeapon[WEAPON_PROP_MODEL_V]))
			if (!cw_null_string(xDataGetWeapon[WEAPON_PROP_MODEL_V])) {
				precache_model(xDataGetWeapon[WEAPON_PROP_MODEL_V])
			}
		}
		case WEAPON_VAR_P_MODEL:
		{
			get_string(arg_value, xDataGetWeapon[WEAPON_PROP_MODEL_P], charsmax(xDataGetWeapon[WEAPON_PROP_MODEL_P]))
			if (!cw_null_string(xDataGetWeapon[WEAPON_PROP_MODEL_P])) {
				precache_model(xDataGetWeapon[WEAPON_PROP_MODEL_P])
			}
		}
		case WEAPON_VAR_W_MODEL:
		{
			get_string(arg_value, xDataGetWeapon[WEAPON_PROP_MODEL_W], charsmax(xDataGetWeapon[WEAPON_PROP_MODEL_W]))
			if (!cw_null_string(xDataGetWeapon[WEAPON_PROP_MODEL_W])) {
				precache_model(xDataGetWeapon[WEAPON_PROP_MODEL_W])
			}
		}
		case WEAPON_VAR_DAMAGE_GENERIC:
		{
			xDataGetWeapon[WEAPON_PROP_DAMAGE_GENERIC] = get_float_byref(arg_value)
		}
		case WEAPON_VAR_DAMAGE_HEAD:
		{
			xDataGetWeapon[WEAPON_PROP_DAMAGE_HEAD] = get_float_byref(arg_value)
		}
		case WEAPON_VAR_DAMAGE_CHEST:
		{
			xDataGetWeapon[WEAPON_PROP_DAMAGE_CHEST] = get_float_byref(arg_value)
		}
		case WEAPON_VAR_DAMAGE_STOMACH:
		{
			xDataGetWeapon[WEAPON_PROP_DAMAGE_STOMACH] = get_float_byref(arg_value)
		}
		case WEAPON_VAR_DAMAGE_ARMS:
		{
			xDataGetWeapon[WEAPON_PROP_DAMAGE_ARMS] = get_float_byref(arg_value)
		}
		case WEAPON_VAR_DAMAGE_LEGS:
		{
			xDataGetWeapon[WEAPON_PROP_DAMAGE_LEGS] = get_float_byref(arg_value)
		}
		case WEAPON_VAR_ANIM_DUMMY:
		{
			xDataGetWeapon[WEAPON_PROP_ANIM_DUMMY] = get_param_byref(arg_value)
		}
		case WEAPON_VAR_MAX_CLIP:
		{
			xDataGetWeapon[WEAPON_PROP_MAX_CLIP] = get_param_byref(arg_value)
		}
		case WEAPON_VAR_MAX_AMMO:
		{
			xDataGetWeapon[WEAPON_PROP_MAX_AMMO] = get_param_byref(arg_value)
		}
		case WEAPON_VAR_RELOAD_TIME:
		{
			xDataGetWeapon[WEAPON_PROP_RELOAD_TIME] = get_float_byref(arg_value)
		}
		case WEAPON_VAR_CAN_DROP:
		{
			xDataGetWeapon[WEAPON_PROP_CAN_DROP] = bool:get_param_byref(arg_value)
		}

		default: { return false; }
	}

	ArraySetArray(aDataWeapon, weapon_id, xDataGetWeapon)
	return true
}

public Command_SelectWeapon(id, index)
{
	if (index < 0 || index >= ArraySize(aDataWeapon))
		return PLUGIN_HANDLED

	ArrayGetArray(aDataWeapon, index, aDataTemp)

	rg_internal_cmd(id, aDataTemp[WEAPON_PROP_REFERENCE])
	return PLUGIN_HANDLED
}

public CBasePlayer_AddPlayerItem_Post(id, item)
{
	if (!GetHookChainReturn(ATYPE_INTEGER))
		return

	if (is_nullent(item))
		return

	if (!IsWeaponValid(item))
	{
		static weaponid
		weaponid = get_member(item, m_iId)
		SendWeaponList(id, item, .weaponId = weaponid)
		return
	}

	new pArrayIndex = GetWeaponArrayId(item)
	if (pArrayIndex < 0) 
		return

	ArrayGetArray(aDataWeapon, pArrayIndex, aDataTemp)
	SendWeaponList(id, item, aDataTemp[WEAPON_PROP_WEAPONLIST])
}

stock SendWeaponList(const id, const item, name[64] = "", ammo1 = -2, maxAmmo1 = -2, ammo2 = -2, maxAmmo2 = -2, slot = -2, position = -2, weaponId = -2, flags = -2) 
{
	if (!is_user_connected(id))
		return

	if (name[0] == EOS)
		rg_get_iteminfo(item, ItemInfo_pszName, name, charsmax(name))

	static pMsg; if (!pMsg) pMsg = get_user_msgid("WeaponList")

	message_begin(MSG_ONE, pMsg, .player = id)
	write_string(name)
	write_byte((ammo1 <= -2) ? get_member(item, m_Weapon_iPrimaryAmmoType) : ammo1)
	write_byte((maxAmmo1 <= -2) ? rg_get_iteminfo(item, ItemInfo_iMaxAmmo1 ) : maxAmmo1)
	write_byte((ammo2 <= -2) ? get_member(item, m_Weapon_iSecondaryAmmoType ) : ammo2)
	write_byte((maxAmmo2 <= -2) ? rg_get_iteminfo(item, ItemInfo_iMaxAmmo2 ) : maxAmmo2)
	write_byte((slot <= -2) ? rg_get_iteminfo(item, ItemInfo_iSlot ) : slot)
	write_byte((position <= -2) ? rg_get_iteminfo(item, ItemInfo_iPosition) : position)
	write_byte((weaponId <= -2) ? rg_get_iteminfo(item, ItemInfo_iId ) : weaponId)
	write_byte((flags <= -2) ? rg_get_iteminfo(item, ItemInfo_iFlags ) : flags)
	message_end()
}

public CBasePlayerWeapon_SendWeaponAnim_Pre(const pWeapon, const iAnim, const skiplocal)
{
	if (!IsWeaponValid(pWeapon))
		return HC_CONTINUE

	if (GetWeaponArrayId(pWeapon) < 0) 
		return HC_CONTINUE

	new pPlayer = get_member(pWeapon, m_pPlayer)
	new pBody = get_entvar(pWeapon, var_body)
	set_entvar(pPlayer, var_weaponanim, iAnim)

	message_begin(MSG_ONE, SVC_WEAPONANIM, .player = pPlayer)
	write_byte(iAnim)
	write_byte(pBody)
	message_end()

	for (new pObserver = 1; pObserver <= MaxClients; pObserver++)
	{
		if (pObserver == pPlayer || !is_user_connected(pObserver) || is_user_alive(pObserver) || is_nullent(pObserver) 
	 	|| get_entvar(pObserver, var_iuser1) != OBS_IN_EYE || get_entvar(pObserver, var_iuser2) != pPlayer)
			continue

		set_entvar(pObserver, var_weaponanim, iAnim)

		message_begin(MSG_ONE, SVC_WEAPONANIM, .player = pObserver)
		write_byte(iAnim)
		write_byte(pBody)
		message_end()
	}

	return HC_SUPERCEDE
}

public CBasePlayerWeapon_DefaultDeploy_Pre(pWeapon, viewModel[], weaponModel[], anim, animExt[], skiplocal)
{
	if (!IsWeaponValid(pWeapon))
		return

	static pArrayIndex; pArrayIndex = GetWeaponArrayId(pWeapon)
	if (pArrayIndex < 0) return

	ArrayGetArray(aDataWeapon, pArrayIndex, aDataTemp)

	set_member(pWeapon, m_flLastEventCheck, get_gametime() + 0.1)

	if (!cw_null_string(aDataTemp[WEAPON_PROP_MODEL_V])) {
		SetHookChainArg(2, ATYPE_STRING, aDataTemp[WEAPON_PROP_MODEL_V])
	}

	if (!cw_null_string(aDataTemp[WEAPON_PROP_MODEL_P])) {
		SetHookChainArg(3, ATYPE_STRING, aDataTemp[WEAPON_PROP_MODEL_P])
	}

	SetHookChainArg(4, ATYPE_INTEGER, aDataTemp[WEAPON_PROP_ANIM_DUMMY])

	if (!cw_null_string(aDataTemp[WEAPON_PROP_ANIM_EXTENSION])) {
		SetHookChainArg(5, ATYPE_STRING, aDataTemp[WEAPON_PROP_ANIM_EXTENSION])
	}

	static pPlayer
	pPlayer = get_member(pWeapon, m_pPlayer)

	ExecuteBindedFunction
	(
		WEAPON_BIND_DEPLOY,
		pWeapon,
		pPlayer
	)
}

public CBasePlayerWeapon_DefaultReload_Pre(const pWeapon, const iClipSize, const animation, Float:fDelay)
{
	if (!IsWeaponValid(pWeapon))
		return

	new pArrayIndex = GetWeaponArrayId(pWeapon)
	if (pArrayIndex < 0) 
		return

	ArrayGetArray(aDataWeapon, pArrayIndex, aDataTemp)

	if (get_member(pWeapon, m_Weapon_iClip) >= aDataTemp[WEAPON_PROP_MAX_CLIP])
		return

	SetHookChainArg(2, ATYPE_INTEGER, aDataTemp[WEAPON_PROP_MAX_CLIP])

	if (aDataTemp[WEAPON_PROP_RELOAD_TIME] != -1)
		SetHookChainArg(4, ATYPE_FLOAT, aDataTemp[WEAPON_PROP_RELOAD_TIME])

	static pPlayer
	pPlayer = get_member(pWeapon, m_pPlayer)

	ExecuteBindedFunction
	(
		WEAPON_BIND_RELOAD,
		pWeapon,
		pPlayer,
		animation
	)
}

public CWeaponBox_SetModel_Pre(const weapon, const model[])
{
	new item, pArrayIndex
	for (new InventorySlotType:i = PRIMARY_WEAPON_SLOT; i <= PISTOL_SLOT; i++)
	{
		item = get_member(weapon, m_WeaponBox_rgpPlayerItems, i)

		if (is_nullent(item))
			continue

		if (!IsWeaponValid(item))
			continue

		pArrayIndex = GetWeaponArrayId(item)
		if (pArrayIndex < 0) 
			continue

		ArrayGetArray(aDataWeapon, pArrayIndex, aDataTemp)

		if (!cw_null_string(aDataTemp[WEAPON_PROP_MODEL_W]))
		{
			SetHookChainArg(2, ATYPE_STRING, aDataTemp[WEAPON_PROP_MODEL_W])
			break
		}
	}
}

public CBasePlayer_TakeDamage_Pre(const pVictim, const pInflictor, const pAttacker, Float:pDamage, const bitsDamageType)
{
	if (!(bitsDamageType & DMG_BULLET) || pVictim == pAttacker || pInflictor == pAttacker || is_nullent(pInflictor) || !is_user_connected(pAttacker) || !is_user_alive(pVictim))
		return

	if (!rg_is_player_can_takedamage(pVictim, pAttacker))
		return

	if (!IsWeaponValid(pInflictor))
		return

	static pArrayIndex; pArrayIndex = GetWeaponArrayId(pInflictor)
	if (pArrayIndex < 0) return

	ArrayGetArray(aDataWeapon, pArrayIndex, aDataTemp)

	switch (HitBoxGroup:get_member(pVictim, m_LastHitGroup))
	{
		case HITGROUP_GENERIC:	pDamage = aDataTemp[WEAPON_PROP_DAMAGE_GENERIC]
		case HITGROUP_HEAD:		pDamage = aDataTemp[WEAPON_PROP_DAMAGE_HEAD]
		case HITGROUP_CHEST:	pDamage = aDataTemp[WEAPON_PROP_DAMAGE_CHEST]
		case HITGROUP_STOMACH:	pDamage = aDataTemp[WEAPON_PROP_DAMAGE_STOMACH]
		case HITGROUP_LEFTARM, HITGROUP_RIGHTARM: pDamage = aDataTemp[WEAPON_PROP_DAMAGE_ARMS]
		case HITGROUP_LEFTLEG, HITGROUP_RIGHTLEG: pDamage = aDataTemp[WEAPON_PROP_DAMAGE_LEGS]
		default: pDamage = aDataTemp[WEAPON_PROP_DAMAGE_ARMS]
	}

	if (pDamage == CW_INVALID_DAMAGE)
		return

	SetHookChainArg(4, ATYPE_FLOAT, pDamage)
}

public HamHook_Weapon_Spawn_Post(const pWeapon)
{
	if (!IsWeaponValid(pWeapon))
		return

	static pArrayIndex, pSlot
	pArrayIndex = GetWeaponArrayId(pWeapon)
	if (pArrayIndex < 0) return

	ArrayGetArray(aDataWeapon, pArrayIndex, aDataTemp)

	set_member(pWeapon, m_Weapon_iClip, aDataTemp[WEAPON_PROP_MAX_CLIP])
	set_member(pWeapon, m_Weapon_iDefaultAmmo, aDataTemp[WEAPON_PROP_MAX_AMMO])

	rg_set_iteminfo(pWeapon, ItemInfo_iMaxClip, aDataTemp[WEAPON_PROP_MAX_CLIP])
	rg_set_iteminfo(pWeapon, ItemInfo_pszName, aDataTemp[WEAPON_PROP_WEAPONLIST])
	rg_set_iteminfo(pWeapon, ItemInfo_iMaxAmmo1, aDataTemp[WEAPON_PROP_MAX_AMMO])

	pSlot = clamp(aDataTemp[WEAPON_PROP_SLOT], 1, 6)
	rg_set_iteminfo(pWeapon, ItemInfo_iSlot, pSlot -1)

	ExecuteBindedFunction(WEAPON_BIND_SPAWN, pWeapon)
}

public HamHook_Weapon_WeaponIdle_Pre(const pWeapon)
{
	if (!IsWeaponValid(pWeapon)) {
		return HAM_IGNORED
	}

	static pPlayer, Float:pIdleTime
	pIdleTime = Float:get_member
	(
		pWeapon, 
		m_Weapon_flTimeWeaponIdle
	)

	pPlayer = get_member(pWeapon, m_pPlayer)

	ExecuteBindedFunction
	(
		WEAPON_BIND_IDLE,
		pWeapon,
		pIdleTime,
		pPlayer
	)

	return HAM_SUPERCEDE
}

public HamHook_Weapon_PrimaryAttack_Pre(const pWeapon)
{
	if (!IsWeaponValid(pWeapon))
		return HAM_IGNORED

	static pWeaponClip; pWeaponClip = get_member(pWeapon, m_Weapon_iClip)
	static pPlayer; pPlayer = get_member(pWeapon, m_pPlayer)

	if (pWeaponClip <= 0)
	{
		ExecuteHamB(Ham_Weapon_PlayEmptySound, pWeapon)
		set_member(pWeapon, m_Weapon_flNextPrimaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	ExecuteBindedFunction
	(
		WEAPON_BIND_PRIMARY_ATTACK,
		pWeapon,
		pPlayer,
		pWeaponClip
	)

	/*set_member(pWeapon, m_Weapon_flNextPrimaryAttack, 
	get_member(pWeapon, m_Weapon_fMaxSpeed));*/

	return HAM_SUPERCEDE
}

public HamHook_Weapon_SecondaryAttack_Pre(const pWeapon)
{
	if (!IsWeaponValid(pWeapon))
		return HAM_IGNORED

	static pPlayer; pPlayer = get_member(pWeapon, m_pPlayer)

	ExecuteBindedFunction
	(
		WEAPON_BIND_SECONDARY_ATTACK, 
		pWeapon,
		pPlayer
	)

	return HAM_SUPERCEDE
}

public HamHook_Weapon_CanDrop_pre(pThis)
{
	if (!IsWeaponValid(pThis))
		return HAM_IGNORED

	static pArrayIndex
	pArrayIndex = GetWeaponArrayId(pThis)

	if (pArrayIndex < 0) 
		return HAM_IGNORED

	ArrayGetArray(aDataWeapon, pArrayIndex, aDataTemp)

	if (aDataTemp[WEAPON_PROP_CAN_DROP])
		return HAM_IGNORED

	return HAM_OVERRIDE
}

public _CW_weapon_find(iPluginId, iArgc) {

	enum {ArgHandler = 1}

	new szWeapon[64]
	get_string(ArgHandler, szWeapon, charsmax(szWeapon))

	new pWeaponIndex = GetIndexByHandler(szWeapon)
	if (pWeaponIndex < 0)
		return CW_INVALID

	return pWeaponIndex
}

public _CW_weapon_give(iPluginId, iArgc)
{
	enum {ArgPlayer = 1, ArgHandler}

	new pPlayer = get_param(ArgPlayer)
	if (!is_user_alive(pPlayer))
		return false

	new szWeapon[64]
	get_string(ArgHandler, szWeapon, charsmax(szWeapon))

	new pWeaponIndex = GetIndexByHandler(szWeapon)
	if (pWeaponIndex < 0)
		return false

	return Give_Custom_Weapon(pPlayer, pWeaponIndex)
}

public _CW_weapon_rd_give(iPluginId, iArgc)
{
	if (cw_invalid_array(aDataWeapon))
		return false

	enum {ArgPlayer = 1}

	new pPlayer = get_param(ArgPlayer)
	if (!is_user_alive(pPlayer))
		return false

	new xWeaponCount = ArraySize(aDataWeapon)
	if (xWeaponCount <= 0)
		return false

	return Give_Custom_Weapon(pPlayer, random(xWeaponCount))
}

stock bool:Give_Custom_Weapon(const pPlayer, const pWeaponIndex)
{
	if (pWeaponIndex < 0) return false

	ArrayGetArray(aDataWeapon, pWeaponIndex, aDataTemp)

	new customWeapon = rg_give_custom_item(
		pPlayer, 
		aDataTemp[WEAPON_PROP_REFERENCE],
		aDataTemp[WEAPON_PROP_GIVE_TYPE],
		pWeaponIndex + CW_ARRAYID_OFFSET
	)

	if (!is_nullent(customWeapon))
	{
		new iAmmoType = get_member(customWeapon, m_Weapon_iPrimaryAmmoType)
		set_member(pPlayer, m_rgAmmo, aDataTemp[WEAPON_PROP_MAX_AMMO], iAmmoType)
		rg_switch_weapon(pPlayer, customWeapon)
	}

	return true
}

public _CW_weapon_bind(iPluginId, iArgc)
{
	enum {ArgWeapon = 1, ArgBinding, ArgFuction}

	new pWeaponIndex = get_param(ArgWeapon)
	new pBinding = get_param(ArgBinding)

	new szFunctionName[32]
	get_string(ArgFuction, szFunctionName, charsmax(szFunctionName))

	Bind(pWeaponIndex, pBinding, iPluginId, get_func_id(szFunctionName, iPluginId))
}

stock Bind(pWeaponIndex, iBinding, iPluginId, iFunctionid)
{
	new rgBinding[Function];
	rgBinding[Function_PluginId] = iPluginId;
	rgBinding[Function_FunctionId] = iFunctionid;

	new Array:irgBindings = GetData(pWeaponIndex, CW_Data_Bindings);
	ArraySetArray(irgBindings, iBinding, rgBinding);
}

stock Array:InitWeaponBindings(pWeaponIndex) {
	new Array:irgBindings = ArrayCreate(Function, _:eBindWeapon);
	for (new i = 0; i < _:eBindWeapon; ++i) {
		new rgBinding[Function]= {-1, -1};
		ArrayPushArray(irgBindings, rgBinding);
	}

	SetData(pWeaponIndex, CW_Data_Bindings, irgBindings);
}

stock GetBinding(pWeaponIndex, eBindWeapon:iBinding, &iPluginId, &iFunctionId) {
	new Array:iszBindings = GetData(pWeaponIndex, CW_Data_Bindings)

	static rgBinding[Function]
	ArrayGetArray(iszBindings, _:iBinding, rgBinding, sizeof(rgBinding))

	if (rgBinding[Function_PluginId] == -1) {
		return false
	}

	if (rgBinding[Function_FunctionId] == -1) {
		return false
	}

	iPluginId = rgBinding[Function_PluginId]
	iFunctionId = rgBinding[Function_FunctionId]

	return true
}

stock any:GetData(pWeaponIndex, CW_Data:iParam) {
	return ArrayGetCell(Array:g_rgWeapons[iParam], pWeaponIndex)
}

stock SetData(pWeaponIndex, CW_Data:iParam, any:value) {
	ArraySetCell(Array:g_rgWeapons[iParam], pWeaponIndex, value)
}

stock any:ExecuteBindedFunction(eBindWeapon:iBinding, pEntity, any:...) {
	new pWeaponIndex = GetIndexByEntity(pEntity)

	new iPluginId, iFunctionId
	if (!GetBinding(pWeaponIndex, iBinding, iPluginId, iFunctionId)) {
		return PLUGIN_CONTINUE
	}

	if (callfunc_begin_i(iFunctionId, iPluginId) == 1)
	{
		switch (iBinding)
		{
			case WEAPON_BIND_SPAWN:
			{
				callfunc_push_int(pEntity)
			}
			case WEAPON_BIND_IDLE:
			{
				callfunc_push_int(pEntity)
				callfunc_push_float(Float:getarg(2))// Arg 2 = pIdleTime
				callfunc_push_int(getarg(3))// Arg 3 = pPlayer
			}
			case WEAPON_BIND_RELOAD:
			{
				callfunc_push_int(pEntity)
				callfunc_push_int(getarg(2)) // Arg 2 = pPlayer
				callfunc_push_int(getarg(3)) // Arg 3 = animation
			}
			case WEAPON_BIND_DEPLOY:
			{
				callfunc_push_int(pEntity)
				callfunc_push_int(getarg(2)) // Arg 2 = pPlayer
			}
			case WEAPON_BIND_PRIMARY_ATTACK:
			{
				callfunc_push_int(pEntity)
				callfunc_push_int(getarg(2)) // Arg 2 = pPlayer
				callfunc_push_int(getarg(3)) // Arg 3 = pWeaponClip
			}
			case WEAPON_BIND_SECONDARY_ATTACK:
			{
				callfunc_push_int(pEntity)
				callfunc_push_int(getarg(2)) // Arg 2 = pPlayer
			}
			case WEAPON_BIND_ANIM_SPEC_IDLE:
			{
				callfunc_push_int(pEntity)
			}
			case WEAPON_BIND_ANIM_DEPLOY:
			{
				callfunc_push_int(pEntity)
			}
		}

		return callfunc_end()
	}

	return PLUGIN_CONTINUE
}

stock UTIL_PrecacheWeaponList(const szWeaponList[])
{
	new szBuffer[128], pFile

	format(szBuffer, charsmax(szBuffer), "sprites/%s.txt", szWeaponList)
	precache_generic(szBuffer)

	if(!(pFile = fopen(szBuffer, "rb")))
		return

	new szSprName[64], iPos, zsSprCheck[64]

	while(!feof(pFile)) 
	{
		fgets(pFile, szBuffer, charsmax(szBuffer))
		trim(szBuffer)

		if(!strlen(szBuffer)) 
			continue

		if((iPos = containi(szBuffer, "640" )) == -1)
			continue
				
		format(szBuffer, charsmax(szBuffer), "%s", szBuffer[iPos+3])	
		trim(szBuffer)

		strtok(szBuffer, szSprName, charsmax(szSprName), szBuffer, charsmax(szBuffer), ' ', 1)
		trim(szSprName)
		
		formatex(zsSprCheck, charsmax(zsSprCheck), fmt("sprites/%s.spr", szSprName))

		if (file_exists(zsSprCheck))
			precache_generic(zsSprCheck)
	}

	fclose(pFile)
}

stock GetIndexByHandler(const szName[]) {
	new pWeaponIndex
	if (!TrieGetCell(aWeaponsMap, szName, pWeaponIndex)) {
		return CW_INVALID
	}
	return pWeaponIndex
}

stock GetIndexByEntity(pEnt)
{
	static pImpulse
	pImpulse = get_entvar(pEnt, var_impulse)

	if (pImpulse >= CW_ARRAYID_OFFSET && pImpulse < CW_ARRAYID_OFFSET + xDataWeaponCount) {
		return (pImpulse - CW_ARRAYID_OFFSET)
	}

	return CW_INVALID
}

stock bool:IsWeaponValid(pEnt)
{
	return get_entvar(pEnt, var_impulse) >= CW_ARRAYID_OFFSET
}

stock GetWeaponArrayId(pEnt)
{
	return get_entvar(pEnt, var_impulse) - CW_ARRAYID_OFFSET
}