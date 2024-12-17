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

export enum ChannelType {
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

export interface Channel {
    id: string,
    type: ChannelType,
    name: string,
    position: number,
    isNfsw: boolean,
    parentId: string,
}

export interface Role {
    id: string,
    name: string,
    position: number,
    isHoisted: boolean,
    color: string,
    icon?: string,
    flags: number,
    permissions: number,
}

export interface Tag {
    id: number,
    name: string,
    content: string,
    enabled: boolean,
    authorId: boolean,
}

export interface Feature {
    name: string,
    data: any,
    enabledBy: string,
    enabledAt: string,
}

export interface JellyfinInstance {
    id: string,
    name: string,
    isDefault: string,
    basePath: string,
    sonarrBasePath: string,
    wizarrBasePath: string,
}

export interface KavitaInstance {
    id: string,
    name: string,
    isDefault: string,
    basePath: string,
}

export interface FeaturesDetails {
    enabledFeatures: Feature[],
    jellyfinInstances: JellyfinInstance[],
    kavitaInstances: KavitaInstance[]
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
    roles: Role[],
    channels: Channel[],
    features: FeaturesDetails,
    tags: Tag[],
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

interface FetchGuildTags {
    id: string,
    perPage?: number,
    query?: string,
}

export async function fetchGuildTags({id, perPage = 5, query}: FetchGuildTags): Promise<Tag[]> {
    const params = [["perPage", perPage.toString()]];
    if (query != null && query !== '') {
        params.push(["query", query])
    }

    return await request<Tag[]>({path: `/api/guilds/${id}/tags`, auth: true, searchParams: params});
}
