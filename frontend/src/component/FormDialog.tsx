import {DefaultAppProps} from "../constants";
import React, {useState} from "react";
import {Button, Dialog, DialogActions} from "@mui/material";

export interface FormDialogProps extends DefaultAppProps, FormDialogHookResult {
    onSubmit: (data: Record<string, string>) => Promise<void>
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
    const [loading, setLoading] = useState<boolean>(false);

    return <Dialog
        open={isOpen}
        onClose={close}
        PaperProps={{
            component: 'form',
            onSubmit: (event: any) => {
                event.preventDefault();
                setLoading(true);

                const formData = new FormData(event.currentTarget);
                const formJson = Object.fromEntries(formData.entries());

                onSubmit(formJson as Record<string, string>)
                    .then(() => {
                        close();
                    });
            },
        }}
    >
        {loading ? <span>Loading...</span> : children}
        <DialogActions>
            <Button onClick={close} disabled={loading}>Cancel</Button>
            <Button type="submit" disabled={loading}>Submit</Button>
        </DialogActions>
    </Dialog>
}
