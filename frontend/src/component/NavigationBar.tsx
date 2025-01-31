import React from "react";
import {discordLoginUri, getUserAvatar} from "../constants";
import {isLoggedIn, getUser, logout} from "../service/auth";

import {
    AppBar,
    Avatar,
    Box,
    Button,
    Container, FormControl, FormControlLabel,
    IconButton,
    Menu,
    MenuItem, Radio, RadioGroup,
    Toolbar,
    Tooltip,
    Typography, useColorScheme
} from "@mui/material";
import {useNavigate} from "react-router-dom";
import {ProtectedElement} from "./ProtectedElement";

export default function NavigationBar() {
    const { mode, setMode } = useColorScheme();
    const navigate = useNavigate();

    const userLoggedIn = isLoggedIn();

    const [anchorElUser, setAnchorElUser] = React.useState<null | HTMLElement>(null);
    const toggleUserMenu = (event?: React.MouseEvent<HTMLElement>) => {
        setAnchorElUser(event?.currentTarget ?? null);
    };

    const logoutAndRedirect = () => {
        logout();
        navigate("/");
    };

    let userElement = <Button href={discordLoginUri}>Login</Button>;
    if (userLoggedIn) {
        const user = getUser()!;

        userElement = <Box sx={{flexGrow: 0}}>
            <Tooltip title="Open settings">
                <IconButton onClick={toggleUserMenu} sx={{p: 0}}>
                    <Typography sx={{color: 'white', fontSize: 20}} marginInlineEnd="0.5em">{user.name}</Typography>
                    <Avatar alt="User's avatar" src={getUserAvatar(user.id, user.avatar as string)}/>
                </IconButton>
            </Tooltip>
            <Menu
                sx={{mt: '45px'}}
                id="menu-appbar"
                anchorEl={anchorElUser}
                anchorOrigin={{
                    vertical: 'top',
                    horizontal: 'right',
                }}
                keepMounted
                transformOrigin={{
                    vertical: 'top',
                    horizontal: 'right',
                }}
                open={Boolean(anchorElUser)}
                onClose={() => toggleUserMenu()}
            >
                <MenuItem key="color-mode">
                    <FormControl>
                        <RadioGroup
                            name="theme-toggle"
                            row
                            value={mode ?? 'system'}
                            onChange={(event) =>
                                setMode(event.target.value as 'system' | 'light' | 'dark')
                            }
                        >
                            <FormControlLabel value="system" control={<Radio />} label="System" />
                            <FormControlLabel value="light" control={<Radio />} label="Light" />
                            <FormControlLabel value="dark" control={<Radio />} label="Dark" />
                        </RadioGroup>
                    </FormControl>
                </MenuItem>
                <MenuItem key="profile" onClick={() => navigate("/profile")}>
                    <Typography sx={{textAlign: 'center'}}>Profile</Typography>
                </MenuItem>
                <MenuItem key="log-out" onClick={logoutAndRedirect}>
                    <Typography sx={{textAlign: 'center'}}>Log Out</Typography>
                </MenuItem>
            </Menu>
        </Box>
    }

    return (
        <AppBar position="static">
            <Container maxWidth="xl">
                <Toolbar disableGutters>
                    <Typography
                        variant="h6"
                        noWrap
                        component="a"
                        sx={{
                            mr: 2,
                            display: {xs: 'none', md: 'flex'},
                            fontFamily: 'monospace',
                            fontWeight: 700,
                            color: 'inherit',
                            textDecoration: 'none',
                        }}
                        onClick={() => navigate("/")}
                    >
                        Running on Dart
                    </Typography>
                    <Box sx={{flexGrow: 1, display: {xs: 'none', md: 'flex'}}}>
                        <ProtectedElement requiresLogin={true}>
                            <Button onClick={() => navigate('/guilds')} sx={{my: 2, color: 'white', display: 'block'}}>Guilds</Button>
                        </ProtectedElement>
                    </Box>

                    {userElement}
                </Toolbar>
            </Container>
        </AppBar>
    );
}
