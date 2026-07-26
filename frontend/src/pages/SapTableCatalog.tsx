import {
  ArrowBack as BackIcon,
  Key as KeyIcon,
  OpenInNew as OpenInNewIcon,
  Search as SearchIcon,
  TableChart as TableIcon
} from '@mui/icons-material';
import {
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Collapse,
  IconButton,
  InputAdornment,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TablePagination,
  TableRow,
  TextField,
  Tooltip,
  Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import { Link as RouterLink, useNavigate, useSearchParams } from 'react-router-dom';
import sapCatalogService, { SapTable, SapTableField } from '../services/sapCatalogService';

const SCOPE_LABELS: Record<string, string> = {
  fournisseur: 'Fournisseurs',
  article: 'Articles',
  client: 'Clients',
  achat: 'Achats',
  maintenance: 'Maintenance',
  comptabilite: 'Comptabilité',
};

const SapTableCatalog: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const scope = (searchParams.get('scope') || '').trim().toLowerCase();
  const [tables, setTables] = useState<SapTable[]>([]);
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(25);
  const [expandedTable, setExpandedTable] = useState<string | null>(null);
  const [tableFields, setTableFields] = useState<Record<string, SapTableField[]>>({});
  const [loadingFields, setLoadingFields] = useState<Record<string, boolean>>({});

  useEffect(() => {
    loadTables();
  }, [scope]);

  useEffect(() => {
    setPage(0);
    setExpandedTable(null);
    setTableFields({});
    setSearchTerm('');
  }, [scope]);

  const loadTables = async () => {
    try {
      setLoading(true);
      const data = await sapCatalogService.getTables(scope || undefined);
      setTables(data);
    } catch (error) {
      console.error('Erreur lors du chargement des tables:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadTableFields = async (tableName: string) => {
    if (tableFields[tableName]) return;

    try {
      setLoadingFields({ ...loadingFields, [tableName]: true });
      const fields = await sapCatalogService.getTableFields(tableName);
      setTableFields({ ...tableFields, [tableName]: fields });
    } catch (error) {
      console.error(`Erreur lors du chargement des champs de ${tableName}:`, error);
    } finally {
      setLoadingFields({ ...loadingFields, [tableName]: false });
    }
  };

  const handleExpandClick = async (tableName: string) => {
    if (expandedTable === tableName) {
      setExpandedTable(null);
    } else {
      setExpandedTable(tableName);
      await loadTableFields(tableName);
    }
  };

  const filteredTables = tables.filter(table =>
    table.table_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    (table.description && table.description.toLowerCase().includes(searchTerm.toLowerCase()))
  );

  const paginatedTables = filteredTables.slice(
    page * rowsPerPage,
    page * rowsPerPage + rowsPerPage
  );

  const handleChangePage = (_event: unknown, newPage: number) => {
    setPage(newPage);
  };

  const handleChangeRowsPerPage = (event: React.ChangeEvent<HTMLInputElement>) => {
    setRowsPerPage(parseInt(event.target.value, 10));
    setPage(0);
  };

  return (
    <Box sx={{ width: '100%', p: 3 }}>
      {/* Header */}
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
        <IconButton onClick={() => navigate('/sap-data')} sx={{ mr: 2 }}>
          <BackIcon />
        </IconButton>
        <TableIcon sx={{ fontSize: 32, mr: 2, color: '#ff9800' }} />
        <Typography variant="h4" component="h1">
          {scope
            ? `Catalogue Tables SAP — ${SCOPE_LABELS[scope] || scope}`
            : 'Catalogue Tables SAP'}
        </Typography>
        {scope && (
          <Chip
            label={`Filtre actif : ${SCOPE_LABELS[scope] || scope}`}
            color="primary"
            variant="outlined"
            onDelete={() => navigate('/sap-data/catalog')}
            sx={{ ml: 2 }}
          />
        )}
      </Box>

      {/* Search */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <TextField
            fullWidth
            placeholder="Rechercher une table..."
            value={searchTerm}
            onChange={(e) => { setSearchTerm(e.target.value); setPage(0); }}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <SearchIcon />
                </InputAdornment>
              ),
            }}
          />
          <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
            {filteredTables.length} table(s) trouvée(s)
          </Typography>
        </CardContent>
      </Card>

      {/* Tables List */}
      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
          <CircularProgress />
        </Box>
      ) : (
        <Paper>
          <TableContainer>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell width="20%">Nom de la table</TableCell>
                  <TableCell width="50%">Description</TableCell>
                  <TableCell width="15%">Classe</TableCell>
                  <TableCell width="15%" align="center">Propriétés</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {paginatedTables.map((table) => (
                  <React.Fragment key={table.table_name}>
                    <TableRow
                      hover
                      onClick={() => handleExpandClick(table.table_name)}
                      sx={{ cursor: 'pointer' }}
                    >
                      <TableCell>
                        <Typography variant="body2" fontWeight="bold" sx={{ fontFamily: 'monospace' }}>
                          {table.table_name}
                        </Typography>
                      </TableCell>
                      <TableCell>
                        <Typography variant="body2">
                          {table.description || '-'}
                        </Typography>
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={table.table_class || 'N/A'}
                          size="small"
                          color="primary"
                          variant="outlined"
                        />
                      </TableCell>
                      <TableCell align="center">
                        <Box sx={{ display: 'flex', gap: 0.5, justifyContent: 'center', flexWrap: 'wrap' }}>
                          {table.client_dependent && (
                            <Tooltip title="Dépendant du client">
                              <Chip label="Client" size="small" color="info" />
                            </Tooltip>
                          )}
                          {table.buffer_allowed && (
                            <Tooltip title="Buffer autorisé">
                              <Chip label="Buffer" size="small" color="success" />
                            </Tooltip>
                          )}
                          {table.availableformapping && (
                            <Tooltip title="Disponible pour mapping">
                              <Chip label="Mapping" size="small" color="secondary" />
                            </Tooltip>
                          )}
                        </Box>
                      </TableCell>
                    </TableRow>

                    {/* Expanded Row - Fields */}
                    <TableRow>
                      <TableCell colSpan={4} sx={{ p: 0, border: 0 }}>
                        <Collapse in={expandedTable === table.table_name} timeout="auto" unmountOnExit>
                          <Box sx={{ p: 2, bgcolor: 'background.default' }}>
                            {loadingFields[table.table_name] ? (
                              <Box sx={{ display: 'flex', justifyContent: 'center', p: 2 }}>
                                <CircularProgress size={24} />
                              </Box>
                            ) : tableFields[table.table_name] ? (
                              <>
                                <Box
                                  sx={{
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'space-between',
                                    flexWrap: 'wrap',
                                    gap: 1,
                                    mb: 1,
                                  }}
                                >
                                  <Typography variant="subtitle2" fontWeight="bold">
                                    Champs ({tableFields[table.table_name].length})
                                  </Typography>
                                  <Button
                                    component={RouterLink}
                                    to={`/sap-data/explorer?table=${encodeURIComponent(table.table_name)}`}
                                    variant="contained"
                                    size="small"
                                    endIcon={<OpenInNewIcon />}
                                    sx={{ textTransform: 'none', fontWeight: 600 }}
                                  >
                                    Voir les données
                                  </Button>
                                </Box>
                                <TableContainer component={Paper} variant="outlined">
                                  <Table size="small">
                                    <TableHead>
                                      <TableRow>
                                        <TableCell width="5%">Pos</TableCell>
                                        <TableCell width="20%">Nom du champ</TableCell>
                                        <TableCell width="10%">Type</TableCell>
                                        <TableCell width="8%">Longueur</TableCell>
                                        <TableCell width="8%">Décimales</TableCell>
                                        <TableCell width="10%">Clés</TableCell>
                                        <TableCell width="39%">Description</TableCell>
                                      </TableRow>
                                    </TableHead>
                                    <TableBody>
                                      {tableFields[table.table_name].map((field) => (
                                        <TableRow key={field.field_name}>
                                          <TableCell>{field.position}</TableCell>
                                          <TableCell>
                                            <Typography variant="body2" sx={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>
                                              {field.field_name}
                                            </Typography>
                                          </TableCell>
                                          <TableCell>
                                            <Chip
                                              label={field.data_type}
                                              size="small"
                                              variant="outlined"
                                            />
                                          </TableCell>
                                          <TableCell align="center">{field.length || '-'}</TableCell>
                                          <TableCell align="center">{field.decimals || '-'}</TableCell>
                                          <TableCell>
                                            <Box sx={{ display: 'flex', gap: 0.5 }}>
                                              {field.key_flag && (
                                                <Tooltip title="Clé primaire">
                                                  <KeyIcon fontSize="small" color="warning" />
                                                </Tooltip>
                                              )}
                                              {field.mandatory && (
                                                <Chip label="Obligatoire" size="small" color="error" variant="outlined" />
                                              )}
                                            </Box>
                                          </TableCell>
                                          <TableCell>
                                            <Typography variant="body2" fontSize="0.8rem">
                                              {field.field_text || field.header_text || '-'}
                                            </Typography>
                                          </TableCell>
                                        </TableRow>
                                      ))}
                                    </TableBody>
                                  </Table>
                                </TableContainer>
                              </>
                            ) : null}
                          </Box>
                        </Collapse>
                      </TableCell>
                    </TableRow>
                  </React.Fragment>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
          <TablePagination
            component="div"
            count={filteredTables.length}
            page={page}
            onPageChange={handleChangePage}
            rowsPerPage={rowsPerPage}
            onRowsPerPageChange={handleChangeRowsPerPage}
            rowsPerPageOptions={[10, 25, 50, 100]}
            labelRowsPerPage="Lignes par page:"
          />
        </Paper>
      )}
    </Box>
  );
};

export default SapTableCatalog;




