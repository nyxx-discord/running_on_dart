import {lazy, Suspense} from 'react';

import {Base} from "../component/Base";

const BotInfoGrid = lazy(() => import("../component/botInfo/BotInfoGrid"));

export default function Home() {
    return (
        <Base>
            <Suspense fallback={<div>Loading...</div>}>
                <BotInfoGrid />
            </Suspense>
        </Base>
    );
}
