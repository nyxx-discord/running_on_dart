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

interface PaginationParameters {
    perPage?: number,
    page?: number,
}

interface FetchGuildTagsParameters extends PaginationParameters{
    id: string,
    query?: string,
}

export async function fetchBotInfo(): Promise<BotInfo> {
    return await request<BotInfo>({path: "/api/server-info"});
}

export async function fetchGuilds({perPage = 25, page = 0}: PaginationParameters = {}): Promise<GuildSummary[]> {
    const params = [["perPage", perPage.toString()], ["page", (page + 1).toString()]];

    return await request<GuildSummary[]>({path: "/api/guilds", auth: true, searchParams: params});
}

export async function fetchGuildDetails(id: string): Promise<GuildDetails> {
    return await request<GuildDetails>({path: `/api/guilds/${id}`, auth: true});
}

export async function fetchGuildTags({id, perPage = 5, page = 0, query}: FetchGuildTagsParameters): Promise<Tag[]> {
    const params = [["perPage", perPage.toString()], ["page", (page + 1).toString()]];
    if (query != null && query !== '') {
        params.push(["query", query])
    }

    return await request<Tag[]>({path: `/api/guilds/${id}/tags`, auth: true, searchParams: params});
}
