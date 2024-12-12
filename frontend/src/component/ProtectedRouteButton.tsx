import {Button} from "@mui/material";
import React from "react";
import {useNavigate} from "react-router-dom";
import {containsAll} from "../util";

export type ProtectedRouteButtonProps = {
    permissions: number[]|null,
    label: string,
    navigateTo: string,
    requiredPermissions: number[]
}

export function ProtectedRouteButton({permissions, label, navigateTo, requiredPermissions}: ProtectedRouteButtonProps) {
    const navigate = useNavigate();

    if (permissions == null || !containsAll(permissions, requiredPermissions)) {
        return <span></span>;
    }

    return <Button onClick={() => navigate(navigateTo)} sx={{my: 2, color: 'white', display: 'block'}}>{label}</Button>;
}
