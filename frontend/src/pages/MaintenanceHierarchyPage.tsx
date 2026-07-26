import React, { useState, useEffect, useCallback } from 'react';
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
  Collapse,
  Divider,
  useTheme,
  alpha,
  Button,
  Grid,
  Snackbar,
  Tabs,
  Tab,
  Autocomplete,
} from '@mui/material';
import {
  Search as SearchIcon,
  AccountTree as TreeIcon,
  ExpandMore as ExpandMoreIcon,
  ChevronRight as ChevronRightIcon,
  Folder as FolderIcon,
  FolderOpen as FolderOpenIcon,
  Build as EquipmentIcon,
  LocationOn as LocationIcon,
  Refresh as RefreshIcon,
  Edit as EditIcon,
  Save as SaveIcon,
  Cancel as CancelIcon,
  Info as InfoIcon,
  Business as BusinessIcon,
  CalendarToday as CalendarIcon,
  Person as PersonIcon,
  Place as PlaceIcon,
  Schema as StructureIcon,
  History as HistoryIcon,
} from '@mui/icons-material';
import api from '../services/api';

interface TreeNode {
  id: string;
  parent_id: string | null;
  description: string;
  type: string;
  node_type: 'functional_location' | 'equipment';
  children_count?: number;
  equipment_count?: number;
  [key: string]: any;
}

interface DetailedNode extends TreeNode {
  maintenance_plant?: string;
  planner_group?: string;
  created_date?: string;
  created_by?: string;
  modified_date?: string;
  modified_by?: string;
  valid_from?: string;
  authorization_group?: string;
  object_type?: string;
  inventory_number?: string;
  size?: string;
  weight?: string;
  weight_unit?: string;
  acquisition_value?: string;
  currency?: string;
  acquisition_date?: string;
  manufacturer?: string;
  manufacturer_country?: string;
  construction_year?: string;
  construction_month?: string;
  model?: string;
  deletion_flag?: string;
  cost_center?: string;
  company_code?: string;
  business_area?: string;
  plant?: string;
  location?: string;
  serial_number?: string;
  start_date?: string;
  category?: string;
  warranty_period?: string;
  warranty_end_date?: string;
  supplier?: string;
  material_number?: string;
}

interface ExpandedNodes {
  [key: string]: boolean;
}

interface LoadedChildren {
  [key: string]: {
    locations: TreeNode[];
    equipment: TreeNode[];
  };
}

// Composant pour un champ de détail
const DetailField: React.FC<{
  label: string;
  value: string | undefined | null;
  isEditing: boolean;
  fieldName: string;
  editedData: Record<string, string>;
  onFieldChange: (field: string, value: string) => void;
  monospace?: boolean;
  editable?: boolean;
}> = ({ label, value, isEditing, fieldName, editedData, onFieldChange, monospace = false, editable = true }) => {
  if (!value && !isEditing) return null;
  
  return (
    <Box>
      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
        {label}
      </Typography>
      {isEditing && editable ? (
        <TextField
          size="small"
          fullWidth
          value={editedData[fieldName] ?? value ?? ''}
          onChange={(e) => onFieldChange(fieldName, e.target.value)}
          sx={{ 
            '& input': { 
              fontFamily: monospace ? 'monospace' : 'inherit',
              fontSize: '0.9rem',
            } 
          }}
        />
      ) : (
        <Typography 
          variant="body2" 
          sx={{ 
            fontFamily: monospace ? 'monospace' : 'inherit',
            fontWeight: 500,
            color: 'text.primary',
          }}
        >
          {value || '-'}
        </Typography>
      )}
    </Box>
  );
};

