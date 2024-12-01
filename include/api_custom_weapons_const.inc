#if defined _api_custom_weapons_const_included
	#endinput
#endif

#define _api_custom_weapons_const_included

#define cw_invalid_array(%0) (%0 == Invalid_Array || !ArraySize(%0))
#define cw_null_string(%0) bool:(%0[0] == EOS)

#define CW_INVALID -1
#define CW_INVALID_DAMAGE -1.0

#define CW_ARRAYID_OFFSET 1000

enum CW_Data {
	CW_Data_Bindings,
	CW_Data_Max,
};

enum eVarWeapon
{
	WEAPON_VAR_HANDLE = 0,		// string [64]
	WEAPON_VAR_REFERENCE,		// string [64]
	WEAPON_VAR_REFERENCE,		// string [64]
	WEAPON_VAR_WEAPONLIST,		// string [64]
	WEAPON_VAR_ANIM_EXTENSION,	// string [64]
	WEAPON_VAR_GIVE_TYPE,		// GiveType
	WEAPON_VAR_SLOT,			// Int
	WEAPON_VAR_V_MODEL,			// string [64]
	WEAPON_VAR_P_MODEL,			// string [64]
	WEAPON_VAR_W_MODEL,			// string [64]
	WEAPON_VAR_DAMAGE_GENERIC,	// Float
	WEAPON_VAR_DAMAGE_HEAD,		// Float
	WEAPON_VAR_DAMAGE_CHEST,	// Float
	WEAPON_VAR_DAMAGE_STOMACH,	// Float
	WEAPON_VAR_DAMAGE_ARMS,		// Float
	WEAPON_VAR_DAMAGE_LEGS,		// Float
	WEAPON_VAR_ANIM_IDLE,		// Int
	WEAPON_VAR_ANIM_DUMMY,		// Int
	WEAPON_VAR_MAX_CLIP,		// Int
	WEAPON_VAR_MAX_AMMO,		// Int
	WEAPON_VAR_RELOAD_TIME,		// Float
	WEAPON_VAR_CAN_DROP,		// Bool
};

enum eBindWeapon
{
	WEAPON_BIND_SPAWN,
	WEAPON_BIND_IDLE,
	WEAPON_BIND_RELOAD,
	WEAPON_BIND_DEPLOY,
	WEAPON_BIND_PRIMARY_ATTACK,
	WEAPON_BIND_SECONDARY_ATTACK,
	WEAPON_BIND_ANIM_SPEC_IDLE,
	WEAPON_BIND_ANIM_DEPLOY,
};