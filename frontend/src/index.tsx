import React, {lazy} from 'react';
import ReactDOM from 'react-dom/client';
import {BrowserRouter, Route, Routes} from "react-router-dom";
import Redirect from "./page/Redirect";
import {ProtectedRoute} from "./component/ProtectedRoute";

const Guilds = lazy(() => import("./page/admin/Guilds"));
const Home = lazy(() => import("./page/Home"));

ReactDOM.createRoot(
    document.getElementById('root') as HTMLElement
).render(
    <BrowserRouter>
        <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/guilds" element={<ProtectedRoute><Guilds /></ProtectedRoute>} />
            <Route path="/redirect" element={<Redirect />}/>
        </Routes>
    </BrowserRouter>
);
