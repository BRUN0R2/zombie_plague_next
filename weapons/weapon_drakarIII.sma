#include <amxmodx>
#include <fakemeta_util>
#include <hamsandwich>
#include <reapi>
#include <api_custom_weapons>
#include <api_custom_weapons_const>

#define PLUGIN  "[ZPN] Weapon: DrakarIII"
#define VERSION "1.0"
#define AUTHOR  "BRUN0"

//const WeaponIdType:WEAPON_ID = WEAPON_AK47

new const SOUNDS[][]=
{
	"zpn/weapons/drakarIII/fire.wav",		// 00
	"zpn/weapons/drakarIII/beep.wav",		// 01
	"zpn/weapons/drakarIII/boltpull.wav", 	// 02
	"zpn/weapons/drakarIII/boltpull01.wav", // 03
	"zpn/weapons/drakarIII/boltpull10.wav",	// 04
	"zpn/weapons/drakarIII/boltpull12.wav",	// 05
	"zpn/weapons/drakarIII/clipin.wav",		// 06
	"zpn/weapons/drakarIII/clipin20.wav",	// 07
	"zpn/weapons/drakarIII/clipout.wav",	// 08
	"zpn/weapons/drakarIII/draw.wav",		// 09
	"zpn/weapons/drakarIII/shoot3.wav",		// 10
	"zpn/weapons/drakarIII/shoot4.wav",		// 11
	"zpn/weapons/drakarIII/shoot5.wav",		// 12
	"zpn/weapons/drakarIII/shoot6.wav",		// 13
	"zpn/weapons/drakarIII/shoot_end.wav",	// 14
}

enum
{
	ANIM_A_IDLE = 0,
	ANIM_A_SHOOT1,
	ANIM_A_SHOOT2,
	ANIM_A_RELOAD,
	ANIM_A_DRAW,
	ANIM_A_SHOOT3,
	ANIM_A_SHOOT4,
	ANIM_A_SHOOT5,

	ANIM_B_IDLE,
	ANIM_B_SHOOT1,
	ANIM_B_SHOOT2,
	ANIM_B_RELOAD,
	ANIM_B_DRAW,
	ANIM_B_SHOOT3,
	ANIM_B_SHOOT4,
	ANIM_B_SHOOT5,

	ANIM_C_IDLE,
	ANIM_C_SHOOT1,
	ANIM_C_SHOOT2,
	ANIM_C_RELOAD,
	ANIM_C_DRAW,
	ANIM_C_SHOOT3,
	ANIM_C_SHOOT4,
	ANIM_C_SHOOT5,

	ANIM_RELOAD1,
	ANIM_RELOAD2,
	ANIM_RELOAD3,
	ANIM_RELOAD4,
	ANIM_RELOAD5,

	ANIM_DUMMY,
};

enum _:WeaponStates
{
	STATE_NORMAL,
	STATE_ELETRIC,
}

new CWHandler

