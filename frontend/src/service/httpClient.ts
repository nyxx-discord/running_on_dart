import {getToken, logout} from "./auth";

const API_SERVER = process.env.REACT_APP_API_SERVER;

export interface FetchParams {
    path: string,
    method?: string,
    auth?: boolean
    searchParams?: string|string[][]|URLSearchParams|Record<string, string>
    body?: any,
}

interface ErrorResponse {
    message: string
}

export async function request<T>({path, method = 'GET', auth = false, searchParams, body}: FetchParams): Promise<T> {
    if (body && method === 'GET') {
        throw new Error("Cannot send GET request with body");
    }

    const headers = new Headers();
    headers.append('Accept', 'application/json');

    if (auth) {
        headers.append('authorization', `Bearer ${getToken()}`)
    }

    const url = new URL(`${API_SERVER}${path}`);
    if (searchParams != undefined) {
        url.search = new URLSearchParams(searchParams).toString();
    }

    let serializedBody = undefined;
    if (body) {
        serializedBody = JSON.stringify(body);
    }

    const response = await fetch(
        url,
        {
            method: method,
            headers: headers,
            body: serializedBody,
        }
    );

    const responseBody = await response.json();

    if (response.status === 422) {
        throw new Error(responseBody);
    }

    if (response.ok) {
        if (responseBody) {
            return responseBody as T;
        }

        return undefined as T; // ???????????
    }

    if ([401, 403].includes(response.status)) {
        logout();
    }

    throw new Error((responseBody as ErrorResponse).message);
}
