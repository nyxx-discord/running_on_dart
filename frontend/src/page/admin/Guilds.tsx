import React, {Suspense, use, useEffect, useState} from 'react';
import {Base} from "../../component/Base";
import {fetchGuilds, fetchGuildTags, GuildSummary} from "../../service/api";
import {DataGrid, GridActionsCellItem, GridColDef, GridRowParams} from "@mui/x-data-grid";
import {Alert, Stack, Tooltip, Typography} from "@mui/material";
import {GridCell} from "../../component/GridCell";
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import {getUser} from "../../service/auth";
import OpenInFullIcon from '@mui/icons-material/OpenInFull';
import {useNavigate} from "react-router-dom";
import {getGuildNameElement} from "../../guildUtil";
import useUpdateEffect from "../../util";

interface GuildRowDef {
    id: string,
    joined: boolean,
    name: React.JSX.Element|string,
    cachedMembers: number,
    cachedChannels: number,
    cachedMessages: number,
    cachedRoles: number,
    enabledFeatures: string[],
    tagsCount: number,
}

function mapApiDataToRows(guilds: GuildSummary[]): GuildRowDef[] {
    const joinedGuilds = getUser()?.guilds ?? [];

    return guilds.map(guild => {
        return {
            id: guild.id,
            name: getGuildNameElement(guild),
            joined: joinedGuilds.includes(guild.id),
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
    const navigate = useNavigate();
    const initialRows = use(guildDataPromise);

    const [paginationModel, setPaginationModel] = useState({
        pageSize: 25,
        page: 0,
    });
    const [rows, setRows] = useState(initialRows);

    useUpdateEffect(() => {
        fetchGuilds({page: paginationModel.page, perPage: paginationModel.pageSize}).then(guilds => {
            return mapApiDataToRows(guilds);
        }).then((r) => setRows(r));
    }, [paginationModel]);

    const columns: GridColDef[] = [
        { field: 'name', headerName: 'Name', flex: 1, renderCell: params => params.value},
        { field: 'joined', headerName: 'Joined?', renderCell: params => <GridCell>
                {params.value ? <CheckCircleIcon /> : <></>}
            </GridCell>},
        { field: 'cachedMembers', headerName: 'Members', minWidth: 100 },
        { field: 'cachedChannels', headerName: 'Channels', minWidth: 100 },
        { field: 'cachedMessages', headerName: 'Messages', minWidth: 100 },
        { field: 'cachedRoles', headerName: 'Roles', minWidth: 100 },
        { field: 'enabledFeatures', headerName: 'Features', minWidth: 100, renderCell: params => {
                return <GridCell>
                    <Tooltip title={params.value.join(', ')} arrow placement="bottom-start">
                        <Typography>{params.value.length}</Typography>
                    </Tooltip>
                </GridCell>
            }
        },
        { field: 'tagsCount', headerName: 'Tags', minWidth: 100 },
        { field: 'action', type: 'actions', headerName: 'Actions', getActions: ({row}: GridRowParams) => {
                return [
                    <GridActionsCellItem
                        icon={<OpenInFullIcon />}
                        label="Open details"
                        color='inherit'
                        className='textPrimary'
                        onClick={() => navigate(`/guilds/${row.id}`)}
                    />
                ];
            }
        }
    ];

    return (
        <DataGrid rows={rows} columns={columns} paginationModel={paginationModel} onPaginationModelChange={setPaginationModel} paginationMode="server" rowCount={-1} />
    );
}

export default function Guilds() {
    return (
        <Base>
            <Stack direction="column" spacing={1}>
            <Alert severity="error">Table represents cached data that is available for bot at the moment</Alert>
                <Suspense fallback={<div>Loading...</div>}>
                    <Grid />
                </Suspense>
            </Stack>
        </Base>
    );
}
