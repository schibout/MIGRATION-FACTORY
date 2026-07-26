import {
  Delete as DeleteIcon,
  DeleteSweep as DeleteMultipleIcon,
  Edit as EditIcon,
  Visibility as ViewIcon
} from '@mui/icons-material';
import {
  alpha,
  Box,
  Button,
  Card,
  CardContent,
  Checkbox,
  Fade,
  IconButton,
  ListItemText,
  Menu,
  MenuItem,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TablePagination,
  TableRow,
  TableSortLabel,
  Tooltip,
  Typography,
  useMediaQuery,
  useTheme
} from '@mui/material';
import React, { useState } from 'react';
import { TableData } from '../../services/ifsTablesService';

interface IfsDataTableProps {
  data: TableData;
  onPageChange: (page: number) => void;
  onRowsPerPageChange: (rowsPerPage: number) => void;
  onSortChange: (field: string, direction: 'asc' | 'desc') => void;
  currentPage: number;
  currentRowsPerPage: number;
  currentSortField: string;
  currentSortDirection: 'asc' | 'desc';
  loading: boolean;
  onEdit?: (row: any) => void;
  onDelete?: (row: any) => void;
  onView?: (row: any) => void;
  onExport?: (format: 'csv' | 'excel') => void;
  onDeleteMultiple?: (rows: any[]) => void;
}

