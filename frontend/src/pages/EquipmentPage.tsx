import React, { useState, useEffect, useCallback } from 'react';
import MaintenanceJobBanner from '../components/maintenance/MaintenanceJobBanner';
import {
  Box,
  Paper,
  Typography,
  TextField,
  InputAdornment,
  CircularProgress,
  Alert,
  Chip,
  IconButton,
  Tooltip,
  Divider,
  useTheme,
  alpha,
  Button,
  Grid,
  Snackbar,
  Tabs,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TablePagination,
  TableSortLabel,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Card,
  CardContent,
  LinearProgress,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
} from '@mui/material';
import {
  Search as SearchIcon,
  Build as EquipmentIcon,
  Refresh as RefreshIcon,
  Edit as EditIcon,
  Save as SaveIcon,
  Cancel as CancelIcon,
  Info as InfoIcon,
  Business as BusinessIcon,
  CalendarToday as CalendarIcon,
  FilterList as FilterIcon,
  Clear as ClearIcon,
  LocationOn as LocationIcon,
  Factory as FactoryIcon,
  Inventory as InventoryIcon,
  Add as AddIcon,
  Delete as DeleteIcon,
} from '@mui/icons-material';
import api from '../services/api';

interface Equipment {
  id: string;
  description: string;
  type: string;
  category?: string;
  manufacturer?: string;
  model?: string;
  serial_number?: string;
  inventory_number?: string;
  functional_location?: string;
  maintenance_plant?: string;
  planner_group?: string;
  start_date?: string;
  construction_year?: string;
  construction_month?: string;
  created_date?: string;
  created_by?: string;
  modified_date?: string;
  modified_by?: string;
  deletion_flag?: string;
  [key: string]: any;
}

// Field component for details
const FIELD_MAX_LENGTHS: Record<string, number> = {
  description: 40,
  type: 10,
  category: 1,
  manufacturer: 30,
  manufacturer_country: 3,
  model: 20,
  serial_number: 18,
  inventory_number: 25,
  material_number: 18,
  maintenance_plant: 4,
  planner_group: 3,
  construction_year: 4,
  construction_month: 2,
  size: 18,
  weight_unit: 3,
  currency: 5,
  supplier: 10,
  warranty_period: 10,
};

const DetailField: React.FC<{
  label: string;
  value: string | undefined | null;
  isEditing: boolean;
  fieldName: string;
  editedData: Record<string, string>;
  onFieldChange: (field: string, value: string) => void;
  monospace?: boolean;
  editable?: boolean;
  fullWidth?: boolean;
}> = ({ label, value, isEditing, fieldName, editedData, onFieldChange, monospace = false, editable = true, fullWidth = false }) => {
  if (!value && !isEditing) return null;
  
  const maxLen = FIELD_MAX_LENGTHS[fieldName];
  const currentVal = editedData[fieldName] ?? value ?? '';
  const isOverLimit = maxLen && currentVal.length > maxLen;

  return (
    <Grid item xs={fullWidth ? 12 : 6} md={fullWidth ? 12 : 4}>
      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
        {label}
        {isEditing && editable && maxLen && (
          <Typography component="span" variant="caption" sx={{ ml: 1, color: isOverLimit ? 'error.main' : 'text.disabled', fontWeight: isOverLimit ? 600 : 400 }}>
            ({currentVal.length}/{maxLen})
          </Typography>
        )}
      </Typography>
      {isEditing && editable ? (
        <TextField
          size="small"
          fullWidth
          value={currentVal}
          onChange={(e) => onFieldChange(fieldName, e.target.value)}
          inputProps={{ maxLength: maxLen || undefined }}
          error={!!isOverLimit}
          helperText={isOverLimit ? `Max ${maxLen} caractères` : undefined}
          sx={{ 
            '& input': { 
              fontFamily: monospace ? 'monospace' : 'inherit',
              fontSize: '0.875rem',
            } 
          }}
        />
      ) : (
        <Typography 
          variant="body2" 
          sx={{ 
            fontFamily: monospace ? 'monospace' : 'inherit',
            fontWeight: 500,
          }}
        >
          {value || '-'}
        </Typography>
      )}
    </Grid>
  );
};

