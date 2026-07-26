import {
    Add as AddIcon,
    ArrowForward as ArrowForwardIcon,
    Delete as DeleteIcon,
    Description as DescriptionIcon,
    Edit as EditIcon,
    ExpandMore as ExpandMoreIcon,
    GridView as GridViewIcon,
    Rule as RuleIcon,
    Search as SearchIcon,
    TableRows as TableRowsIcon,
    Transform as TransformIcon,
    UploadFile as UploadFileIcon,
} from '@mui/icons-material';
import {
    Accordion,
    AccordionDetails,
    AccordionSummary,
    Alert,
    Box,
    Button,
    Card,
    CardContent,
    Chip,
    CircularProgress,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    Divider,
    FormControl,
    FormControlLabel,
    Grid,
    IconButton,
    InputAdornment,
    InputLabel,
    MenuItem,
    Paper,
    Select,
    Snackbar,
    Switch,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TextField,
    ToggleButton,
    ToggleButtonGroup,
    Tooltip,
    Typography,
    alpha,
    useTheme,
} from '@mui/material';
import React, { useCallback, useEffect, useMemo, useState } from 'react';

import businessRuleService, { BusinessRule } from '../services/businessRuleService';

type ViewMode = 'graphic' | 'table';

const OBJECT_COLORS = [
  '#1976d2', '#7b1fa2', '#388e3c', '#f57c00',
  '#c2185b', '#00838f', '#5d4037', '#455a64',
];

const getObjectColor = (name: string): string => {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash);
  }
  return OBJECT_COLORS[Math.abs(hash) % OBJECT_COLORS.length];
};

const emptyRule: Partial<BusinessRule> = {
  business_object: '',
  rule_name: '',
  source_table: '',
  source_field: '',
  transformation: '',
  target_table: '',
  target_field: '',
  description: '',
  is_active: true,
};

