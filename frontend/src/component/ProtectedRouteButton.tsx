import {Button} from "@mui/material";
import React from "react";
import {useNavigate} from "react-router-dom";
import {containsAll} from "../util";
import {getCurrentUserPermissions} from "../service/auth";

export type ProtectedRouteButtonProps = {
    label: string,
    navigateTo: string,
    requiredPermissions?: number[]
}

export function ProtectedRouteButton({label, navigateTo, requiredPermissions}: ProtectedRouteButtonProps) {
    const navigate = useNavigate();
    const userPermissions = getCurrentUserPermissions();

    if (userPermissions == null || (requiredPermissions != null && !containsAll(userPermissions, requiredPermissions))) {
        return <span></span>;
    }

    return <Button onClick={() => navigate(navigateTo)} sx={{my: 2, color: 'white', display: 'block'}}>{label}</Button>;
}