const EquipmentPage: React.FC = () => {
  const theme = useTheme();
  
  // List state
  const [equipment, setEquipment] = useState<Equipment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(25);
  const [total, setTotal] = useState(0);
  const [orderBy, setOrderBy] = useState<string>('id');
  const [order, setOrder] = useState<'asc' | 'desc'>('asc');
  
  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [filterType, setFilterType] = useState('');
  const [filterPlant, setFilterPlant] = useState('');
  const [types, setTypes] = useState<string[]>([]);
  const [plants, setPlants] = useState<string[]>([]);
  
  // Details state
  const [selectedEquipment, setSelectedEquipment] = useState<Equipment | null>(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editedData, setEditedData] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [activeTab, setActiveTab] = useState(0);
  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>({
    open: false,
    message: '',
    severity: 'success',
  });

  // Create dialog state
  const [createOpen, setCreateOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [newEq, setNewEq] = useState<Record<string, string>>({
    description: '',
    type: '',
    manufacturer: '',
    model: '',
    serial_number: '',
    inventory_number: '',
    maintenance_plant: '',
    planner_group: '',
    functional_location: '',
  });

  // Delete dialog state
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);

  // Load equipment list
  const loadEquipment = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      
      const params = new URLSearchParams({
        page: String(page + 1),
        per_page: String(rowsPerPage),
        order_by: orderBy,
        order: order,
      });
      
      if (debouncedSearch) params.append('search', debouncedSearch);
      if (filterType) params.append('type', filterType);
      if (filterPlant) params.append('plant', filterPlant);
      
      const response = await api.get(`/maintenance/equipment?${params}`);
      
      if (response.data.success) {
        setEquipment(response.data.data);
        setTotal(response.data.total);
        
        if (response.data.filter_options) {
          setTypes(response.data.filter_options.types || []);
          setPlants(response.data.filter_options.plants || []);
        }
      }
    } catch (err: any) {
      console.error('Erreur chargement équipements:', err);
      setError('Erreur lors du chargement des données');
    } finally {
      setLoading(false);
    }
  }, [page, rowsPerPage, orderBy, order, debouncedSearch, filterType, filterPlant]);

  useEffect(() => {
    loadEquipment();
  }, [loadEquipment]);

  // Load equipment details
  const loadEquipmentDetails = async (equnr: string) => {
    try {
      setDetailsLoading(true);
      const response = await api.get(`/maintenance/equipment/${encodeURIComponent(equnr)}/details`);
      if (response.data.success) {
        setSelectedEquipment(response.data.data);
      }
    } catch (err) {
      console.error('Erreur chargement détails:', err);
    } finally {
      setDetailsLoading(false);
    }
  };

  // Handle row selection
  const handleRowClick = (eq: Equipment) => {
    setIsEditing(false);
    setEditedData({});
    setActiveTab(0);
    loadEquipmentDetails(eq.id);
  };

  // Handle sort
  const handleSort = (property: string) => {
    const isAsc = orderBy === property && order === 'asc';
    setOrder(isAsc ? 'desc' : 'asc');
    setOrderBy(property);
  };

  // Debounce search
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedSearch(searchQuery);
      setPage(0);
    }, 400);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  // Edit functions
  const startEditing = () => {
    setIsEditing(true);
    setEditedData({});
  };

  const cancelEditing = () => {
    setIsEditing(false);
    setEditedData({});
  };

  const handleFieldChange = (field: string, value: string) => {
    if (!selectedEquipment) return;
    const original = String(selectedEquipment[field] ?? '');
    if (value === original) {
      setEditedData((prev) => {
        const next = { ...prev };
        delete next[field];
        return next;
      });
    } else {
      setEditedData((prev) => ({ ...prev, [field]: value }));
    }
  };

  const saveChanges = async () => {
    if (!selectedEquipment) return;

    for (const [field, val] of Object.entries(editedData)) {
      const maxLen = FIELD_MAX_LENGTHS[field];
      if (maxLen && typeof val === 'string' && val.length > maxLen) {
        setSnackbar({ open: true, message: `Le champ "${field}" dépasse ${maxLen} caractères`, severity: 'error' });
        return;
      }
    }

    try {
      setSaving(true);
      const response = await api.put(`/maintenance/equipment/${encodeURIComponent(selectedEquipment.id)}`, editedData);
      
      if (response.data.success) {
        setSnackbar({
          open: true,
          message: 'Modifications enregistrées',
          severity: 'success',
        });
        setIsEditing(false);
        loadEquipmentDetails(selectedEquipment.id);
        loadEquipment();
      }
    } catch (err: any) {
      const serverMsg = err?.response?.data?.error || err?.response?.data?.message || 'Erreur lors de la sauvegarde';
      setSnackbar({
        open: true,
        message: serverMsg,
        severity: 'error',
      });
    } finally {
      setSaving(false);
    }
  };

  // Clear filters
  const clearFilters = () => {
    setSearchQuery('');
    setDebouncedSearch('');
    setFilterType('');
    setFilterPlant('');
    setPage(0);
  };

  // Create equipment
  const openCreateDialog = () => {
    setNewEq({
      description: '',
      type: '',
      manufacturer: '',
      model: '',
      serial_number: '',
      inventory_number: '',
      maintenance_plant: '',
      planner_group: '',
      functional_location: '',
    });
    setCreateOpen(true);
  };

  const handleCreate = async () => {
    if (!newEq.description.trim()) {
      setSnackbar({ open: true, message: 'La description est requise', severity: 'error' });
      return;
    }
    for (const [field, val] of Object.entries(newEq)) {
      const maxLen = FIELD_MAX_LENGTHS[field];
      if (maxLen && val.length > maxLen) {
        setSnackbar({ open: true, message: `Le champ "${field}" dépasse ${maxLen} caractères`, severity: 'error' });
        return;
      }
    }
    try {
      setCreating(true);
      const response = await api.post('/maintenance/equipment', newEq);
      if (response.data.success) {
        setSnackbar({ open: true, message: 'Équipement créé', severity: 'success' });
        setCreateOpen(false);
        loadEquipment();
      }
    } catch (err: any) {
      const msg = err?.response?.data?.error || 'Erreur lors de la création';
      setSnackbar({ open: true, message: msg, severity: 'error' });
    } finally {
      setCreating(false);
    }
  };

  // Delete equipment
  const handleDelete = async () => {
    if (!selectedEquipment) return;
    try {
      setDeleting(true);
      const response = await api.delete(`/maintenance/equipment/${encodeURIComponent(selectedEquipment.id)}`);
      if (response.data.success) {
        setSnackbar({ open: true, message: response.data.message || 'Équipement supprimé', severity: 'success' });
        setDeleteOpen(false);
        setSelectedEquipment(null);
        loadEquipment();
      }
    } catch (err: any) {
      const msg = err?.response?.data?.error || 'Erreur lors de la suppression';
      setSnackbar({ open: true, message: msg, severity: 'error' });
    } finally {
      setDeleting(false);
    }
  };

  // Stats cards
  const renderStats = () => (
    <Grid container spacing={2} sx={{ mb: 3 }}>
      <Grid item xs={12} sm={6} md={3}>
        <Card sx={{ backgroundColor: alpha(theme.palette.primary.main, 0.1) }}>
          <CardContent sx={{ py: 2 }}>
            <Box sx={{ display: 'flex', alignItems: 'center' }}>
              <EquipmentIcon sx={{ fontSize: 40, color: theme.palette.primary.main, mr: 2 }} />
              <Box>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>{total.toLocaleString()}</Typography>
                <Typography variant="body2" color="text.secondary">Équipements</Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
      <Grid item xs={12} sm={6} md={3}>
        <Card sx={{ backgroundColor: alpha(theme.palette.success.main, 0.1) }}>
          <CardContent sx={{ py: 2 }}>
            <Box sx={{ display: 'flex', alignItems: 'center' }}>
              <FactoryIcon sx={{ fontSize: 40, color: theme.palette.success.main, mr: 2 }} />
              <Box>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>{plants.length}</Typography>
                <Typography variant="body2" color="text.secondary">Divisions</Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
      <Grid item xs={12} sm={6} md={3}>
        <Card sx={{ backgroundColor: alpha(theme.palette.warning.main, 0.1) }}>
          <CardContent sx={{ py: 2 }}>
            <Box sx={{ display: 'flex', alignItems: 'center' }}>
              <InventoryIcon sx={{ fontSize: 40, color: theme.palette.warning.main, mr: 2 }} />
              <Box>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>{types.length}</Typography>
                <Typography variant="body2" color="text.secondary">Types</Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
      <Grid item xs={12} sm={6} md={3}>
        <Card sx={{ backgroundColor: alpha(theme.palette.info.main, 0.1) }}>
          <CardContent sx={{ py: 2 }}>
            <Box sx={{ display: 'flex', alignItems: 'center' }}>
              <LocationIcon sx={{ fontSize: 40, color: theme.palette.info.main, mr: 2 }} />
              <Box>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>-</Typography>
                <Typography variant="body2" color="text.secondary">Postes techniques</Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
    </Grid>
  );

  // Details panel
  const renderDetailsPanel = () => {
    if (!selectedEquipment) {
      return (
        <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', color: 'text.secondary' }}>
          <EquipmentIcon sx={{ fontSize: 64, mb: 2, opacity: 0.3 }} />
          <Typography variant="body1">Sélectionnez un équipement</Typography>
        </Box>
      );
    }

    if (detailsLoading) {
      return (
        <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100%' }}>
          <CircularProgress />
        </Box>
      );
    }

    const eq = selectedEquipment;

    return (
      <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
        {/* Header */}
        <Box sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <Box sx={{ display: 'flex', alignItems: 'center' }}>
              <EquipmentIcon sx={{ fontSize: 32, color: theme.palette.warning.main, mr: 2 }} />
              <Box>
                <Typography variant="h6" sx={{ fontFamily: 'monospace' }}>
                  {eq.id.replace(/^0+/, '')}
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
                  {eq.description}
                </Typography>
              </Box>
            </Box>
            
            <Box>
              {isEditing ? (
                <>
                  <Button size="small" variant="outlined" startIcon={<CancelIcon />} onClick={cancelEditing} sx={{ mr: 1 }}>
                    Annuler
                  </Button>
                  <Button
                    size="small"
                    variant="contained"
                    startIcon={saving ? <CircularProgress size={16} /> : <SaveIcon />}
                    onClick={saveChanges}
                    disabled={saving || Object.keys(editedData).length === 0}
                  >
                    Enregistrer
                  </Button>
                </>
              ) : (
                <>
                  <Button size="small" variant="outlined" startIcon={<EditIcon />} onClick={startEditing} sx={{ mr: 1 }}>
                    Modifier
                  </Button>
                  <Button
                    size="small"
                    variant="outlined"
                    color="error"
                    startIcon={<DeleteIcon />}
                    onClick={() => setDeleteOpen(true)}
                  >
                    Supprimer
                  </Button>
                </>
              )}
            </Box>
          </Box>
        </Box>

        {/* Tabs */}
        <Tabs value={activeTab} onChange={(_, v) => setActiveTab(v)} sx={{ borderBottom: `1px solid ${theme.palette.divider}`, px: 2 }}>
          <Tab icon={<InfoIcon />} iconPosition="start" label="Général" />
          <Tab icon={<BusinessIcon />} iconPosition="start" label="Organisation" />
          <Tab icon={<CalendarIcon />} iconPosition="start" label="Historique" />
        </Tabs>

        {/* Content */}
        <Box sx={{ flex: 1, overflow: 'auto', p: 2 }}>
          {activeTab === 0 && (
            <Grid container spacing={2}>
              <DetailField label="Description" value={eq.description} isEditing={isEditing} fieldName="description" editedData={editedData} onFieldChange={handleFieldChange} fullWidth />
              <DetailField label="Type" value={eq.type} isEditing={isEditing} fieldName="type" editedData={editedData} onFieldChange={handleFieldChange} />
              <DetailField label="Catégorie" value={eq.category} isEditing={isEditing} fieldName="category" editedData={editedData} onFieldChange={handleFieldChange} />
              <DetailField label="Fabricant" value={eq.manufacturer} isEditing={isEditing} fieldName="manufacturer" editedData={editedData} onFieldChange={handleFieldChange} />
              <DetailField label="Pays fabricant" value={eq.manufacturer_country} isEditing={isEditing} fieldName="manufacturer_country" editedData={editedData} onFieldChange={handleFieldChange} />
              <DetailField label="Modèle" value={eq.model} isEditing={isEditing} fieldName="model" editedData={editedData} onFieldChange={handleFieldChange} />
              <DetailField label="N° Série" value={eq.serial_number} isEditing={isEditing} fieldName="serial_number" editedData={editedData} onFieldChange={handleFieldChange} monospace />
              <DetailField label="N° Inventaire" value={eq.inventory_number} isEditing={isEditing} fieldName="inventory_number" editedData={editedData} onFieldChange={handleFieldChange} monospace />
              <DetailField label="N° Article" value={eq.material_number} isEditing={isEditing} fieldName="material_number" editedData={editedData} onFieldChange={handleFieldChange} monospace />
              <Grid item xs={12}><Divider sx={{ my: 1 }} /></Grid>
              <DetailField label="Poste technique" value={eq.parent_id} isEditing={isEditing} fieldName="parent_id" editedData={editedData} onFieldChange={handleFieldChange} monospace editable={false} />
              <DetailField label="Division maintenance" value={eq.maintenance_plant} isEditing={isEditing} fieldName="maintenance_plant" editedData={editedData} onFieldChange={handleFieldChange} />
              <DetailField label="Groupe planification" value={eq.planner_group} isEditing={isEditing} fieldName="planner_group" editedData={editedData} onFieldChange={handleFieldChange} />
              <Grid item xs={12}><Divider sx={{ my: 1 }} /></Grid>
              <DetailField label="Date mise en service" value={eq.start_date} isEditing={isEditing} fieldName="start_date" editedData={editedData} onFieldChange={handleFieldChange} />
              <DetailField label="Année construction" value={eq.construction_year} isEditing={isEditing} fieldName="construction_year" editedData={editedData} onFieldChange={handleFieldChange} />
              <DetailField label="Mois construction" value={eq.construction_month} isEditing={isEditing} fieldName="construction_month" editedData={editedData} onFieldChange={handleFieldChange} />
              <DetailField label="Garantie (fin)" value={eq.warranty_end_date} isEditing={isEditing} fieldName="warranty_end_date" editedData={editedData} onFieldChange={handleFieldChange} />
            </Grid>
          )}

          {activeTab === 1 && (
            <Grid container spacing={2}>
              <DetailField label="Centre de coûts" value={eq.cost_center} isEditing={isEditing} fieldName="cost_center" editedData={editedData} onFieldChange={handleFieldChange} monospace editable={false} />
              <DetailField label="Société" value={eq.company_code} isEditing={isEditing} fieldName="company_code" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              <DetailField label="Division" value={eq.plant} isEditing={isEditing} fieldName="plant" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              <DetailField label="Fournisseur" value={eq.supplier} isEditing={isEditing} fieldName="supplier" editedData={editedData} onFieldChange={handleFieldChange} />
              <Grid item xs={12}><Divider sx={{ my: 1 }} /></Grid>
              <DetailField label="Valeur acquisition" value={eq.acquisition_value} isEditing={isEditing} fieldName="acquisition_value" editedData={editedData} onFieldChange={handleFieldChange} />
              <DetailField label="Devise" value={eq.currency} isEditing={isEditing} fieldName="currency" editedData={editedData} onFieldChange={handleFieldChange} />
              <DetailField label="Date acquisition" value={eq.acquisition_date} isEditing={isEditing} fieldName="acquisition_date" editedData={editedData} onFieldChange={handleFieldChange} />
            </Grid>
          )}

          {activeTab === 2 && (
            <Grid container spacing={2}>
              <DetailField label="Date création" value={eq.created_date} isEditing={false} fieldName="created_date" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              <DetailField label="Créé par" value={eq.created_by} isEditing={false} fieldName="created_by" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              <DetailField label="Date modification" value={eq.modified_date} isEditing={false} fieldName="modified_date" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              <DetailField label="Modifié par" value={eq.modified_by} isEditing={false} fieldName="modified_by" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              <DetailField label="Indicateur suppression" value={eq.deletion_flag === 'X' ? 'Oui' : 'Non'} isEditing={false} fieldName="deletion_flag" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
            </Grid>
          )}
        </Box>
      </Box>
    );
  };

  return (
    <Box sx={{ p: 3, height: 'calc(100vh - 64px)', display: 'flex', flexDirection: 'column' }}>
      {/* Header */}
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
        <EquipmentIcon sx={{ fontSize: 32, mr: 2, color: theme.palette.warning.main }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Équipements
        </Typography>
        <IconButton onClick={loadEquipment} sx={{ ml: 2 }} disabled={loading}>
          <RefreshIcon />
        </IconButton>
        <Box sx={{ flex: 1 }} />
        <Button variant="contained" startIcon={<AddIcon />} onClick={openCreateDialog}>
          Nouveau
        </Button>
      </Box>

      {/* Restauration / rechargement SAP : ces donnees sont reecrites pendant l'operation */}
      <MaintenanceJobBanner onFinished={() => loadEquipment()} />

      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      {/* Stats */}
      {renderStats()}

      {/* Main content */}
      <Box sx={{ display: 'flex', gap: 3, flex: 1, minHeight: 0 }}>
        {/* List panel */}
        <Paper elevation={0} sx={{ flex: 2, display: 'flex', flexDirection: 'column', border: `1px solid ${theme.palette.divider}`, borderRadius: 2, overflow: 'hidden' }}>
          {/* Filters */}
          <Box sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
            <Grid container spacing={2} alignItems="center">
              <Grid item xs={12} md={4}>
                <TextField
                  fullWidth
                  size="small"
                  placeholder="Rechercher..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  InputProps={{
                    startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment>,
                  }}
                />
              </Grid>
              <Grid item xs={6} md={3}>
                <FormControl fullWidth size="small">
                  <InputLabel>Type</InputLabel>
                  <Select value={filterType} onChange={(e) => { setFilterType(e.target.value); setPage(0); }} label="Type">
                    <MenuItem value="">Tous</MenuItem>
                    {types.map((t) => <MenuItem key={t} value={t}>{t}</MenuItem>)}
                  </Select>
                </FormControl>
              </Grid>
              <Grid item xs={6} md={3}>
                <FormControl fullWidth size="small">
                  <InputLabel>Division</InputLabel>
                  <Select value={filterPlant} onChange={(e) => { setFilterPlant(e.target.value); setPage(0); }} label="Division">
                    <MenuItem value="">Toutes</MenuItem>
                    {plants.map((p) => <MenuItem key={p} value={p}>{p}</MenuItem>)}
                  </Select>
                </FormControl>
              </Grid>
              <Grid item xs={12} md={2}>
                <Button fullWidth variant="outlined" startIcon={<ClearIcon />} onClick={clearFilters} disabled={!searchQuery && !filterType && !filterPlant}>
                  Effacer
                </Button>
              </Grid>
            </Grid>
          </Box>

          {/* Loading bar */}
          {loading && <LinearProgress />}

          {/* Table */}
          <TableContainer sx={{ flex: 1 }}>
            <Table stickyHeader size="small">
              <TableHead>
                <TableRow>
                  <TableCell>
                    <TableSortLabel active={orderBy === 'id'} direction={orderBy === 'id' ? order : 'asc'} onClick={() => handleSort('id')}>
                      N° Équipement
                    </TableSortLabel>
                  </TableCell>
                  <TableCell>
                    <TableSortLabel active={orderBy === 'description'} direction={orderBy === 'description' ? order : 'asc'} onClick={() => handleSort('description')}>
                      Description
                    </TableSortLabel>
                  </TableCell>
                  <TableCell>Type</TableCell>
                  <TableCell>Fabricant</TableCell>
                  <TableCell>Division</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {equipment.map((eq) => (
                  <TableRow
                    key={eq.id}
                    hover
                    selected={selectedEquipment?.id === eq.id}
                    onClick={() => handleRowClick(eq)}
                    sx={{ cursor: 'pointer' }}
                  >
                    <TableCell sx={{ fontFamily: 'monospace', fontWeight: 600, color: theme.palette.warning.dark }}>
                      {eq.id.replace(/^0+/, '')}
                    </TableCell>
                    <TableCell sx={{ maxWidth: 300, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {eq.description}
                    </TableCell>
                    <TableCell>
                      {eq.type && <Chip size="small" label={eq.type} sx={{ height: 20, fontSize: '0.7rem' }} />}
                    </TableCell>
                    <TableCell>{eq.manufacturer}</TableCell>
                    <TableCell>{eq.maintenance_plant}</TableCell>
                  </TableRow>
                ))}
                {!loading && equipment.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={5} align="center" sx={{ py: 4 }}>
                      <Typography color="text.secondary">Aucun équipement trouvé</Typography>
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </TableContainer>

          {/* Pagination */}
          <TablePagination
            component="div"
            count={total}
            page={page}
            onPageChange={(_, p) => setPage(p)}
            rowsPerPage={rowsPerPage}
            onRowsPerPageChange={(e) => { setRowsPerPage(parseInt(e.target.value, 10)); setPage(0); }}
            rowsPerPageOptions={[10, 25, 50, 100]}
            labelRowsPerPage="Lignes par page:"
            labelDisplayedRows={({ from, to, count }) => `${from}-${to} sur ${count}`}
          />
        </Paper>

        {/* Details panel */}
        <Paper elevation={0} sx={{ flex: 1, minWidth: 400, border: `1px solid ${theme.palette.divider}`, borderRadius: 2, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
          {renderDetailsPanel()}
        </Paper>
      </Box>

      {/* Create dialog */}
      <Dialog open={createOpen} onClose={() => setCreateOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>Nouvel équipement</DialogTitle>
        <DialogContent dividers>
          <Grid container spacing={2} sx={{ mt: 0.5 }}>
            <Grid item xs={12}>
              <TextField
                fullWidth
                size="small"
                required
                label="Description"
                value={newEq.description}
                onChange={(e) => setNewEq({ ...newEq, description: e.target.value })}
                inputProps={{ maxLength: 40 }}
                helperText={`${newEq.description.length}/40`}
              />
            </Grid>
            <Grid item xs={6}>
              <TextField
                fullWidth size="small" label="Type"
                value={newEq.type}
                onChange={(e) => setNewEq({ ...newEq, type: e.target.value })}
                inputProps={{ maxLength: 10 }}
              />
            </Grid>
            <Grid item xs={6}>
              <TextField
                fullWidth size="small" label="Poste technique (optionnel)"
                value={newEq.functional_location}
                onChange={(e) => setNewEq({ ...newEq, functional_location: e.target.value })}
                placeholder="Ex: 9200-A1"
              />
            </Grid>
            <Grid item xs={6}>
              <TextField
                fullWidth size="small" label="Fabricant"
                value={newEq.manufacturer}
                onChange={(e) => setNewEq({ ...newEq, manufacturer: e.target.value })}
                inputProps={{ maxLength: 30 }}
              />
            </Grid>
            <Grid item xs={6}>
              <TextField
                fullWidth size="small" label="Modèle"
                value={newEq.model}
                onChange={(e) => setNewEq({ ...newEq, model: e.target.value })}
                inputProps={{ maxLength: 20 }}
              />
            </Grid>
            <Grid item xs={6}>
              <TextField
                fullWidth size="small" label="N° Série"
                value={newEq.serial_number}
                onChange={(e) => setNewEq({ ...newEq, serial_number: e.target.value })}
                inputProps={{ maxLength: 18 }}
              />
            </Grid>
            <Grid item xs={6}>
              <TextField
                fullWidth size="small" label="N° Inventaire"
                value={newEq.inventory_number}
                onChange={(e) => setNewEq({ ...newEq, inventory_number: e.target.value })}
                inputProps={{ maxLength: 25 }}
              />
            </Grid>
            <Grid item xs={6}>
              <TextField
                fullWidth size="small" label="Division maintenance"
                value={newEq.maintenance_plant}
                onChange={(e) => setNewEq({ ...newEq, maintenance_plant: e.target.value })}
                inputProps={{ maxLength: 4 }}
                placeholder="Ex: 9200"
              />
            </Grid>
            <Grid item xs={6}>
              <TextField
                fullWidth size="small" label="Groupe planification"
                value={newEq.planner_group}
                onChange={(e) => setNewEq({ ...newEq, planner_group: e.target.value })}
                inputProps={{ maxLength: 3 }}
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setCreateOpen(false)} disabled={creating}>Annuler</Button>
          <Button
            variant="contained"
            onClick={handleCreate}
            disabled={creating || !newEq.description.trim()}
            startIcon={creating ? <CircularProgress size={16} /> : <SaveIcon />}
          >
            Créer
          </Button>
        </DialogActions>
      </Dialog>

      {/* Delete confirmation */}
      <Dialog open={deleteOpen} onClose={() => setDeleteOpen(false)}>
        <DialogTitle>Supprimer l'équipement ?</DialogTitle>
        <DialogContent>
          <Typography>
            Cette action supprimera l'équipement <strong>{selectedEquipment?.id.replace(/^0+/, '')}</strong>
            {selectedEquipment?.description ? ` — ${selectedEquipment.description}` : ''} ainsi que tous ses sous-équipements.
            Cette action est irréversible.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDeleteOpen(false)} disabled={deleting}>Annuler</Button>
          <Button
            color="error"
            variant="contained"
            onClick={handleDelete}
            disabled={deleting}
            startIcon={deleting ? <CircularProgress size={16} /> : <DeleteIcon />}
          >
            Supprimer
          </Button>
        </DialogActions>
      </Dialog>

      {/* Snackbar */}
      <Snackbar open={snackbar.open} autoHideDuration={4000} onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}>
        <Alert severity={snackbar.severity} onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}>{snackbar.message}</Alert>
      </Snackbar>
    </Box>
  );
};

export default EquipmentPage;
