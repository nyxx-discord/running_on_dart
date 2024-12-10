import {getItem, removeItem, setItem} from "./localStorage";
import {jwtDecode, JwtPayload} from "jwt-decode";

export type UserData = {
    id: string,
    name: string,
    avatar: string|null,
    guilds: string[],
}

export type AuthData = {
    userData: UserData,
    token: string,
}

export type TokenCustomData = {
    permissions: number[]
}

export interface TokenPayload extends JwtPayload {
    pld: TokenCustomData
}

export function getToken(): string|null {
    return getItem('token');
}

export function getTokenPayload(): TokenPayload|null {
    const token = getToken();
    if (token == null) {
        return null;
    }

    return jwtDecode<TokenPayload>(token);
}

export function getCurrentUserPermissions(): number[]|null {
    const payload = getTokenPayload();
    if (payload == null) {
        return null;
    }

    return payload.pld.permissions;
}

export function logout() {
    removeItem('token');
    removeItem('user');
}

export function getUser(): UserData|null {
    const userData = getItem('user');
    if (userData === null) {
        return null;
    }

    return JSON.parse(userData);
}

export function isLoggedIn(): boolean {
    const tokenPayload = getTokenPayload();
    if (tokenPayload == null) {
        return false;
    }

    if (tokenPayload.exp == null) {
        return false;
    }

    if((tokenPayload.exp * 1000) < Date.now()) {
        logout();
        return false;

    }
    return true
}

export function setAuthData(authData: AuthData) {
    setItem('token', authData.token);
    setItem('user', JSON.stringify(authData.userData));
}
