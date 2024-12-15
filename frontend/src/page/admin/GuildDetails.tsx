import {fetchGuildDetails, GuildDetails as GuildDetailsDto} from "../../service/api";
import {Base} from "../../component/Base";
import {Box} from "@mui/material";
import {useParams} from "react-router-dom";
import {Suspense, use} from "react";

interface GuildDetailsDataProps {
    dataPromise: Promise<GuildDetailsDto>
}

function GuildDetailsData({dataPromise}: GuildDetailsDataProps) {
    const data = use(dataPromise);

    return <Box>
        {data.name}
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
