import {getToken, logout} from "./auth";

const API_SERVER = process.env.REACT_APP_API_SERVER;

export interface FetchParams {
    path: string,
    method?: string,
    auth?: boolean
}

interface ErrorResponse {
    message: string
}

export async function request<T extends object>({path, method = 'GET', auth = false}: FetchParams) {
    const headers = new Headers();
    headers.append('Accept', 'application/json');

    if (auth) {
        headers.append('authorization', `Bearer ${getToken()}`)
    }

    const response = await fetch(
        `${API_SERVER}${path}`,
        {
            method: method,
            headers: headers,
        }
    );

    const responseBody = await response.json();
    if (response.ok) {
        return responseBody as T;
    }

    if ([400, 401].includes(response.status)) {
        logout();
    }

    throw new Error((responseBody as ErrorResponse).message);
}
