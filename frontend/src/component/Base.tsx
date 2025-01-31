import React from 'react';

import {DefaultAppProps} from "../constants";
import AppBar from "./NavigationBar";
import {Container, createTheme, CssBaseline, ThemeProvider} from "@mui/material"

export function Base({children}: DefaultAppProps) {
    const theme = createTheme({
        colorSchemes: {
            dark: true,
        },
    });

    return (
        <ThemeProvider theme={theme}>
            <CssBaseline />
            <Container>
                <AppBar />
                <Container children={children} sx={{mt: '10px'}}/>
            </Container>
        </ThemeProvider>
    );
}
