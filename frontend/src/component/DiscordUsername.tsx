import {Avatar, Stack, Typography} from "@mui/material";
import React, {useEffect, useState} from "react";
import {fetchMemberDetails, MemberDetails} from "../service/api";
import {getUserAvatar} from "../constants";

interface DiscordUsernameProps {
    guildId: string,
    userId: string
}

export function DiscordUsername({guildId, userId}: DiscordUsernameProps) {
    const [member, setMember] = useState<MemberDetails|null>(null);

    useEffect(() => {
        fetchMemberDetails(guildId, userId).then(m => setMember(m));
    }, []);

    if (member == null) {
        return <Stack direction="row" spacing={2} alignItems="center" height={'100%'}>
            <Typography>{userId}</Typography>
        </Stack>;
    }

    return <Stack direction="row" spacing={2} alignItems="center" height={'100%'}>
        <Avatar src={getUserAvatar(member?.id, member?.user.avatar as string)}/>
        <Typography>{member?.nick ?? member?.user.username}</Typography>
    </Stack>;
}
