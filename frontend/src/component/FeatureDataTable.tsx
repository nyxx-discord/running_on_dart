import {Paper, Table, TableBody, TableCell, TableContainer, TableHead, TableRow} from "@mui/material";
import React from "react";

export interface FeatureDataTableProps {
    data: Record<string, any>
}

export function FeatureDataTable({data}: FeatureDataTableProps) {
    const headers = [];
    const cells = [];

    for (const [key, value] of Object.entries(data)) {
        headers.push(<TableCell align="left">{key}</TableCell>);
        cells.push(<TableCell align="left">{value}</TableCell>);
    }

    return <TableContainer component={Paper}>
        <Table>
            <TableHead>
                <TableRow>
                    {headers}
                </TableRow>
            </TableHead>
            <TableBody>
                <TableRow>{cells}</TableRow>
            </TableBody>
        </Table>
    </TableContainer>;
}
