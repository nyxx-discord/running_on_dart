import {useEffect, useRef} from "react";

export function containsAll<T>(haystack: T[], required: T[]): boolean {
    return required.every(ai => haystack.includes(ai));
}

export default function useUpdateEffect(effect: Function, dependencies = <any>[]) {
    const isInitialMount = useRef(true);

    useEffect(() => {
        if (isInitialMount.current) {
            isInitialMount.current = false;
        } else {
            return effect();
        }
    }, dependencies);
}
