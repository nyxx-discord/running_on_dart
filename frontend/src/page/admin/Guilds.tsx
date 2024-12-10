import React, {useEffect, useState} from 'react';
import {Base} from "../../component/Base";
import {Guild, useApi} from "../../service/useApi";
import {DataGrid, GridColDef} from "@mui/x-data-grid";
import {Alert, Avatar, Stack, Typography} from "@mui/material";
import {getGuildIcon} from "../../constants";

const columns: GridColDef[] = [
    { field: 'name', headerName: 'Name', width: 300, renderCell: params => params.value},
    { field: 'cachedMembers', headerName: 'Members', minWidth: 100 },
    { field: 'cachedChannels', headerName: 'Channels', minWidth: 100 },
    { field: 'cachedMessages', headerName: 'Messages', minWidth: 100 },
    { field: 'cachedRoles', headerName: 'Roles', minWidth: 100 },
    { field: 'enabledFeatures', headerName: 'Features', minWidth: 100 },
    { field: 'tagsCount', headerName: 'Tags', minWidth: 100 },
];

type GuildRowDef = {
    id: string,
    name: React.JSX.Element|string,
    cachedMembers: number,
    cachedChannels: number,
    cachedMessages: number,
    cachedRoles: number,
    enabledFeatures: number,
    tagsCount: number,
};

function getGuildNameElement(guild: Guild): React.JSX.Element|string {
    const guildName = <Typography>{guild.name}</Typography>;

    if (guild.icon != null) {
        return <Stack direction="row" spacing={2} alignItems="center" sx={{mt: '4px'}}>
            <Avatar src={getGuildIcon(guild.id, guild.icon as string)}/>
            {guildName}
        </Stack>;
    }

    return guildName;
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
            enabledFeatures: guild.enabledFeatures.length,
            tagsCount: guild.tagsCount,
        } as GuildRowDef;
    });
}

export default function Guilds() {
    const [rows, setRows] = useState<GuildRowDef[]>([]);
    const {fetchGuilds} = useApi();

    useEffect(() => {
        fetchGuilds().then(guilds => {
            setRows(mapApiDataToRows(guilds));
        });
    }, []);

    return (
        <Base>
            <Stack direction="column" spacing={1}>
                <Alert severity="error">Table represents cached data, that is available for bot at the moment.</Alert>
                <DataGrid rows={rows} columns={columns}/>
            </Stack>
        </Base>
    );
}
