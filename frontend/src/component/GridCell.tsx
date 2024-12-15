import {Props} from "../constants";
import {Stack} from "@mui/material";
import React from "react";

export function GridCell({children}: Props) {
    return <Stack direction="row" spacing={2} alignItems="center" height={'100%'}>
        {children}
    </Stack>;
}
