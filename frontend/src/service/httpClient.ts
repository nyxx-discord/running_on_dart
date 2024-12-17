import {getToken, logout} from "./auth";

const API_SERVER = process.env.REACT_APP_API_SERVER;

export interface FetchParams {
    path: string,
    method?: string,
    auth?: boolean
    searchParams?: string|string[][]|URLSearchParams|Record<string, string>
}

interface ErrorResponse {
    message: string
}

export async function request<T extends object>({path, method = 'GET', auth = false, searchParams}: FetchParams) {
    const headers = new Headers();
    headers.append('Accept', 'application/json');

    if (auth) {
        headers.append('authorization', `Bearer ${getToken()}`)
    }

    const url = new URL(`${API_SERVER}${path}`);
    if (searchParams != undefined) {
        url.search = new URLSearchParams(searchParams).toString();
    }

    const response = await fetch(
        url,
        {
            method: method,
            headers: headers,
        }
    );

    const responseBody = await response.json();
    if (response.ok) {
        return responseBody as T;
    }

    if ([401, 403].includes(response.status)) {
        logout();
    }

    throw new Error((responseBody as ErrorResponse).message);
}
