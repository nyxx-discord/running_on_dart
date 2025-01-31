import {
    createTag,
    fetchGuildDetails, fetchGuildReminders,
    fetchGuildTags,
    GuildDetails as GuildDetailsDto,
    PaginationResponse, Reminder,
    Tag
} from "../../service/api";
import {Base} from "../../component/Base";
import {
    Accordion,
    AccordionDetails,
    AccordionSummary, Button,
    Container, DialogContent, DialogTitle,
    Paper,
    Stack,
    TextField,
    Typography
} from "@mui/material";
import {useParams} from "react-router-dom";
import React, {Suspense, use, useEffect, useState} from "react";
import {getGuildNameElement} from "../../guildUtil";
import {DataGrid, GridColDef} from "@mui/x-data-grid";
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import {DiscordUserName} from "../../component/DiscordUserName";
import {formatRelativeTime} from "../../util";
import {DiscordChannel} from "../../component/DiscordChannel";
import {FeatureData} from "../../component/FeatureData";
import {FormDialog, useFormDialog} from "../../component/FormDialog";
import {getUser} from "../../service/auth";
import {GridFilterModel} from "@mui/x-data-grid/models/gridFilterModel";

interface GuildDetailsDataProps {
    dataPromise: Promise<GuildDetailsDto>
}

interface TagsDataPaperProps {
    id: string,
}

const dateFormat = new Intl.DateTimeFormat('en-GB', { dateStyle: 'short', timeStyle: 'short' });

function FeaturesPaper({dataPromise}: GuildDetailsDataProps) {
    const originalData = use(dataPromise);
    const data = originalData.features;

    const enabledFeatures = data.enabledFeatures.map(f => {
        const enabledAt = dateFormat.format(new Date(f.enabledAt))

        return <Accordion>
            <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                {f.name} (enabled: {enabledAt})
            </AccordionSummary>
            <AccordionDetails>
                <Stack direction="row" spacing={2} alignItems="center" height={'100%'}>
                    <Typography fontWeight="bold" display="inline">Enabled by: </Typography>
                    <DiscordUserName guildId={originalData.id} userId={f.enabledBy} />
                </Stack>
                <FeatureData feature={f} guildId={originalData.id} />
            </AccordionDetails>
        </Accordion>;
    });

    return <Stack direction="column">
        <Typography variant='h5'>Features</Typography>
        <div>
            {enabledFeatures}
        </div>
    </Stack>;
}

function TagsDataPaper({id}: TagsDataPaperProps) {
    const [tags, setTags] = useState<PaginationResponse<Tag>|null>(null);
    const [filterModel, setFilterModel] = useState<GridFilterModel|null>(null);
    const [paginationModel, setPaginationModel] = useState({
        pageSize: 5,
        page: 0,
    });

    useEffect(() => {
        fetchGuildTags({id: id, filterModel: filterModel, page: paginationModel.page, perPage: paginationModel.pageSize}).then((t) => setTags(t));
    }, [filterModel, paginationModel]);

    const columns: GridColDef[] = [
        { field: 'name', headerName: 'Name' },
        { field: 'content', headerName: 'Content', flex: 1 },
        { field: 'enabled', headerName: 'Enabled?', filterable: false },
        { field: 'authorId', headerName: 'Author', minWidth: 200, filterable: false, renderCell: params => <DiscordUserName guildId={id} userId={params.value} />},
    ];

    const dialog = useFormDialog();

    const onSubmit = async (data: Record<string, string>) => {
        data['authorId'] = getUser()!.id;

        await createTag(id, data);
        fetchGuildTags({id: id, filterModel: filterModel, page: paginationModel.page, perPage: paginationModel.pageSize}).then((t) => setTags(t));
    };

    return <Stack direction="column">
        <Stack direction='row' spacing={{sm: 5}} sx={{p: '5px'}}>
            <Typography variant='h5'>Tags</Typography>
            <Button variant='outlined' onClick={() => dialog.open()}>Create tag</Button>
        </Stack>
        <DataGrid
            onFilterModelChange={(model) => setFilterModel(model)}
            filterMode="server"
            rows={tags?.data ?? []}
            columns={columns}
            paginationModel={paginationModel}
            onPaginationModelChange={setPaginationModel}
            paginationMode="server"
            rowCount={tags?.total ?? -1}
        />
        <FormDialog onSubmit={onSubmit} {...dialog} >
            <DialogTitle>Create new Tag</DialogTitle>
            <DialogContent>
                <TextField autoFocus required margin="dense" id="name" name="name" label="Name" type="text" fullWidth variant="standard" />
                <TextField autoFocus required margin="dense" id="content" name="content" label="Content" type="text" fullWidth variant="standard" multiline maxRows={3} />
            </DialogContent>
        </FormDialog>
    </Stack>;
}

function ReminderDataPaper({id}: TagsDataPaperProps) {
    const [reminders, setReminders] = useState<PaginationResponse<Reminder>|null>(null);
    const [filterModel, setFilterModel] = useState<GridFilterModel|null>(null);
    const [paginationModel, setPaginationModel] = useState({
        pageSize: 5,
        page: 0,
    });

    useEffect(() => {
        fetchGuildReminders({id: id, filterModel: filterModel, page: paginationModel.page, perPage: paginationModel.pageSize}).then((t) => setReminders(t));
    }, [filterModel, paginationModel]);

    const columns: GridColDef[] = [
        { field: 'id', headerName: 'Id', filterable: false},
        { field: 'message', headerName: 'Message', flex: 1},
        { field: 'userId', headerName: 'Created by', minWidth: 200, filterable: false, renderCell: params => <DiscordUserName guildId={id} userId={params.value} />},
        { field: 'channelId', headerName: 'Channel', flex: 1, filterable: false, renderCell: params => <DiscordChannel guildId={id} channelId={params.value} />},
        { field: 'triggerAt', headerName: 'Triggers', flex: 1, filterable: false, renderCell: params => formatRelativeTime(new Date(params.value))},
        { field: 'addedAt', headerName: 'Created', flex: 1, filterable: false, renderCell: params => formatRelativeTime(new Date(params.value))},
    ];

    return <Stack direction="column">
        <Stack direction='row' spacing={{sm: 5}} sx={{p: '5px'}}>
            <Typography variant='h5'>Reminders</Typography>
        </Stack>
        <DataGrid
            onFilterModelChange={(model) => setFilterModel(model)}
            filterMode="server"
            rows={reminders?.data ?? []}
            columns={columns}
            paginationModel={paginationModel}
            onPaginationModelChange={setPaginationModel}
            paginationMode="server"
            rowCount={reminders?.total ?? -1}
        />
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
    </Stack>
}

export default function GuildDetails() {
    const {id} = useParams()
    const promise = fetchGuildDetails(id!);

    return <Base>
        <Paper elevation={1} sx={{p: '5px', mb: '5px'}}>
            <Suspense fallback={<span>Loading...</span>}>
                <GuildDetailsData dataPromise={promise} />
            </Suspense>
        </Paper>
        <Paper elevation={1} sx={{p: '5px', mb: '5px'}}>
            <TagsDataPaper id={id!} />
        </Paper>
        <Paper elevation={1} sx={{p: '5px', mb: '5px'}}>
            <ReminderDataPaper id={id!} />
        </Paper>
        <Paper elevation={1} sx={{p: '5px'}}>
            <Suspense fallback={<span>Loading...</span>}>
                <FeaturesPaper dataPromise={promise} />
            </Suspense>
        </Paper>
    </Base>
}