const IfsDataTable = ({
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
  onExport,
  onDeleteMultiple
}: IfsDataTableProps) => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  
  const [selectedRows, setSelectedRows] = useState<any[]>([]);
  const [selectAll, setSelectAll] = useState(false);
  const [visibleColumns, setVisibleColumns] = useState<string[]>(
    data.columns
      .filter(col => !['created_timestamp', 'updated_timestamp', 'created_by', 'updated_by', 'is_deleted'].includes(col.name))
      .map(col => col.name)
  );
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const open = Boolean(anchorEl);

  const handleSort = (column: string) => {
    const newDirection = currentSortField === column && currentSortDirection === 'asc' ? 'desc' : 'asc';
    onSortChange(column, newDirection);
  };

  const handleChangePage = (_event: unknown, newPage: number) => {
    setSelectedRows([]);
    setSelectAll(false);
    onPageChange(newPage);
  };

  const handleChangeRowsPerPage = (event: React.ChangeEvent<HTMLInputElement>) => {
    setSelectedRows([]);
    setSelectAll(false);
    onRowsPerPageChange(parseInt(event.target.value, 10));
  };

  const handleEdit = (row: any) => {
    if (onEdit) {
      onEdit(row);
    } else {
      console.warn("La fonction onEdit n'est pas définie");
    }
  };

  const handleDelete = (row: any) => {
    if (onDelete) {
      if (selectedRows.some(selectedRow => JSON.stringify(selectedRow) === JSON.stringify(row))) {
        setSelectedRows(selectedRows.filter(
          selectedRow => JSON.stringify(selectedRow) !== JSON.stringify(row)
        ));
      }
      onDelete(row);
    } else {
      console.warn("La fonction onDelete n'est pas définie");
    }
  };

  const handleView = (row: any) => {
    if (onView) {
      onView(row);
    } else {
      console.warn("La fonction onView n'est pas définie");
    }
  };

  const handleSelectRow = (event: React.ChangeEvent<HTMLInputElement>, row: any) => {
    if (event.target.checked) {
      setSelectedRows([...selectedRows, row]);
    } else {
      setSelectedRows(selectedRows.filter(
        selectedRow => JSON.stringify(selectedRow) !== JSON.stringify(row)
      ));
      setSelectAll(false);
    }
  };

  const handleSelectAll = (event: React.ChangeEvent<HTMLInputElement>) => {
    setSelectAll(event.target.checked);
    if (event.target.checked) {
      setSelectedRows([...data.rows]);
    } else {
      setSelectedRows([]);
    }
  };

  const isRowSelected = (row: any) => {
    return selectedRows.some(selectedRow => JSON.stringify(selectedRow) === JSON.stringify(row));
  };

  const handleDeleteMultiple = () => {
    if (onDeleteMultiple) {
      const rowsToDelete = [...selectedRows];
      setSelectedRows([]);
      setSelectAll(false);
      onDeleteMultiple(rowsToDelete);
    } else {
      console.warn("La fonction onDeleteMultiple n'est pas définie");
      setSelectedRows([]);
      setSelectAll(false);
    }
  };

  const handleOpenMenu = (event: React.MouseEvent<HTMLButtonElement>) => setAnchorEl(event.currentTarget);
  const handleCloseMenu = () => setAnchorEl(null);
  const handleToggleColumn = (colName: string) => {
    setVisibleColumns(cols =>
      cols.includes(colName)
        ? cols.filter(c => c !== colName)
        : [...cols, colName]
    );
  };

  if (data.rows.length === 0) {
    return (
      <Card>
        <CardContent sx={{ textAlign: 'center', py: 5 }}>
          <Typography variant="body2" color="text.secondary">
            Aucune donnée disponible.
          </Typography>
        </CardContent>
      </Card>
    );
  }

  const headerBgColor = '#1a237e';
  const headerTextColor = 'white';
  const rowEvenBgColor = '#e8eaf6';
  const rowOddBgColor = '#ffffff';

  return (
    <Box sx={{ width: '100%', overflowX: 'auto' }}>
      <Fade in={selectedRows.length > 0}>
        <Box sx={{ 
          display: 'flex', 
          justifyContent: 'flex-end', 
          mb: 0.10, 
          mt: 0.10 
        }}>
          <Button
            variant="contained"
            color="error"
            startIcon={<DeleteMultipleIcon />}
            onClick={handleDeleteMultiple}
            sx={{ 
              fontWeight: 'bold',
              textTransform: 'uppercase'
            }}
          >
            Supprimer {selectedRows.length} élément{selectedRows.length > 1 ? 's' : ''} sélectionné{selectedRows.length > 1 ? 's' : ''}
          </Button>
        </Box>
      </Fade>
      
      <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 1, mt: 0.5 }}>
        <Button
          onClick={handleOpenMenu}
          variant="outlined"
          size="small"
          sx={{
            ml: 1,
            height: '32px',
            px: 1.5,
            py: 0.5,
            fontSize: '0.8rem',
            fontWeight: 'bold',
            color: '#1a237e',
            borderColor: '#1a237e',
            backgroundColor: '#fff',
            '&:hover': {
              backgroundColor: '#e3eafc',
              borderColor: '#1a237e',
              color: '#111a60'
            },
            boxShadow: '0 2px 4px rgba(26,35,126,0.08)'
          }}
        >
          Colonnes à afficher
        </Button>
        <Menu anchorEl={anchorEl} open={open} onClose={handleCloseMenu}>
          {data.columns.map(col => (
            <MenuItem key={col.name} onClick={() => handleToggleColumn(col.name)}>
              <Checkbox checked={visibleColumns.includes(col.name)} />
              <ListItemText primary={col.label || col.name} />
            </MenuItem>
          ))}
        </Menu>
      </Box>
      
      <TableContainer component={Paper} sx={{ maxHeight: 650 }}>
        <Table stickyHeader aria-label="données IFS">
          <TableHead>
            <TableRow>
              <TableCell 
                padding="checkbox"
                sx={{ 
                  backgroundColor: headerBgColor, 
                  position: 'sticky',
                  left: 0,
                  zIndex: 3
                }}
              >
                <Checkbox
                  indeterminate={selectedRows.length > 0 && selectedRows.length < data.rows.length}
                  checked={selectAll}
                  onChange={handleSelectAll}
                  sx={{
                    color: headerTextColor,
                    '&.Mui-checked': {
                      color: headerTextColor,
                    },
                    '&.MuiCheckbox-indeterminate': {
                      color: headerTextColor,
                    }
                  }}
                />
              </TableCell>
              
              <TableCell 
                align="center"
                sx={{ 
                  width: '120px',
                  fontWeight: 'bold', 
                  backgroundColor: headerBgColor, 
                  color: headerTextColor,
                  py: 1,
                  px: 0.5,
                  fontSize: '0.875rem',
                  position: 'sticky',
                  left: '48px',
                  zIndex: 3
                }}
              >
                Actions
              </TableCell>
              
              {data.columns.filter(col => visibleColumns.includes(col.name)).map((column) => (
                <TableCell
                  key={column.name}
                  align="left"
                  sx={{ 
                    fontWeight: 'bold', 
                    backgroundColor: headerBgColor, 
                    color: headerTextColor,
                    py: 1,
                    px: 1,
                    fontSize: '0.875rem',
                    minWidth: '120px'
                  }}
                  onClick={() => handleSort(column.name)}
                >
                  <TableSortLabel
                    active={currentSortField === column.name}
                    direction={currentSortField === column.name ? currentSortDirection : 'asc'}
                    sx={{
                      '&.MuiTableSortLabel-root': {
                        color: headerTextColor,
                      },
                      '&.MuiTableSortLabel-root:hover': {
                        color: 'rgba(255, 255, 255, 0.8)',
                      },
                      '&.Mui-active': {
                        color: headerTextColor,
                      },
                      '& .MuiTableSortLabel-icon': {
                        color: `${headerTextColor} !important`,
                      },
                    }}
                  >
                    {column.label}
                  </TableSortLabel>
                </TableCell>
              ))}
            </TableRow>
          </TableHead>
          
          <TableBody>
            {data.rows.map((row, index) => (
              <TableRow
                key={index}
                hover
                selected={isRowSelected(row)}
                sx={{ 
                  backgroundColor: index % 2 === 0 ? rowEvenBgColor : rowOddBgColor,
                  height: '32px',
                  '&.Mui-selected, &.Mui-selected:hover': {
                    backgroundColor: alpha(theme.palette.primary.main, 0.15),
                  }
                }}
              >
                <TableCell 
                  padding="checkbox"
                  sx={{ 
                    position: 'sticky',
                    left: 0,
                    zIndex: 2,
                    py: 0.25,
                    backgroundColor: isRowSelected(row) 
                      ? alpha(theme.palette.primary.main, 0.15)
                      : (index % 2 === 0 ? rowEvenBgColor : rowOddBgColor)
                  }}
                >
                  <Checkbox
                    checked={isRowSelected(row)}
                    onChange={(event) => handleSelectRow(event, row)}
                    size="small"
                    sx={{
                      color: '#1a237e',
                      '&.Mui-checked': {
                        color: '#1a237e',
                      }
                    }}
                  />
                </TableCell>
                
                <TableCell 
                  align="center"
                  sx={{ 
                    width: '120px',
                    position: 'sticky',
                    left: '48px',
                    zIndex: 2,
                    py: 0.25,
                    backgroundColor: isRowSelected(row) 
                      ? alpha(theme.palette.primary.main, 0.15)
                      : (index % 2 === 0 ? rowEvenBgColor : rowOddBgColor)
                  }}
                >
                  <Box sx={{ display: 'flex', justifyContent: 'center', gap: 0.5 }}>
                    <Tooltip title="Voir">
                      <IconButton 
                        size="small"
                        onClick={() => handleView(row)}
                        sx={{ 
                          color: '#1a237e',
                          p: 0.25,
                          '&:hover': { bgcolor: alpha('#1a237e', 0.08) }
                        }}
                      >
                        <ViewIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    
                    {onEdit && (
                      <Tooltip title="Modifier">
                        <IconButton 
                          size="small"
                          onClick={() => handleEdit(row)}
                          sx={{ 
                            color: '#1976d2',
                            p: 0.25,
                            '&:hover': { bgcolor: alpha('#1976d2', 0.08) }
                          }}
                        >
                          <EditIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}
                    
                    {onDelete && (
                      <Tooltip title="Supprimer">
                        <IconButton 
                          size="small"
                          onClick={() => handleDelete(row)}
                          sx={{ 
                            color: '#d32f2f',
                            p: 0.25,
                            '&:hover': { bgcolor: alpha('#d32f2f', 0.08) }
                          }}
                        >
                          <DeleteIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}
                  </Box>
                </TableCell>
                
                {data.columns.filter(col => visibleColumns.includes(col.name)).map((column) => (
                  <TableCell
                    key={column.name}
                    align="left"
                    sx={{ 
                      py: 0.5,
                      px: 1,
                      fontSize: '0.875rem',
                      color: '#000000',
                      backgroundColor: isRowSelected(row) 
                        ? alpha(theme.palette.primary.main, 0.15)
                        : 'inherit'
                    }}
                  >
                    <Typography 
                      variant="body2" 
                      sx={{ 
                        fontSize: '0.8rem',
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        maxWidth: '200px',
                        color: '#000000'
                      }}
                    >
                      {row[column.name] !== null && row[column.name] !== undefined 
                        ? String(row[column.name]) 
                        : '-'
                      }
                    </Typography>
                  </TableCell>
                ))}
              </TableRow>
            ))}
          </TableBody>
        </Table>
        
        <Box sx={{ 
          display: 'flex', 
          justifyContent: 'space-between', 
          alignItems: 'center',
          p: 1, 
          borderTop: '1px solid #e0e0e0',
          backgroundColor: '#f5f5f5' 
        }}>
          <TablePagination
            rowsPerPageOptions={[10, 25, 50, 100]}
            component="div"
            count={data.total}
            rowsPerPage={currentRowsPerPage}
            page={currentPage}
            onPageChange={handleChangePage}
            onRowsPerPageChange={handleChangeRowsPerPage}
            labelDisplayedRows={({ from, to, count }) => `${from}-${to} sur ${count}`}
            labelRowsPerPage="Lignes par page:"
            sx={{
              '.MuiTablePagination-select': {
                fontWeight: 'bold',
                color: '#1a237e'
              },
              '.MuiTablePagination-displayedRows': {
                fontWeight: 'bold',
                color: '#1a237e'
              },
              '.MuiTablePagination-selectLabel': {
                fontWeight: 'bold',
                color: '#1a237e'
              },
              '.MuiTablePagination-actions': {
                color: '#1a237e'
              }
            }}
          />
        </Box>
      </TableContainer>
    </Box>
  );
};

export default IfsDataTable; 