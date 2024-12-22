import {useEffect, useRef} from "react";

export function containsAll<T>(haystack: T[], required: T[]): boolean {
    return required.every(ai => haystack.includes(ai));
}

export default function useUpdateEffect(effect: Function, dependencies = [] as any) {
    const isInitialMount = useRef(true);

    useEffect(() => {
        if (isInitialMount.current) {
            isInitialMount.current = false;
        } else {
            return effect();
        }
    }, dependencies);
}

const millisecondsPerSecond = 1000;
const secondsPerMinute = 60;
const minutesPerHour = 60;
const hoursPerDay = 24;
const daysPerWeek = 7;
const intervals = {
    'week':         millisecondsPerSecond * secondsPerMinute * minutesPerHour * hoursPerDay * daysPerWeek,
    'day':          millisecondsPerSecond * secondsPerMinute * minutesPerHour * hoursPerDay,
    'hour':         millisecondsPerSecond * secondsPerMinute * minutesPerHour,
    'minute':       millisecondsPerSecond * secondsPerMinute,
    'second':       millisecondsPerSecond,
}
const relativeDateFormat = new Intl.RelativeTimeFormat('en', { style: 'long' });

export function formatRelativeTime(createTime: Date) {
    const diff = createTime.valueOf() - new Date().valueOf();
    for (const interval in intervals) {
        // @ts-ignore
        if (intervals[interval] <= Math.abs(diff)) {
            // @ts-ignore
            return relativeDateFormat.format(Math.trunc(diff / intervals[interval]), interval);
        }
    }
    return relativeDateFormat.format(diff / 1000, 'second');
}
