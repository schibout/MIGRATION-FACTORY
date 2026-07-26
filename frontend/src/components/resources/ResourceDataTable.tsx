import {
    Delete as DeleteIcon,
    Edit as EditIcon,
    Visibility as ViewIcon,
    ArrowUpward as ArrowUpIcon,
    ArrowDownward as ArrowDownIcon,
    DeleteSweep as DeleteMultipleIcon,
} from '@mui/icons-material';
import {
    Box,
    Checkbox,
    Chip,
    IconButton,
    Paper,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TablePagination,
    TableRow,
    Tooltip,
    Typography,
    Button,
    alpha
} from '@mui/material';
import React, { useState } from 'react';
import { ResourceTableData } from '../../services/resourcesService';

interface ResourceDataTableProps {
    data: ResourceTableData;
    onPageChange: (newPage: number) => void;
    onRowsPerPageChange: (newRowsPerPage: number) => void;
    onSortChange: (field: string, direction: 'asc' | 'desc') => void;
    currentPage: number;
    currentRowsPerPage: number;
    currentSortField: string;
    currentSortDirection: 'asc' | 'desc';
    loading: boolean;
    onEdit?: (row: any) => void;
    onDelete?: (row: any) => void;
    onView?: (row: any) => void;
    onDeleteMultiple?: (rows: any[]) => void;
    visibleColumns?: string[];
}

