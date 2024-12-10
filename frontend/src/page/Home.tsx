import React, {useEffect, useState} from 'react';

import {Base} from "../component/Base";
import {BotInfo, useApi} from "../service/useApi";
import {BotInfoGrid} from "../component/botInfo/BotInfoGrid";

export default function Home() {
    const {fetchBotInfo} = useApi();

    const [stats, setStats] = useState<BotInfo|null>();

    useEffect(() => {
        fetchBotInfo().then(result => {
            setStats(result);
        });
    }, []);

    return (
        <Base>
            {stats != null ? <BotInfoGrid botInfoStats={stats!} /> : <div>Loading...</div>}
        </Base>
    );
}
