import {Avatar, Stack, Tooltip, Typography} from "@mui/material";
import React, {useEffect, useState} from "react";
import {fetchMemberDetails, MemberDetails} from "../service/api";
import {getUserAvatar} from "../constants";
import {cache} from "../service/cache";

interface DiscordUsernameProps {
    guildId: string,
    userId: string
}

export function DiscordUserName({guildId, userId}: DiscordUsernameProps) {
    const [member, setMember] = useState<MemberDetails|null>(null);

    useEffect(() => {
        cache(`${guildId}_${userId}`, () => fetchMemberDetails(guildId, userId)).then(m => setMember(m));
    }, []);

    if (member == null) {
        return <Stack direction="row" spacing={2} alignItems="center" height={'100%'}>
            <Typography>{userId}</Typography>
        </Stack>;
    }

    const avatarSrc = member.user.avatar
        ? getUserAvatar(member?.id, member?.user.avatar as string)
        : undefined;

    return <Tooltip title={userId} arrow placement="bottom-start">
        <Stack direction="row" spacing={2} alignItems="center" height={'100%'}>
            <Avatar src={avatarSrc} sx={{ width: 24, height: 24 }}/>
            <Typography>{member?.nick ?? member?.user.username}</Typography>
        </Stack>
    </Tooltip>;
}
