import React, {useEffect, useState} from "react";
import {Navigate, useSearchParams} from 'react-router-dom';
import {AuthData, setAuthData} from "../service/auth";
import {request} from "../service/httpClient";

export default function Redirect() {
    const [searchParams] = useSearchParams();

    const [isSuccess, setIsSuccess] = useState(false);

    useEffect(() => {
        request<AuthData>({path: `/api/validate-oauth?code=${searchParams.get('code')}`}).then(result => {
            setAuthData(result);
            setIsSuccess(true);
        }).catch(_ => {
            setIsSuccess(false);
        });
    }, []);

    if (!isSuccess) {
        return <div>...</div>;
    }

    return <Navigate to="/" />;
}
