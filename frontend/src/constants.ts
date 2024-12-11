import React from "react";

export interface Props {
    children: string | React.JSX.Element | React.JSX.Element[]
}

export const discordLoginUri = encodeURI(`https://discord.com/oauth2/authorize?client_id=${process.env.REACT_APP_CLIENT_ID}&response_type=code&redirect_uri=${process.env.REACT_APP_REDIRECT_URL}&scope=identify+guilds`);

export function getUserAvatar(id: string, hash: string) {
    return `https://media.discordapp.net/avatars/${id}/${hash}.png?size=64`;
}

export function getGuildIcon(id: string, hash: string) {
    return `https://media.discordapp.net/icons/${id}/${hash}.png?size=64`;
}
