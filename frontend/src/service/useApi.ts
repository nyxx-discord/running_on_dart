import {axiosAuthenticated} from "./axios";

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

export class Api {
    async fetchBotInfo(): Promise<BotInfo> {
        const response = await axiosAuthenticated.get<BotInfo>("/api/server-info", {data: {useAuth: false}});

        return response.data;
    }

    async fetchGuilds(): Promise<Guild[]> {
        const response = await axiosAuthenticated.get<Guild[]>("/api/guilds", {data: {useAuth: true}})

        return response.data;
    }
}

export const useApi = () => new Api();
