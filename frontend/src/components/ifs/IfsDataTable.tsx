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

  // Palette claire en dur supprimee (#1a237e / #e8eaf6 / #ffffff / #000000) :
  // ce tableau s'affichait en blanc au milieu de l'application sombre.
  // En-tete, zebrage, survol et couleurs de texte viennent du theme.

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
              {/* Colonnes figees a gauche : le fond doit rester opaque (herite
                  du theme, MuiTableCell.head) sinon les lignes defilent au
                  travers. */}
              <TableCell
                padding="checkbox"
                sx={{ position: 'sticky', left: 0, zIndex: 3 }}
              >
                <Checkbox
                  indeterminate={selectedRows.length > 0 && selectedRows.length < data.rows.length}
                  checked={selectAll}
                  onChange={handleSelectAll}
                />
              </TableCell>

              <TableCell
                align="center"
                sx={{
                  width: '120px',
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
                  sx={{ minWidth: '120px' }}
                >
                  {/* Le tri est porte par le TableSortLabel seul : le poser aussi
                      sur la cellule le declenchait deux fois par clic. */}
                  <TableSortLabel
                    active={currentSortField === column.name}
                    direction={currentSortField === column.name ? currentSortDirection : 'asc'}
                    onClick={() => handleSort(column.name)}
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
                sx={{ height: '32px' }}
              >
                <TableCell
                  padding="checkbox"
                  sx={{
                    position: 'sticky',
                    left: 0,
                    zIndex: 2,
                    py: 0.25,
                    // Cellule figee : fond OPAQUE obligatoire. Le zebrage du
                    // theme etant un voile translucide, on le reproduit ici
                    // par-dessus une base opaque pour garder la continuite.
                    backgroundColor: isRowSelected(row)
                      ? alpha(theme.palette.primary.main, 0.15)
                      : theme.palette.background.paper,
                    ...(!isRowSelected(row) && index % 2 !== 0 && {
                      backgroundImage:
                        'linear-gradient(rgba(255,255,255,0.025), rgba(255,255,255,0.025))',
                    }),
                  }}
                >
                  <Checkbox
                    checked={isRowSelected(row)}
                    onChange={(event) => handleSelectRow(event, row)}
                    size="small"
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
                    // Meme regle que la colonne cases a cocher : base opaque +
                    // voile de zebrage reproduit.
                    backgroundColor: isRowSelected(row)
                      ? alpha(theme.palette.primary.main, 0.15)
                      : theme.palette.background.paper,
                    ...(!isRowSelected(row) && index % 2 !== 0 && {
                      backgroundImage:
                        'linear-gradient(rgba(255,255,255,0.025), rgba(255,255,255,0.025))',
                    }),
                  }}
                >
                  <Box sx={{ display: 'flex', justifyContent: 'center', gap: 0.5 }}>
                    <Tooltip title="Voir">
                      <IconButton
                        size="small"
                        color="primary"
                        onClick={() => handleView(row)}
                        sx={{ p: 0.25 }}
                      >
                        <ViewIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>

                    {onEdit && (
                      <Tooltip title="Modifier">
                        <IconButton
                          size="small"
                          color="primary"
                          onClick={() => handleEdit(row)}
                          sx={{ p: 0.25 }}
                        >
                          <EditIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}

                    {onDelete && (
                      <Tooltip title="Supprimer">
                        <IconButton
                          size="small"
                          color="error"
                          onClick={() => handleDelete(row)}
                          sx={{ p: 0.25 }}
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
          borderTop: 1,
          borderColor: 'divider',
          backgroundColor: 'background.default'
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
          />
        </Box>
      </TableContainer>
    </Box>
  );
};

export default IfsDataTable; 