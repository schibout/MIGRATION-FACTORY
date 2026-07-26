import {
    ArrowBack as ArrowBackIcon,
    CalendarToday as CalendarIcon,
    CheckCircle as CheckCircleIcon,
    Info as InfoIcon,
    Link as LinkIcon,
    Timeline as TimelineIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Breadcrumbs,
    Button,
    Card,
    CardContent,
    Chip,
    CircularProgress,
    Divider,
    Grid,
    LinearProgress,
    Link,
    Paper,
    Tab,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Tabs,
    Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../services/api';
import { projectService } from '../services/projectService';
import EtatAvancementDetailModal from '../components/etats/EtatAvancementDetailModal';
import PorteHistoriqueDialog from '../components/etats/PorteHistoriqueDialog';

interface TabPanelProps {
    children?: React.ReactNode;
    index: number;
    value: number;
}

function TabPanel(props: TabPanelProps) {
    const { children, value, index, ...other } = props;
    return (
        <div role="tabpanel" hidden={value !== index} {...other}>
            {value === index && <Box sx={{ pt: 3 }}>{children}</Box>}
        </div>
    );
}

const ProjectDetailPage: React.FC = () => {
    const { projectId } = useParams<{ projectId: string }>();
    const navigate = useNavigate();
    const [project, setProject] = useState<any>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [tabValue, setTabValue] = useState(0);
    const [etats, setEtats] = useState<any[]>([]);
    const [etatsLoading, setEtatsLoading] = useState(false);
    const [detailEtatId, setDetailEtatId] = useState<number | null>(null);
    const [selectedGate, setSelectedGate] = useState<string | null>(null);
    const [cfvCommissions, setCfvCommissions] = useState<any[]>([]);
    const [cfvLoading, setCfvLoading] = useState(false);

    useEffect(() => {
        loadProjectDetail();
    }, [projectId]);

    const loadProjectDetail = async () => {
        try {
            setLoading(true);
            setError(null);
            const response = await projectService.getProjectDetail(Number(projectId));
            if (response.success) {
                setProject(response.data);
            } else {
                setError(response.error || 'Erreur lors du chargement du projet');
            }
        } catch (err: any) {
            setError(err.response?.data?.message || 'Erreur lors du chargement du projet');
        } finally {
            setLoading(false);
        }
    };

    const loadEtatsAvancement = async () => {
        try {
            setEtatsLoading(true);
            const response = await api.get(`/data/sharepoint-projets/${projectId}/etats-avancement`);
            if (response.data.success) {
                setEtats(response.data.data);
            }
        } catch (err) {
            console.error('Erreur chargement états avancement:', err);
        } finally {
            setEtatsLoading(false);
        }
    };

    const loadCommissionsCfv = async () => {
        try {
            setCfvLoading(true);
            const response = await api.get(`/data/projets/${projectId}/commissions-cfv`);
            if (response.data.success) setCfvCommissions(response.data.data);
        } catch (err) {
            console.error('Erreur chargement commissions CFV:', err);
        } finally {
            setCfvLoading(false);
        }
    };

    useEffect(() => {
        if (tabValue === 4) {
            loadEtatsAvancement();
        }
        if (tabValue === 5) {
            loadCommissionsCfv();
        }
    }, [tabValue]);

    const formatCurrency = (value: number | null) => {
        if (value === null || value === undefined) return '-';
        return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(value);
    };

    const formatDate = (date: string | null) => {
        if (!date) return '-';
        return new Date(date).toLocaleDateString('fr-FR');
    };

    const getStatusColor = (status: string) => {
        const statusMap: { [key: string]: any } = {
            'En cours': 'primary',
            'Clôturé': 'success',
            'Annulé': 'error',
            'En attente': 'warning',
            'Suspendu': 'default'
        };
        return statusMap[status] || 'default';
    };

    const getIndicatorColor = (indicator: string) => {
        const colorMap: { [key: string]: any } = {
            'Ok': 'success',
            'Alerte': 'warning',
            'Problème': 'error'
        };
        return colorMap[indicator] || 'default';
    };

    if (loading) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" minHeight="60vh">
                <CircularProgress />
            </Box>
        );
    }

    if (error || !project) {
        return (
            <Box p={3}>
                <Alert severity="error">{error || 'Projet non trouvé'}</Alert>
                <Button startIcon={<ArrowBackIcon />} onClick={() => navigate(-1)} sx={{ mt: 2 }}>
                    Retour
                </Button>
            </Box>
        );
    }

    return (
        <Box>
            {/* Header */}
            <Paper sx={{ p: 3, mb: 3 }}>
                <Box display="flex" alignItems="center" justifyContent="space-between" mb={2}>
                    <Breadcrumbs>
                        <Link underline="hover" color="inherit" sx={{ cursor: 'pointer' }} onClick={() => navigate('/projets')}>
                            Projets
                        </Link>
                        <Typography color="text.primary">Détail #{project.sharepoint_id}</Typography>
                    </Breadcrumbs>
                    <Button startIcon={<ArrowBackIcon />} onClick={() => navigate(-1)}>
                        Retour
                    </Button>
                </Box>

                <Box display="flex" alignItems="center" gap={2} mb={2}>
                    <Typography variant="h4" component="h1">
                        {project.title}
                    </Typography>
                    <Chip label={project.global_status || 'N/A'} color={getStatusColor(project.global_status)} />
                </Box>

                <Grid container spacing={2}>
                    <Grid item xs={12} md={3}>
                        <Typography variant="caption" color="text.secondary">Code Projet</Typography>
                        <Typography variant="body1" fontWeight="medium">{project.code || '-'}</Typography>
                    </Grid>
                    <Grid item xs={12} md={3}>
                        <Typography variant="caption" color="text.secondary">Numéro</Typography>
                        <Typography variant="body1" fontWeight="medium">{project.project_number || '-'}</Typography>
                    </Grid>
                    <Grid item xs={12} md={3}>
                        <Typography variant="caption" color="text.secondary">Secteur</Typography>
                        <Typography variant="body1" fontWeight="medium">{project.sector || '-'}</Typography>
                    </Grid>
                    <Grid item xs={12} md={3}>
                        <Typography variant="caption" color="text.secondary">Template</Typography>
                        <Typography variant="body1" fontWeight="medium">{project.template || '-'}</Typography>
                    </Grid>
                </Grid>

                {project.site_url && (
                    <Box mt={2}>
                        <Button
                            startIcon={<LinkIcon />}
                            href={project.site_url}
                            target="_blank"
                            rel="noopener noreferrer"
                            size="small"
                        >
                            Ouvrir dans SharePoint
                        </Button>
                    </Box>
                )}
            </Paper>

            {/* Tabs */}
            <Paper>
                <Tabs value={tabValue} onChange={(_, newValue) => setTabValue(newValue)}>
                    <Tab label="Informations générales" />
                    <Tab label="Budgets" />
                    <Tab label="Jalons" />
                    <Tab label="Dates" />
                    <Tab icon={<TimelineIcon />} iconPosition="start" label={`États d'avancement${etats.length > 0 ? ` (${etats.length})` : ''}`} />
                    <Tab label="Commissions Feu Vert" />
                </Tabs>

                {/* Tab 1: Informations générales */}
                <TabPanel value={tabValue} index={0}>
                    <Grid container spacing={3} p={3}>
                        <Grid item xs={12}>
                            <Card>
                                <CardContent>
                                    <Typography variant="h6" gutterBottom>
                                        <InfoIcon sx={{ mr: 1, verticalAlign: 'middle' }} />
                                        Description
                                    </Typography>
                                    <Divider sx={{ my: 2 }} />
                                    {project.description ? (
                                        <div dangerouslySetInnerHTML={{ __html: project.description }} />
                                    ) : (
                                        <Typography color="text.secondary">Aucune description disponible</Typography>
                                    )}
                                </CardContent>
                            </Card>
                        </Grid>

                        <Grid item xs={12} md={6}>
                            <Card>
                                <CardContent>
                                    <Typography variant="h6" gutterBottom>Progression</Typography>
                                    <Divider sx={{ my: 2 }} />
                                    <Box mb={2}>
                                        <Typography variant="body2" color="text.secondary" mb={1}>
                                            Avancement: {project.percent_completed ? `${(project.percent_completed * 100).toFixed(0)}%` : '0%'}
                                        </Typography>
                                        <LinearProgress
                                            variant="determinate"
                                            value={project.percent_completed * 100 || 0}
                                            sx={{ height: 10, borderRadius: 5 }}
                                        />
                                    </Box>
                                    <Box>
                                        <Typography variant="body2" color="text.secondary" mb={1}>Phase actuelle</Typography>
                                        <Chip label={project.phase_text || 'N/A'} color="primary" />
                                        {project.passing_gate && (
                                            <Chip label={`Gate: ${project.passing_gate}`} sx={{ ml: 1 }} />
                                        )}
                                    </Box>
                                </CardContent>
                            </Card>
                        </Grid>

                        <Grid item xs={12} md={6}>
                            <Card>
                                <CardContent>
                                    <Typography variant="h6" gutterBottom>Indicateurs</Typography>
                                    <Divider sx={{ my: 2 }} />
                                    <Grid container spacing={2}>
                                        <Grid item xs={4}>
                                            <Typography variant="caption" color="text.secondary">Santé</Typography>
                                            <Box mt={1}>
                                                <Chip
                                                    label={project.health || 'N/A'}
                                                    color={getIndicatorColor(project.health)}
                                                    size="small"
                                                />
                                            </Box>
                                        </Grid>
                                        <Grid item xs={4}>
                                            <Typography variant="caption" color="text.secondary">Planning</Typography>
                                            <Box mt={1}>
                                                <Chip
                                                    label={project.planning || 'N/A'}
                                                    color={getIndicatorColor(project.planning)}
                                                    size="small"
                                                />
                                            </Box>
                                        </Grid>
                                        <Grid item xs={4}>
                                            <Typography variant="caption" color="text.secondary">Coût</Typography>
                                            <Box mt={1}>
                                                <Chip
                                                    label={project.cost || 'N/A'}
                                                    color={getIndicatorColor(project.cost)}
                                                    size="small"
                                                />
                                            </Box>
                                        </Grid>
                                    </Grid>
                                </CardContent>
                            </Card>
                        </Grid>

                        <Grid item xs={12} md={6}>
                            <Card>
                                <CardContent>
                                    <Typography variant="h6" gutterBottom>Organisation</Typography>
                                    <Divider sx={{ my: 2 }} />
                                    <Box display="flex" flexDirection="column" gap={1.5}>
                                        <Box>
                                            <Typography variant="caption" color="text.secondary">Groupe</Typography>
                                            <Typography variant="body2">{project.group_name || '-'}</Typography>
                                        </Box>
                                        <Box>
                                            <Typography variant="caption" color="text.secondary">PM ID</Typography>
                                            <Typography variant="body2">{project.pm_id || '-'}</Typography>
                                        </Box>
                                        <Box>
                                            <Typography variant="caption" color="text.secondary">Client Correspondent ID</Typography>
                                            <Typography variant="body2">{project.client_correspondent_id || '-'}</Typography>
                                        </Box>
                                    </Box>
                                </CardContent>
                            </Card>
                        </Grid>

                        <Grid item xs={12} md={6}>
                            <Card>
                                <CardContent>
                                    <Typography variant="h6" gutterBottom>Flags</Typography>
                                    <Divider sx={{ my: 2 }} />
                                    <Box display="flex" gap={1} flexWrap="wrap">
                                        {project.project_ahead && <Chip label="En avance" color="success" size="small" />}
                                        {project.retroplanning && <Chip label="Retroplanning" color="info" size="small" />}
                                        {project.attachments && <Chip label="Pièces jointes" size="small" />}
                                        {!project.project_ahead && !project.retroplanning && !project.attachments && (
                                            <Typography variant="body2" color="text.secondary">Aucun flag actif</Typography>
                                        )}
                                    </Box>
                                </CardContent>
                            </Card>
                        </Grid>
                    </Grid>
                </TabPanel>

                {/* Tab 2: Budgets */}
                <TabPanel value={tabValue} index={1}>
                    <Grid container spacing={3} p={3}>
                        <Grid item xs={12} md={6} lg={3}>
                            <Card>
                                <CardContent>
                                    <Typography variant="caption" color="text.secondary">Budget Initial</Typography>
                                    <Typography variant="h5" color="primary" mt={1}>
                                        {formatCurrency(project.budget_initial)}
                                    </Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid item xs={12} md={6} lg={3}>
                            <Card>
                                <CardContent>
                                    <Typography variant="caption" color="text.secondary">Budget Total SAP</Typography>
                                    <Typography variant="h5" color="primary" mt={1}>
                                        {formatCurrency(project.budget_total_sap)}
                                    </Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid item xs={12} md={6} lg={3}>
                            <Card>
                                <CardContent>
                                    <Typography variant="caption" color="text.secondary">Budget Actual</Typography>
                                    <Typography variant="h5" color="success.main" mt={1}>
                                        {formatCurrency(project.budget_actual)}
                                    </Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid item xs={12} md={6} lg={3}>
                            <Card>
                                <CardContent>
                                    <Typography variant="caption" color="text.secondary">Budget At Completion</Typography>
                                    <Typography variant="h5" mt={1}>
                                        {formatCurrency(project.budget_at_completion)}
                                    </Typography>
                                </CardContent>
                            </Card>
                        </Grid>

                        <Grid item xs={12} md={6} lg={3}>
                            <Card>
                                <CardContent>
                                    <Typography variant="caption" color="text.secondary">Budget Demandé</Typography>
                                    <Typography variant="body1" mt={1}>
                                        {formatCurrency(project.budget_demanded)}
                                    </Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid item xs={12} md={6} lg={3}>
                            <Card>
                                <CardContent>
                                    <Typography variant="caption" color="text.secondary">Budget Delivered</Typography>
                                    <Typography variant="body1" mt={1}>
                                        {formatCurrency(project.budget_delivered)}
                                    </Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid item xs={12} md={6} lg={3}>
                            <Card>
                                <CardContent>
                                    <Typography variant="caption" color="text.secondary">Budget IM SAP</Typography>
                                    <Typography variant="body1" mt={1}>
                                        {formatCurrency(project.budget_im_sap)}
                                    </Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid item xs={12} md={6} lg={3}>
                            <Card>
                                <CardContent>
                                    <Typography variant="caption" color="text.secondary">Budget EX SAP</Typography>
                                    <Typography variant="body1" mt={1}>
                                        {formatCurrency(project.budget_ex_sap)}
                                    </Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                    </Grid>
                </TabPanel>

                {/* Tab 3: Jalons (Gates) */}
                <TabPanel value={tabValue} index={2}>
                    <Box p={3}>
                        <Typography variant="h6" gutterBottom>Jalons du Projet (Gates)</Typography>
                        <Grid container spacing={2} mt={2}>
                            {['P0', 'P1', 'P2', 'P3', 'P4', 'P5', 'P6'].map((gate) => {
                                const fieldName = `end_${gate.toLowerCase()}`;
                                const date = project[fieldName];
                                return (
                                    <Grid item xs={12} sm={6} md={4} lg={3} key={gate}>
                                        <Card
                                            variant="outlined"
                                            onClick={() => setSelectedGate(gate)}
                                            sx={{
                                                cursor: 'pointer',
                                                transition: 'all 0.2s',
                                                '&:hover': { boxShadow: 3, borderColor: 'primary.main' },
                                            }}
                                        >
                                            <CardContent>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    {date && <CheckCircleIcon color="success" fontSize="small" />}
                                                    <Typography variant="subtitle1" fontWeight="bold">
                                                        {gate}
                                                    </Typography>
                                                </Box>
                                                <Typography variant="body2" color="text.secondary" mt={1}>
                                                    {formatDate(date)}
                                                </Typography>
                                                <Typography variant="caption" color="primary" mt={1} display="block">
                                                    Voir l'historique →
                                                </Typography>
                                            </CardContent>
                                        </Card>
                                    </Grid>
                                );
                            })}
                        </Grid>

                        <Divider sx={{ my: 4 }} />

                        <Typography variant="h6" gutterBottom>Dates Spécifiques</Typography>
                        <Grid container spacing={2} mt={2}>
                            <Grid item xs={12} md={4}>
                                <Card>
                                    <CardContent>
                                        <Typography variant="caption" color="text.secondary">Conception</Typography>
                                        <Typography variant="body1" mt={1}>{formatDate(project.conception_date)}</Typography>
                                        <Typography variant="caption" color="text.secondary" mt={1}>
                                            État: {project.conception_state || '-'}
                                        </Typography>
                                    </CardContent>
                                </Card>
                            </Grid>
                            <Grid item xs={12} md={4}>
                                <Card>
                                    <CardContent>
                                        <Typography variant="caption" color="text.secondary">Mise en Service</Typography>
                                        <Typography variant="body1" mt={1}>{formatDate(project.mise_en_service_date)}</Typography>
                                        <Typography variant="caption" color="text.secondary" mt={1}>
                                            État: {project.mise_en_service_state || '-'}
                                        </Typography>
                                    </CardContent>
                                </Card>
                            </Grid>
                            <Grid item xs={12} md={4}>
                                <Card>
                                    <CardContent>
                                        <Typography variant="caption" color="text.secondary">Achèvement Industriel</Typography>
                                        <Typography variant="body1" mt={1}>{formatDate(project.achevement_industriel_date)}</Typography>
                                        <Typography variant="caption" color="text.secondary" mt={1}>
                                            État: {project.achevement_industriel_state || '-'}
                                        </Typography>
                                    </CardContent>
                                </Card>
                            </Grid>
                        </Grid>
                    </Box>
                </TabPanel>

                {/* Tab 4: Dates */}
                <TabPanel value={tabValue} index={3}>
                    <Grid container spacing={3} p={3}>
                        <Grid item xs={12} md={6}>
                            <Card>
                                <CardContent>
                                    <Typography variant="h6" gutterBottom>
                                        <CalendarIcon sx={{ mr: 1, verticalAlign: 'middle' }} />
                                        Dates Principales
                                    </Typography>
                                    <Divider sx={{ my: 2 }} />
                                    <Box display="flex" flexDirection="column" gap={2}>
                                        <Box>
                                            <Typography variant="caption" color="text.secondary">Date de Début</Typography>
                                            <Typography variant="body1">{formatDate(project.start_date)}</Typography>
                                        </Box>
                                        <Box>
                                            <Typography variant="caption" color="text.secondary">Date de Fin Estimée</Typography>
                                            <Typography variant="body1">{formatDate(project.estimated_end_date)}</Typography>
                                        </Box>
                                        <Box>
                                            <Typography variant="caption" color="text.secondary">Date d'Ouverture</Typography>
                                            <Typography variant="body1">{formatDate(project.opening_date)}</Typography>
                                        </Box>
                                        <Box>
                                            <Typography variant="caption" color="text.secondary">Dernier Rapport de Statut</Typography>
                                            <Typography variant="body1">{formatDate(project.last_status_report_date)}</Typography>
                                        </Box>
                                        <Box>
                                            <Typography variant="caption" color="text.secondary">Dernier Jalon Passé</Typography>
                                            <Typography variant="body1">{formatDate(project.last_milestone_passed)}</Typography>
                                        </Box>
                                    </Box>
                                </CardContent>
                            </Card>
                        </Grid>

                        <Grid item xs={12} md={6}>
                            <Card>
                                <CardContent>
                                    <Typography variant="h6" gutterBottom>Métadonnées</Typography>
                                    <Divider sx={{ my: 2 }} />
                                    <Box display="flex" flexDirection="column" gap={2}>
                                        <Box>
                                            <Typography variant="caption" color="text.secondary">Créé le</Typography>
                                            <Typography variant="body1">{formatDate(project.created)}</Typography>
                                        </Box>
                                        <Box>
                                            <Typography variant="caption" color="text.secondary">Modifié le</Typography>
                                            <Typography variant="body1">{formatDate(project.modified)}</Typography>
                                        </Box>
                                        <Box>
                                            <Typography variant="caption" color="text.secondary">Importé le</Typography>
                                            <Typography variant="body1">{formatDate(project.imported_at)}</Typography>
                                        </Box>
                                        <Box>
                                            <Typography variant="caption" color="text.secondary">GUID</Typography>
                                            <Typography variant="body2" fontFamily="monospace" sx={{ wordBreak: 'break-all' }}>
                                                {project.guid || '-'}
                                            </Typography>
                                        </Box>
                                    </Box>
                                </CardContent>
                            </Card>
                        </Grid>
                    </Grid>
                </TabPanel>

                {/* Tab 5: États d'avancement */}
                <TabPanel value={tabValue} index={4}>
                    <Box p={3}>
                        {etatsLoading ? (
                            <Box display="flex" justifyContent="center" p={4}><CircularProgress /></Box>
                        ) : etats.length === 0 ? (
                            <Alert severity="info">Aucun état d'avancement trouvé pour ce projet</Alert>
                        ) : (
                            <TableContainer component={Paper} variant="outlined">
                                <Table size="small">
                                    <TableHead>
                                        <TableRow>
                                            <TableCell sx={{ fontWeight: 600 }}>Date</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }}>Statut</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }}>% Complété</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }}>Santé</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }}>Planning</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }}>Coût</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }}>Commentaire</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {etats.map((etat: any) => (
                                            <TableRow
                                                key={etat.sharepoint_id}
                                                hover
                                                onClick={() => setDetailEtatId(etat.sharepoint_id)}
                                                sx={{ cursor: 'pointer' }}
                                            >
                                                <TableCell>{formatDate(etat.status_date)}</TableCell>
                                                <TableCell>
                                                    <Chip label={etat.global_status || '-'} color={getStatusColor(etat.global_status)} size="small" />
                                                </TableCell>
                                                <TableCell>
                                                    <Box display="flex" alignItems="center" gap={1}>
                                                        <LinearProgress
                                                            variant="determinate"
                                                            value={(etat.percent_completed || 0) * 100}
                                                            sx={{ width: 60, height: 6, borderRadius: 3 }}
                                                        />
                                                        <Typography variant="body2">
                                                            {etat.percent_completed ? `${(etat.percent_completed * 100).toFixed(0)}%` : '0%'}
                                                        </Typography>
                                                    </Box>
                                                </TableCell>
                                                <TableCell>
                                                    <Chip label={etat.health || '-'} color={getIndicatorColor(etat.health)} size="small" variant="outlined" />
                                                </TableCell>
                                                <TableCell>
                                                    <Chip label={etat.planning || '-'} color={getIndicatorColor(etat.planning)} size="small" variant="outlined" />
                                                </TableCell>
                                                <TableCell>
                                                    <Chip label={etat.cost || '-'} color={getIndicatorColor(etat.cost)} size="small" variant="outlined" />
                                                </TableCell>
                                                <TableCell sx={{ maxWidth: 300 }}>
                                                    {etat.update_text ? (
                                                        <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap', fontSize: '0.8rem' }}>
                                                            {etat.update_text.replace(/<[^>]*>/g, '').substring(0, 200)}
                                                            {etat.update_text.length > 200 ? '...' : ''}
                                                        </Typography>
                                                    ) : '-'}
                                                </TableCell>
                                            </TableRow>
                                        ))}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        )}
                    </Box>
                </TabPanel>

                {/* Tab 6: Commissions Feu Vert */}
                <TabPanel value={tabValue} index={5}>
                    <Box p={3}>
                        <Typography variant="h6" gutterBottom>Commissions Feu Vert</Typography>
                        {cfvLoading ? (
                            <Box display="flex" justifyContent="center" p={4}><CircularProgress /></Box>
                        ) : (
                            <Grid container spacing={2} mt={1}>
                                {['Conception', 'Mise en service', 'Achèvement industriel'].map((phase) => {
                                    const c = cfvCommissions.find((x: any) => x.phase === phase);
                                    const state = (c?.state || '').trim();
                                    const palette: Record<string, string> = {
                                        'Vert': '#4caf50',
                                        'Orange': '#ff9800',
                                        'Rouge': '#f44336',
                                        'Prévue': '#90a4ae',
                                        'pas nécessaire (NA)': '#bdbdbd',
                                    };
                                    const color = palette[state] || '#bdbdbd';
                                    return (
                                        <Grid item xs={12} sm={6} md={4} key={phase}>
                                            <Card variant="outlined" sx={{ borderTop: `6px solid ${color}` }}>
                                                <CardContent>
                                                    <Typography variant="subtitle1" fontWeight="bold" gutterBottom>{phase}</Typography>
                                                    <Box display="flex" alignItems="center" gap={1}>
                                                        <Box sx={{ width: 18, height: 18, borderRadius: '50%', bgcolor: color }} />
                                                        <Chip label={state || 'Non défini'} size="small" sx={{ bgcolor: color, color: '#fff', fontWeight: 600 }} />
                                                    </Box>
                                                    {c?.forecast && (
                                                        <Typography variant="caption" color="text.secondary" display="block" mt={1}>
                                                            Prévue : {formatDate(c.forecast)}
                                                        </Typography>
                                                    )}
                                                </CardContent>
                                            </Card>
                                        </Grid>
                                    );
                                })}
                            </Grid>
                        )}
                    </Box>
                </TabPanel>
            </Paper>

            <EtatAvancementDetailModal
                open={detailEtatId !== null}
                siteId={String(projectId)}
                etatId={detailEtatId}
                onClose={() => setDetailEtatId(null)}
            />

            <PorteHistoriqueDialog
                open={selectedGate !== null}
                siteId={String(projectId)}
                gate={selectedGate}
                onClose={() => setSelectedGate(null)}
            />
        </Box>
    );
};

export default ProjectDetailPage;


