import {createContext, useState} from "react";

interface ModalProps<T> {
    open: boolean,
    data?: T|null
}

export interface UseModalResult<T> {
    isOpen: boolean,
    openModal: (data: T) => void;
    onClose: () => void;
    data?: T|null,
}

export function useModal<T>(): UseModalResult<T> {
    const [modalState, setModalState ] = useState<ModalProps<T>>({open: false});

    const openModal = (data: T) => setModalState({open: true, data});
    const onClose = () => setModalState({open: false, data: null});

    return {
        isOpen: modalState.open,
        openModal: openModal,
        onClose: onClose,
        data: modalState.data,
    };
}

export const ModalContext = createContext<UseModalResult<any>|null>(null);
