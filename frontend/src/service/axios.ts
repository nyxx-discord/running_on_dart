import Axios from "axios";
import {CreateAxiosDefaults} from "axios/index";
import {getToken} from "./auth";

const API_SERVER = process.env.REACT_APP_API_SERVER;

export const axios = Axios.create({
    baseURL: API_SERVER,
    headers: { "Content-Type": "application/json" },
});

export const axiosAuthenticated = createAxiosClient({
    options: {
        baseURL: API_SERVER,
        headers: {
            'Content-Type': 'application/json',
        }
    },
    getCurrentAccessToken: getToken,
});

type CreateAxiosClientParams = {
    options: CreateAxiosDefaults,
    getCurrentAccessToken: () => string|null,
}

export function createAxiosClient({
      options,
      getCurrentAccessToken,
  }: CreateAxiosClientParams) {
    const client = Axios.create(options);

    client.interceptors.request.use(
        (config) => {
            if (config.data.useAuth !== false) {
                const token = getCurrentAccessToken();
                if (token !== null) {
                    config.headers.Authorization = "Bearer " + token;
                }
            }
            return config;
        },
        (error) => {
            return Promise.reject(error);
        }
    );

    return client;
}
