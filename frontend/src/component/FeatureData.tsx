import {Feature, FeatureName} from "../service/api";
import {
    Stack,
    Typography
} from "@mui/material";
import React from "react";
import {DiscordChannel} from "./DiscordChannel";
import {FeatureDataTable} from "./FeatureDataTable";

function getCustomizedElement(feature: Feature, guildId: string) {
    switch (feature.name) {
        case FeatureName.poopName:
        case FeatureName.mentions:
            return <Typography>No data.</Typography>;
        case FeatureName.joinLogs:
        case FeatureName.modLogs:
            return <FeatureDataTable data={{"Target channel": <DiscordChannel guildId={guildId} channelId={feature.data.value} />}} />;
        case FeatureName.jellyfin:
        case FeatureName.kavita:
            return <FeatureDataTable data={{"Create instance channel": feature.data.create_instance_role}} />;
        case FeatureName.emojiReact:
            return <FeatureDataTable data={{
                "Use builtin": feature.data.use_builtin.toString(),
                "Mode": feature.data.mode.toString(),
                "Process other bots messages": feature.data.process_other_bots.toString(),
            }} />;
        default:
            return <Typography>Cannot render feature data (type: {feature.name})</Typography>;
    }
}

export interface FeatureDataProps {
    feature: Feature,
    guildId: string
}

export function FeatureData({feature, guildId}: FeatureDataProps) {
    return <Stack direction="column">
        <Typography fontWeight="bold">Data: </Typography>
        <Typography>{getCustomizedElement(feature, guildId)}</Typography>
    </Stack>
}
