#include <amxmodx>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new class

public plugin_init()
{
	register_plugin("[ZPN] Class: Zombie Fast", "1.0", "Wilian M.")
}

public plugin_precache()
{
	class = zpn_class_init()
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_TYPE, CLASS_TEAM_TYPE_ZOMBIE)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_NAME, "Fast")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_INFO, "Nice speed")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_MODEL, "zombie_source")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_MODEL_VIEW, "models/v_knife_zombie.mdl")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_SPEED, 450.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_HEALTH, 1200.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_GRAVITY, 0.5)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_KNOCKBACK, 1.0)
}