const ResourceDataTable: React.FC<ResourceDataTableProps> = ({
    data,
    onPageChange,
    onRowsPerPageChange,
    onSortChange,
    currentPage,
    currentRowsPerPage,
    currentSortField,
    currentSortDirection,
    loading,
    onEdit,
    onDelete,
    onView,
    onDeleteMultiple,
    visibleColumns
}) => {
    const [selectedRows, setSelectedRows] = useState<any[]>([]);

    const handleSelectAll = (event: React.ChangeEvent<HTMLInputElement>) => {
        setSelectedRows(event.target.checked ? data.rows : []);
    };

    const handleSelectRow = (row: any) => {
        const isSelected = selectedRows.some(r => JSON.stringify(r) === JSON.stringify(row));
        setSelectedRows(isSelected 
            ? selectedRows.filter(r => JSON.stringify(r) !== JSON.stringify(row))
            : [...selectedRows, row]
        );
    };

    const handleSort = (field: string) => {
        const newDirection = currentSortField === field && currentSortDirection === 'asc' ? 'desc' : 'asc';
        onSortChange(field, newDirection);
    };

    const handleDeleteMultiple = () => {
        if (onDeleteMultiple && selectedRows.length > 0) {
            onDeleteMultiple(selectedRows);
            setSelectedRows([]);
        }
    };

    const handleChangePage = (_event: unknown, newPage: number) => {
        onPageChange(newPage);
        setSelectedRows([]);
    };

    const handleChangeRowsPerPage = (event: React.ChangeEvent<HTMLInputElement>) => {
        onRowsPerPageChange(parseInt(event.target.value, 10));
        setSelectedRows([]);
    };

    const displayColumns = visibleColumns 
        ? data.columns.filter(col => visibleColumns.includes(col.name))
        : data.columns;

    const formatCellValue = (value: any): React.ReactNode => {
        if (value === null || value === undefined || value === '') {
            return <span style={{ fontSize: '0.85rem', color: '#999' }}>-</span>;
        }
        if (typeof value === 'boolean') {
            return value ? <Chip size="small" label="Oui" color="success" /> : <Chip size="small" label="Non" color="default" />;
        }
        if (typeof value === 'object') {
            return <span style={{ fontSize: '0.85rem', color: '#1a1a1a' }}>{JSON.stringify(value)}</span>;
        }
        
        // Format dates
        const dateStr = String(value);
        if (dateStr.match(/^\d{4}-\d{2}-\d{2}/) || dateStr.includes('GMT')) {
            try {
                const date = new Date(value);
                if (!isNaN(date.getTime())) {
                    return (
                        <span style={{ fontSize: '0.85rem', color: '#1a1a1a' }}>
                            {date.toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' })}
                            {' '}
                            <span style={{ color: '#555', fontSize: '0.75rem' }}>
                                {date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}
                            </span>
                        </span>
                    );
                }
            } catch { /* ignore */ }
        }
        
        return <span style={{ fontSize: '0.85rem', color: '#1a1a1a' }}>{String(value)}</span>;
    };

    const colSpanTotal = displayColumns.length + (onDeleteMultiple ? 1 : 0) + (onView || onEdit || onDelete ? 1 : 0);

    return (
        <Box>
            {/* Selection bar */}
            {selectedRows.length > 0 && onDeleteMultiple && (
                <Box sx={{ 
                    p: 2, 
                    background: 'linear-gradient(135deg, #fff8e1 0%, #ffecb3 100%)',
                    display: 'flex', 
                    alignItems: 'center', 
                    gap: 2,
                    borderBottom: '1px solid #ffe082'
                }}>
                    <Chip 
                        label={`${selectedRows.length} sélectionné(s)`}
                        color="warning"
                        sx={{ fontWeight: 600 }}
                    />
                    <Box sx={{ flex: 1 }} />
                    <Button
                        variant="contained"
                        color="error"
                        size="small"
                        startIcon={<DeleteMultipleIcon />}
                        onClick={handleDeleteMultiple}
                        sx={{ borderRadius: 2, textTransform: 'none', fontWeight: 600 }}
                    >
                        Supprimer la sélection
                    </Button>
                </Box>
            )}

            <TableContainer>
                <Table size="small">
                    <TableHead>
                        <TableRow 
                            style={{ 
                                background: 'linear-gradient(135deg, #1e3c72 0%, #2a5298 100%)'
                            }}
                        >
                            {onDeleteMultiple && (
                                <TableCell padding="checkbox" style={{ borderBottom: 'none', backgroundColor: 'transparent' }}>
                                    <Checkbox
                                        indeterminate={selectedRows.length > 0 && selectedRows.length < data.rows.length}
                                        checked={data.rows.length > 0 && selectedRows.length === data.rows.length}
                                        onChange={handleSelectAll}
                                        style={{ color: 'white' }}
                                    />
                                </TableCell>
                            )}
                            {displayColumns.map((column) => (
                                <TableCell 
                                    key={column.name}
                                    onClick={() => handleSort(column.name)}
                                    style={{ 
                                        fontWeight: 700,
                                        color: '#ffffff',
                                        cursor: 'pointer',
                                        userSelect: 'none',
                                        borderBottom: 'none',
                                        fontSize: '0.875rem',
                                        padding: '12px 16px',
                                        backgroundColor: 'transparent'
                                    }}
                                >
                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                        <span style={{ color: '#ffffff', fontWeight: 700 }}>{column.label}</span>
                                        {currentSortField === column.name && (
                                            <span style={{ color: '#ffd700', display: 'flex', alignItems: 'center' }}>
                                                {currentSortDirection === 'asc' ? 
                                                    <ArrowUpIcon sx={{ fontSize: 18 }} /> : 
                                                    <ArrowDownIcon sx={{ fontSize: 18 }} />
                                                }
                                            </span>
                                        )}
                                    </Box>
                                </TableCell>
                            ))}
                            {(onView || onEdit || onDelete) && (
                                <TableCell 
                                    align="center" 
                                    style={{ 
                                        fontWeight: 700, 
                                        color: '#ffffff',
                                        borderBottom: 'none',
                                        width: 140,
                                        fontSize: '0.875rem',
                                        padding: '12px 16px',
                                        backgroundColor: 'transparent'
                                    }}
                                >
                                    <span style={{ color: '#ffffff', fontWeight: 700 }}>Actions</span>
                                </TableCell>
                            )}
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {data.rows.length === 0 ? (
                            <TableRow>
                                <TableCell colSpan={colSpanTotal} align="center" sx={{ py: 6 }}>
                                    <Typography color="text.secondary" sx={{ fontSize: '1rem' }}>
                                        Aucune donnée disponible
                                    </Typography>
                                </TableCell>
                            </TableRow>
                        ) : (
                            data.rows.map((row, index) => {
                                const isSelected = selectedRows.some(r => JSON.stringify(r) === JSON.stringify(row));
                                return (
                                    <TableRow 
                                        key={index} 
                                        hover
                                        selected={isSelected}
                                        sx={{ 
                                            transition: 'background 0.2s',
                                            bgcolor: index % 2 === 0 ? '#ffffff' : '#f8f9fa',
                                            '&:hover': { bgcolor: '#e3f2fd' },
                                            '&.Mui-selected': { 
                                                bgcolor: '#fff3e0',
                                                '&:hover': { bgcolor: '#ffe0b2' }
                                            }
                                        }}
                                    >
                                        {onDeleteMultiple && (
                                            <TableCell padding="checkbox">
                                                <Checkbox
                                                    checked={isSelected}
                                                    onChange={() => handleSelectRow(row)}
                                                    sx={{ color: '#1e3c72' }}
                                                />
                                            </TableCell>
                                        )}
                                        {displayColumns.map((column) => (
                                            <TableCell key={column.name} sx={{ color: '#222' }}>
                                                {formatCellValue(row[column.name])}
                                            </TableCell>
                                        ))}
                                        {(onView || onEdit || onDelete) && (
                                            <TableCell align="center">
                                                <Box sx={{ display: 'flex', gap: 0.5, justifyContent: 'center' }}>
                                                    {onView && (
                                                        <Tooltip title="Voir les détails" arrow>
                                                            <IconButton 
                                                                size="small" 
                                                                onClick={() => onView(row)}
                                                                sx={{ 
                                                                    color: '#2196f3',
                                                                    bgcolor: alpha('#2196f3', 0.08),
                                                                    '&:hover': { bgcolor: alpha('#2196f3', 0.15) }
                                                                }}
                                                            >
                                                                <ViewIcon fontSize="small" />
                                                            </IconButton>
                                                        </Tooltip>
                                                    )}
                                                    {onEdit && (
                                                        <Tooltip title="Modifier" arrow>
                                                            <IconButton 
                                                                size="small" 
                                                                onClick={() => onEdit(row)}
                                                                sx={{ 
                                                                    color: '#ff9800',
                                                                    bgcolor: alpha('#ff9800', 0.08),
                                                                    '&:hover': { bgcolor: alpha('#ff9800', 0.15) }
                                                                }}
                                                            >
                                                                <EditIcon fontSize="small" />
                                                            </IconButton>
                                                        </Tooltip>
                                                    )}
                                                    {onDelete && (
                                                        <Tooltip title="Supprimer" arrow>
                                                            <IconButton 
                                                                size="small" 
                                                                onClick={() => onDelete(row)}
                                                                sx={{ 
                                                                    color: '#f44336',
                                                                    bgcolor: alpha('#f44336', 0.08),
                                                                    '&:hover': { bgcolor: alpha('#f44336', 0.15) }
                                                                }}
                                                            >
                                                                <DeleteIcon fontSize="small" />
                                                            </IconButton>
                                                        </Tooltip>
                                                    )}
                                                </Box>
                                            </TableCell>
                                        )}
                                    </TableRow>
                                );
                            })
                        )}
                    </TableBody>
                </Table>
            </TableContainer>

            <TablePagination
                component="div"
                count={data.total}
                page={currentPage}
                onPageChange={handleChangePage}
                rowsPerPage={currentRowsPerPage}
                onRowsPerPageChange={handleChangeRowsPerPage}
                rowsPerPageOptions={[10, 25, 50, 100]}
                labelRowsPerPage="Lignes par page:"
                labelDisplayedRows={({ from, to, count }) => (
                    <span style={{ fontSize: '0.875rem', color: '#333' }}>
                        <strong>{from}-{to}</strong> sur <strong>{count}</strong>
                    </span>
                )}
                sx={{
                    borderTop: '1px solid #e0e0e0',
                    bgcolor: '#fafbfc',
                    color: '#333',
                    '& .MuiTablePagination-selectLabel': {
                        fontSize: '0.875rem',
                        color: '#333'
                    },
                    '& .MuiTablePagination-displayedRows': {
                        fontSize: '0.875rem',
                        color: '#333'
                    },
                    '& .MuiTablePagination-select': {
                        color: '#333'
                    },
                    '& .MuiTablePagination-selectIcon': {
                        color: '#333'
                    },
                    '& .MuiIconButton-root': {
                        color: '#333'
                    }
                }}
            />
        </Box>
    );
};

export default ResourceDataTable;
