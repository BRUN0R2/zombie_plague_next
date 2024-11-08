#include <amxmodx>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

new class

public plugin_init()
{
	register_plugin("[ZPN] Class: Human Default", "1.0", "Wilian M.")
}

public plugin_precache()
{
	class = zpn_class_init()
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_TYPE, CLASS_TEAM_TYPE_HUMAN)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_NAME, "Default")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_INFO, "Balanced")
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_MODEL, "sas") // pode setar uma model 'diferente' para a classe, ou remover esta linha.
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_SPEED, 280.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_HEALTH, 120.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_ARMOR, 15.0)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_GRAVITY, 0.5)
	zpn_class_set_prop(class, CLASS_PROP_REGISTER_KNOCKBACK, 1.0)
}