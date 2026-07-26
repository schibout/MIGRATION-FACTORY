import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Grid,
  TextField,
  Button,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  LinearProgress,
  TablePagination,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  IconButton,
  InputAdornment
} from '@mui/material';
import {
  Search as SearchIcon,
  FileDownload as ExportIcon,
  Refresh as RefreshIcon,
  FilterList as FilterIcon
} from '@mui/icons-material';
import api from '../services/api';

interface SapTable {
  name: string;
  class: string;
}

interface TableData {
  columns: string[];
  rows: Record<string, any>[];
  total: number;
}

const DataExplorer = () => {
  const { tableName } = useParams<{ tableName: string }>();
  const [tables, setTables] = useState<SapTable[]>([]);
  const [selectedTable, setSelectedTable] = useState<string>(tableName || '');
  const [tableData, setTableData] = useState<TableData>({ columns: [], rows: [], total: 0 });
  const [loading, setLoading] = useState<boolean>(false);
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [totalTables, setTotalTables] = useState<number>(0);
  const [tableSearchQuery, setTableSearchQuery] = useState<string>('');
  
  // Récupération de la liste des tables SAP disponibles
  useEffect(() => {
    const fetchSapTables = async () => {
      try {
        setLoading(true);
        
        try {
          // Essayer de récupérer les données depuis l'API
          const response = await api.get('/data/sap-tables', {
            params: {
              page: page + 1,
              limit: rowsPerPage,
              search: tableSearchQuery || undefined
            }
          });
          
          if (response.data) {
            setTables(response.data.tables || []);
            setTotalTables(response.data.total || 0);
            
            // Si tableName est fourni via l'URL, l'utiliser
            // Sinon, sélectionner la première table disponible si aucune n'est déjà sélectionnée
            if (tableName) {
              setSelectedTable(tableName);
            } else if (response.data.tables?.length > 0 && !selectedTable) {
              setSelectedTable(response.data.tables[0].name);
            }
          }
        } catch (error) {
          console.error('Erreur lors de la récupération des tables SAP depuis l\'API:', error);
          
          // Utiliser des données de test si l'API ne répond pas
          console.log('Utilisation de données de test pour les tables SAP');
          const mockTables = [
            { name: 'T001', class: 'TRANSP' },
            { name: 'MARA', class: 'TRANSP' },
            { name: 'KNA1', class: 'TRANSP' },
            { name: 'EKKO', class: 'TRANSP' },
            { name: 'VBAK', class: 'TRANSP' },
            { name: 'LFA1', class: 'TRANSP' },
            { name: 'BKPF', class: 'TRANSP' },
            { name: 'MAKT', class: 'TRANSP' },
            { name: 'VBAP', class: 'TRANSP' },
            { name: 'LIKP', class: 'TRANSP' },
          ];
          
          // Filtrer les tables selon la recherche si nécessaire
          let filteredTables = mockTables;
          if (tableSearchQuery) {
            const searchLower = tableSearchQuery.toLowerCase();
            filteredTables = mockTables.filter(table => 
              table.name.toLowerCase().includes(searchLower)
            );
          }
          
          setTables(filteredTables);
          setTotalTables(filteredTables.length);
          
          if (tableName) {
            setSelectedTable(tableName);
          } else if (filteredTables.length > 0 && !selectedTable) {
            setSelectedTable(filteredTables[0].name);
          }
        }
      } finally {
        setLoading(false);
      }
    };
    
    fetchSapTables();
  }, [tableName, page, rowsPerPage, tableSearchQuery]);
  
  // Récupération des données de la table sélectionnée
  useEffect(() => {
    const fetchTableData = async () => {
      if (!selectedTable) return;
      
      try {
        setLoading(true);
        
        try {
          // Essayer de récupérer les données depuis l'API
          const response = await api.get(`/data/${selectedTable}/preview`, {
            params: {
              limit: 50
            }
          });
          
          if (response.data) {
            setTableData({
              columns: response.data.columns || [],
              rows: response.data.data || [],
              total: response.data.data?.length || 0
            });
          }
        } catch (error) {
          console.error(`Erreur lors de la récupération des données de ${selectedTable}:`, error);
          
          // Utiliser des données de test si l'API ne répond pas
          console.log(`Utilisation de données de test pour la table ${selectedTable}`);
          
          // Génération de colonnes et données en fonction de la table sélectionnée
          let mockColumns = [];
          let mockRows = [];
          
          // Colonnes et données fictives selon la table sélectionnée
          switch(selectedTable) {
            case 'T001':
              mockColumns = ['MANDT', 'BUKRS', 'BUTXT', 'LAND1', 'WAERS'];
              mockRows = [
                { MANDT: '100', BUKRS: '1000', BUTXT: 'Société France', LAND1: 'FR', WAERS: 'EUR' },
                { MANDT: '100', BUKRS: '2000', BUTXT: 'Société Allemagne', LAND1: 'DE', WAERS: 'EUR' },
                { MANDT: '100', BUKRS: '3000', BUTXT: 'Société USA', LAND1: 'US', WAERS: 'USD' },
              ];
              break;
            case 'MARA':
              mockColumns = ['MATNR', 'MTART', 'MBRSH', 'MEINS', 'BRGEW'];
              mockRows = [
                { MATNR: '000000000000001', MTART: 'FERT', MBRSH: 'M', MEINS: 'ST', BRGEW: '1.500' },
                { MATNR: '000000000000002', MTART: 'ROH', MBRSH: 'M', MEINS: 'KG', BRGEW: '0.800' },
                { MATNR: '000000000000003', MTART: 'HALB', MBRSH: 'M', MEINS: 'L', BRGEW: '2.000' },
              ];
              break;
            case 'KNA1':
              mockColumns = ['KUNNR', 'LAND1', 'NAME1', 'ORT01', 'STRAS'];
              mockRows = [
                { KUNNR: '0000001000', LAND1: 'FR', NAME1: 'Client Exemple 1', ORT01: 'Paris', STRAS: 'Rue de Rivoli' },
                { KUNNR: '0000002000', LAND1: 'DE', NAME1: 'Client Exemple 2', ORT01: 'Berlin', STRAS: 'Hauptstrasse' },
                { KUNNR: '0000003000', LAND1: 'US', NAME1: 'Client Exemple 3', ORT01: 'New York', STRAS: 'Broadway' },
              ];
              break;
            default:
              // Pour les autres tables, générer des données génériques
              mockColumns = ['CHAMP1', 'CHAMP2', 'CHAMP3', 'CHAMP4', 'CHAMP5'];
              mockRows = [
                { CHAMP1: 'Valeur 1-1', CHAMP2: 'Valeur 1-2', CHAMP3: 'Valeur 1-3', CHAMP4: 'Valeur 1-4', CHAMP5: 'Valeur 1-5' },
                { CHAMP1: 'Valeur 2-1', CHAMP2: 'Valeur 2-2', CHAMP3: 'Valeur 2-3', CHAMP4: 'Valeur 2-4', CHAMP5: 'Valeur 2-5' },
                { CHAMP1: 'Valeur 3-1', CHAMP2: 'Valeur 3-2', CHAMP3: 'Valeur 3-3', CHAMP4: 'Valeur 3-4', CHAMP5: 'Valeur 3-5' },
              ];
          }
          
          setTableData({
            columns: mockColumns,
            rows: mockRows,
            total: mockRows.length
          });
        }
      } finally {
        setLoading(false);
      }
    };
    
    fetchTableData();
  }, [selectedTable]);
  
  // Gestion du changement de table
  const handleTableChange = (event: any) => {
    const newTable = event.target.value;
    setSelectedTable(newTable);
    
    // Mise à jour de l'URL sans recharger la page
    if (newTable) {
      window.history.pushState({}, '', `/data/${newTable}`);
    } else {
      window.history.pushState({}, '', '/data');
    }
  };
  
  // Gestion de la recherche de table
  const handleTableSearch = () => {
    setPage(0); // Réinitialiser la pagination lors d'une nouvelle recherche
  };
  
  // Gestion de la pagination
  const handleChangePage = (_event: unknown, newPage: number) => {
    setPage(newPage);
  };
  
  const handleChangeRowsPerPage = (event: React.ChangeEvent<HTMLInputElement>) => {
    setRowsPerPage(parseInt(event.target.value, 10));
    setPage(0);
  };

  return (
    <Box>
      <Typography variant="h4" sx={{ mb: 3 }}>
        EXPLORATEUR DE DONNÉES
      </Typography>
      
      <Card sx={{ mb: 4 }}>
        <CardContent>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} md={7}>
              <TextField
                fullWidth
                label="Recherche de table"
                variant="outlined"
                value={tableSearchQuery}
                onChange={(e) => setTableSearchQuery(e.target.value)}
                placeholder="Rechercher par nom de table..."
                disabled={loading}
                InputProps={{
                  endAdornment: (
                    <InputAdornment position="end">
                      <IconButton onClick={handleTableSearch} disabled={loading}>
                        <SearchIcon />
                      </IconButton>
                    </InputAdornment>
                  ),
                }}
                onKeyPress={(e) => {
                  if (e.key === 'Enter') {
                    handleTableSearch();
                  }
                }}
              />
            </Grid>
            
            <Grid item xs={12} md={3}>
              <FormControl fullWidth>
                <InputLabel>Sélectionner une table</InputLabel>
                <Select
                  value={selectedTable}
                  label="Sélectionner une table"
                  onChange={handleTableChange}
                  disabled={loading}
                >
                  {tables.map((table) => (
                    <MenuItem key={table.name} value={table.name}>
                      {table.name}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            
            <Grid item xs={12} md={2}>
              <Button
                fullWidth
                variant="contained"
                color="primary"
                startIcon={<ExportIcon />}
                disabled={loading || !selectedTable}
              >
                Exporter
              </Button>
            </Grid>
          </Grid>
        </CardContent>
      </Card>
      
      {loading && <LinearProgress sx={{ mb: 2 }} />}
      
      {tables.length > 0 && (
        <TableContainer component={Paper} sx={{ mb: 3 }}>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell><Typography variant="subtitle2">Nom de la table</Typography></TableCell>
                <TableCell><Typography variant="subtitle2">Classe de table</Typography></TableCell>
                <TableCell align="right"><Typography variant="subtitle2">Action</Typography></TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {tables.map((table) => (
                <TableRow 
                  key={table.name} 
                  hover
                  selected={selectedTable === table.name}
                  onClick={() => setSelectedTable(table.name)}
                  sx={{ cursor: 'pointer' }}
                >
                  <TableCell>{table.name}</TableCell>
                  <TableCell>{table.class}</TableCell>
                  <TableCell align="right">
                    <Button
                      size="small"
                      variant="outlined"
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedTable(table.name);
                        window.history.pushState({}, '', `/data/${table.name}`);
                      }}
                    >
                      Sélectionner
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}
      
      {tables.length > 0 && (
        <TablePagination
          rowsPerPageOptions={[10, 25, 50, 100]}
          component="div"
          count={totalTables}
          rowsPerPage={rowsPerPage}
          page={page}
          onPageChange={handleChangePage}
          onRowsPerPageChange={handleChangeRowsPerPage}
          labelDisplayedRows={({ from, to, count }) => `${from}-${to} sur ${count}`}
          labelRowsPerPage="Tables par page:"
        />
      )}
      
      {selectedTable ? (
        <>
          <Typography variant="h5" sx={{ mt: 4, mb: 2 }}>
            Aperçu de {selectedTable}
          </Typography>
          
          {tableData.rows.length > 0 ? (
            <TableContainer component={Paper}>
              <Table sx={{ minWidth: 650 }} size="small">
                <TableHead>
                  <TableRow>
                    {tableData.columns.map((column) => (
                      <TableCell key={column}>
                        <Typography variant="subtitle2">{column}</Typography>
                      </TableCell>
                    ))}
                  </TableRow>
                </TableHead>
                <TableBody>
                  {tableData.rows.map((row, index) => (
                    <TableRow key={index} hover>
                      {tableData.columns.map((column) => (
                        <TableCell key={`${index}-${column}`}>
                          {row[column] !== null && row[column] !== undefined ? String(row[column]) : ''}
                        </TableCell>
                      ))}
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          ) : (
            <Card>
              <CardContent sx={{ textAlign: 'center', py: 5 }}>
                <Typography variant="body2" color="text.secondary">
                  Aucune donnée disponible dans cette table.
                </Typography>
              </CardContent>
            </Card>
          )}
        </>
      ) : (
        <Card>
          <CardContent sx={{ textAlign: 'center', py: 5 }}>
            <Typography variant="h6" color="text.secondary" gutterBottom>
              AUCUNE TABLE SÉLECTIONNÉE
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Veuillez sélectionner une table pour afficher ses données.
            </Typography>
          </CardContent>
        </Card>
      )}
    </Box>
  );
};

export default DataExplorer;