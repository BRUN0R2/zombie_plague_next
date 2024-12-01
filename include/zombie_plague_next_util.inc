#if defined _zombie_plague_next_util_included
	#endinput
#endif

#define _zombie_plague_next_util_included

enum ProtectionState
{
    Protection_NoSet = 0,
    Protection_Active,
    Protection_Expired,
};

stock ProtectionState:GetProtectionState(const this)
{
	static Float:ProtectionEndTime
	ProtectionEndTime = get_member(this, m_flSpawnProtectionEndTime);
	if (ProtectionEndTime <= 0.0) return Protection_NoSet;
	if (ProtectionEndTime >= get_gametime()) return Protection_Active;
	return Protection_Expired;
}

stock zpn_util_screenshake(id, amplitude, duration, frequency)
{
	static xMsg; if(!xMsg) xMsg = get_user_msgid("ScreenShake");
	static MSG_DEST; MSG_DEST = id ? MSG_ONE : MSG_ALL;

	message_begin(MSG_DEST, xMsg, .player = id);
	write_short((1<<12) * amplitude);	// amplitude
	write_short((1<<12) * duration);	// duration
	write_short((1<<12) * frequency);	// frequency
	message_end();
}