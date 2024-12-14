import React, {Suspense, use} from 'react';
import {Base} from "../../component/Base";
import {fetchGuilds, Guild} from "../../service/api";
import {DataGrid, GridColDef} from "@mui/x-data-grid";
import {Alert, Avatar, Stack, Tooltip, Typography} from "@mui/material";
import {getGuildIcon} from "../../constants";

const columns: GridColDef[] = [
    { field: 'name', headerName: 'Name', flex: 1, renderCell: params => params.value},
    { field: 'cachedMembers', headerName: 'Members', minWidth: 100 },
    { field: 'cachedChannels', headerName: 'Channels', minWidth: 100 },
    { field: 'cachedMessages', headerName: 'Messages', minWidth: 100 },
    { field: 'cachedRoles', headerName: 'Roles', minWidth: 100 },
    { field: 'enabledFeatures', headerName: 'Features', minWidth: 100, renderCell: params => {
        return <Stack direction="row" spacing={2} alignItems="center" height={'100%'}>
                <Tooltip title={params.value.join(', ')} arrow placement="bottom-start">
                    <Typography>{params.value.length}</Typography>
                </Tooltip>
            </Stack>
        }
    },
    { field: 'tagsCount', headerName: 'Tags', minWidth: 100 },
];

type GuildRowDef = {
    id: string,
    name: React.JSX.Element|string,
    cachedMembers: number,
    cachedChannels: number,
    cachedMessages: number,
    cachedRoles: number,
    enabledFeatures: string[],
    tagsCount: number,
};

function getGuildNameElement(guild: Guild): React.JSX.Element|string {
    const elements = [<Typography>{guild.name}</Typography>];

    if (guild.icon != null) {
        elements.push(<Avatar src={getGuildIcon(guild.id, guild.icon as string)}/>);
    }

    return <Stack direction="row" spacing={2} alignItems="center" height={'100%'}>
        {elements.reverse()}
    </Stack>;
}

function mapApiDataToRows(guilds: Guild[]): GuildRowDef[] {
    return guilds.map(guild => {
        return {
            id: guild.id,
            name: getGuildNameElement(guild),
            cachedMembers: guild.cachedMembers,
            cachedChannels: guild.cachedChannels,
            cachedMessages: guild.cachedMessages,
            cachedRoles: guild.cachedRoles,
            enabledFeatures: guild.enabledFeatures,
            tagsCount: guild.tagsCount,
        } as GuildRowDef;
    });
}

const guildDataPromise = fetchGuilds().then(guilds => {
    return mapApiDataToRows(guilds);
});

function Grid() {
    const rows = use(guildDataPromise);

    return (
        <DataGrid rows={rows} columns={columns}/>
    );
}

export default function Guilds() {
    return (
        <Base>
            <Stack direction="column" spacing={1}>
            <Alert severity="error">Table represents cached data, that is available for bot at the moment.</Alert>
                <Suspense fallback={<div>Loading...</div>}>
                    <Grid />
                </Suspense>
            </Stack>
        </Base>
    );
}
