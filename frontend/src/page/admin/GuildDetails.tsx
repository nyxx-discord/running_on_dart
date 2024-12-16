import {fetchGuildDetails, GuildDetails as GuildDetailsDto, Tag} from "../../service/api";
import {Base} from "../../component/Base";
import {Box, Container, Paper, Stack, TextField, Typography} from "@mui/material";
import {useParams} from "react-router-dom";
import React, {Suspense, use} from "react";
import {getGuildNameElement} from "../../guildUtil";
import {DataGrid, GridColDef} from "@mui/x-data-grid";

interface GuildDetailsDataProps {
    dataPromise: Promise<GuildDetailsDto>
}

interface TagsDataGridProps {
    tags: Tag[]
}

function TagsDataGrid({tags}: TagsDataGridProps) {
    const columns: GridColDef[] = [
        { field: 'name', headerName: 'Name' },
        { field: 'content', headerName: 'Content', flex: 1 },
        { field: 'enabled', headerName: 'Enabled?'},
        { field: 'authorId', headerName: 'Author', minWidth: 200},
    ];

    return <Container>
        <DataGrid rows={tags} columns={columns}/>
    </Container>
}

function GuildDetailsData({dataPromise}: GuildDetailsDataProps) {
    const data = use(dataPromise);

    const guildName = getGuildNameElement(data);

    return <Box>
        <Paper elevation={1} sx={{p: '5px', mb: '5px'}}>
            <Stack direction="row">
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
        </Paper>
        <Paper elevation={1} sx={{p: '5px'}}>
            <Stack direction="column">
                <Container sx={{mb: '5px'}}>
                    <Stack direction='row' spacing={{sm: 5}}>
                        <Typography variant='h5'>Tags</Typography>
                        <TextField id="tag-name-filter" label="Name..." variant="outlined" size='small' />
                    </Stack>
                </Container>
                <TagsDataGrid tags={data.tags} />
            </Stack>
        </Paper>
    </Box>
}

export default function GuildDetails() {
    const {id} = useParams()
    const promise = fetchGuildDetails(id as string);

    return <Base>
        <Suspense fallback={<div>Loading...</div>}>
            <GuildDetailsData dataPromise={promise} />
        </Suspense>
    </Base>
}
