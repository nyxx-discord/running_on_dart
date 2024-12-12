import {Box, Grid2, Paper, Typography} from "@mui/material";
import React from "react";

interface BotInfoElementProps {
    name: string,
    value: string|number|undefined,
    size?: number,
}

export function BotInfoElement({name, value, size = 3}:  BotInfoElementProps) {
    return (
       <Grid2 size={{xs: 6, md: size}} >
           <Paper elevation={2}>
               <Box sx={{padding: '8px'}}>
                   <Typography fontWeight="bold">{name}</Typography>
                   <Typography>{value}</Typography>
               </Box>
           </Paper>
       </Grid2>
    );
}
