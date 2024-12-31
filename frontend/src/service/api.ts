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

export enum FeatureName {
    poopName = 'poop_name',
    joinLogs = 'join_logs',
    modLogs = 'mod_logs',
    jellyfin = 'jellyfin',
    mentions = 'mentions',
    kavita = 'kavita',
    emojiReact = 'emoji_react',
}

export interface Feature {
    name: FeatureName,
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
}

export interface MemberUser {
    avatar?: string,
    username: string,
}

export interface MemberDetails {
    id: string,
    nick?: string,
    avatar?: string,
    user: MemberUser,
}

export interface Reminder {
    id: number,
    channelId: string,
    userId: string,
    messageId: string,
    triggerAt: string,
    addedAt: string,
    message: string,
}

export interface PaginationResponse<T> {
    page: number,
    perPage: number,
    total: number,
    data: T[],
}

interface PaginationParameters {
    perPage?: number,
    page?: number,
}

interface FetchGuildDataParameters extends PaginationParameters {
    id: string,
    query?: string,
}


export function fetchMemberDetails(guildId: string, userId: string): Promise<MemberDetails> {
    return request<MemberDetails>({path: `/api/guilds/${guildId}/members/${userId}`, auth: true});
}

export function fetchChannelDetails(guildId: string, channelId: string): Promise<Channel> {
    return request<Channel>({path: `/api/guilds/${guildId}/channels/${channelId}`, auth: true});
}

export function fetchBotInfo(): Promise<BotInfo> {
    return request<BotInfo>({path: "/api/server-info"});
}

export function fetchGuilds({perPage = 25, page = 0}: PaginationParameters = {}): Promise<PaginationResponse<GuildSummary>> {
    const params = [["perPage", perPage.toString()], ["page", (page + 1).toString()]];

    return request<PaginationResponse<GuildSummary>>({path: "/api/guilds", auth: true, searchParams: params});
}

export function fetchGuildDetails(id: string): Promise<GuildDetails> {
    return request<GuildDetails>({path: `/api/guilds/${id}`, auth: true});
}

export function fetchGuildReminders({id, perPage = 5, page = 0, query}: FetchGuildDataParameters): Promise<PaginationResponse<Reminder>> {
    const params = [["perPage", perPage.toString()], ["page", (page + 1).toString()]];
    if (query != null && query !== '') {
        params.push(["query", query])
    }

    return request<PaginationResponse<Reminder>>({path: `/api/guilds/${id}/reminders`, auth: true, searchParams: params});
}

export function fetchGuildTags({id, perPage = 5, page = 0, query}: FetchGuildDataParameters): Promise<PaginationResponse<Tag>> {
    const params = [["perPage", perPage.toString()], ["page", (page + 1).toString()]];
    if (query != null && query !== '') {
        params.push(["query", query])
    }

    return request<PaginationResponse<Tag>>({path: `/api/guilds/${id}/tags`, auth: true, searchParams: params});
}

export function createTag(id: string, body: any): Promise<Tag> {
    return request<Tag>({path: `/api/guilds/${id}/tags`, method: 'POST', body: body, auth: true});
}
