import InfoIcon from '@mui/icons-material/Info';
import PlayArrowIcon from '@mui/icons-material/PlayArrow';
import RefreshIcon from '@mui/icons-material/Refresh';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Divider,
  FormControl,
  Grid,
  IconButton,
  InputLabel,
  LinearProgress,
  MenuItem,
  Paper,
  Select,
  Stack,
  Tooltip,
  Typography
} from '@mui/material';
import React, { useEffect, useRef, useState } from 'react';
import etlService, { ETLTargetTable } from '../../services/etlService';

// Type pour les messages de log
interface LogMessage {
  id: number;
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
  timestamp: string;
}

const DataLoadingPage: React.FC = () => {
  // Debug console log
  console.log('✅ PAGE DATA LOADING CHARGÉE CORRECTEMENT - DataLoadingPage.tsx');
  
  // États
  const [tables, setTables] = useState<ETLTargetTable[]>([]);
  const [selectedTable, setSelectedTable] = useState<ETLTargetTable | null>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const [progress, setProgress] = useState<number>(0);
  const [logs, setLogs] = useState<LogMessage[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [executionId, setExecutionId] = useState<string | null>(null);
  
  // Ref pour suivre le nombre de messages déjà affichés
  const lastMessageCountRef = useRef(0);

  // Charger les tables cibles au chargement de la page
  useEffect(() => {
    fetchTargetTables();
  }, []);

  // Effet pour vérifier périodiquement le statut de l'ETL
  useEffect(() => {
    let interval: number | null = null;
    
    if (executionId && loading) {
      interval = window.setInterval(async () => {
        try {
          const status = await etlService.checkETLStatus(executionId);
          setProgress(status.progress);
          
          // Ajouter tous les nouveaux messages depuis le dernier appel
          if (status.all_messages && Array.isArray(status.all_messages)) {
            const newMessages = status.all_messages.slice(lastMessageCountRef.current);
            newMessages.forEach((msg: any) => {
              addLogMessage(msg.message, msg.type);
            });
            lastMessageCountRef.current = status.all_messages.length;
          } else if (status.message) {
            // Fallback sur le message unique si all_messages n'est pas disponible
            addLogMessage(status.message, status.type);
          }
          
          if (status.progress >= 100 || status.type === 'error') {
            setLoading(false);
            clearInterval(interval!);
            setExecutionId(null);
          }
        } catch (err) {
          console.error('Erreur lors de la vérification du statut:', err);
          // Ne pas arrêter l'intervalle en cas d'erreur temporaire
        }
      }, 2000);
    }
    
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [executionId, loading]);

  // Fonction pour récupérer la liste des tables cibles
  const fetchTargetTables = async () => {
    try {
      setLoading(true);
      setError(null);
      addLogMessage('Chargement des tables cibles ETL...', 'info');
      
      const data = await etlService.getTargetTables();

      // Tri d'affichage : modules actifs d'abord, inactifs relégués à la fin,
      // chaque groupe classé par ordre alphabétique sur le libellé.
      const sorted = [...data].sort((a, b) => {
        if (!!a.is_active !== !!b.is_active) return a.is_active ? -1 : 1;
        return (a.display_name || '').localeCompare(b.display_name || '', 'fr', { sensitivity: 'base' });
      });

      setTables(sorted);
      if (sorted.length > 0) {
        // Sélectionner par défaut la première table active
        const activeTable = sorted.find(t => t.is_active) || sorted[0];
        setSelectedTable(activeTable);
        addLogMessage(`${sorted.length} tables cibles chargées avec succès`, 'success');
      } else {
        addLogMessage('Aucune table cible trouvée dans la base de données', 'warning');
      }
    } catch (err: any) {
      console.error('Erreur lors du chargement des tables cibles:', err);
      setError('Impossible de charger les tables cibles. Veuillez réessayer.');
      addLogMessage(`Erreur: ${err?.response?.data?.error || err.message}`, 'error');
    } finally {
      setLoading(false);
    }
  };

  // Gestionnaire de changement pour le select
  const handleTableChange = (event: any) => {
    const selectedId = parseInt(event.target.value);
    const table = tables.find(t => t.id === selectedId) || null;
    setSelectedTable(table);
  };

  // Fonction pour lancer le processus ETL
  const handleExecute = async () => {
    if (!selectedTable) return;

    try {
      setLoading(true);
      setProgress(0);
      setLogs([]);
      lastMessageCountRef.current = 0; // Réinitialiser le compteur
      
      // Ajouter un message initial
      addLogMessage(`Démarrage du chargement vers ${selectedTable.display_name}`, 'info');
      
      // Lancer le processus ETL via l'API
      const result = await etlService.executeETL(selectedTable.id);
      
      if (result.success) {
        // Si le backend retourne un ID d'exécution pour le suivi
        if (result.details && result.details.execution_id) {
          setExecutionId(result.details.execution_id);
        } else {
          // Si pas de suivi en temps réel, terminer immédiatement
          setProgress(100);
          addLogMessage(result.message, 'success');
          setLoading(false);
        }
      } else {
        throw new Error(result.message);
      }
    } catch (err: any) {
      console.error('Erreur lors de l\'exécution du processus ETL:', err);
      addLogMessage(`Erreur: ${err?.response?.data?.error || err.message}`, 'error');
      setLoading(false);
    }
  };

  // Ajouter un message au journal
  const addLogMessage = (message: string, type: 'info' | 'success' | 'warning' | 'error') => {
    const newMessage: LogMessage = {
      id: Date.now(),
      message,
      type,
      timestamp: new Date().toLocaleTimeString()
    };
    setLogs(prevLogs => [...prevLogs, newMessage]);
  };

  return (
    <Box sx={{ p: 3, overflow: 'visible' }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
        <Typography variant="h4">
          Chargement des données
        </Typography>
        <Button 
          startIcon={<RefreshIcon />} 
          onClick={fetchTargetTables}
          disabled={loading}
        >
          Actualiser
        </Button>
      </Box>
      <Divider sx={{ mb: 3 }} />
      
      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          {error}
        </Alert>
      )}
      
      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6" gutterBottom>
          Sélection de la table cible
        </Typography>
        
        <FormControl fullWidth sx={{ mb: 3 }}>
          <InputLabel id="target-table-label">Table cible</InputLabel>
          <Select
            labelId="target-table-label"
            value={selectedTable?.id || ''}
            label="Table cible"
            onChange={handleTableChange}
            disabled={loading}
          >
            {tables.map((table) => (
              <MenuItem 
                key={table.id} 
                value={table.id}
                disabled={!table.is_active}
              >
                {table.display_name}
                {!table.is_active && (
                  <Chip 
                    label="Inactif" 
                    size="small" 
                    color="default" 
                    sx={{ ml: 1 }}
                  />
                )}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        
        {selectedTable && (
          <Card variant="outlined" sx={{ mb: 3 }}>
            <CardContent>
              <Grid container spacing={2}>
                <Grid item xs={12}>
                  <Typography variant="subtitle1" gutterBottom>
                    Description:
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    {selectedTable.description}
                  </Typography>
                </Grid>
                
                <Grid item xs={12}>
                  <Divider sx={{ my: 1 }} />
                </Grid>
                
                <Grid item xs={12} sm={6} md={4}>
                  <Typography variant="subtitle2" component="span">
                    Table source: 
                  </Typography>
                  <Typography variant="body2" component="span" color="text.secondary" sx={{ ml: 1 }}>
                    {selectedTable.source_schema}.{selectedTable.table_name}
                  </Typography>
                </Grid>
                
                <Grid item xs={12} sm={6} md={4}>
                  <Typography variant="subtitle2" component="span">
                    Table cible: 
                  </Typography>
                  <Typography variant="body2" component="span" color="text.secondary" sx={{ ml: 1 }}>
                    {selectedTable.target_schema}.{selectedTable.table_name}
                  </Typography>
                </Grid>
                
                <Grid item xs={12} sm={6} md={4}>
                  <Typography variant="subtitle2" component="span">
                    Module Python: 
                  </Typography>
                  <Typography variant="body2" component="span" color="text.secondary" sx={{ ml: 1 }}>
                    {selectedTable.python_module}
                  </Typography>
                </Grid>
                
                {selectedTable.dependent_on && (
                  <Grid item xs={12}>
                    <Typography variant="subtitle2" component="span">
                      Dépendances: 
                    </Typography>
                    <Typography variant="body2" component="span" color="text.secondary" sx={{ ml: 1 }}>
                      {selectedTable.dependent_on.split(',').map(dep => dep.trim()).join(', ')}
                    </Typography>
                    <Tooltip title="Cette table dépend d'autres tables qui doivent être chargées au préalable">
                      <IconButton size="small" sx={{ ml: 1 }}>
                        <InfoIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                  </Grid>
                )}
              </Grid>
            </CardContent>
          </Card>
        )}
        
        <Box sx={{ display: 'flex', justifyContent: 'flex-start', mb: 2 }}>
          <Button 
            variant="contained" 
            color="primary" 
            startIcon={<PlayArrowIcon />}
            onClick={handleExecute}
            disabled={!selectedTable || loading || (selectedTable && !selectedTable.is_active)}
          >
            Exécuter
          </Button>
        </Box>
        
        {loading && (
          <>
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
              <Box sx={{ width: '100%', mr: 1 }}>
                <LinearProgress variant="determinate" value={progress} />
              </Box>
              <Box sx={{ minWidth: 35 }}>
                <Typography variant="body2" color="text.secondary">{`${progress}%`}</Typography>
              </Box>
            </Box>
          </>
        )}
      </Paper>
      
      <Paper sx={{ p: 3 }}>
        <Typography variant="h6" gutterBottom>
          Journal d'exécution
        </Typography>
        
        <Box 
          sx={{ 
            height: 300, 
            overflowY: 'auto', 
            bgcolor: 'background.default',
            p: 2,
            borderRadius: 1
          }}
        >
          <Stack spacing={1}>
            {logs.length === 0 ? (
              <Typography variant="body2" color="text.secondary" sx={{ fontStyle: 'italic' }}>
                Aucune activité à afficher. Cliquez sur "Exécuter" pour démarrer le processus.
              </Typography>
            ) : (
              logs.map((log) => (
                <Box key={log.id} sx={{ display: 'flex', alignItems: 'flex-start' }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', mr: 1, minWidth: 60 }}>
                    [{log.timestamp}]
                  </Typography>
                  <Typography 
                    variant="body2" 
                    sx={{ 
                      color: log.type === 'error' ? 'error.main' : 
                             log.type === 'warning' ? 'warning.main' : 
                             log.type === 'success' ? 'success.main' : 'text.primary'
                    }}
                  >
                    {log.message}
                  </Typography>
                </Box>
              ))
            )}
          </Stack>
        </Box>
      </Paper>
    </Box>
  );
};

export default DataLoadingPage; 