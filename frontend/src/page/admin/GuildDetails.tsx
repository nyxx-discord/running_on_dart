import {fetchGuildDetails, fetchGuildTags, GuildDetails as GuildDetailsDto} from "../../service/api";
import {Base} from "../../component/Base";
import {
    Accordion,
    AccordionDetails,
    AccordionSummary,
    Container,
    Paper,
    Stack,
    TextField,
    Typography
} from "@mui/material";
import {useParams} from "react-router-dom";
import React, {Suspense, use, useState} from "react";
import {getGuildNameElement} from "../../guildUtil";
import {DataGrid, GridColDef} from "@mui/x-data-grid";
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import {useDebounce} from "use-debounce";
import useUpdateEffect from "../../util";

interface GuildDetailsDataProps {
    dataPromise: Promise<GuildDetailsDto>
}

const dateFormat = new Intl.DateTimeFormat('en-GB', { dateStyle: 'short', timeStyle: 'short' });

function FeaturesPaper({dataPromise}: GuildDetailsDataProps) {
    const data = use(dataPromise).features;

    const enabledFeatures = data.enabledFeatures.map(f => {
        const enabledAt = dateFormat.format(new Date(f.enabledAt))

        return <Accordion>
            <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                {f.name} (enabled: {enabledAt})
            </AccordionSummary>
            <AccordionDetails>
                <Typography fontWeight="bold" display="inline">Enabled by: </Typography><Typography display="inline">{f.enabledBy}</Typography>
                <Typography fontWeight="bold">Data: </Typography><Typography>{JSON.stringify(f.data)}</Typography>
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

function TagsDataPaper({dataPromise}: GuildDetailsDataProps) {
    const data = use(dataPromise);

    const [tags, setTags] = useState(data.tags);
    const [searchQuery, setSearchQuery] = useState<string|null>(null);
    const [searchQueryDebounced] = useDebounce(searchQuery, 500);
    const [paginationModel, setPaginationModel] = useState({
        pageSize: 5,
        page: 0,
    });

    useUpdateEffect(() => {
        if (searchQueryDebounced == null) {
            return;
        }

        fetchGuildTags({id: data.id, query: searchQueryDebounced, page: paginationModel.page, perPage: paginationModel.pageSize}).then((t) => setTags(t));
    }, [searchQueryDebounced, paginationModel]);

    const columns: GridColDef[] = [
        { field: 'name', headerName: 'Name' },
        { field: 'content', headerName: 'Content', flex: 1 },
        { field: 'enabled', headerName: 'Enabled?'},
        { field: 'authorId', headerName: 'Author', minWidth: 200},
    ];

    return <Stack direction="column">
        <Stack direction='row' spacing={{sm: 5}} sx={{p: '5px'}}>
            <Typography variant='h5'>Tags</Typography>
            <TextField id="tag-name-filter" label="Name..." variant="outlined" size='small' onChange={(e) => setSearchQuery(e.target.value)} />
        </Stack>
        <DataGrid rows={tags} columns={columns} paginationModel={paginationModel} onPaginationModelChange={setPaginationModel} />
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
        <Paper elevation={1} sx={{p: '5px', mb: '5px'}}>
            <Suspense fallback={<span>Loading...</span>}>
                <TagsDataPaper dataPromise={promise} />
            </Suspense>
        </Paper>
        <Paper elevation={1} sx={{p: '5px'}}>
            <Suspense fallback={<span>Loading...</span>}>
                <FeaturesPaper dataPromise={promise} />
            </Suspense>
        </Paper>
    </Base>
}
