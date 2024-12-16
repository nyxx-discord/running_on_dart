import React from "react";
import {Avatar, Stack, Typography} from "@mui/material";
import {getGuildIcon} from "./constants";

export type GuildNameProps = {
    name: string,
    id: string,
    icon?: string,
};

export function getGuildNameElement({name, id, icon}: GuildNameProps): React.JSX.Element|string {
    const elements = [<Typography>{name}</Typography>];

    if (icon != null) {
        elements.push(<Avatar src={getGuildIcon(id, icon as string)}/>);
    }

    return <Stack direction="row" spacing={2} alignItems="center" height={'100%'}>
        {elements.reverse()}
    </Stack>;
}
