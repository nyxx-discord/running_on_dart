import {getCurrentUserPermissions} from "../service/auth";
import {containsAll} from "../util";
import React from "react";
import {DefaultAppProps} from "../constants";

export interface ProtectedElementProps extends DefaultAppProps {
    requiredPermissions?: number[],
    requiresLogin?: boolean
}

export function ProtectedElement({requiresLogin, requiredPermissions, children}: ProtectedElementProps) {
    const userPermissions = getCurrentUserPermissions();

    const missingPermissions = userPermissions == null;
    const isLoggedIn = (requiresLogin ?? false) && missingPermissions;
    const noPermissions = requiredPermissions != null && !containsAll(userPermissions ?? [], requiredPermissions);

    if (missingPermissions || isLoggedIn || noPermissions) {
        return <></>;
    }

    return <>
        {children}
    </>;
}
