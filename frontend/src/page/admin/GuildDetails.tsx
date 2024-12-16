import {fetchGuildDetails, GuildDetails as GuildDetailsDto} from "../../service/api";
import {Base} from "../../component/Base";
import {Container, Paper, Stack, TextField, Typography} from "@mui/material";
import {useParams} from "react-router-dom";
import React, {Suspense, use} from "react";
import {getGuildNameElement} from "../../guildUtil";
import {DataGrid, GridColDef} from "@mui/x-data-grid";

interface GuildDetailsDataProps {
    dataPromise: Promise<GuildDetailsDto>
}

function TagsDataPaper({dataPromise}: GuildDetailsDataProps) {
    const data = use(dataPromise);

    const columns: GridColDef[] = [
        { field: 'name', headerName: 'Name' },
        { field: 'content', headerName: 'Content', flex: 1 },
        { field: 'enabled', headerName: 'Enabled?'},
        { field: 'authorId', headerName: 'Author', minWidth: 200},
    ];

    return <Stack direction="column">
        <Stack direction='row' spacing={{sm: 5}} sx={{p: '5px'}}>
            <Typography variant='h5'>Tags</Typography>
            <TextField id="tag-name-filter" label="Name..." variant="outlined" size='small' />
        </Stack>
        <DataGrid rows={data.tags} columns={columns}/>
    </Stack>;
}

function GuildDetailsData({dataPromise}: GuildDetailsDataProps) {
    const data = use(dataPromise);
    const guildName = getGuildNameElement(data);

    return <Stack direction="row">
        <Container>
            {guildName}
        </Container>
        <Container>
            <Typography fontWeight="bold">ID: </Typography>
            <Typography>{data.id}</Typography>
        </Container>
        <Container>
            <Typography fontWeight="bold">Features enabled: </Typography>
            <Typography>{data.features.enabledFeatures.length}</Typography>
        </Container>
        <Container>
            <Typography fontWeight="bold">Tags: </Typography>
            <Typography>{data.tags.length}</Typography>
        </Container>
    </Stack>
}

export default function GuildDetails() {
    const {id} = useParams()
    const promise = fetchGuildDetails(id as string);

    return <Base>
        <Paper elevation={1} sx={{p: '5px', mb: '5px'}}>
            <Suspense fallback={<span>Loading...</span>}>
                <GuildDetailsData dataPromise={promise} />
            </Suspense>
        </Paper>
        <Paper elevation={1} sx={{p: '5px'}}>
            <Suspense fallback={<span>Loading...</span>}>
                <TagsDataPaper dataPromise={promise} />
            </Suspense>
        </Paper>
    </Base>
}