public plugin_precache()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	CWHandler = CW_weapon_init("weapon_drakarIII")

	precache_sounds(SOUNDS)

	CW_weapon_set_var(CWHandler, WEAPON_VAR_REFERENCE, "weapon_ak47")
	CW_weapon_set_var(CWHandler, WEAPON_VAR_WEAPONLIST, "zpn/weapons/drakarIII/hud")
	CW_weapon_set_var(CWHandler, WEAPON_VAR_ANIM_EXTENSION, "ak47") // On deploy
	CW_weapon_set_var(CWHandler, WEAPON_VAR_GIVE_TYPE, GT_DROP_AND_REPLACE)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_SLOT, 1)

	CW_weapon_set_var(CWHandler, WEAPON_VAR_V_MODEL, "models/zpn/weapons/drakarIII/model_v.mdl")
	CW_weapon_set_var(CWHandler, WEAPON_VAR_P_MODEL, "models/zpn/weapons/drakarIII/model_p.mdl")
	CW_weapon_set_var(CWHandler, WEAPON_VAR_W_MODEL, "models/zpn/weapons/drakarIII/model_w.mdl")

	CW_weapon_set_var(CWHandler, WEAPON_VAR_DAMAGE_GENERIC, 100.0)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_DAMAGE_HEAD, 320.0)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_DAMAGE_CHEST, 230.0)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_DAMAGE_STOMACH, 200.0)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_DAMAGE_ARMS, 180.0)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_DAMAGE_LEGS, 130.0)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_ANIM_DUMMY, ANIM_DUMMY)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_MAX_CLIP, 60)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_MAX_AMMO, 240)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_RELOAD_TIME, 2.55)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_CAN_DROP, true)

	CW_weapon_bind(CWHandler, WEAPON_BIND_SPAWN, "@OnSpawn")
	CW_weapon_bind(CWHandler, WEAPON_BIND_IDLE, "@OnIdle")
	CW_weapon_bind(CWHandler, WEAPON_BIND_RELOAD, "@OnReload")
	CW_weapon_bind(CWHandler, WEAPON_BIND_DEPLOY, "@OnDeploy")
	CW_weapon_bind(CWHandler, WEAPON_BIND_PRIMARY_ATTACK, "@OnPrimaryAttack")
	CW_weapon_bind(CWHandler, WEAPON_BIND_SECONDARY_ATTACK, "@OnSecondaryAttack")
	CW_weapon_bind(CWHandler, WEAPON_BIND_ANIM_SPEC_IDLE, "@OnAnimSpecIdle")
	CW_weapon_bind(CWHandler, WEAPON_BIND_ANIM_DEPLOY, "@OnAnimDeploy")
}

@OnSpawn(weapon)
{
	set_member(weapon, m_Weapon_bHasSecondaryAttack, true)
	set_member(weapon, m_Weapon_iWeaponState, STATE_NORMAL)
}

@OnIdle(weapon, Float:idleTime, player)
{
	ExecuteHamB(Ham_Weapon_ResetEmptySound, weapon)
	if (idleTime > 0.0) {
		return
	}

	set_member(weapon, m_Weapon_flTimeWeaponIdle, 99999.0)
	rg_weapon_send_animation(weapon, ANIM_A_IDLE)
}

@OnReload(weapon, player, animation)
{
	//rg_set_animation(player, PLAYER_RELOAD)
	//rg_weapon_send_animation(weapon, ANIM_A_RELOAD)

	SetHookChainArg(3, ATYPE_INTEGER, ANIM_A_RELOAD)
}

@OnDeploy(weapon, player)
{
	set_entvar(weapon, var_body, 1)
}

@OnPrimaryAttack(weapon, player, clip)
{
	rg_set_animation(player, PLAYER_ATTACK1)

	set_member(weapon, m_Weapon_iClip, --clip)
	set_member(player, m_iWeaponVolume, NORMAL_GUN_VOLUME)
	set_member(player, m_iWeaponFlash, BRIGHT_GUN_FLASH)
	set_member(player, m_flEjectBrass, get_gametime())

	rg_weapon_send_animation(weapon, ANIM_A_SHOOT1)

	static Float:aiming[3], Float:src[3]
	GunPositionAndAiming(player, src, aiming)

	rh_emit_sound2(player, 0, CHAN_WEAPON, SOUNDS[0])

	rg_fire_bullets3(
		weapon,
		player,
		src,
		aiming,
		0.0,
		8192.0,
		2,
		BULLET_PLAYER_762MM,
		80,
		1.0,
		false,
		get_member(player, random_seed)
	)

	set_member(weapon, m_Weapon_flNextPrimaryAttack, 0.15)
	set_member(weapon, m_Weapon_flNextSecondaryAttack, 0.4)
	set_member(weapon, m_Weapon_flTimeWeaponIdle, 2.0)
}

@OnSecondaryAttack(weapon, player)
{
	set_member(weapon, m_Weapon_flNextPrimaryAttack, 0.2)
	set_member(weapon, m_Weapon_flNextSecondaryAttack, 0.4)
}

@OnAnimSpecIdle(weapon)
{
	rg_weapon_send_animation(weapon, ANIM_A_IDLE)
}

@OnAnimDeploy(weapon)
{
	rg_weapon_send_animation(weapon, ANIM_A_DRAW)
}