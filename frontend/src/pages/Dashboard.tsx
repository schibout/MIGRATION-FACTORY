import { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  Box,
  Grid,
  Card,
  CardHeader,
  CardContent,
  Typography,
  Divider,
  IconButton,
  MenuItem,
  Select,
  FormControl,
  CircularProgress,
  SelectChangeEvent,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
} from '@mui/material';
import { ArrowUpward, ArrowDownward, MoreVert as MoreVertIcon } from '@mui/icons-material';
import { RootState } from '../store';
import { fetchExtractionHistory } from '../store/slices/extractionSlice';
import ExtractionStatusChart from '../components/dashboard/ExtractionStatusChart';
import DataQualityChart from '../components/dashboard/DataQualityChart';
import MetricCard from '../components/dashboard/MetricCard';
import LineChart from '../components/dashboard/LineChart';

// Périodes disponibles
const periods = [
  { value: 'today', label: "Aujourd'hui" },
  { value: 'this_week', label: 'Cette semaine' },
  { value: 'this_month', label: 'Ce mois' },
  { value: 'last_month', label: 'Mois dernier' },
  { value: 'custom', label: 'Personnalisé' },
];

const Dashboard = () => {
  const dispatch = useDispatch();
  const [period, setPeriod] = useState('this_month');
  
  const extractionJobs = useSelector(
    (state: RootState) => state.extraction.extractionJobs
  );
  
  const isLoading = useSelector(
    (state: RootState) => state.extraction.status === 'loading'
  );

  // Données fictives pour les KPI
  const metrics = {
    extractionTotal: 24,
    extractionSuccess: 18,
    extractionRunning: 2,
    extractionFailed: 4,
    tablesTotal: 15,
    recordsExtracted: 754923,
    qualityScore: 87,
    completionRate: 72,
  };

  // Données fictives pour l'historique des extractions
  const recentExtractions = [
    {
      id: '1',
      table: 'LFA1',
      date: '2023-04-15 09:30',
      status: 'completed',
      records: 2945,
    },
    {
      id: '2',
      table: 'ADRC',
      date: '2023-04-15 10:15',
      status: 'completed',
      records: 3827,
    },
    {
      id: '3',
      table: 'LFBK',
      date: '2023-04-15 11:00',
      status: 'running',
      records: 1294,
    },
    {
      id: '4',
      table: 'LFB1',
      date: '2023-04-14 16:45',
      status: 'failed',
      records: 0,
    },
    {
      id: '5',
      table: 'LFBW',
      date: '2023-04-14 15:30',
      status: 'completed',
      records: 2187,
    },
  ];

  // Récupération des données d'extraction
  useEffect(() => {
    dispatch(fetchExtractionHistory({}) as any);
  }, [dispatch]);

  const handlePeriodChange = (event: SelectChangeEvent) => {
    setPeriod(event.target.value);
  };

  return (
    <Box sx={{ overflow: 'visible' }}>
      {/* En-tête avec sélecteur de période */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3, alignItems: 'center' }}>
        <Typography variant="h4" component="h1">
          TABLEAU DE BORD
        </Typography>
        <FormControl sx={{ minWidth: 200 }}>
          <Select
            value={period}
            onChange={handlePeriodChange}
            displayEmpty
            size="small"
            sx={{ 
              backgroundColor: '#2c3649', 
              '.MuiOutlinedInput-notchedOutline': { borderColor: 'rgba(255, 255, 255, 0.12)' } 
            }}
          >
            {periods.map((option) => (
              <MenuItem key={option.value} value={option.value}>
                {option.label}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      </Box>

      {/* Section KPI */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} md={4}>
          <Card>
            <CardHeader
              title="EXTRACTIONS"
              action={
                <IconButton aria-label="settings">
                  <MoreVertIcon />
                </IconButton>
              }
            />
            <CardContent sx={{ pt: 0 }}>
              <Typography variant="h3" component="div" sx={{ mb: 2 }}>
                {metrics.extractionTotal}
              </Typography>
              <ExtractionStatusChart 
                success={metrics.extractionSuccess} 
                running={metrics.extractionRunning} 
                failed={metrics.extractionFailed} 
              />
              <Box sx={{ display: 'flex', justifyContent: 'space-between', mt: 2 }}>
                <Typography variant="body2" color="text.secondary">
                  Succès: {metrics.extractionSuccess}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  En cours: {metrics.extractionRunning}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Échec: {metrics.extractionFailed}
                </Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card>
            <CardHeader
              title="TAUX DE COMPLÉTION"
              action={
                <IconButton aria-label="settings">
                  <MoreVertIcon />
                </IconButton>
              }
            />
            <CardContent sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', pt: 0 }}>
              <Box sx={{ position: 'relative', display: 'inline-flex', mb: 2 }}>
                <CircularProgress
                  variant="determinate"
                  value={metrics.completionRate}
                  size={120}
                  thickness={5}
                  sx={{ color: '#4d8bf0' }}
                />
                <Box
                  sx={{
                    top: 0,
                    left: 0,
                    bottom: 0,
                    right: 0,
                    position: 'absolute',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <Typography variant="h4" component="div">
                    {`${Math.round(metrics.completionRate)}%`}
                  </Typography>
                </Box>
              </Box>
              <Typography variant="body2" color="text.secondary" textAlign="center">
                {metrics.tablesTotal} tables / {metrics.recordsExtracted.toLocaleString()} enregistrements
              </Typography>
              <Box sx={{ display: 'flex', alignItems: 'center', mt: 1 }}>
                <ArrowUpward sx={{ color: 'success.main', fontSize: 16, mr: 0.5 }} />
                <Typography variant="body2" color="success.main">
                  +4% par rapport à la dernière période
                </Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card>
            <CardHeader
              title="QUALITÉ DES DONNÉES"
              action={
                <IconButton aria-label="settings">
                  <MoreVertIcon />
                </IconButton>
              }
            />
            <CardContent sx={{ pt: 0 }}>
              <DataQualityChart quality={metrics.qualityScore} />
              <Box sx={{ mt: 2 }}>
                <Grid container spacing={2}>
                  <Grid item xs={6}>
                    <MetricCard 
                      title="Score" 
                      value={metrics.qualityScore.toString()} 
                      change={4} 
                      unit="%" 
                    />
                  </Grid>
                  <Grid item xs={6}>
                    <MetricCard 
                      title="Var." 
                      value="+8" 
                      change={2} 
                      suffix="pts" 
                    />
                  </Grid>
                </Grid>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Section tableau d'extractions récentes */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12}>
          <Card>
            <CardHeader title="EXTRACTIONS RÉCENTES" />
            <Divider />
            <CardContent sx={{ p: 0 }}>
              <TableContainer component={Paper} sx={{ boxShadow: 'none', backgroundColor: 'transparent' }}>
                <Table>
                  <TableHead>
                    <TableRow>
                      <TableCell>Table</TableCell>
                      <TableCell>Date</TableCell>
                      <TableCell>Statut</TableCell>
                      <TableCell align="right">Enregistrements</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {recentExtractions.map((extraction) => (
                      <TableRow key={extraction.id}>
                        <TableCell>{extraction.table}</TableCell>
                        <TableCell>{extraction.date}</TableCell>
                        <TableCell>
                          <Chip
                            label={
                              extraction.status === 'completed'
                                ? 'Succès'
                                : extraction.status === 'running'
                                ? 'En cours'
                                : 'Échec'
                            }
                            size="small"
                            sx={{
                              backgroundColor:
                                extraction.status === 'completed'
                                  ? 'rgba(109, 212, 140, 0.2)'
                                  : extraction.status === 'running'
                                  ? 'rgba(77, 139, 240, 0.2)'
                                  : 'rgba(244, 67, 54, 0.2)',
                              color:
                                extraction.status === 'completed'
                                  ? '#6dd48c'
                                  : extraction.status === 'running'
                                  ? '#4d8bf0'
                                  : '#f44336',
                            }}
                          />
                        </TableCell>
                        <TableCell align="right">
                          {extraction.records.toLocaleString()}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Section performance et progression */}
      <Grid container spacing={3}>
        <Grid item xs={12} md={6}>
          <Card>
            <CardHeader title="PERFORMANCE D'EXTRACTION" />
            <CardContent>
              <LineChart />
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} md={6}>
          <Card>
            <CardHeader title="PROGRESSION DE LA MIGRATION" />
            <CardContent>
              <Box sx={{ display: 'flex', justifyContent: 'space-around', mb: 2 }}>
                <Box sx={{ textAlign: 'center' }}>
                  <Typography variant="h5" color="primary.main">58%</Typography>
                  <Typography variant="body2" color="text.secondary">Extraction</Typography>
                </Box>
                <Box sx={{ textAlign: 'center' }}>
                  <Typography variant="h5" color="secondary.main">42%</Typography>
                  <Typography variant="body2" color="text.secondary">Nettoyage</Typography>
                </Box>
                <Box sx={{ textAlign: 'center' }}>
                  <Typography variant="h5" color="error.main">12%</Typography>
                  <Typography variant="body2" color="text.secondary">Validation</Typography>
                </Box>
              </Box>

              {/* Barres de progression */}
              <Box sx={{ mb: 1.5 }}>
                <Typography variant="body2" sx={{ mb: 0.5 }}>Extraction</Typography>
                <Box sx={{ height: 8, width: '100%', bgcolor: 'background.paper', borderRadius: 1 }}>
                  <Box
                    sx={{
                      height: '100%',
                      width: '58%',
                      bgcolor: 'primary.main',
                      borderRadius: 1,
                    }}
                  />
                </Box>
              </Box>
              <Box sx={{ mb: 1.5 }}>
                <Typography variant="body2" sx={{ mb: 0.5 }}>Nettoyage</Typography>
                <Box sx={{ height: 8, width: '100%', bgcolor: 'background.paper', borderRadius: 1 }}>
                  <Box
                    sx={{
                      height: '100%',
                      width: '42%',
                      bgcolor: 'secondary.main',
                      borderRadius: 1,
                    }}
                  />
                </Box>
              </Box>
              <Box sx={{ mb: 1.5 }}>
                <Typography variant="body2" sx={{ mb: 0.5 }}>Validation</Typography>
                <Box sx={{ height: 8, width: '100%', bgcolor: 'background.paper', borderRadius: 1 }}>
                  <Box
                    sx={{
                      height: '100%',
                      width: '12%',
                      bgcolor: 'error.main',
                      borderRadius: 1,
                    }}
                  />
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Dashboard;