const ReglesGestion: React.FC = () => {
  const theme = useTheme();

  const [rules, setRules] = useState<BusinessRule[]>([]);
  const [objects, setObjects] = useState<string[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [viewMode, setViewMode] = useState<ViewMode>('graphic');

  // Filtres
  const [search, setSearch] = useState<string>('');
  const [objectFilter, setObjectFilter] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<string>('all');

  // Dialogs
  const [importOpen, setImportOpen] = useState<boolean>(false);
  const [importFile, setImportFile] = useState<File | null>(null);
  const [importing, setImporting] = useState<boolean>(false);
  const [importResult, setImportResult] = useState<string>('');

  const [formOpen, setFormOpen] = useState<boolean>(false);
  const [editRule, setEditRule] = useState<Partial<BusinessRule>>(emptyRule);
  const [saving, setSaving] = useState<boolean>(false);

  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' | 'info' }>({
    open: false,
    message: '',
    severity: 'info',
  });

  const showSnackbar = (message: string, severity: 'success' | 'error' | 'info' = 'info') => {
    setSnackbar({ open: true, message, severity });
  };

  const fetchRules = useCallback(async () => {
    try {
      setLoading(true);
      const response = await businessRuleService.getRules({
        business_object: objectFilter,
        status: statusFilter,
        search,
      });
      setRules(response.rules);
    } catch (error) {
      console.error('Erreur lors du chargement des règles:', error);
      showSnackbar('Erreur lors du chargement des règles de gestion', 'error');
    } finally {
      setLoading(false);
    }
  }, [objectFilter, statusFilter, search]);

  const fetchObjects = useCallback(async () => {
    try {
      const list = await businessRuleService.getObjects();
      setObjects(list);
    } catch (error) {
      console.error('Erreur lors du chargement des objets métier:', error);
    }
  }, []);

  // Recherche avec léger debounce
  useEffect(() => {
    const timer = setTimeout(() => {
      fetchRules();
    }, 300);
    return () => clearTimeout(timer);
  }, [fetchRules]);

  useEffect(() => {
    fetchObjects();
  }, [fetchObjects]);

  // Regroupement par objet métier pour la vue graphique
  const groupedRules = useMemo(() => {
    const groups: Record<string, BusinessRule[]> = {};
    rules.forEach((rule) => {
      const key = rule.business_object || 'Non classé';
      if (!groups[key]) groups[key] = [];
      groups[key].push(rule);
    });
    return groups;
  }, [rules]);

  const stats = useMemo(() => {
    const activeCount = rules.filter((r) => r.is_active).length;
    const transformCount = rules.filter((r) => r.transformation && r.transformation.trim()).length;
    return {
      total: rules.length,
      objects: Object.keys(groupedRules).length,
      transformations: transformCount,
      active: activeCount,
    };
  }, [rules, groupedRules]);

  // ---- Import Excel ----
  const handleImport = async () => {
    if (!importFile) return;
    try {
      setImporting(true);
      setImportResult('');
      const result = await businessRuleService.importFile(importFile);
      setImportResult(result.message + (result.errors.length ? `\n${result.errors.join('\n')}` : ''));
      showSnackbar(result.message, result.failed > 0 ? 'info' : 'success');
      await fetchRules();
      await fetchObjects();
    } catch (error: any) {
      const msg = error?.response?.data?.error || "Erreur lors de l'import du fichier";
      setImportResult(msg);
      showSnackbar(msg, 'error');
    } finally {
      setImporting(false);
    }
  };

  const handleDownloadTemplate = async () => {
    try {
      await businessRuleService.downloadTemplate();
    } catch (error) {
      showSnackbar('Erreur lors du téléchargement du modèle', 'error');
    }
  };

  // ---- Création / édition ----
  const openCreate = () => {
    setEditRule(emptyRule);
    setFormOpen(true);
  };

  const openEdit = (rule: BusinessRule) => {
    setEditRule({ ...rule });
    setFormOpen(true);
  };

  const handleSave = async () => {
    if (!editRule.business_object || !editRule.rule_name) {
      showSnackbar("L'objet métier et le nom de la règle sont obligatoires", 'error');
      return;
    }
    try {
      setSaving(true);
      if (editRule.id) {
        await businessRuleService.updateRule(editRule.id, editRule);
        showSnackbar('Règle mise à jour', 'success');
      } else {
        await businessRuleService.createRule(editRule);
        showSnackbar('Règle créée', 'success');
      }
      setFormOpen(false);
      await fetchRules();
      await fetchObjects();
    } catch (error) {
      showSnackbar("Erreur lors de l'enregistrement de la règle", 'error');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (rule: BusinessRule) => {
    if (!window.confirm(`Supprimer la règle « ${rule.rule_name} » ?`)) return;
    try {
      await businessRuleService.deleteRule(rule.id);
      showSnackbar('Règle supprimée', 'success');
      await fetchRules();
    } catch (error) {
      showSnackbar('Erreur lors de la suppression', 'error');
    }
  };

  // ---- Sous-rendus ----
  const renderMappingCard = (rule: BusinessRule) => {
    const color = getObjectColor(rule.business_object || '');
    return (
      <Card
        key={rule.id}
        variant="outlined"
        sx={{
          mb: 1.5,
          borderLeft: `4px solid ${color}`,
          opacity: rule.is_active ? 1 : 0.55,
          transition: 'box-shadow .2s',
          '&:hover': { boxShadow: 3 },
        }}
      >
        <CardContent sx={{ py: 1.5, '&:last-child': { pb: 1.5 } }}>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 1 }}>
            <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
              {rule.rule_name}
            </Typography>
            <Box>
              {!rule.is_active && <Chip label="Inactive" size="small" sx={{ mr: 1 }} />}
              <Tooltip title="Modifier">
                <IconButton size="small" onClick={() => openEdit(rule)}>
                  <EditIcon fontSize="small" />
                </IconButton>
              </Tooltip>
              <Tooltip title="Supprimer">
                <IconButton size="small" color="error" onClick={() => handleDelete(rule)}>
                  <DeleteIcon fontSize="small" />
                </IconButton>
              </Tooltip>
            </Box>
          </Box>

          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, flexWrap: 'wrap' }}>
            {/* Source */}
            <Paper
              variant="outlined"
              sx={{
                px: 1.5,
                py: 1,
                minWidth: 150,
                backgroundColor: alpha(theme.palette.info.main, 0.06),
                borderColor: alpha(theme.palette.info.main, 0.4),
              }}
            >
              <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
                Source SAP
              </Typography>
              <Typography variant="body2" sx={{ fontWeight: 600 }}>
                {rule.source_table || '—'}
              </Typography>
              {rule.source_field && (
                <Typography variant="caption" color="text.secondary">
                  {rule.source_field}
                </Typography>
              )}
            </Paper>

            {/* Transformation + flèche */}
            <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', minWidth: 110 }}>
              {rule.transformation ? (
                <Tooltip title={rule.transformation}>
                  <Chip
                    icon={<TransformIcon />}
                    label={
                      rule.transformation.length > 22
                        ? rule.transformation.slice(0, 22) + '…'
                        : rule.transformation
                    }
                    size="small"
                    sx={{ mb: 0.5, maxWidth: 180 }}
                    color="warning"
                    variant="outlined"
                  />
                </Tooltip>
              ) : (
                <Chip label="Direct" size="small" sx={{ mb: 0.5 }} variant="outlined" />
              )}
              <ArrowForwardIcon color="action" />
            </Box>

            {/* Cible */}
            <Paper
              variant="outlined"
              sx={{
                px: 1.5,
                py: 1,
                minWidth: 150,
                backgroundColor: alpha(theme.palette.success.main, 0.06),
                borderColor: alpha(theme.palette.success.main, 0.4),
              }}
            >
              <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
                Cible IFS
              </Typography>
              <Typography variant="body2" sx={{ fontWeight: 600 }}>
                {rule.target_table || '—'}
              </Typography>
              {rule.target_field && (
                <Typography variant="caption" color="text.secondary">
                  {rule.target_field}
                </Typography>
              )}
            </Paper>
          </Box>

          {rule.description && (
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1 }}>
              {rule.description}
            </Typography>
          )}
        </CardContent>
      </Card>
    );
  };

  const renderGraphicView = () => {
    const objectKeys = Object.keys(groupedRules).sort();
    if (objectKeys.length === 0) {
      return (
        <Paper sx={{ p: 4, textAlign: 'center' }}>
          <Typography color="text.secondary">Aucune règle de gestion à afficher.</Typography>
        </Paper>
      );
    }
    return objectKeys.map((objectKey) => {
      const color = getObjectColor(objectKey);
      const objectRules = groupedRules[objectKey];
      return (
        <Accordion key={objectKey} defaultExpanded sx={{ mb: 1 }}>
          <AccordionSummary expandIcon={<ExpandMoreIcon />}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
              <Box sx={{ width: 14, height: 14, borderRadius: '50%', backgroundColor: color }} />
              <Typography sx={{ fontWeight: 600 }}>{objectKey}</Typography>
              <Chip label={`${objectRules.length} règle(s)`} size="small" />
            </Box>
          </AccordionSummary>
          <AccordionDetails>{objectRules.map(renderMappingCard)}</AccordionDetails>
        </Accordion>
      );
    });
  };

  const renderTableView = () => (
    <TableContainer component={Paper}>
      <Table size="small">
        <TableHead>
          <TableRow sx={{ backgroundColor: alpha(theme.palette.primary.main, 0.05) }}>
            <TableCell sx={{ fontWeight: 600 }}>Objet métier</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Règle</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Source (table.champ)</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Transformation</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Cible (table.champ)</TableCell>
            <TableCell sx={{ fontWeight: 600 }} align="center">Statut</TableCell>
            <TableCell sx={{ fontWeight: 600 }} align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {rules.length === 0 ? (
            <TableRow>
              <TableCell colSpan={7} align="center" sx={{ py: 4 }}>
                <Typography color="text.secondary">Aucune règle de gestion.</Typography>
              </TableCell>
            </TableRow>
          ) : (
            rules.map((rule) => (
              <TableRow key={rule.id} hover>
                <TableCell>
                  <Chip
                    label={rule.business_object}
                    size="small"
                    sx={{
                      backgroundColor: alpha(getObjectColor(rule.business_object || ''), 0.15),
                      color: getObjectColor(rule.business_object || ''),
                      fontWeight: 600,
                    }}
                  />
                </TableCell>
                <TableCell>{rule.rule_name}</TableCell>
                <TableCell>
                  {[rule.source_table, rule.source_field].filter(Boolean).join('.') || '—'}
                </TableCell>
                <TableCell>{rule.transformation || '—'}</TableCell>
                <TableCell>
                  {[rule.target_table, rule.target_field].filter(Boolean).join('.') || '—'}
                </TableCell>
                <TableCell align="center">
                  <Chip
                    label={rule.is_active ? 'Active' : 'Inactive'}
                    size="small"
                    color={rule.is_active ? 'success' : 'default'}
                    variant={rule.is_active ? 'filled' : 'outlined'}
                  />
                </TableCell>
                <TableCell align="right">
                  <IconButton size="small" onClick={() => openEdit(rule)}>
                    <EditIcon fontSize="small" />
                  </IconButton>
                  <IconButton size="small" color="error" onClick={() => handleDelete(rule)}>
                    <DeleteIcon fontSize="small" />
                  </IconButton>
                </TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>
    </TableContainer>
  );

  const kpiCards = [
    { label: 'Règles de gestion', value: stats.total, color: theme.palette.primary.main, icon: <RuleIcon /> },
    { label: 'Objets métier', value: stats.objects, color: theme.palette.secondary.main, icon: <GridViewIcon /> },
    { label: 'Transformations', value: stats.transformations, color: theme.palette.warning.main, icon: <TransformIcon /> },
    { label: 'Règles actives', value: stats.active, color: theme.palette.success.main, icon: <RuleIcon /> },
  ];

  return (
    <Box sx={{ width: '100%', p: 3 }}>
      {/* En-tête */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 2, mb: 2 }}>
        <Box>
          <Typography variant="h4" sx={{ fontWeight: 700 }}>
            Règles de gestion
          </Typography>
          <Typography variant="subtitle1" color="text.secondary">
            Visualisation des mappings métier Source SAP → Cible IFS
          </Typography>
        </Box>
        <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
          <Button variant="outlined" startIcon={<DescriptionIcon />} onClick={handleDownloadTemplate}>
            Modèle Excel
          </Button>
          <Button variant="outlined" startIcon={<UploadFileIcon />} onClick={() => { setImportFile(null); setImportResult(''); setImportOpen(true); }}>
            Importer Excel
          </Button>
          <Button variant="contained" startIcon={<AddIcon />} onClick={openCreate}>
            Ajouter une règle
          </Button>
        </Box>
      </Box>

      {/* KPI */}
      <Grid container spacing={2} sx={{ mb: 2 }}>
        {kpiCards.map((kpi) => (
          <Grid item xs={6} md={3} key={kpi.label}>
            <Card>
              <CardContent sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                <Box
                  sx={{
                    width: 44,
                    height: 44,
                    borderRadius: 2,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    backgroundColor: alpha(kpi.color, 0.12),
                    color: kpi.color,
                  }}
                >
                  {kpi.icon}
                </Box>
                <Box>
                  <Typography variant="h5" sx={{ fontWeight: 700 }}>
                    {kpi.value}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {kpi.label}
                  </Typography>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      {/* Filtres */}
      <Card sx={{ mb: 2 }}>
        <CardContent>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} md={5}>
              <TextField
                fullWidth
                size="small"
                placeholder="Rechercher (règle, table, champ, transformation...)"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <SearchIcon />
                    </InputAdornment>
                  ),
                }}
              />
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <FormControl fullWidth size="small">
                <InputLabel id="object-filter-label">Objet métier</InputLabel>
                <Select
                  labelId="object-filter-label"
                  label="Objet métier"
                  value={objectFilter}
                  onChange={(e) => setObjectFilter(e.target.value)}
                >
                  <MenuItem value="">Tous</MenuItem>
                  {objects.map((obj) => (
                    <MenuItem key={obj} value={obj}>
                      {obj}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} sm={6} md={2}>
              <FormControl fullWidth size="small">
                <InputLabel id="status-filter-label">Statut</InputLabel>
                <Select
                  labelId="status-filter-label"
                  label="Statut"
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                >
                  <MenuItem value="all">Tous</MenuItem>
                  <MenuItem value="active">Actives</MenuItem>
                  <MenuItem value="inactive">Inactives</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={2} sx={{ display: 'flex', justifyContent: { md: 'flex-end' } }}>
              <ToggleButtonGroup
                value={viewMode}
                exclusive
                size="small"
                onChange={(_, value) => value && setViewMode(value)}
              >
                <ToggleButton value="graphic">
                  <Tooltip title="Vue graphique">
                    <GridViewIcon fontSize="small" />
                  </Tooltip>
                </ToggleButton>
                <ToggleButton value="table">
                  <Tooltip title="Vue tableau">
                    <TableRowsIcon fontSize="small" />
                  </Tooltip>
                </ToggleButton>
              </ToggleButtonGroup>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Contenu */}
      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
          <CircularProgress />
        </Box>
      ) : viewMode === 'graphic' ? (
        renderGraphicView()
      ) : (
        renderTableView()
      )}

      {/* Dialog Import */}
      <Dialog open={importOpen} onClose={() => setImportOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Importer des règles depuis Excel</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Formats acceptés : .xlsx, .xls, .csv. Colonnes attendues : Objet métier, Nom de la règle,
            Table source, Champ source, Transformation, Table cible, Champ cible, Description, Active.
          </Typography>
          <Button variant="outlined" component="label" startIcon={<UploadFileIcon />} fullWidth sx={{ py: 2 }}>
            {importFile ? importFile.name : 'Choisir un fichier'}
            <input
              type="file"
              hidden
              accept=".xlsx,.xls,.csv"
              onChange={(e) => setImportFile(e.target.files?.[0] || null)}
            />
          </Button>
          {importResult && (
            <Alert severity="info" sx={{ mt: 2, whiteSpace: 'pre-line' }}>
              {importResult}
            </Alert>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleDownloadTemplate} startIcon={<DescriptionIcon />}>
            Modèle
          </Button>
          <Box sx={{ flex: 1 }} />
          <Button onClick={() => setImportOpen(false)}>Fermer</Button>
          <Button variant="contained" onClick={handleImport} disabled={!importFile || importing}>
            {importing ? 'Import en cours…' : 'Importer'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Dialog Création / Édition */}
      <Dialog open={formOpen} onClose={() => setFormOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>{editRule.id ? 'Modifier la règle' : 'Nouvelle règle de gestion'}</DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 0 }}>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                size="small"
                label="Objet métier *"
                value={editRule.business_object || ''}
                onChange={(e) => setEditRule({ ...editRule, business_object: e.target.value })}
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                size="small"
                label="Nom de la règle *"
                value={editRule.rule_name || ''}
                onChange={(e) => setEditRule({ ...editRule, rule_name: e.target.value })}
              />
            </Grid>
            <Grid item xs={12}>
              <Divider>
                <Chip label="Source SAP" size="small" />
              </Divider>
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                size="small"
                label="Table source"
                value={editRule.source_table || ''}
                onChange={(e) => setEditRule({ ...editRule, source_table: e.target.value })}
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                size="small"
                label="Champ source"
                value={editRule.source_field || ''}
                onChange={(e) => setEditRule({ ...editRule, source_field: e.target.value })}
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                size="small"
                label="Transformation"
                value={editRule.transformation || ''}
                onChange={(e) => setEditRule({ ...editRule, transformation: e.target.value })}
              />
            </Grid>
            <Grid item xs={12}>
              <Divider>
                <Chip label="Cible IFS" size="small" />
              </Divider>
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                size="small"
                label="Table cible"
                value={editRule.target_table || ''}
                onChange={(e) => setEditRule({ ...editRule, target_table: e.target.value })}
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                size="small"
                label="Champ cible"
                value={editRule.target_field || ''}
                onChange={(e) => setEditRule({ ...editRule, target_field: e.target.value })}
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                size="small"
                multiline
                minRows={2}
                label="Description"
                value={editRule.description || ''}
                onChange={(e) => setEditRule({ ...editRule, description: e.target.value })}
              />
            </Grid>
            <Grid item xs={12}>
              <FormControlLabel
                control={
                  <Switch
                    checked={editRule.is_active ?? true}
                    onChange={(e) => setEditRule({ ...editRule, is_active: e.target.checked })}
                  />
                }
                label="Règle active"
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setFormOpen(false)}>Annuler</Button>
          <Button variant="contained" onClick={handleSave} disabled={saving}>
            {saving ? 'Enregistrement…' : 'Enregistrer'}
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={snackbar.open}
        autoHideDuration={4000}
        onClose={() => setSnackbar({ ...snackbar, open: false })}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      >
        <Alert severity={snackbar.severity} onClose={() => setSnackbar({ ...snackbar, open: false })}>
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default ReglesGestion;
