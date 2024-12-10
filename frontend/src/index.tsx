import React from 'react';
import ReactDOM from 'react-dom/client';
import {BrowserRouter, Route, Routes} from "react-router-dom";
import Guilds from "./page/admin/Guilds";
import Home from "./page/Home";
import Redirect from "./page/Redirect";
import {ProtectedRoute} from "./component/ProtectedRoute";

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
