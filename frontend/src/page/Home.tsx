import React, {Suspense, use} from 'react';

import {Base} from "../component/Base";
import {Container, Grid2, Paper, Typography} from "@mui/material";
import {BotInfoElement} from "../component/BotInfoElement";
import {fetchBotInfo} from "../service/api";
import {formatRelativeTime} from "../util";

const botInfoStatusPromise = fetchBotInfo();

function BotInfoWidget() {
    const botInfoStats = use(botInfoStatusPromise);

    const uptime = formatRelativeTime(new Date(botInfoStats.uptime));

    return <>
        <Typography>Bot Info</Typography>
        <Grid2 container spacing={1} sx={{mt: '5px'}}>
            <BotInfoElement name="Nyxx version" value={botInfoStats.nyxxVersion} />
            <BotInfoElement name="Bot version" value={botInfoStats.version} />
            <BotInfoElement name="Dart version" value={botInfoStats.platform} />
            <BotInfoElement name="Up since" value={uptime} />
            <BotInfoElement name="Memory usage" value={botInfoStats.memoryUsageString} />
        </Grid2>
    </>;
}

function CacheInfoWidget() {
    const botInfoStats = use(botInfoStatusPromise);

    return <>
        <Typography>Cache Info</Typography>
        <Grid2 container spacing={1} sx={{mt: '5px'}}>
            <BotInfoElement name="Cached channels" value={botInfoStats.cachedChannels} />
            <BotInfoElement name="Cached messages" value={botInfoStats.cachedMessages} />
            <BotInfoElement name="Cached guilds" value={botInfoStats.cachedGuilds} />
            <BotInfoElement name="Cached users" value={botInfoStats.cachedUsers} />
            <BotInfoElement name="Cached voice states" value={botInfoStats.cachedVoiceStates} />
        </Grid2>
    </>;
}

function ModuleInfoWidget() {
    const botInfoStats = use(botInfoStatusPromise);

    const docsUpdatedAt = formatRelativeTime(new Date(botInfoStats.docsUpdate));

    return <>
        <Typography>Module Info</Typography>
        <Grid2 container spacing={1} sx={{mt: '5px'}}>
            <BotInfoElement name="Tags count" value={botInfoStats.totalTagsCount} />
            <BotInfoElement name="Reminder count" value={botInfoStats.totalReminderCount} />
            <BotInfoElement name="Last docs update" value={docsUpdatedAt} />
        </Grid2>
    </>;
}

export default function Home() {
    return (
        <Base>
            <Container>
                <Paper elevation={1} sx={{p: '5px'}}>
                    <Suspense fallback={<div>Loading...</div>}>
                        <BotInfoWidget />
                    </Suspense>
                </Paper>
                <Paper elevation={1} sx={{mt: '10px', p: '5px'}}>
                    <Suspense fallback={<div>Loading...</div>}>
                        <CacheInfoWidget />
                    </Suspense>
                </Paper>
                <Paper elevation={1} sx={{mt: '10px', p: '5px'}}>
                    <Suspense fallback={<div>Loading...</div>}>
                        <ModuleInfoWidget />
                    </Suspense>
                </Paper>
            </Container>
        </Base>
    );
}
