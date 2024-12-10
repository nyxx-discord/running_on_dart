import {Container, Grid2, Paper, Typography} from "@mui/material";
import React from "react";
import {BotInfo} from "../../service/useApi";
import {BotInfoElement} from "./BotInfoElement";
import {parseISO, formatRelative} from "date-fns";

type BotInfoGridProps = {
    botInfoStats: BotInfo,
};

export function BotInfoGrid({botInfoStats}: BotInfoGridProps) {
    const docsUpdatedAt = formatRelative(parseISO(botInfoStats.docsUpdate), new Date());
    const uptime = formatRelative(parseISO(botInfoStats.uptime), new Date());

    return (
        <Container>
            <Paper elevation={1} sx={{p: '5px'}}>
                <Typography>Bot Info</Typography>
                <Grid2 container spacing={1} sx={{mt: '5px'}}>
                    <BotInfoElement name="Nyxx version" value={botInfoStats.nyxxVersion} />
                    <BotInfoElement name="Bot version" value={botInfoStats.version} />
                    <BotInfoElement name="Dart version" value={botInfoStats.platform} />
                    <BotInfoElement name="Up since" value={uptime} />
                    <BotInfoElement name="Memory usage" value={botInfoStats.memoryUsageString} />
                </Grid2>
            </Paper>
            <Paper elevation={1} sx={{mt: '10px', p: '5px'}}>
                <Typography>Cache Info</Typography>
                <Grid2 container spacing={1} sx={{mt: '5px'}}>
                    <BotInfoElement name="Cached channels" value={botInfoStats.cachedChannels} />
                    <BotInfoElement name="Cached messages" value={botInfoStats.cachedMessages} />
                    <BotInfoElement name="Cached guilds" value={botInfoStats.cachedGuilds} />
                    <BotInfoElement name="Cached users" value={botInfoStats.cachedUsers} />
                    <BotInfoElement name="Cached voice states" value={botInfoStats.cachedVoiceStates} />
                </Grid2>
            </Paper>
            <Paper elevation={1} sx={{mt: '10px', p: '5px'}}>
                <Typography>Module Info</Typography>
                <Grid2 container spacing={1} sx={{mt: '5px'}}>
                    <BotInfoElement name="Tags count" value={botInfoStats.totalTagsCount} />
                    <BotInfoElement name="Reminder count" value={botInfoStats.totalReminderCount} />
                    <BotInfoElement name="Last docs update" value={docsUpdatedAt} />
                </Grid2>
            </Paper>
        </Container>
    );
}
