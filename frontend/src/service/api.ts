import {request} from "./httpClient";

export type BotInfo = {
    nyxxVersion: string;
    version: string;
    platform: string;
    memoryUsageString: string;
    cachedChannels: number;
    cachedMessages: number;
    cachedGuilds: number;
    cachedUsers: number;
    cachedVoiceStates: number;
    shardCount: number;
    totalTagsCount: number;
    totalReminderCount: number;
    uptime: string;
    docsUpdate: string;
};

export type Guild = {
    id: string,
    name: string,
    banner?: string,
    icon?: string,
    cachedMembers: number,
    cachedChannels: number,
    cachedMessages: number,
    cachedRoles: number,
    enabledFeatures: string[],
    tagsCount: number,
};

export async function fetchBotInfo(): Promise<BotInfo> {
    return await request<BotInfo>({path: "/api/server-info"});
}

export async function fetchGuilds(): Promise<Guild[]> {
    return await request<Guild[]>({path: "/api/guilds", auth: true});
}
