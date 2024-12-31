import {DefaultAppProps} from "../constants";
import React, {useState} from "react";
import {Button, Dialog, DialogActions} from "@mui/material";

export interface FormDialogProps extends DefaultAppProps {
    onSubmit: (data: Record<string, string>) => Promise<void>;
    isOpen: boolean;
    open: () => void;
    close: () => void;
}

export interface FormDialogHookResult {
    isOpen: boolean;
    open: () => void;
    close: () => void;
}

export function useFormDialog(): FormDialogHookResult {
    const [dialogIsOpen, setDialogIsOpen] = useState(false);

    const open = () => setDialogIsOpen(true);
    const close = () => setDialogIsOpen(false);

    return {
        isOpen: dialogIsOpen,
        close: close,
        open: open
    };
}

export function FormDialog({onSubmit, children, isOpen, close}: FormDialogProps) {
    return <Dialog
        open={isOpen}
        onClose={close}
        PaperProps={{
            component: 'form',
            onSubmit: (event: any) => {
                event.preventDefault();
                const formData = new FormData(event.currentTarget);
                const formJson = Object.fromEntries(formData.entries());

                onSubmit(formJson as Record<string, string>)
                    .then(_ => close());
            },
        }}
    >
        {children}
        <DialogActions>
            <Button onClick={close}>Cancel</Button>
            <Button type="submit">Submit</Button>
        </DialogActions>
    </Dialog>
}