const MaintenanceHierarchyPage: React.FC = () => {
  const theme = useTheme();
  const [rootNodes, setRootNodes] = useState<TreeNode[]>([]);
  const [expandedNodes, setExpandedNodes] = useState<ExpandedNodes>({});
  const [loadedChildren, setLoadedChildren] = useState<LoadedChildren>({});
  const [loading, setLoading] = useState(true);
  const [loadingNodes, setLoadingNodes] = useState<{ [key: string]: boolean }>({});
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<{ locations: TreeNode[]; equipment: TreeNode[] } | null>(null);
  const [searchLoading, setSearchLoading] = useState(false);
  const [selectedNode, setSelectedNode] = useState<TreeNode | null>(null);
  const [detailedNode, setDetailedNode] = useState<DetailedNode | null>(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editedData, setEditedData] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>({
    open: false,
    message: '',
    severity: 'success',
  });
  const [activeTab, setActiveTab] = useState(0);
  const [parentOptions, setParentOptions] = useState<{ id: string; description: string }[]>([]);
  const [parentSearchLoading, setParentSearchLoading] = useState(false);
  const [parentInputValue, setParentInputValue] = useState('');

  // Rechercher les parents possibles
  const searchParents = useCallback(async (searchQuery: string, excludeId: string) => {
    try {
      setParentSearchLoading(true);
      const response = await api.get(`/maintenance/functional-locations/search-parents`, {
        params: { q: searchQuery, exclude: excludeId }
      });
      if (response.data.success) {
        setParentOptions(response.data.data);
      }
    } catch (err) {
      console.error('Erreur recherche parents:', err);
    } finally {
      setParentSearchLoading(false);
    }
  }, []);

  // Charger les nœuds racines
  const loadRootNodes = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await api.get('/maintenance/root-locations');
      if (response.data.success) {
        setRootNodes(response.data.data);
      }
    } catch (err: any) {
      console.error('Erreur chargement racines:', err);
      setError('Erreur lors du chargement des données');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadRootNodes();
  }, [loadRootNodes]);

  // Charger les enfants d'un nœud
  const loadChildren = async (nodeId: string) => {
    if (loadedChildren[nodeId]) {
      return;
    }

    try {
      setLoadingNodes((prev) => ({ ...prev, [nodeId]: true }));
      const response = await api.get(`/maintenance/functional-locations/${encodeURIComponent(nodeId)}/children`);
      if (response.data.success) {
        setLoadedChildren((prev) => ({
          ...prev,
          [nodeId]: {
            locations: response.data.data.functional_locations,
            equipment: response.data.data.equipment,
          },
        }));
      }
    } catch (err) {
      console.error('Erreur chargement enfants:', err);
    } finally {
      setLoadingNodes((prev) => ({ ...prev, [nodeId]: false }));
    }
  };

  // Charger les détails d'un nœud
  const loadNodeDetails = async (node: TreeNode) => {
    try {
      setDetailsLoading(true);
      const isEquipment = node.node_type === 'equipment';
      const endpoint = isEquipment
        ? `/maintenance/equipment/${encodeURIComponent(node.id)}/details`
        : `/maintenance/functional-locations/${encodeURIComponent(node.id)}/details`;
      
      const response = await api.get(endpoint);
      if (response.data.success) {
        setDetailedNode(response.data.data);
      }
    } catch (err) {
      console.error('Erreur chargement détails:', err);
      // Fallback to basic node data
      setDetailedNode(node as DetailedNode);
    } finally {
      setDetailsLoading(false);
    }
  };

  // Toggle expand/collapse
  const toggleNode = async (node: TreeNode) => {
    const isExpanded = expandedNodes[node.id];
    
    if (!isExpanded) {
      await loadChildren(node.id);
    }
    
    setExpandedNodes((prev) => ({
      ...prev,
      [node.id]: !isExpanded,
    }));
  };

  // Recherche
  const handleSearch = async () => {
    if (searchQuery.length < 2) {
      setSearchResults(null);
      return;
    }

    try {
      setSearchLoading(true);
      const response = await api.get(`/maintenance/search?q=${encodeURIComponent(searchQuery)}`);
      if (response.data.success) {
        setSearchResults({
          locations: response.data.data.functional_locations,
          equipment: response.data.data.equipment,
        });
      }
    } catch (err) {
      console.error('Erreur recherche:', err);
    } finally {
      setSearchLoading(false);
    }
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchQuery.length >= 2) {
        handleSearch();
      } else {
        setSearchResults(null);
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  // Sélectionner un nœud
  const selectNode = (node: TreeNode) => {
    setSelectedNode(node);
    setIsEditing(false);
    setEditedData({});
    loadNodeDetails(node);
  };

  // Gérer le mode édition
  const startEditing = () => {
    setIsEditing(true);
    setEditedData({});
    setParentInputValue(detailedNode?.parent_id || '');
    // Charger les options de parent initiales
    if (detailedNode) {
      searchParents('', detailedNode.id);
    }
  };

  const cancelEditing = () => {
    setIsEditing(false);
    setEditedData({});
    setParentInputValue('');
  };

  const handleFieldChange = (field: string, value: string) => {
    setEditedData((prev) => ({ ...prev, [field]: value }));
  };

  // Sauvegarder les modifications
  const saveChanges = async () => {
    if (!detailedNode) return;

    try {
      setSaving(true);
      const isEquipment = detailedNode.node_type === 'equipment';
      let newNodeId = detailedNode.id;
      
      // Si l'ID a changé, appeler d'abord l'endpoint de renommage
      if (editedData.new_id && editedData.new_id !== detailedNode.id && !isEquipment) {
        const renameEndpoint = `/maintenance/functional-locations/${encodeURIComponent(detailedNode.id)}/rename`;
        const renameResponse = await api.put(renameEndpoint, { new_id: editedData.new_id });
        
        if (!renameResponse.data.success) {
          setSnackbar({
            open: true,
            message: renameResponse.data.error || 'Erreur lors du renommage',
            severity: 'error',
          });
          setSaving(false);
          return;
        }
        newNodeId = editedData.new_id;
      }
      
      // Préparer les données à envoyer (sans new_id qui est géré séparément)
      const updateData = { ...editedData };
      delete updateData.new_id;
      
      // S'il reste des modifications à faire
      if (Object.keys(updateData).length > 0) {
        const endpoint = isEquipment
          ? `/maintenance/equipment/${encodeURIComponent(newNodeId)}`
          : `/maintenance/functional-locations/${encodeURIComponent(newNodeId)}`;

        const response = await api.put(endpoint, updateData);
        
        if (!response.data.success) {
          setSnackbar({
            open: true,
            message: response.data.error || 'Erreur lors de la mise à jour',
            severity: 'error',
          });
          setSaving(false);
          return;
        }
      }
      
      setSnackbar({
        open: true,
        message: 'Modifications enregistrées avec succès',
        severity: 'success',
      });
      setIsEditing(false);
      setParentInputValue('');
      
      // Si l'ID ou le parent a changé, recharger tout
      if (editedData.new_id || editedData.parent_id) {
        loadRootNodes();
        setLoadedChildren({});
        setExpandedNodes({});
        setSelectedNode(null);
        setDetailedNode(null);
      } else {
        // Sinon juste recharger les détails
        loadNodeDetails({ ...detailedNode, id: newNodeId });
      }
    } catch (err: any) {
      console.error('Erreur sauvegarde:', err);
      setSnackbar({
        open: true,
        message: err.response?.data?.error || 'Erreur lors de la sauvegarde',
        severity: 'error',
      });
    } finally {
      setSaving(false);
    }
  };

  // Rendu d'un nœud de l'arbre
  const renderTreeNode = (node: TreeNode, level: number = 0) => {
    const isExpanded = expandedNodes[node.id];
    const isLoading = loadingNodes[node.id];
    const children = loadedChildren[node.id];
    const hasChildren = (node.children_count && node.children_count > 0) ||
                       (node.equipment_count && node.equipment_count > 0) ||
                       (children && (children.locations.length > 0 || children.equipment.length > 0));
    const isSelected = selectedNode?.id === node.id;
    const isEquipment = node.node_type === 'equipment';

    return (
      <Box key={node.id}>
        <Box
          sx={{
            display: 'flex',
            alignItems: 'center',
            py: 0.75,
            px: 1,
            pl: level * 3 + 1,
            cursor: 'pointer',
            borderRadius: 1,
            transition: 'all 0.2s ease',
            backgroundColor: isSelected 
              ? alpha(theme.palette.primary.main, 0.15) 
              : 'transparent',
            '&:hover': {
              backgroundColor: isSelected 
                ? alpha(theme.palette.primary.main, 0.2) 
                : alpha(theme.palette.action.hover, 0.08),
            },
            borderLeft: isSelected 
              ? `3px solid ${theme.palette.primary.main}` 
              : '3px solid transparent',
          }}
          onClick={() => selectNode(node)}
        >
          {!isEquipment && (
            <IconButton
              size="small"
              onClick={(e) => {
                e.stopPropagation();
                toggleNode(node);
              }}
              sx={{ 
                mr: 0.5, 
                p: 0.25,
                visibility: hasChildren || !children ? 'visible' : 'hidden',
              }}
            >
              {isLoading ? (
                <CircularProgress size={16} />
              ) : isExpanded ? (
                <ExpandMoreIcon fontSize="small" />
              ) : (
                <ChevronRightIcon fontSize="small" />
              )}
            </IconButton>
          )}

          <Box sx={{ mr: 1.5, display: 'flex', alignItems: 'center' }}>
            {isEquipment ? (
              <EquipmentIcon fontSize="small" sx={{ color: theme.palette.warning.main }} />
            ) : isExpanded ? (
              <FolderOpenIcon fontSize="small" sx={{ color: theme.palette.primary.main }} />
            ) : (
              <FolderIcon fontSize="small" sx={{ color: theme.palette.primary.main }} />
            )}
          </Box>

          <Typography
            variant="body2"
            sx={{
              fontFamily: 'monospace',
              fontWeight: 600,
              color: isEquipment ? theme.palette.warning.dark : theme.palette.primary.dark,
              minWidth: isEquipment ? 180 : 120,
              fontSize: '0.85rem',
            }}
          >
            {isEquipment ? node.id.replace(/^0+/, '') : node.id}
          </Typography>

          <Typography
            variant="body2"
            sx={{
              ml: 2,
              flex: 1,
              color: theme.palette.text.primary,
              fontWeight: isSelected ? 500 : 400,
            }}
          >
            {node.description}
          </Typography>

          {node.children_count !== undefined && node.children_count > 0 && (
            <Chip
              size="small"
              label={node.children_count}
              sx={{
                ml: 1,
                height: 20,
                fontSize: '0.7rem',
                backgroundColor: alpha(theme.palette.info.main, 0.1),
                color: theme.palette.info.main,
              }}
            />
          )}
          {node.equipment_count !== undefined && node.equipment_count > 0 && (
            <Tooltip title="Équipements">
              <Chip
                size="small"
                icon={<EquipmentIcon sx={{ fontSize: '0.8rem !important' }} />}
                label={node.equipment_count}
                sx={{
                  ml: 0.5,
                  height: 20,
                  fontSize: '0.7rem',
                  backgroundColor: alpha(theme.palette.warning.main, 0.1),
                  color: theme.palette.warning.dark,
                }}
              />
            </Tooltip>
          )}
        </Box>

        <Collapse in={isExpanded} timeout="auto" unmountOnExit>
          {children && (
            <>
              {children.locations.map((child) => renderTreeNode(child, level + 1))}
              {children.equipment.map((eq) => renderTreeNode(eq, level + 1))}
            </>
          )}
        </Collapse>
      </Box>
    );
  };

  // Rendu des résultats de recherche
  const renderSearchResults = () => {
    if (!searchResults) return null;

    const allResults = [...searchResults.locations, ...searchResults.equipment];

    if (allResults.length === 0) {
      return (
        <Alert severity="info" sx={{ mt: 2 }}>
          Aucun résultat trouvé pour "{searchQuery}"
        </Alert>
      );
    }

    return (
      <Box sx={{ mt: 2 }}>
        <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1 }}>
          {allResults.length} résultat(s) trouvé(s)
        </Typography>
        {allResults.map((node) => (
          <Box
            key={`${node.node_type}-${node.id}`}
            sx={{
              display: 'flex',
              alignItems: 'center',
              py: 1,
              px: 2,
              cursor: 'pointer',
              borderRadius: 1,
              mb: 0.5,
              backgroundColor: alpha(theme.palette.background.paper, 0.5),
              '&:hover': {
                backgroundColor: alpha(theme.palette.primary.main, 0.1),
              },
            }}
            onClick={() => selectNode(node)}
          >
            {node.node_type === 'equipment' ? (
              <EquipmentIcon fontSize="small" sx={{ color: theme.palette.warning.main, mr: 1.5 }} />
            ) : (
              <LocationIcon fontSize="small" sx={{ color: theme.palette.primary.main, mr: 1.5 }} />
            )}
            <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600, mr: 2 }}>
              {node.id.replace(/^0+/, '')}
            </Typography>
            <Typography variant="body2">{node.description}</Typography>
            <Chip
              size="small"
              label={node.node_type === 'equipment' ? 'Équipement' : 'Poste technique'}
              sx={{ ml: 'auto', height: 20, fontSize: '0.7rem' }}
            />
          </Box>
        ))}
      </Box>
    );
  };

  // Panneau de détails
  const renderDetailsPanel = () => {
    if (!selectedNode) {
      return (
        <Box
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            height: '100%',
            color: 'text.secondary',
          }}
        >
          <TreeIcon sx={{ fontSize: 64, mb: 2, opacity: 0.3 }} />
          <Typography variant="body1">
            Sélectionnez un élément pour voir ses détails
          </Typography>
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

    const node = detailedNode || selectedNode;
    const isEquipment = node.node_type === 'equipment';

    return (
      <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
        {/* Header */}
        <Box sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <Box sx={{ display: 'flex', alignItems: 'center' }}>
              {isEquipment ? (
                <EquipmentIcon sx={{ fontSize: 32, color: theme.palette.warning.main, mr: 2 }} />
              ) : (
                <LocationIcon sx={{ fontSize: 32, color: theme.palette.primary.main, mr: 2 }} />
              )}
              <Box>
                {isEditing && !isEquipment ? (
                  <TextField
                    size="small"
                    value={editedData.new_id ?? node.id}
                    onChange={(e) => handleFieldChange('new_id', e.target.value)}
                    sx={{ 
                      '& input': { 
                        fontFamily: 'monospace',
                        fontSize: '1.1rem',
                        fontWeight: 600,
                      },
                      minWidth: 200,
                    }}
                    placeholder="ID du poste technique"
                  />
                ) : (
                  <Typography variant="h6" sx={{ fontFamily: 'monospace' }}>
                    {node.id.replace(/^0+/, '')}
                  </Typography>
                )}
                <Chip
                  size="small"
                  label={isEquipment ? 'Équipement' : 'Poste technique'}
                  color={isEquipment ? 'warning' : 'primary'}
                  sx={{ mt: 0.5 }}
                />
              </Box>
            </Box>
            
            {/* Edit buttons */}
            <Box>
              {isEditing ? (
                <>
                  <Button
                    size="small"
                    variant="outlined"
                    startIcon={<CancelIcon />}
                    onClick={cancelEditing}
                    sx={{ mr: 1 }}
                  >
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
                <Button
                  size="small"
                  variant="outlined"
                  startIcon={<EditIcon />}
                  onClick={startEditing}
                >
                  Modifier
                </Button>
              )}
            </Box>
          </Box>
        </Box>

        {/* Tabs - 4 onglets comme SAP */}
        <Tabs
          value={activeTab}
          onChange={(_, v) => setActiveTab(v)}
          sx={{ borderBottom: `1px solid ${theme.palette.divider}`, px: 2 }}
          variant="scrollable"
          scrollButtons="auto"
        >
          <Tab icon={<InfoIcon />} iconPosition="start" label="Generalites" />
          <Tab icon={<PlaceIcon />} iconPosition="start" label="Localisation" />
          <Tab icon={<BusinessIcon />} iconPosition="start" label="Organisation" />
          <Tab icon={<StructureIcon />} iconPosition="start" label="Structure" />
        </Tabs>

        {/* Content */}
        <Box sx={{ flex: 1, overflow: 'auto', p: 2 }}>

          {/* ========== Tab 0: Generalites ========== */}
          {activeTab === 0 && (
            <Grid container spacing={2}>
              {/* --- Donnees generales --- */}
              <Grid item xs={12}>
                <Typography variant="subtitle2" sx={{ color: theme.palette.primary.main, fontWeight: 600, mb: 0.5 }}>
                  Donnees generales
                </Typography>
                <Divider />
              </Grid>
              <Grid item xs={12}>
                <DetailField label="Designation" value={node.description} isEditing={isEditing} fieldName="description" editedData={editedData} onFieldChange={handleFieldChange} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Type" value={node.type} isEditing={isEditing} fieldName="type" editedData={editedData} onFieldChange={handleFieldChange} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Type objet" value={node.object_type || node.category} isEditing={isEditing} fieldName="object_type" editedData={editedData} onFieldChange={handleFieldChange} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Groupe autoris." value={node.authorization_group} isEditing={isEditing} fieldName="authorization_group" editedData={editedData} onFieldChange={handleFieldChange} />
              </Grid>
              <Grid item xs={3}>
                <DetailField label="Poids" value={node.weight} isEditing={isEditing} fieldName="weight" editedData={editedData} onFieldChange={handleFieldChange} />
              </Grid>
              <Grid item xs={3}>
                <DetailField label="Unite poids" value={node.weight_unit} isEditing={false} fieldName="weight_unit" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Taille/dimens." value={node.size} isEditing={isEditing} fieldName="size" editedData={editedData} onFieldChange={handleFieldChange} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="N. inventaire" value={node.inventory_number} isEditing={isEditing} fieldName="inventory_number" editedData={editedData} onFieldChange={handleFieldChange} monospace />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Debut mise en service" value={node.start_date || node.valid_from} isEditing={false} fieldName="start_date" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>

              {isEquipment && (
                <>
                  <Grid item xs={6}>
                    <DetailField label="N. serie" value={node.serial_number} isEditing={isEditing} fieldName="serial_number" editedData={editedData} onFieldChange={handleFieldChange} monospace />
                  </Grid>
                  <Grid item xs={6}>
                    <DetailField label="N. article" value={node.material_number} isEditing={false} fieldName="material_number" editedData={editedData} onFieldChange={handleFieldChange} monospace editable={false} />
                  </Grid>
                </>
              )}

              {/* --- Donnees appro. --- */}
              <Grid item xs={12} sx={{ mt: 1 }}>
                <Typography variant="subtitle2" sx={{ color: theme.palette.primary.main, fontWeight: 600, mb: 0.5 }}>
                  Donnees appro.
                </Typography>
                <Divider />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Val. acquisition" value={node.acquisition_value} isEditing={false} fieldName="acquisition_value" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Date acquis." value={node.acquisition_date} isEditing={false} fieldName="acquisition_date" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              {node.currency && (
                <Grid item xs={6}>
                  <DetailField label="Devise" value={node.currency} isEditing={false} fieldName="currency" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
                </Grid>
              )}

              {/* --- Donnees fabrication --- */}
              <Grid item xs={12} sx={{ mt: 1 }}>
                <Typography variant="subtitle2" sx={{ color: theme.palette.primary.main, fontWeight: 600, mb: 0.5 }}>
                  Donnees fabrication
                </Typography>
                <Divider />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Fabricant" value={node.manufacturer} isEditing={isEditing} fieldName="manufacturer" editedData={editedData} onFieldChange={handleFieldChange} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Pays fabric." value={node.manufacturer_country} isEditing={isEditing} fieldName="manufacturer_country" editedData={editedData} onFieldChange={handleFieldChange} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Designat. type" value={node.model} isEditing={isEditing} fieldName="model" editedData={editedData} onFieldChange={handleFieldChange} />
              </Grid>
              <Grid item xs={3}>
                <DetailField label="Ann. cnst" value={node.construction_year} isEditing={isEditing} fieldName="construction_year" editedData={editedData} onFieldChange={handleFieldChange} />
              </Grid>
              <Grid item xs={3}>
                <DetailField label="Mois cnst" value={node.construction_month} isEditing={isEditing} fieldName="construction_month" editedData={editedData} onFieldChange={handleFieldChange} />
              </Grid>

              {isEquipment && (
                <>
                  <Grid item xs={6}>
                    <DetailField label="Garantie (fin)" value={node.warranty_end_date} isEditing={false} fieldName="warranty_end_date" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
                  </Grid>
                  <Grid item xs={6}>
                    <DetailField label="Duree garantie" value={node.warranty_period} isEditing={false} fieldName="warranty_period" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
                  </Grid>
                </>
              )}
            </Grid>
          )}

          {/* ========== Tab 1: Localisation ========== */}
          {activeTab === 1 && (
            <Grid container spacing={2}>
              <Grid item xs={12}>
                <Box>
                  <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                    Poste technique (Parent)
                  </Typography>
                  {isEditing && !isEquipment ? (
                    <Autocomplete
                      size="small"
                      freeSolo
                      options={parentOptions}
                      getOptionLabel={(option) =>
                        typeof option === 'string' ? option : `${option.id} - ${option.description}`
                      }
                      inputValue={parentInputValue}
                      onInputChange={(_, value) => {
                        setParentInputValue(value);
                        if (value.length >= 1) {
                          searchParents(value, node.id);
                        }
                      }}
                      onChange={(_, value) => {
                        if (value) {
                          const newParentId = typeof value === 'string' ? value : value.id;
                          handleFieldChange('parent_id', newParentId);
                          setParentInputValue(newParentId);
                        } else {
                          handleFieldChange('parent_id', '');
                          setParentInputValue('');
                        }
                      }}
                      loading={parentSearchLoading}
                      renderOption={(props, option) => (
                        <li {...props} key={option.id}>
                          <Box>
                            <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600 }}>
                              {option.id}
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                              {option.description}
                            </Typography>
                          </Box>
                        </li>
                      )}
                      renderInput={(params) => (
                        <TextField
                          {...params}
                          placeholder={node.parent_id || 'Selectionner un parent...'}
                          sx={{ '& input': { fontFamily: 'monospace', fontSize: '0.9rem' } }}
                          InputProps={{
                            ...params.InputProps,
                            endAdornment: (
                              <>
                                {parentSearchLoading ? <CircularProgress size={16} /> : null}
                                {params.InputProps.endAdornment}
                              </>
                            ),
                          }}
                        />
                      )}
                    />
                  ) : (
                    <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 500, color: 'text.primary' }}>
                      {node.parent_id || '-'}
                    </Typography>
                  )}
                </Box>
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Division" value={node.plant || node.fl_plant} isEditing={false} fieldName="plant" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Emplacement" value={node.location || node.fl_location} isEditing={false} fieldName="location" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Section" value={node.plant_section} isEditing={false} fieldName="plant_section" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Poste de travail" value={node.work_center} isEditing={false} fieldName="work_center" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Division maintenance" value={node.maintenance_plant} isEditing={isEditing} fieldName="maintenance_plant" editedData={editedData} onFieldChange={handleFieldChange} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Groupe planification" value={node.planner_group} isEditing={isEditing} fieldName="planner_group" editedData={editedData} onFieldChange={handleFieldChange} />
              </Grid>
            </Grid>
          )}

          {/* ========== Tab 2: Organisation ========== */}
          {activeTab === 2 && (
            <Grid container spacing={2}>
              <Grid item xs={6}>
                <DetailField label="Societe" value={node.company_code} isEditing={false} fieldName="company_code" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Centre de couts" value={node.cost_center} isEditing={false} fieldName="cost_center" editedData={editedData} onFieldChange={handleFieldChange} monospace editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Domaine d'activite" value={node.business_area} isEditing={false} fieldName="business_area" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Groupe d'autorisation" value={node.authorization_group} isEditing={false} fieldName="authorization_group" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              {isEquipment && (
                <Grid item xs={6}>
                  <DetailField label="Fournisseur" value={node.supplier} isEditing={false} fieldName="supplier" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
                </Grid>
              )}
              <Grid item xs={12}>
                <Divider sx={{ my: 1 }} />
                <Typography variant="subtitle2" sx={{ color: theme.palette.primary.main, fontWeight: 600, mb: 0.5 }}>
                  Valeurs financieres
                </Typography>
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Val. acquisition" value={node.acquisition_value} isEditing={false} fieldName="acquisition_value" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Devise" value={node.currency} isEditing={false} fieldName="currency" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Date d'acquisition" value={node.acquisition_date} isEditing={false} fieldName="acquisition_date" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
            </Grid>
          )}

          {/* ========== Tab 3: Structure ========== */}
          {activeTab === 3 && (
            <Grid container spacing={2}>
              {/* Infos hierarchiques */}
              <Grid item xs={12}>
                <Typography variant="subtitle2" sx={{ color: theme.palette.primary.main, fontWeight: 600, mb: 0.5 }}>
                  Hierarchie
                </Typography>
                <Divider />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Parent" value={node.parent_id} isEditing={false} fieldName="parent_id" editedData={editedData} onFieldChange={handleFieldChange} monospace editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Type noeud" value={isEquipment ? 'Equipement' : 'Poste technique'} isEditing={false} fieldName="node_type" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              {!isEquipment && (
                <>
                  <Grid item xs={6}>
                    <Box>
                      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                        Sous-postes techniques
                      </Typography>
                      <Chip
                        size="small"
                        label={node.children_count ?? 0}
                        sx={{
                          fontWeight: 600,
                          backgroundColor: alpha(theme.palette.info.main, 0.1),
                          color: theme.palette.info.main,
                        }}
                      />
                    </Box>
                  </Grid>
                  <Grid item xs={6}>
                    <Box>
                      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                        Equipements rattaches
                      </Typography>
                      <Chip
                        size="small"
                        icon={<EquipmentIcon sx={{ fontSize: '0.9rem !important' }} />}
                        label={node.equipment_count ?? 0}
                        sx={{
                          fontWeight: 600,
                          backgroundColor: alpha(theme.palette.warning.main, 0.1),
                          color: theme.palette.warning.dark,
                        }}
                      />
                    </Box>
                  </Grid>
                </>
              )}

              {/* Historique */}
              <Grid item xs={12} sx={{ mt: 1 }}>
                <Typography variant="subtitle2" sx={{ color: theme.palette.primary.main, fontWeight: 600, mb: 0.5 }}>
                  Historique
                </Typography>
                <Divider />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Date de creation" value={node.created_date} isEditing={false} fieldName="created_date" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Cree par" value={node.created_by} isEditing={false} fieldName="created_by" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Date de modification" value={node.modified_date} isEditing={false} fieldName="modified_date" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Modifie par" value={node.modified_by} isEditing={false} fieldName="modified_by" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
              <Grid item xs={6}>
                <DetailField label="Indicateur suppression" value={node.deletion_flag === 'X' ? 'Oui' : 'Non'} isEditing={false} fieldName="deletion_flag" editedData={editedData} onFieldChange={handleFieldChange} editable={false} />
              </Grid>
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
        <TreeIcon sx={{ fontSize: 32, mr: 2, color: theme.palette.primary.main }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Structure de Maintenance
        </Typography>
        <IconButton onClick={loadRootNodes} sx={{ ml: 2 }} disabled={loading}>
          <RefreshIcon />
        </IconButton>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      {/* Main content */}
      <Box sx={{ display: 'flex', gap: 3, flex: 1, minHeight: 0 }}>
        {/* Tree panel */}
        <Paper
          elevation={0}
          sx={{
            flex: 2,
            display: 'flex',
            flexDirection: 'column',
            border: `1px solid ${theme.palette.divider}`,
            borderRadius: 2,
            overflow: 'hidden',
          }}
        >
          <Box sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
            <TextField
              fullWidth
              size="small"
              placeholder="Rechercher un poste technique ou équipement..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    {searchLoading ? <CircularProgress size={20} /> : <SearchIcon />}
                  </InputAdornment>
                ),
              }}
            />
          </Box>

          <Box sx={{ flex: 1, overflow: 'auto', p: 1 }}>
            {loading ? (
              <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
                <CircularProgress />
              </Box>
            ) : searchQuery.length >= 2 ? (
              renderSearchResults()
            ) : (
              rootNodes.map((node) => renderTreeNode(node))
            )}
          </Box>
        </Paper>

        {/* Details panel */}
        <Paper
          elevation={0}
          sx={{
            flex: 1,
            minWidth: 400,
            border: `1px solid ${theme.palette.divider}`,
            borderRadius: 2,
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          {renderDetailsPanel()}
        </Paper>
      </Box>

      {/* Snackbar for notifications */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={4000}
        onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}
      >
        <Alert severity={snackbar.severity} onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}>
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default MaintenanceHierarchyPage;
