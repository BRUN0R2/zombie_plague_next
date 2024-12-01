#include <amxmodx>
#include <reapi>
#include <zombie_plague_next>
#include <zombie_plague_next_const>

#include <api_custom_weapons>

#define PLUGIN  "[ZPN] Item: Ethereal"
#define VERSION "1.0"
#define AUTHOR  "BRUN0"

new item

public plugin_precache()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	item = zpn_item_init()

	zpn_item_set_prop(item, ITEM_PROP_REGISTER_TEAM, ITEM_TEAM_HUMAN)
	zpn_item_set_prop(item, ITEM_PROP_REGISTER_NAME, "Ethereal")
	zpn_item_set_prop(item, ITEM_PROP_REGISTER_COST, 0)
}

public zpn_item_selected_post(const id, const item_id)
{
	if(item_id != item)
		return

	CW_weapon_give(id, "weapon_ethereal")
}