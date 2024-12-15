import {request} from "./httpClient";

export interface BotInfo {
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
}

export interface GuildSummary {
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
}

export interface Channel {
    id: string,
    type: ChannelType,
    name: string,
    position: number,
    isNfsw: boolean,
    parentId: string,
}

enum ChannelType {
    GuildText = 0,
    Dm,
    GuildVoice,
    GroupDm,
    GuildCategory,
    GuildAnnouncement,
    AnnouncementThread,
    PublicThread,
    PrivateThread,
    GuildStageVoice,
    GuildDirectory,
    GuildForum,
    GuildMedia
}

export interface GuildDetails {
    id: string,
    name: string,
    banner?: string,
    icon?: string,
    position: number,
    isNsfw: boolean,
    parentId: string,
    rateLimitPerUser?: string,
    lastPinTimestamp?: string,
    cachedMessages?: number,
    bitrate?: string,
    userLimit?: string,
    rtcRegion: string,
    videoQualityMode: string,
    channels: Channel[],
}

export async function fetchBotInfo(): Promise<BotInfo> {
    return await request<BotInfo>({path: "/api/server-info"});
}

export async function fetchGuilds(): Promise<GuildSummary[]> {
    return await request<GuildSummary[]>({path: "/api/guilds", auth: true});
}

export async function fetchGuildDetails(id: string): Promise<GuildDetails> {
    return await request<GuildDetails>({path: `/api/guilds/${id}`, auth: true});
}
