import {Box, Modal} from "@mui/material";
import React, {useContext} from "react";
import {ModalContext} from "../service/useModal";
import {Props} from "../constants";

const style = {
    position: 'absolute',
    top: '50%',
    left: '50%',
    width: '50%',
    height: '50%',
    transform: 'translate(-50%, -50%)',
};

export function CustomModal({children}: Props) {
    const context = useContext(ModalContext);
    if (context == null) {
        throw Error("Requires ModalContext context");
    }

    return <Modal open={context.isOpen} onClose={context.onClose}>
        <Box sx={style} children={children}/>
    </Modal>
}
