import {Stack, Tooltip, Typography} from "@mui/material";
import React, {useEffect, useState} from "react";
import {Channel, fetchChannelDetails} from "../service/api";
import {cache} from "../service/cache";

interface DiscordChannelProps {
    guildId: string,
    channelId: string
}

export function DiscordChannel({guildId, channelId}: DiscordChannelProps) {
    const [channel, setChannel] = useState<Channel|null>(null);

    useEffect(() => {
        cache(`${guildId}_${channelId}`, () => fetchChannelDetails(guildId, channelId)).then(m => setChannel(m));
    }, []);

    if (channel == null) {
        return <Stack direction="row" spacing={2} alignItems="center" height={'100%'}>
            <Typography>{channelId}</Typography>
        </Stack>;
    }

    return <Tooltip title={channelId} arrow placement="bottom-start">
        <Stack direction="row" spacing={2} alignItems="center" height={'100%'}>
            <Typography>{channel?.name}</Typography>
        </Stack>
    </Tooltip>;
}
