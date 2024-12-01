#include <amxmodx>
#include <fakemeta_util>
#include <hamsandwich>
#include <reapi>
#include <api_custom_weapons>
#include <api_custom_weapons_const>

#define PLUGIN  "[ZPN] Weapon: Ethereal"
#define VERSION "1.0"
#define AUTHOR  "BRUN0"

const WeaponIdType:WEAPON_ID = WEAPON_AUG

new const SOUNDS[][]=
{
	"zpn/weapons/ethereal/shoot.wav",		// 00
	"zpn/weapons/ethereal/idle.wav",		// 01
	"zpn/weapons/ethereal/shock.wav", 		// 02
	"zpn/weapons/ethereal/draw.wav", 		// 03
	"zpn/weapons/ethereal/reload.wav",		// 04
}

enum _:WeaponAnim
{
	ANIM_IDLE = 0,
	ANIM_RELOAD,
	ANIM_DRAW,
	ANIM_SHOTS,
	ANIM_DUMMY,
}

enum _:WeaponStates
{
	STATE_NORMAL,
	STATE_ELETRIC,
}

new CWHandler

public plugin_precache()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	CWHandler = CW_weapon_init("weapon_ethereal")

	precache_sounds(SOUNDS)

	CW_weapon_set_var(CWHandler, WEAPON_VAR_REFERENCE, "weapon_aug")
	CW_weapon_set_var(CWHandler, WEAPON_VAR_WEAPONLIST, "zpn/weapons/ethereal/hud")
	CW_weapon_set_var(CWHandler, WEAPON_VAR_ANIM_EXTENSION, "ak47") // On deploy
	CW_weapon_set_var(CWHandler, WEAPON_VAR_GIVE_TYPE, GT_DROP_AND_REPLACE)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_SLOT, 1)

	CW_weapon_set_var(CWHandler, WEAPON_VAR_V_MODEL, "models/zpn/weapons/ethereal/model_v.mdl")
	CW_weapon_set_var(CWHandler, WEAPON_VAR_P_MODEL, "models/zpn/weapons/ethereal/model_p.mdl")
	CW_weapon_set_var(CWHandler, WEAPON_VAR_W_MODEL, "models/zpn/weapons/ethereal/model_w.mdl")

	CW_weapon_set_var(CWHandler, WEAPON_VAR_DAMAGE_GENERIC, 80.0)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_DAMAGE_HEAD, 200.0)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_DAMAGE_CHEST, 175.0)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_DAMAGE_STOMACH, 150.0)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_DAMAGE_ARMS, 120.0)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_DAMAGE_LEGS, 100.0)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_ANIM_DUMMY, ANIM_DUMMY)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_MAX_CLIP, 50)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_MAX_AMMO, 200)
	CW_weapon_set_var(CWHandler, WEAPON_VAR_RELOAD_TIME, 3.033)
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

	set_member(weapon, m_Weapon_flTimeWeaponIdle, 3.5)
	rg_weapon_send_animation(weapon, ANIM_IDLE)
}

@OnReload(weapon, player)
{
	//rg_set_animation(player, PLAYER_RELOAD)
	rg_weapon_send_animation(weapon, ANIM_RELOAD)
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

	rg_weapon_send_animation(weapon, ANIM_SHOTS)

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
	rh_emit_sound2(player, player, CHAN_WEAPON, SOUNDS[2])

	set_member(weapon, m_Weapon_flNextPrimaryAttack, 0.2)
	set_member(weapon, m_Weapon_flNextSecondaryAttack, 0.4)
}

@OnAnimSpecIdle(weapon)
{
	rg_weapon_send_animation(weapon, ANIM_IDLE)
}

@OnAnimDeploy(weapon)
{
	rg_weapon_send_animation(weapon, ANIM_DRAW)
}