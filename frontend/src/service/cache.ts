const _cache = new Map<string, Promise<any>>();

export function cache<T>(key: string, fn: () => Promise<T>): Promise<T> {
    if (_cache.has(key)) {
        return _cache.get(key)!;
    }

    const promise = fn();
    _cache.set(key, promise);

    return promise;
}
