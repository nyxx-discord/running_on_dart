import {Suspense} from 'react';

import {Base} from "../component/Base";
import {BotInfoGrid} from "../component/botInfo/BotInfoGrid";

export default function Home() {
    return (
        <Base>
            <Suspense fallback={<div>Loading...</div>}>
                <BotInfoGrid />
            </Suspense>
        </Base>
    );
}
