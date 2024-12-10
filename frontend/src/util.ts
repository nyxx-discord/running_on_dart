export function containsAll<T>(haystack: T[], required: T[]): boolean {
    return required.every(ai => haystack.includes(ai));
}
