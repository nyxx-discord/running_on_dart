import React, {useEffect, useState} from "react";
import {Navigate, useSearchParams} from 'react-router-dom';
import {axios} from "../service/axios";
import {AuthData, setAuthData} from "../service/auth";

export default function Redirect() {
    const [searchParams] = useSearchParams();

    const [isSuccess, setIsSuccess] = useState(false);

    useEffect(() => {
        axios.get<AuthData>(`/api/validate-oauth?code=${searchParams.get('code')}`).then(result => {
            if (result.status === 200) {
                setAuthData(result.data);
                setIsSuccess(true);
            }
        });
    }, []);

    if (!isSuccess) {
        return <div>...</div>;
    }

    return <Navigate to="/" />;
}
