#if defined _api_json_settings_included
	#endinput
#endif
#define _api_json_settings_included

#pragma reqlib api_json_settings
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib api_json_settings
#endif

/**
 * Removes the section and all its keys
 *
 * @param file_name_path	.json file path
 * @param section			section name
 *
 * @return					true if the section was found and removed, false otherwise
 */
native bool:json_setting_remove_section(const file_name_path[], const section[]);

/**
 * Remove the key from section
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key to remove
 *
 * @return					true if the section and key was found and removed, false otherwise
 */
native bool:json_setting_remove_key(const file_name_path[], const section[], const key[]);

/**
 * Returns the integer value of the key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param int_value			integer return variable
 * @param check_type 		false to not check if the value is int
 *
 * @return					true if the section and key exists, false otherwise
 */
native bool:json_setting_get_int(const file_name_path[], const section[], const key[], &int_value, const bool:check_type = true);

/**
 * Defines an integer value for key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param int_value			integer value for key
 * @param replace			true to always replace the key value
 * @param check_type 		false to not check if the value is int
 *
 * @return					true if the key was added or replaced successfully, false otherwise
 */
native bool:json_setting_set_int(const file_name_path[], const section[], const key[], int_value, const bool:replace = false, const bool:check_type = true);

/**
 * Returns the boolean value of the key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param bool_value		bool return variable
 * @param check_type 		false to not check if the value is bool
 *
 * @return					true if the section and key exists, false otherwise
 */
native bool:json_setting_get_bool(const file_name_path[], const section[], const key[], &bool:bool_value, const bool:check_type = true);

/**
 * Defines an boolean value for key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param bool_value		bool value for key
 * @param replace			true to always replace the key value
 * @param check_type 		false to not check if the value is bool
 *
 * @return					true if the key was added or replaced successfully, false otherwise
 */
native bool:json_setting_set_bool(const file_name_path[], const section[], const key[], bool:bool_value, const bool:replace = false, const bool:check_type = true);

/**
 * Returns the float value of the key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param float_value		float return variable
 * @param check_type 		false to not check if the value is float
 *
 * @return					true if the section and key exists, false otherwise
 */
native bool:json_setting_get_float(const file_name_path[], const section[], const key[], &Float:float_value, const bool:check_type = true);

/**
 * Defines an float value for key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param float_value		float value for key
 * @param replace			true to always replace the key value
 * @param check_type 		false to not check if the value is float
 *
 * @return					true if the key was added or replaced successfully, false otherwise
 */
native bool:json_setting_set_float(const file_name_path[], const section[], const key[], Float:float_value, const bool:replace = false, const bool:check_type = true);

/**
 * Returns the string value of the key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param buffer			buffer to copy value to
 * @param len				maximum size of the buffer
 * @param check_type 		false to not check if the value is string
 *
 * @return					true if the section and key exists, false otherwise
 */
native bool:json_setting_get_string(const file_name_path[], const section[], const key[], buffer[], len, const bool:check_type = true);

/**
 * Defines an string value for key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param buffer			string value for key
 * @param replace			true to always replace the key value
 * @param check_type 		false to not check if the value is string
 *
 * @return					true if the key was added or replaced successfully, false otherwise
 */
native bool:json_setting_set_string(const file_name_path[], const section[], const key[], buffer[], const bool:replace = false, const bool:check_type = true);

/**
 * Returns the array int value of the key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param array_value		array int return variable
 * @param check_type 		false to not check if the value is array
 *
 * @return					true if the section and key exists, false otherwise
 */
native bool:json_setting_get_int_arr(const file_name_path[], const section[], const key[], Array:array_value = Invalid_Array, const bool:check_type = true);

/**
 * Defines an array int value for key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param array_value		array int values for key
 * @param replace			true to always replace the key value
 * @param check_type 		false to not check if the value is array
 *
 * @return					true if the key was added or replaced successfully, false otherwise
 */
native bool:json_setting_set_int_arr(const file_name_path[], const section[], const key[], Array:array_value = Invalid_Array, const bool:replace = false, const bool:check_type = true);

/**
 * Returns the array string value of the key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param array_value		array string return variable
 * @param check_type 		false to not check if the value is array
 *
 * @return					true if the section and key exists, false otherwise
 */
native bool:json_setting_get_string_arr(const file_name_path[], const section[], const key[], Array:array_value = Invalid_Array, const bool:check_type = true);

/**
 * Defines an array string value for key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param array_value		array string values for key
 * @param replace			true to always replace the key value
 * @param check_type 		false to not check if the value is array
 *
 * @return					true if the key was added or replaced successfully, false otherwise
 */
native bool:json_setting_set_string_arr(const file_name_path[], const section[], const key[], Array:array_value = Invalid_Array, const bool:replace = false, const bool:check_type = true);

/**
 * Returns the array float value of the key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param array_value		array float return variable
 * @param check_type 		false to not check if the value is array
 *
 * @return					true if the section and key exists, false otherwise
 */
native bool:json_setting_get_float_arr(const file_name_path[], const section[], const key[], Array:array_value = Invalid_Array, const bool:check_type = true);

/**
 * Defines an array float value for key
 *
 * @param file_name_path	.json file path
 * @param section			section name
 * @param key				key name
 * @param array_value		array float values for key
 * @param replace			true to always replace the key value
 * @param check_type 		false to not check if the value is array
 *
 * @return					true if the key was added or replaced successfully, false otherwise
 */
native bool:json_setting_set_float_arr(const file_name_path[], const section[], const key[], Array:array_value = Invalid_Array, const bool:replace = false, const bool:check_type = true);