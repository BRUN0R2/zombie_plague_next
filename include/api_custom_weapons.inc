#if defined _api_custom_weapons_included
	#endinput
#endif
#define _api_custom_weapons_included

#pragma reqlib api_custom_weapons
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib api_custom_weapons
#endif

/*
* Init new weapon, use in: plugin_precache
*/
native CW_weapon_init(const weaponHandler[]);

/*
* Get var info from weapon
*/
native CW_weapon_get_var(weapon, eVarWeapon:prop, any:...);

/*
* Set var to weapon
*/
native CW_weapon_set_var(weapon, eVarWeapon:prop, any:...);

/*
* Bind functions to weapon
*/
native CW_weapon_bind(weapon, eBindWeapon:binding, const functionName[]);

/*
* Find weapon by handler
*/
native CW_weapon_find(const handle[]);

/*
* Player who will receive the weapon
* Give weapon by handler
*/
native CW_weapon_give(const player, const handle[]);

/*
* Player who will receive the weapon
* Give weapon by handler
* This function delivers random weapons
*/
native CW_weapon_rd_give(const player);

stock precache_sounds(const sounds[][], const size = sizeof(sounds)) {
	for (new sound = 0; sound < size; ++sound) {
		precache_sound(sounds[sound]);
	}
}

stock getAimingAngle(const player, Float:aimingAngle[3])
{
	static Float:viewAngle[3], Float:punchAngle[3]
	get_entvar(player, var_v_angle, viewAngle)
	get_entvar(player, var_punchangle, punchAngle)

	for (new i = 0; i < sizeof(viewAngle); ++i) {
		aimingAngle[i] = viewAngle[i] + punchAngle[i]
	}
}

stock GunPositionAndAiming(const player, Float:src[3], Float:aiming[3])
{
	static Float:viewAngle[3]
	getAimingAngle(player, viewAngle)
	engfunc(EngFunc_MakeVectors, viewAngle)
	ExecuteHamB(Ham_Player_GetGunPosition, player, src)
	global_get(glb_v_forward, aiming)
}