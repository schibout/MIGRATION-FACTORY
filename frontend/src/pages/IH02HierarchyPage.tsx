import {
  Add as AddIcon,
  Inventory2 as BomIcon,
  EditNote as BulkEditIcon,
  Business as BusinessIcon,
  ChevronRight as ChevronRightIcon,
  Close as CloseIcon,
  Delete as DeleteIcon,
  FileDownload as DownloadIcon,
  DragIndicator as DragIcon,
  Edit as EditIcon,
  Engineering as EngineeringIcon,
  Build as EquipmentIcon,
  ExpandMore as ExpandMoreIcon,
  Folder as FolderIcon,
  FolderOpen as FolderOpenIcon,
  Handyman as HandymanIcon,
  Info as InfoIcon,
  LocationOn as LocationIcon,
  Save as SaveIcon,
  Search as SearchIcon,
  AccountTree as TreeIcon
} from '@mui/icons-material';
import {
  Alert,
  alpha,
  Autocomplete,
  Box,
  Button,
  Chip,
  CircularProgress,
  Collapse,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControl,
  Grid,
  IconButton,
  InputAdornment,
  InputLabel,
  ListItemIcon,
  ListItemText,
  Menu,
  MenuItem,
  Paper,
  Select,
  SelectChangeEvent,
  Snackbar,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Tabs,
  TextField,
  Tooltip,
  Typography,
  useTheme,
} from '@mui/material';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import api from '../services/api';
import MaintenanceJobBanner from '../components/maintenance/MaintenanceJobBanner';
import MaintenanceActions from '../components/maintenance/MaintenanceActions';
import { MaintenanceJob } from '../services/maintenanceSnapshotService';

interface LocationNode {
  row_id: string;
  node_id: string;
  display_name?: string | null;
  display_parent?: string | null;
  structure_indicator?: string | null;
  designation: string;
  type_poste: string | null;
  centre_couts: string | null;
  poste_travail_resp_maintenance: string | null;
  poste_resp_texte: string | null;
  poste_travail: string | null;
  poste_travail_texte: string | null;
  art_type_construction: string | null;
  quantite: string | null;
  unite: string | null;
  level: number;
  children_count: number;
  equipment_count?: number;
  parent_node_id?: string | null;
  node_type: 'location';
  // Tracabilite renvoyee par l'API (non affichee : masquee a la demande)
  source?: string | null;
  updated_by?: string | null;
  updated_at?: string | null;
}

interface EquipmentNode {
  equnr: string;
  equnr_short: string;
  designation: string;
  type_poste: string | null;
  manufacturer: string | null;
  model: string | null;
  serial_number: string | null;
  start_date: string | null;
  centre_couts: string | null;
  maintenance_plant: string | null;
  planner_group: string | null;
  material_number: string | null;
  parent_tplnr: string | null;
  children_count: number;
  node_type: 'equipment';
}

type TreeNode = LocationNode | EquipmentNode;

// Porteur d'un article trouvé par la recherche : poste technique (nomenclature
// stlty='T') ou article parent (nomenclature matière stlty='M').
interface ArticleUsage {
  node_type: 'location' | 'article';
  designation: string;
  // node_type = 'location'
  row_id?: string;
  node_id?: string;
  display_name?: string;
  level?: number;
  // node_type = 'article'
  idnrk?: string;
  matnr_short?: string;
}

interface ArticleResult {
  idnrk: string;
  matnr_short: string;
  designation: string;
  material_type: string | null;
  usage_count: number;
  used_in: ArticleUsage[];
}

interface EquipmentDetails {
  equnr: string;
  equnr_short: string;
  designation: string;
  type_equipement: string | null;
  categorie: string | null;
  fabricant: string | null;
  pays_fabricant: string | null;
  modele: string | null;
  numero_serie: string | null;
  numero_inventaire: string | null;
  taille: string | null;
  poids: string | null;
  unite_poids: string | null;
  valeur_acquisition: string | null;
  devise: string | null;
  date_acquisition: string | null;
  annee_construction: string | null;
  mois_construction: string | null;
  date_mise_service: string | null;
  date_creation: string | null;
  cree_par: string | null;
  date_modification: string | null;
  modifie_par: string | null;
  indicateur_suppression: string | null;
  duree_garantie: string | null;
  fin_garantie: string | null;
  fournisseur: string | null;
  numero_article: string | null;
  centre_couts: string | null;
  societe: string | null;
  domaine_activite: string | null;
  division_maintenance: string | null;
  groupe_planification: string | null;
  division: string | null;
  emplacement: string | null;
  section: string | null;
  poste_technique: string | null;
  equipement_superieur: string | null;
  plan_maintenance: string | null;
  gewrk: string | null;
  arbpl: string | null;
  poste_travail_texte: string | null;
  // Tracabilite renvoyee par l'API (non affichee : masquee a la demande)
  source?: string | null;
  updated_by?: string | null;
  updated_at?: string | null;
}

interface Stats {
  total_nodes: number;
  distinct_types: number;
  distinct_cost_centers: number;
  level_0: number;
  level_1: number;
  level_2: number;
  level_3: number;
  level_4: number;
  level_5: number;
  level_6_plus: number;
}

interface WorkCenter {
  code: string;
  objid: string;
  designation: string | null;
}

interface LoadedChildren {
  [key: string]: { locations: LocationNode[]; equipment: EquipmentNode[] };
}

interface LoadedEquipmentChildren {
  [key: string]: EquipmentNode[];
}

interface BomComponent {
  // Cle unique de la LIGNE de nomenclature (sap_key du BOM_ITEM).
  // Seule poignee fiable pour la deplacer : (stlnr, stlkn) n'est pas unique
  // d'un monde a l'autre.
  bom_key?: string;
  tplnr?: string;
  posnr: string;
  idnrk: string;
  matnr_short: string;
  designation: string | null;
  quantity: string | null;
  unit: string | null;
  item_category: string | null;
  material_type: string | null;
  stlnr: string;
  stlal: string;
  stlkn?: string;
  potx1?: string | null;
  potx2?: string | null;
  // nb de sous-composants de la nomenclature matière de CET article (récursif)
  children_count?: number;
}

// Composant BOM sélectionné dans le panneau de détails (droite)
interface SelectedBom {
  comp: BomComponent;
  mode: 'fl' | 'article';
  pathKey: string;       // identité de la ligne rendue (un article peut apparaître plusieurs fois)
  tplnr?: string;        // mode 'fl' : poste technique porteur
  parentIdnrk?: string;  // mode 'article' : article dont ce composant fait partie
}

interface LoadedBom {
  [tplnr: string]: BomComponent[];
}

// Glisser-deposer d'une LIGNE de nomenclature (et non de la fiche article,
// qui est partagee entre tous ses emplacements).
interface DraggedBom {
  comp: BomComponent;
  mode: 'fl' | 'article';
  sourceKey: string;   // tplnr porteur (mode 'fl') ou idnrk du parent (mode 'article')
  label: string;
}

interface PendingBomDrop {
  drag: DraggedBom;
  targetType: 'FUNC_LOC' | 'ARTICLE';
  targetKey: string;
  targetLabel: string;
}

// Nomenclature matière d'un article (BOM stlty='M'), indexée par idnrk complet
interface LoadedArticleBom {
  [idnrk: string]: BomComponent[];
}

function isLocation(node: TreeNode): node is LocationNode {
  return node.node_type === 'location' || !('equnr' in node);
}

function isEquipment(node: TreeNode): node is EquipmentNode {
  return node.node_type === 'equipment' || 'equnr' in node;
}

function getNodeKey(node: TreeNode): string {
  if (isEquipment(node)) return `eq-${node.equnr}`;
  return `loc-${node.level}-${node.node_id}`;
}

// Libellé du type de poste technique (IFS ObjectLevel) dérivé de la profondeur.
// Aligné sur public.TranscodificationTable, catégorie 'ObjectLevel'
// (fltyp = 'P' partout dans SAP, sans libellé -> on affiche le type métier IFS).
const OBJECT_LEVEL_LABELS = [
  'FR_SITE', 'FR_SECTEUR', 'FR_ATELIER', 'FR_CHAINE',
  'FR_MACHINE', 'FR_SECTION', 'FR_SOUS-SECTION', 'FR_EQUIPEMENT',
];
const objectLevelLabel = (level: number): string =>
  OBJECT_LEVEL_LABELS[Math.min(Math.max(level ?? 0, 0), 7)];

const DetailField: React.FC<{
  label: string;
  value: string | number | undefined | null;
  monospace?: boolean;
  editing?: boolean;
  fieldKey?: string;
  onFieldChange?: (key: string, value: string) => void;
}> = ({ label, value, monospace = false, editing = false, fieldKey, onFieldChange }) => {
  if (!editing && (value === null || value === undefined || value === '' || value === '00000000')) return null;

  if (editing && fieldKey && onFieldChange) {
    return (
      <Box>
        <TextField
          label={label}
          value={value ?? ''}
          onChange={(e) => onFieldChange(fieldKey, e.target.value)}
          size="small"
          fullWidth
          variant="outlined"
          InputProps={{ sx: { fontFamily: monospace ? 'monospace' : 'inherit', fontSize: '0.875rem' } }}
        />
      </Box>
    );
  }

  return (
    <Box>
      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
        {label}
      </Typography>
      <Typography
        variant="body2"
        sx={{
          fontFamily: monospace ? 'monospace' : 'inherit',
          fontWeight: 500,
          color: 'text.primary',
        }}
      >
        {String(value) || '-'}
      </Typography>
    </Box>
  );
};

const IH02HierarchyPage: React.FC = () => {
  const theme = useTheme();
  const [rootNodes, setRootNodes] = useState<LocationNode[]>([]);
  const [expandedNodes, setExpandedNodes] = useState<Record<string, boolean>>({});
  const [loadedChildren, setLoadedChildren] = useState<LoadedChildren>({});
  const [loadedEqChildren, setLoadedEqChildren] = useState<LoadedEquipmentChildren>({});
  const [loadedBom, setLoadedBom] = useState<LoadedBom>({});
  const [bomCounts, setBomCounts] = useState<Record<string, number>>({});
  const [expandedBom, setExpandedBom] = useState<Record<string, boolean>>({});
  const [loadingBom, setLoadingBom] = useState<Record<string, boolean>>({});
  // Nomenclature matière des articles (hiérarchie récursive de composants)
  const [loadedArticleBom, setLoadedArticleBom] = useState<LoadedArticleBom>({});
  const [articleBomCounts, setArticleBomCounts] = useState<Record<string, number>>({}); // par idnrk complet
  const [expandedArticleBom, setExpandedArticleBom] = useState<Record<string, boolean>>({}); // par chemin de rendu
  const [loadingArticleBom, setLoadingArticleBom] = useState<Record<string, boolean>>({}); // par idnrk
  const [loading, setLoading] = useState(true);
  const [loadingNodes, setLoadingNodes] = useState<Record<string, boolean>>({});
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<{ locations: LocationNode[]; equipment: EquipmentNode[]; articles: ArticleResult[] } | null>(null);
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchError, setSearchError] = useState<string | null>(null);
  // Articles dont on a déplié la liste des porteurs (postes techniques / articles)
  const [expandedSearchArticle, setExpandedSearchArticle] = useState<Record<string, boolean>>({});
  const [selectedNode, setSelectedNode] = useState<TreeNode | null>(null);
  const [detailedLocation, setDetailedLocation] = useState<LocationNode | null>(null);
  const [detailedEquipment, setDetailedEquipment] = useState<EquipmentDetails | null>(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [stats, setStats] = useState<Stats | null>(null);
  const [activeTab, setActiveTab] = useState(0);
  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>({
    open: false, message: '', severity: 'success',
  });
  const [editMode, setEditMode] = useState(false);
  const [editLocationData, setEditLocationData] = useState<Record<string, any>>({});
  const [editEquipmentData, setEditEquipmentData] = useState<Record<string, any>>({});
  const [saving, setSaving] = useState(false);
  const [exportAnchorEl, setExportAnchorEl] = useState<null | HTMLElement>(null);
  const [exporting, setExporting] = useState(false);

  // Etats sauvegardes / rechargement SAP
  const [trackedJobId, setTrackedJobId] = useState<number | null>(null);
  // Pendant une restauration/rechargement, le backend refuse les ecritures (409) :
  // on desactive aussi les actions cote UI pour eviter les erreurs inutiles.
  const [jobActive, setJobActive] = useState(false);

  const [draggedNode, setDraggedNode] = useState<TreeNode | null>(null);
  const [dropTargetKey, setDropTargetKey] = useState<string | null>(null);
  const [pendingDrop, setPendingDrop] = useState<{ source: LocationNode; target: LocationNode } | null>(null);
  const [dropConfirmLoading, setDropConfirmLoading] = useState(false);
  const [draggedBom, setDraggedBom] = useState<DraggedBom | null>(null);
  // Les evenements HTML5 drag/drop ne declenchent pas tous un rendu React entre
  // dragstart et drop. La ref est donc la source fiable pour le depot ; l'etat
  // reste utilise pour le retour visuel de la cible.
  const draggedBomRef = useRef<DraggedBom | null>(null);
  const [pendingBomDrop, setPendingBomDrop] = useState<PendingBomDrop | null>(null);

  const [workCenters, setWorkCenters] = useState<WorkCenter[]>([]);

  const [bulkDialogOpen, setBulkDialogOpen] = useState(false);
  const [bulkEdits, setBulkEdits] = useState<{ field: string; label: string; value: string }[]>([]);
  const [bulkField, setBulkField] = useState('');
  const [bulkValue, setBulkValue] = useState('');
  const [bulkCount, setBulkCount] = useState(0);
  const [bulkSaving, setBulkSaving] = useState(false);

  const [addDialogOpen, setAddDialogOpen] = useState(false);
  const [addDialogType, setAddDialogType] = useState<'location' | 'equipment'>('location');
  const [addNodeData, setAddNodeData] = useState({ node_id: '', designation: '', type_poste: '', centre_couts: '' });
  const [addEquipmentData, setAddEquipmentData] = useState({ equnr: '', designation: '', eqart: '', herst: '', typbz: '', matnr: '', sernr: '' });
  const [equipmentSuggestions, setEquipmentSuggestions] = useState<any[]>([]);
  const [equipmentSearchLoading, setEquipmentSearchLoading] = useState(false);
  const [equipmentSearchQuery, setEquipmentSearchQuery] = useState('');
  const [articleSuggestions, setArticleSuggestions] = useState<any[]>([]);
  const [articleSearchLoading, setArticleSearchLoading] = useState(false);
  const [articleSearchQuery, setArticleSearchQuery] = useState('');
  const [addSaving, setAddSaving] = useState(false);
  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<{ type: 'location' | 'equipment'; node: TreeNode } | null>(null);
  const [deleteSaving, setDeleteSaving] = useState(false);

  // Panneau de détails d'un composant BOM (droite)
  const [selectedBom, setSelectedBom] = useState<SelectedBom | null>(null);
  const [editBomData, setEditBomData] = useState<Record<string, any>>({});
  const [editBomArticleQuery, setEditBomArticleQuery] = useState('');
  const [editBomArticleSuggestions, setEditBomArticleSuggestions] = useState<any[]>([]);
  const [editBomArticleLoading, setEditBomArticleLoading] = useState(false);

  const BULK_FIELDS = [
    { key: 'designation', label: 'Désignation' },
    { key: 'centre_couts', label: 'Centre de coûts' },
    { key: 'poste_travail_resp_maintenance', label: 'Poste travail resp. maintenance' },
    { key: 'art_type_construction', label: 'Art / Type construction' },
    { key: 'quantite', label: 'Quantité' },
    { key: 'unite', label: 'Unité' },
  ];

  const loadRootNodes = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await api.get('/ih02-hierarchy/root-nodes');
      if (response.data.success) {
        const roots = response.data.data.map((n: any) => ({ ...n, node_type: 'location' }));
        setRootNodes(roots);
        const tplnrList = roots.map((r: LocationNode) => r.node_id);
        if (tplnrList.length > 0) {
          try {
            const countResp = await api.get('/ih02-hierarchy/bom-counts', {
              params: { tplnrs: tplnrList.join(',') },
            });
            if (countResp.data.success) {
              setBomCounts((prev) => ({ ...prev, ...countResp.data.data }));
            }
          } catch { /* ignore */ }
        }
      }
    } catch (err: any) {
      setError('Erreur lors du chargement des données');
    } finally {
      setLoading(false);
    }
  }, []);

  const loadStats = useCallback(async () => {
    try {
      const response = await api.get('/ih02-hierarchy/stats');
      if (response.data.success) setStats(response.data.data);
    } catch (err) { /* ignore */ }
  }, []);

  const loadWorkCenters = useCallback(async () => {
    try {
      const response = await api.get('/ih02-hierarchy/work-centers');
      if (response.data.success) setWorkCenters(response.data.data);
    } catch (err) { /* ignore */ }
  }, []);

  useEffect(() => {
    loadRootNodes();
    loadStats();
    loadWorkCenters();
  }, [loadRootNodes, loadStats, loadWorkCenters]);

  /** Fin d'une restauration / d'un rechargement : l'arbre en memoire est perime. */
  const handleJobFinished = useCallback((job: MaintenanceJob) => {
    setTrackedJobId(null);
    if (job.status === 'DONE') {
      setLoadedChildren({});
      setLoadedEqChildren({});
      setLoadedBom({});
      setLoadedArticleBom({});
      setExpandedNodes({});
      setSelectedNode(null);
      setDetailedLocation(null);
      setDetailedEquipment(null);
      loadRootNodes();
      loadStats();
      setSnackbar({
        open: true,
        severity: 'success',
        message: job.job_type === 'RELOAD'
          ? 'Rechargement depuis SAP terminé.'
          : 'État restauré.',
      });
    } else {
      setSnackbar({
        open: true,
        severity: 'error',
        message: job.error_message ?? "L'opération a échoué.",
      });
    }
  }, [loadRootNodes, loadStats]);

  const loadChildren = async (node: LocationNode) => {
    const key = getNodeKey(node);
    if (loadedChildren[key]) return;

    try {
      setLoadingNodes((prev) => ({ ...prev, [key]: true }));
      const response = await api.get('/ih02-hierarchy/children', {
        params: { parent_level: node.level, parent_id: node.node_id },
      });
      if (response.data.success) {
        const locs = (response.data.data.locations || []).map((n: any) => ({ ...n, node_type: 'location' }));
        const eqs = (response.data.data.equipment || []).map((n: any) => ({ ...n, node_type: 'equipment' }));
        setLoadedChildren((prev) => ({
          ...prev,
          [key]: { locations: locs, equipment: eqs },
        }));

        const tplnrList = locs.map((l: LocationNode) => l.node_id);
        if (tplnrList.length > 0) {
          try {
            const countResp = await api.get('/ih02-hierarchy/bom-counts', {
              params: { tplnrs: tplnrList.join(',') },
            });
            if (countResp.data.success) {
              setBomCounts((prev) => ({ ...prev, ...countResp.data.data }));
            }
          } catch { /* ignore */ }
        }
      }
    } catch (err) {
      console.error('Erreur chargement enfants:', err);
    } finally {
      setLoadingNodes((prev) => ({ ...prev, [key]: false }));
    }
  };

  const loadBom = async (tplnr: string, force = false) => {
    if (!force && loadedBom[tplnr]) return;
    try {
      setLoadingBom((prev) => ({ ...prev, [tplnr]: true }));
      const resp = await api.get(`/ih02-hierarchy/bom/${encodeURIComponent(tplnr)}`);
      if (resp.data.success) {
        const comps: BomComponent[] = resp.data.data || [];
        setLoadedBom((prev) => ({ ...prev, [tplnr]: comps }));
        setBomCounts((prev) => ({ ...prev, [tplnr]: resp.data.total }));
        // Savoir lesquels de ces articles ont eux-mêmes une nomenclature matière
        loadArticleBomCounts(comps.map((c) => c.idnrk));
      }
    } catch (err) {
      console.error('Erreur chargement BOM:', err);
    } finally {
      setLoadingBom((prev) => ({ ...prev, [tplnr]: false }));
    }
  };

  const toggleBom = async (tplnr: string) => {
    const isExpanded = expandedBom[tplnr];
    if (!isExpanded) await loadBom(tplnr);
    setExpandedBom((prev) => ({ ...prev, [tplnr]: !isExpanded }));
  };

  // Récupère, pour une liste d'articles (idnrk complet), le nb de composants de leur
  // nomenclature matière. Les articles sans BOM sont mémorisés à 0 (évite de re-questionner).
  const loadArticleBomCounts = async (idnrks: string[]) => {
    const list = Array.from(new Set(idnrks.filter((x) => x && articleBomCounts[x] === undefined)));
    if (list.length === 0) return;
    try {
      const resp = await api.get('/ih02-hierarchy/article-bom-counts', {
        params: { matnrs: list.join(',') },
      });
      if (resp.data.success) {
        setArticleBomCounts((prev) => {
          const next = { ...prev };
          list.forEach((x) => { next[x] = resp.data.data[x] || 0; });
          return next;
        });
      }
    } catch { /* ignore */ }
  };

  const loadArticleBom = async (idnrk: string, force = false) => {
    if (!force && loadedArticleBom[idnrk]) return;
    try {
      setLoadingArticleBom((prev) => ({ ...prev, [idnrk]: true }));
      const resp = await api.get(`/ih02-hierarchy/article-bom/${encodeURIComponent(idnrk)}`);
      if (resp.data.success) {
        const comps: BomComponent[] = resp.data.data || [];
        setLoadedArticleBom((prev) => ({ ...prev, [idnrk]: comps }));
        // Sans ca, le chevron d'expansion reste fige apres un deplacement
        // (ajout ou retrait d'un composant).
        setArticleBomCounts((prev) => ({ ...prev, [idnrk]: comps.length }));
      }
    } catch (err) {
      console.error('Erreur chargement BOM article:', err);
    } finally {
      setLoadingArticleBom((prev) => ({ ...prev, [idnrk]: false }));
    }
  };

  const toggleArticleBom = async (pathKey: string, idnrk: string) => {
    const isExpanded = expandedArticleBom[pathKey];
    if (!isExpanded) await loadArticleBom(idnrk);
    setExpandedArticleBom((prev) => ({ ...prev, [pathKey]: !isExpanded }));
  };

  // --- Panneau de détails d'un composant BOM (droite) ---

  const selectBomComponent = (sel: SelectedBom) => {
    setSelectedBom(sel);
    setSelectedNode(null);
    setDetailedLocation(null);
    setDetailedEquipment(null);
    setEditMode(false);
    setEditBomData({});
  };

  const startEditBom = (sel: SelectedBom) => {
    const c = sel.comp;
    setEditBomData({
      idnrk: c.matnr_short || c.idnrk || '',
      article_code: c.matnr_short || c.idnrk || '',
      quantity: c.quantity ?? '',
      unit: c.unit ?? '',
      category: c.item_category ?? '',
      posnr: c.posnr ?? '',
      potx1: c.potx1 ?? '',
      potx2: c.potx2 ?? '',
    });
    setEditBomArticleQuery(c.matnr_short || c.idnrk || '');
    setEditBomArticleSuggestions([]);
    setEditMode(true);
  };

  const onBomFieldChange = (key: string, value: string) => {
    setEditBomData((prev) => ({ ...prev, [key]: value }));
  };

  const saveBom = async () => {
    if (!selectedBom) return;
    if (!editBomData.idnrk?.trim()) {
      setSnackbar({ open: true, message: 'L\'article est obligatoire', severity: 'error' });
      return;
    }
    if (editBomData.quantity === '' || editBomData.quantity === undefined || !editBomData.unit?.trim()) {
      setSnackbar({ open: true, message: 'Quantité et unité sont obligatoires', severity: 'error' });
      return;
    }
    setSaving(true);
    try {
      const originalCode = (selectedBom.comp.matnr_short || selectedBom.comp.idnrk || '').trim();
      // L'utilisateur a-t-il repointé la ligne vers un AUTRE article (autocomplete) ?
      const pointerChanged = editBomData.idnrk.trim() !== originalCode;

      // Renommage du code de l'article (fiche partagée) — uniquement si la ligne
      // pointe toujours le même article. Localisé par sap_key (comp.idnrk, immuable).
      const newArticleCode = (editBomData.article_code || '').trim();
      if (!pointerChanged && newArticleCode && newArticleCode !== originalCode) {
        await api.put('/ih02-hierarchy/article-master', {
          idnrk: selectedBom.comp.idnrk,
          code: newArticleCode,
        });
      }

      const payload: Record<string, any> = {
        // Si l'article pointé n'a pas changé, envoyer le sap_key réel (le code
        // affiché peut avoir été renommé et ne plus correspondre au matnr SAP).
        idnrk: pointerChanged ? editBomData.idnrk.trim() : selectedBom.comp.idnrk,
        menge: editBomData.quantity,
        meins: editBomData.unit.trim(),
        category: editBomData.category ?? '',
        posnr: editBomData.posnr ?? '',
        potx1: editBomData.potx1 ?? '',
        potx2: editBomData.potx2 ?? '',
      };
      if (selectedBom.mode === 'article') {
        await api.put('/ih02-hierarchy/article-bom-component', {
          stlnr: selectedBom.comp.stlnr,
          stlkn: selectedBom.comp.stlkn,
          ...payload,
        });
        if (selectedBom.parentIdnrk) await loadArticleBom(selectedBom.parentIdnrk, true);
      } else {
        await api.put('/ih02-hierarchy/bom-component', {
          tplnr: selectedBom.tplnr,
          stlnr: selectedBom.comp.stlnr,
          stlkn: selectedBom.comp.stlkn,
          ...payload,
        });
        if (selectedBom.tplnr) await loadBom(selectedBom.tplnr, true);
      }
      // Rafraîchit le composant affiché dans le panneau
      const displayCode = pointerChanged ? payload.idnrk : (newArticleCode || originalCode);
      setSelectedBom((prev) => prev ? {
        ...prev,
        comp: {
          ...prev.comp,
          idnrk: pointerChanged ? payload.idnrk : prev.comp.idnrk,
          matnr_short: displayCode,
          quantity: payload.menge,
          unit: payload.meins,
          item_category: payload.category,
          posnr: payload.posnr,
          potx1: payload.potx1,
          potx2: payload.potx2,
        },
      } : prev);
      setEditMode(false);
      setSnackbar({ open: true, message: 'Composant de nomenclature mis à jour', severity: 'success' });
    } catch (err: any) {
      setSnackbar({ open: true, message: err.response?.data?.error || 'Erreur mise à jour nomenclature', severity: 'error' });
    } finally {
      setSaving(false);
    }
  };

  const loadEquipmentChildren = async (eq: EquipmentNode) => {
    const key = getNodeKey(eq);
    if (loadedEqChildren[key]) return;

    try {
      setLoadingNodes((prev) => ({ ...prev, [key]: true }));
      const response = await api.get('/ih02-hierarchy/equipment-children', {
        params: { parent_equnr: eq.equnr },
      });
      if (response.data.success) {
        const children = (response.data.data || []).map((n: any) => ({ ...n, node_type: 'equipment' }));
        setLoadedEqChildren((prev) => ({ ...prev, [key]: children }));
      }
    } catch (err) {
      console.error('Erreur chargement enfants équipement:', err);
    } finally {
      setLoadingNodes((prev) => ({ ...prev, [key]: false }));
    }
  };

  const toggleEquipment = async (eq: EquipmentNode) => {
    const key = getNodeKey(eq);
    const isExpanded = expandedNodes[key];
    if (!isExpanded) await loadEquipmentChildren(eq);
    setExpandedNodes((prev) => ({ ...prev, [key]: !isExpanded }));
  };

  const loadLocationDetails = async (node: LocationNode): Promise<LocationNode | null> => {
    try {
      setDetailsLoading(true);
      setDetailedEquipment(null);
      const response = await api.get('/ih02-hierarchy/node-details', {
        params: { row_id: node.row_id, node_id: node.node_id, level: node.level },
      });
      if (response.data.success) {
        const loc = { ...response.data.data, node_type: 'location' as const };
        setDetailedLocation(loc);
        return loc;
      }
      return null;
    } catch (err) {
      setDetailedLocation(node);
      return node;
    } finally {
      setDetailsLoading(false);
    }
  };

  const loadEquipmentDetails = async (node: EquipmentNode): Promise<EquipmentDetails | null> => {
    try {
      setDetailsLoading(true);
      setDetailedLocation(null);
      const response = await api.get('/ih02-hierarchy/equipment-details', {
        params: { equnr: node.equnr },
      });
      if (response.data.success) {
        const eq = response.data.data as EquipmentDetails;
        setDetailedEquipment(eq);
        return eq;
      }
    } catch (err) {
      console.error('Erreur chargement détails équipement:', err);
    } finally {
      setDetailsLoading(false);
    }
    return null;
  };

  const toggleNode = async (node: LocationNode) => {
    const key = getNodeKey(node);
    const isExpanded = expandedNodes[key];
    if (!isExpanded) await loadChildren(node);
    setExpandedNodes((prev) => ({ ...prev, [key]: !isExpanded }));

    if (!isExpanded && (bomCounts[node.node_id] || 0) > 0) {
      if (!loadedBom[node.node_id]) {
        await loadBom(node.node_id);
      }
      setExpandedBom((prev) => ({ ...prev, [node.node_id]: true }));
    }
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchQuery.length >= 2) {
        (async () => {
          try {
            setSearchLoading(true);
            setSearchError(null);
            const response = await api.get(`/ih02-hierarchy/search?q=${encodeURIComponent(searchQuery)}`);
            if (response.data.success) {
              const locs = (response.data.data.locations || []).map((n: any) => ({ ...n, node_type: 'location' }));
              const eqs = (response.data.data.equipment || []).map((n: any) => ({ ...n, node_type: 'equipment' }));
              const arts: ArticleResult[] = response.data.data.articles || [];
              setSearchResults({ locations: locs, equipment: eqs, articles: arts });
              setExpandedSearchArticle({});
            } else {
              setSearchResults(null);
              setSearchError(response.data.error || 'La recherche a échoué');
            }
          } catch (err: any) {
            // Sans ce report, une erreur serveur laissait la zone vide sans message :
            // indiscernable d'une recherche sans résultat.
            console.error('Erreur recherche:', err);
            setSearchResults(null);
            setSearchError(err.response?.data?.error || 'Erreur lors de la recherche');
          } finally {
            setSearchLoading(false);
          }
        })();
      } else {
        setSearchResults(null);
        setSearchError(null);
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  const handleDragStart = (e: React.DragEvent, node: TreeNode) => {
    setDraggedNode(node);
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', getNodeKey(node));
  };

  const handleDragOver = (e: React.DragEvent, targetNode: LocationNode) => {
    e.preventDefault();
    e.stopPropagation();
    const targetKey = getNodeKey(targetNode);
    // Un poste technique accepte deux choses : un autre poste, ou une ligne
    // de nomenclature (qui vient alors s'y rattacher).
    if (draggedBomRef.current) {
      e.dataTransfer.dropEffect = 'move';
      setDropTargetKey(targetKey);
      return;
    }
    if (!draggedNode) return;
    if (getNodeKey(draggedNode) === targetKey) return;
    e.dataTransfer.dropEffect = 'move';
    setDropTargetKey(targetKey);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    setDropTargetKey(null);
  };

  const handleDrop = (e: React.DragEvent, targetNode: LocationNode) => {
    e.preventDefault();
    e.stopPropagation();
    setDropTargetKey(null);

    // Depot d'une ligne de nomenclature sur un poste technique
    if (draggedBomRef.current) {
      const drag = draggedBomRef.current;
      draggedBomRef.current = null;
      setDraggedBom(null);
      if (drag.mode === 'fl' && drag.sourceKey === targetNode.node_id) {
        // Sans ce retour, l'absence de reaction est indiscernable d'une panne.
        setSnackbar({
          open: true,
          severity: 'error',
          message: `"${drag.label}" est déjà dans la nomenclature de "${targetNode.display_name || targetNode.node_id}"`,
        });
        return;
      }
      setPendingBomDrop({
        drag,
        targetType: 'FUNC_LOC',
        targetKey: targetNode.node_id,
        targetLabel: targetNode.display_name || targetNode.node_id,
      });
      return;
    }

    if (!draggedNode || !isLocation(draggedNode)) {
      setDraggedNode(null);
      return;
    }
    const dragKey = getNodeKey(draggedNode);
    const targetKey = getNodeKey(targetNode);
    if (dragKey === targetKey) { setDraggedNode(null); return; }

    setPendingDrop({ source: draggedNode as LocationNode, target: targetNode });
    setDraggedNode(null);
  };

  const confirmDrop = async () => {
    if (!pendingDrop) return;
    setDropConfirmLoading(true);
    try {
      await api.put('/ih02-hierarchy/move-node', {
        row_id: pendingDrop.source.row_id,
        level: pendingDrop.source.level,
        new_parent_id: pendingDrop.target.node_id,
        new_parent_level: pendingDrop.target.level,
      });
      setSnackbar({ open: true, message: `"${pendingDrop.source.node_id}" déplacé sous "${pendingDrop.target.node_id}"`, severity: 'success' });
      setLoadedChildren({});
      setLoadedEqChildren({});
      setExpandedNodes({});
      loadRootNodes();
      loadStats();
    } catch (err: any) {
      setSnackbar({ open: true, message: err.response?.data?.error || 'Erreur lors du déplacement', severity: 'error' });
    } finally {
      setDropConfirmLoading(false);
      setPendingDrop(null);
    }
  };

  const handleDragEnd = () => {
    setDraggedNode(null);
    draggedBomRef.current = null;
    setDraggedBom(null);
    setDropTargetKey(null);
  };

  // --- Glisser-deposer d'une ligne de nomenclature ---

  const handleBomDragStart = (e: React.DragEvent, drag: DraggedBom) => {
    e.stopPropagation();
    // Sans bom_key, le backend actuellement deploye ne sait pas identifier la
    // ligne. On le signale plutot que de laisser un glisser-deposer inerte.
    if (!drag.comp.bom_key) {
      setSnackbar({
        open: true,
        severity: 'error',
        message: 'Cette ligne ne peut pas etre deplacee : le serveur ne fournit pas son identifiant de nomenclature.',
      });
      return;
    }
    draggedBomRef.current = drag;
    setDraggedBom(drag);
    setDraggedNode(null);
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', drag.comp.bom_key || '');
  };

  // Une ligne d'article accepte le depot d'une autre ligne : celle-ci vient
  // alors se rattacher a l'article de la ligne cible (nomenclature matiere).
  const handleBomDragOver = (e: React.DragEvent, pathKey: string) => {
    if (!draggedBomRef.current) return;
    e.preventDefault();
    e.stopPropagation();
    e.dataTransfer.dropEffect = 'move';
    setDropTargetKey(pathKey);
  };

  const handleBomDrop = (e: React.DragEvent, cible: BomComponent) => {
    if (!draggedBomRef.current) return;
    e.preventDefault();
    e.stopPropagation();
    setDropTargetKey(null);
    const drag = draggedBomRef.current;
    draggedBomRef.current = null;
    setDraggedBom(null);
    // Sur elle-meme : geste sans intention, on ignore en silence.
    if (drag.comp.bom_key === cible.bom_key) return;
    // Deja rattachee a cet article : on le dit, sans quoi l'absence de
    // reaction est indiscernable d'une panne.
    if (drag.mode === 'article' && drag.sourceKey === cible.idnrk) {
      setSnackbar({
        open: true,
        severity: 'error',
        message: `"${drag.label}" est déjà dans la nomenclature de "${cible.matnr_short || cible.idnrk}"`,
      });
      return;
    }
    setPendingBomDrop({
      drag,
      targetType: 'ARTICLE',
      targetKey: cible.idnrk,
      targetLabel: cible.matnr_short || cible.idnrk,
    });
  };

  const confirmBomDrop = async () => {
    if (!pendingBomDrop) return;
    const { drag, targetType, targetKey, targetLabel } = pendingBomDrop;
    setDropConfirmLoading(true);
    try {
      await api.put('/ih02-hierarchy/move-bom-item', {
        bom_key: drag.comp.bom_key,
        new_parent_type: targetType,
        new_parent_key: targetKey,
      });
      setSnackbar({
        open: true,
        message: `"${drag.label}" déplacé sous "${targetLabel}"`,
        severity: 'success',
      });
      // Recharger uniquement les deux nomenclatures concernees : l'arbre reste
      // deplie (cf. le repli corrige au renommage).
      if (drag.mode === 'fl') await loadBom(drag.sourceKey, true);
      else await loadArticleBom(drag.sourceKey, true);
      if (targetType === 'FUNC_LOC') await loadBom(targetKey, true);
      else await loadArticleBom(targetKey, true);
      // Le panneau de details pointait peut-etre la ligne deplacee
      if (selectedBom?.comp.bom_key === drag.comp.bom_key) setSelectedBom(null);
    } catch (err: any) {
      setSnackbar({
        open: true,
        message: err.response?.data?.error || 'Erreur lors du déplacement',
        severity: 'error',
      });
    } finally {
      setDropConfirmLoading(false);
      setPendingBomDrop(null);
    }
  };

  const openBulkEdit = async (node: LocationNode) => {
    setBulkEdits([]);
    setBulkField('');
    setBulkValue('');
    setBulkDialogOpen(true);
    try {
      const resp = await api.get('/ih02-hierarchy/descendants-count', { params: { node_id: node.node_id, level: node.level } });
      if (resp.data.success) setBulkCount(resp.data.data.count);
    } catch { setBulkCount(0); }
  };

  const addBulkEdit = () => {
    if (!bulkField) return;
    const label = BULK_FIELDS.find((f) => f.key === bulkField)?.label || bulkField;
    setBulkEdits((prev) => {
      const filtered = prev.filter((e) => e.field !== bulkField);
      return [...filtered, { field: bulkField, label, value: bulkValue }];
    });
    setBulkField('');
    setBulkValue('');
  };

  const removeBulkEdit = (field: string) => {
    setBulkEdits((prev) => prev.filter((e) => e.field !== field));
  };

  const applyBulkEdit = async () => {
    if (!selectedNode || !isLocation(selectedNode) || bulkEdits.length === 0) return;
    try {
      setBulkSaving(true);
      const resp = await api.put('/ih02-hierarchy/bulk-update', {
        node_id: selectedNode.node_id,
        level: selectedNode.level,
        updates: bulkEdits.map((e) => ({ field: e.field, value: e.value })),
      });
      if (resp.data.success) {
        setSnackbar({ open: true, message: resp.data.message, severity: 'success' });
        setBulkDialogOpen(false);
        setLoadedChildren({});
        loadRootNodes();
        loadLocationDetails(selectedNode);
      }
    } catch (err: any) {
      setSnackbar({ open: true, message: err.response?.data?.error || 'Erreur modification en masse', severity: 'error' });
    } finally {
      setBulkSaving(false);
    }
  };

  const openAddLocation = () => {
    setAddNodeData({ node_id: '', designation: '', type_poste: '', centre_couts: '' });
    setAddDialogType('location');
    setAddDialogOpen(true);
  };

  const openAddEquipment = () => {
    setAddEquipmentData({ equnr: '', designation: '', eqart: '', herst: '', typbz: '', matnr: '', sernr: '' });
    setEquipmentSuggestions([]);
    setEquipmentSearchQuery('');
    setArticleSuggestions([]);
    setArticleSearchQuery('');
    setAddDialogType('equipment');
    setAddDialogOpen(true);
  };

  useEffect(() => {
    if (!addDialogOpen || addDialogType !== 'equipment') return;
    const timer = setTimeout(async () => {
      try {
        setEquipmentSearchLoading(true);
        const res = await api.get(`/ih02-hierarchy/search-equipment`, {
          params: { q: equipmentSearchQuery, limit: 20 },
        });
        setEquipmentSuggestions(res.data?.data || []);
      } catch {
        setEquipmentSuggestions([]);
      } finally {
        setEquipmentSearchLoading(false);
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [addDialogOpen, addDialogType, equipmentSearchQuery]);

  useEffect(() => {
    if (!addDialogOpen || addDialogType !== 'equipment') return;
    const timer = setTimeout(async () => {
      try {
        setArticleSearchLoading(true);
        const res = await api.get(`/ih02-hierarchy/search-article`, {
          params: { q: articleSearchQuery, limit: 20 },
        });
        setArticleSuggestions(res.data?.data || []);
      } catch {
        setArticleSuggestions([]);
      } finally {
        setArticleSearchLoading(false);
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [addDialogOpen, addDialogType, articleSearchQuery]);


  // Recherche article pour le panneau de détails composant (mode édition)
  useEffect(() => {
    if (!selectedBom || !editMode) return;
    const timer = setTimeout(async () => {
      try {
        setEditBomArticleLoading(true);
        const res = await api.get(`/ih02-hierarchy/search-article`, {
          params: { q: editBomArticleQuery, limit: 20 },
        });
        setEditBomArticleSuggestions(res.data?.data || []);
      } catch {
        setEditBomArticleSuggestions([]);
      } finally {
        setEditBomArticleLoading(false);
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [selectedBom, editMode, editBomArticleQuery]);

  const confirmAddNode = async () => {
    if (!selectedNode || !isLocation(selectedNode)) return;
    setAddSaving(true);
    try {
      if (addDialogType === 'location') {
        await api.post('/ih02-hierarchy/add-node', {
          parent_id: selectedNode.node_id,
          parent_level: selectedNode.level,
          ...addNodeData,
        });
        setSnackbar({ open: true, message: `Poste technique "${addNodeData.node_id}" créé`, severity: 'success' });
      } else {
        await api.post('/ih02-hierarchy/add-equipment', {
          parent_tplnr: selectedNode.node_id,
          ...addEquipmentData,
        });
        setSnackbar({ open: true, message: `Équipement créé sous "${selectedNode.node_id}"`, severity: 'success' });
      }
      setAddDialogOpen(false);
      const key = getNodeKey(selectedNode);
      setLoadedChildren((prev) => { const n = { ...prev }; delete n[key]; return n; });
      loadChildren(selectedNode);
      loadStats();
    } catch (err: any) {
      setSnackbar({ open: true, message: err.response?.data?.error || 'Erreur lors de la création', severity: 'error' });
    } finally {
      setAddSaving(false);
    }
  };

  const openDeleteConfirm = (type: 'location' | 'equipment', node: TreeNode) => {
    setDeleteTarget({ type, node });
    setDeleteConfirmOpen(true);
  };

  const confirmDelete = async () => {
    if (!deleteTarget) return;
    setDeleteSaving(true);
    try {
      if (deleteTarget.type === 'location') {
        const loc = deleteTarget.node as LocationNode;
        await api.delete('/ih02-hierarchy/delete-node', { params: { row_id: loc.row_id, level: loc.level } });
        setSnackbar({ open: true, message: `"${loc.node_id}" supprimé`, severity: 'success' });
      } else {
        const eq = deleteTarget.node as EquipmentNode;
        await api.delete('/ih02-hierarchy/delete-equipment', { params: { equnr: eq.equnr } });
        setSnackbar({ open: true, message: `Équipement "${eq.equnr_short}" supprimé`, severity: 'success' });
      }
      setDeleteConfirmOpen(false);
      setDeleteTarget(null);
      if (selectedNode && getNodeKey(selectedNode) === getNodeKey(deleteTarget.node)) {
        setSelectedNode(null);
        setDetailedLocation(null);
        setDetailedEquipment(null);
      }
      setLoadedChildren({});
      setLoadedEqChildren({});
      loadRootNodes();
      loadStats();
    } catch (err: any) {
      setSnackbar({ open: true, message: err.response?.data?.error || 'Erreur lors de la suppression', severity: 'error' });
    } finally {
      setDeleteSaving(false);
    }
  };

  const handleExport = async (type: 'structures' | 'equipment') => {
    setExportAnchorEl(null);
    try {
      setExporting(true);
      const endpoint = type === 'structures' ? '/ih02-hierarchy/export-structures' : '/ih02-hierarchy/export-equipment';
      const response = await api.get(endpoint, { responseType: 'blob' });
      const filename = type === 'structures' ? 'ih02_postes_techniques.csv' : 'ih02_equipements.csv';
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', filename);
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
      setSnackbar({ open: true, message: `Export ${type === 'structures' ? 'des structures' : 'des équipements'} téléchargé`, severity: 'success' });
    } catch (err: any) {
      setSnackbar({ open: true, message: 'Erreur lors de l\'export', severity: 'error' });
    } finally {
      setExporting(false);
    }
  };

  const startEditLocation = (node: LocationNode) => {
    setEditLocationData({
      code: node.display_name || node.node_id || '',
      parent_node_id: node.parent_node_id ?? '',
      designation: node.designation ?? '',
      centre_couts: node.centre_couts ?? '',
      poste_travail_resp_maintenance: node.poste_travail_resp_maintenance ?? '',
      poste_travail: node.poste_travail ?? '',
      art_type_construction: node.art_type_construction ?? '',
      quantite: node.quantite ?? '',
      unite: node.unite ?? '',
    });
    setEditMode(true);
  };

  const startEditEquipment = (eq: EquipmentDetails) => {
    setEditEquipmentData({
      designation: eq.designation ?? '',
      type_equipement: eq.type_equipement ?? '',
      categorie: eq.categorie ?? '',
      fabricant: eq.fabricant ?? '',
      pays_fabricant: eq.pays_fabricant ?? '',
      modele: eq.modele ?? '',
      numero_serie: eq.numero_serie ?? '',
      numero_inventaire: eq.numero_inventaire ?? '',
      taille: eq.taille ?? '',
      poids: eq.poids ?? '',
      unite_poids: eq.unite_poids ?? '',
      valeur_acquisition: eq.valeur_acquisition ?? '',
      devise: eq.devise ?? '',
      date_acquisition: eq.date_acquisition ?? '',
      annee_construction: eq.annee_construction ?? '',
      mois_construction: eq.mois_construction ?? '',
      date_mise_service: eq.date_mise_service ?? '',
      fournisseur: eq.fournisseur ?? '',
      numero_article: eq.numero_article ?? '',
      centre_couts: eq.centre_couts ?? '',
      societe: eq.societe ?? '',
      domaine_activite: eq.domaine_activite ?? '',
      division_maintenance: eq.division_maintenance ?? '',
      groupe_planification: eq.groupe_planification ?? '',
      division: eq.division ?? '',
      emplacement: eq.emplacement ?? '',
      section: eq.section ?? '',
      plan_maintenance: eq.plan_maintenance ?? '',
    });
    setEditMode(true);
  };

  const cancelEdit = () => {
    setEditMode(false);
    setEditLocationData({});
    setEditEquipmentData({});
  };

  const saveLocation = async () => {
    if (!detailedLocation) return;

    if (!editLocationData.designation?.trim()) {
      setSnackbar({ open: true, message: 'La désignation est obligatoire', severity: 'error' });
      return;
    }

    try {
      setSaving(true);
      const resp = await api.put('/ih02-hierarchy/update-location', {
        row_id: detailedLocation.row_id,
        level: detailedLocation.level,
        ...editLocationData,
      });
      const msg = resp.data?.message || 'Poste technique mis à jour';
      setSnackbar({ open: true, message: msg, severity: 'success' });
      setEditMode(false);
      const renomme = editLocationData.code !== (detailedLocation.display_name || detailedLocation.node_id);
      const deplace = editLocationData.parent_node_id !== (detailedLocation.parent_node_id ?? '');

      if (deplace) {
        // Le noeud change de place : l'arbre en memoire n'est plus valable.
        // On repart d'un arbre replie -- vider loadedChildren SANS reinitialiser
        // expandedNodes laisserait des branches marquees ouvertes mais vides.
        setLoadedChildren({});
        setLoadedEqChildren({});
        setExpandedNodes({});
        loadRootNodes();
      } else if (renomme) {
        // Seul le libelle change : sap_key (donc les cles d'etat) est immuable.
        // On corrige le noeud sur place, ce qui preserve l'arborescence depliee.
        const cle = detailedLocation.node_id;
        const nouveauCode = editLocationData.code;
        const patch = (n: LocationNode): LocationNode =>
          n.node_id === cle ? { ...n, display_name: nouveauCode } : n;

        setRootNodes((prev) => prev.map(patch));
        setLoadedChildren((prev) => {
          const next: LoadedChildren = {};
          Object.keys(prev).forEach((k) => {
            const branche = prev[k];
            next[k] = { ...branche, locations: branche.locations.map(patch) };
          });
          return next;
        });
      }
      loadLocationDetails(detailedLocation);
    } catch (err: any) {
      const serverMsg = err.response?.data?.error;
      const status = err.response?.status;
      let msg = 'Erreur lors de la sauvegarde';
      if (serverMsg) {
        msg = serverMsg;
      } else if (status === 404) {
        msg = 'Poste technique non trouvé dans la base';
      } else if (status >= 500) {
        msg = 'Erreur serveur - veuillez réessayer';
      } else if (!err.response) {
        msg = 'Erreur réseau - vérifiez votre connexion';
      }
      setSnackbar({ open: true, message: msg, severity: 'error' });
    } finally {
      setSaving(false);
    }
  };

  const saveEquipment = async () => {
    if (!detailedEquipment) return;

    if (!editEquipmentData.designation?.trim()) {
      setSnackbar({ open: true, message: 'La désignation est obligatoire', severity: 'error' });
      return;
    }

    try {
      setSaving(true);
      const resp = await api.put('/ih02-hierarchy/update-equipment', {
        equnr: detailedEquipment.equnr,
        ...editEquipmentData,
      });
      const msg = resp.data?.message || 'Équipement mis à jour';
      setSnackbar({ open: true, message: msg, severity: 'success' });
      setEditMode(false);
      loadEquipmentDetails(selectedNode as EquipmentNode);
    } catch (err: any) {
      const serverMsg = err.response?.data?.error;
      const status = err.response?.status;
      let msg = 'Erreur lors de la sauvegarde';
      if (serverMsg) {
        msg = serverMsg;
      } else if (status === 404) {
        msg = 'Équipement non trouvé dans la base';
      } else if (status >= 500) {
        msg = 'Erreur serveur - veuillez réessayer';
      } else if (!err.response) {
        msg = 'Erreur réseau - vérifiez votre connexion';
      }
      setSnackbar({ open: true, message: msg, severity: 'error' });
    } finally {
      setSaving(false);
    }
  };

  const onLocationFieldChange = (key: string, value: string) => {
    setEditLocationData((prev) => ({ ...prev, [key]: value }));
  };

  const onEquipmentFieldChange = (key: string, value: string) => {
    setEditEquipmentData((prev) => ({ ...prev, [key]: value }));
  };

  const selectNode = (node: TreeNode) => {
    setSelectedBom(null);
    setSelectedNode(node);
    setActiveTab(0);
    setEditMode(false);
    setEditLocationData({});
    setEditEquipmentData({});
    if (isEquipment(node)) {
      loadEquipmentDetails(node);
    } else {
      loadLocationDetails(node);
    }
  };

  const getLevelColor = (level: number) => {
    const colors = [
      theme.palette.error.main, theme.palette.warning.main,
      theme.palette.info.main, theme.palette.success.main,
      theme.palette.secondary.main, '#8e24aa', '#00897b', '#6d4c41',
    ];
    return colors[level % colors.length];
  };

  const renderEquipmentNode = (eq: EquipmentNode, depth: number) => {
    const key = getNodeKey(eq);
    const isSelected = selectedNode && getNodeKey(selectedNode) === key;
    const isExpanded = expandedNodes[key];
    const isLoading = loadingNodes[key];
    const eqChildren = loadedEqChildren[key];
    const hasChildren = eq.children_count > 0 || (eqChildren && eqChildren.length > 0);

    return (
      <Box key={key}>
        <Box
          sx={{
            display: 'flex',
            alignItems: 'center',
            py: 0.75,
            px: 1,
            pl: depth * 3 + 1,
            cursor: 'pointer',
            borderRadius: 1,
            transition: 'all 0.2s ease',
            backgroundColor: isSelected ? alpha(theme.palette.warning.main, 0.15) : 'transparent',
            '&:hover': {
              backgroundColor: isSelected ? alpha(theme.palette.warning.main, 0.2) : alpha(theme.palette.action.hover, 0.08),
            },
            borderLeft: isSelected ? `3px solid ${theme.palette.warning.main}` : '3px solid transparent',
            opacity: draggedNode && getNodeKey(draggedNode) === key ? 0.4 : 1,
          }}
          onClick={() => selectNode(eq)}
        >
          {hasChildren || !eqChildren ? (
            <IconButton
              size="small"
              onClick={(e) => { e.stopPropagation(); toggleEquipment(eq); }}
              sx={{ mr: 0.5, p: 0.25, visibility: hasChildren || !eqChildren ? 'visible' : 'hidden' }}
            >
              {isLoading ? <CircularProgress size={16} /> : isExpanded ? <ExpandMoreIcon fontSize="small" /> : <ChevronRightIcon fontSize="small" />}
            </IconButton>
          ) : (
            <Box sx={{ width: 28 }} />
          )}
          <EquipmentIcon fontSize="small" sx={{ color: theme.palette.warning.main, mr: 1.5 }} />
          <Typography
            variant="body2"
            sx={{ fontFamily: 'monospace', fontWeight: 600, color: theme.palette.warning.dark, minWidth: 140, fontSize: '0.85rem' }}
          >
            {eq.equnr_short}
          </Typography>
          <Typography variant="body2" sx={{ ml: 2, flex: 1, fontWeight: isSelected ? 500 : 400 }}>
            {eq.designation}
          </Typography>
          {eq.children_count > 0 && (
            <Tooltip title="Sous-équipements">
              <Chip
                size="small"
                icon={<EquipmentIcon sx={{ fontSize: '0.8rem !important' }} />}
                label={eq.children_count}
                sx={{ ml: 0.5, height: 20, fontSize: '0.7rem', backgroundColor: alpha(theme.palette.warning.main, 0.1), color: theme.palette.warning.dark }}
              />
            </Tooltip>
          )}
          <Chip
            size="small"
            label="Éqpt"
            sx={{ ml: 0.5, height: 20, fontSize: '0.65rem', backgroundColor: alpha(theme.palette.warning.main, 0.1), color: theme.palette.warning.dark }}
          />
          <Tooltip title="Supprimer">
            <IconButton size="small" sx={{ p: 0.25, ml: 0.5, opacity: 0.3, '&:hover': { opacity: 1 } }} onClick={(e) => { e.stopPropagation(); openDeleteConfirm('equipment', eq); }}>
              <DeleteIcon fontSize="small" sx={{ fontSize: '0.9rem', color: theme.palette.error.main }} />
            </IconButton>
          </Tooltip>
        </Box>

        <Collapse in={isExpanded} timeout="auto" unmountOnExit>
          {eqChildren && eqChildren.map((child) => renderEquipmentNode(child, depth + 1))}
        </Collapse>
      </Box>
    );
  };

  // Rendu récursif d'un composant de nomenclature (article).
  //  - mode 'fl'      : composant direct d'un poste technique (édition via /bom-component)
  //  - mode 'article' : sous-composant d'une nomenclature matière (édition via /article-bom-component)
  // parentIdnrk = article dont ce composant fait partie (requis en mode 'article' pour le rafraîchissement).
  const renderBomComponent = (
    comp: BomComponent,
    depth: number,
    pathKey: string,
    mode: 'fl' | 'article',
    parentIdnrk?: string,
  ) => {
    const childCount = comp.children_count ?? articleBomCounts[comp.idnrk] ?? 0;
    const hasChildren = childCount > 0;
    const isExpanded = expandedArticleBom[pathKey];
    const isLoading = loadingArticleBom[comp.idnrk];
    const children = loadedArticleBom[comp.idnrk];

    const isBomSelected = selectedBom?.pathKey === pathKey;
    const isBomDropTarget = !!draggedBom && dropTargetKey === pathKey;

    return (
      <Box key={pathKey}>
        <Box
          draggable
          onDragStart={(e) => handleBomDragStart(e, {
            comp, mode,
            sourceKey: mode === 'fl' ? (comp.tplnr || '') : (parentIdnrk || ''),
            label: comp.matnr_short || comp.idnrk,
          })}
          onDragEnd={handleDragEnd}
          onDragOver={(e) => handleBomDragOver(e, pathKey)}
          onDragLeave={handleDragLeave}
          onDrop={(e) => handleBomDrop(e, comp)}
          onClick={() => selectBomComponent({
            comp, mode, pathKey,
            tplnr: mode === 'fl' ? (comp.tplnr || '') : undefined,
            parentIdnrk: mode === 'article' ? (parentIdnrk || '') : undefined,
          })}
          sx={{
            display: 'flex', alignItems: 'center', py: 0.5, px: 1,
            pl: depth * 3 + 6, borderRadius: 1, cursor: 'grab',
            backgroundColor: isBomDropTarget
              ? alpha(theme.palette.success.main, 0.3)
              : isBomSelected ? alpha(theme.palette.success.main, 0.15) : 'transparent',
            borderLeft: isBomDropTarget
              ? `3px solid ${theme.palette.success.dark}`
              : isBomSelected ? `3px solid ${theme.palette.success.main}` : '3px solid transparent',
            '&:hover': { backgroundColor: alpha(theme.palette.success.main, isBomSelected ? 0.2 : 0.06) },
          }}
        >
          <Tooltip title="Glisser cet article vers un poste technique ou un autre article">
            <DragIcon fontSize="small" sx={{ mr: 0.5, opacity: 0.45, cursor: 'grab', fontSize: '0.9rem' }} />
          </Tooltip>
          {hasChildren ? (
            <IconButton
              size="small"
              onClick={(e) => { e.stopPropagation(); toggleArticleBom(pathKey, comp.idnrk); }}
              sx={{ mr: 0.5, p: 0.25 }}
            >
              {isLoading ? <CircularProgress size={14} /> : isExpanded ? <ExpandMoreIcon fontSize="small" /> : <ChevronRightIcon fontSize="small" />}
            </IconButton>
          ) : (
            <Box sx={{ width: 28 }} />
          )}
          <BomIcon fontSize="small" sx={{ color: theme.palette.success.main, mr: 1.5, fontSize: '1rem' }} />
          <Typography variant="caption" sx={{ fontFamily: 'monospace', color: 'text.secondary', minWidth: 40 }}>
            {comp.posnr}
          </Typography>
          <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600, color: theme.palette.success.dark, ml: 1, minWidth: 110, fontSize: '0.82rem' }}>
            {comp.matnr_short}
          </Typography>
          <Typography variant="body2" sx={{ ml: 2, flex: 1, fontSize: '0.82rem' }}>
            {comp.designation || '-'}
          </Typography>
          {hasChildren && (
            <Tooltip title="Sous-composants (nomenclature matière)">
              <Chip
                size="small"
                icon={<BomIcon sx={{ fontSize: '0.7rem !important' }} />}
                label={childCount}
                onClick={(e) => { e.stopPropagation(); toggleArticleBom(pathKey, comp.idnrk); }}
                sx={{
                  ml: 0.5, height: 18, fontSize: '0.65rem', cursor: 'pointer',
                  backgroundColor: alpha(theme.palette.success.main, 0.14),
                  color: theme.palette.success.dark,
                  '&:hover': { backgroundColor: alpha(theme.palette.success.main, 0.28) },
                }}
              />
            </Tooltip>
          )}
          <Chip
            size="small"
            label={`${comp.quantity || '0'} ${comp.unit || ''}`}
            sx={{ ml: 1, height: 18, fontSize: '0.65rem', backgroundColor: alpha(theme.palette.info.main, 0.08) }}
          />
          {comp.item_category && (
            <Chip
              size="small"
              label={comp.item_category}
              sx={{ ml: 0.5, height: 18, fontSize: '0.6rem', backgroundColor: alpha(theme.palette.grey[500], 0.15) }}
            />
          )}
        </Box>

        <Collapse in={isExpanded} timeout="auto" unmountOnExit>
          {isLoading ? (
            <Box sx={{ pl: depth * 3 + 9, py: 1 }}>
              <CircularProgress size={14} />
            </Box>
          ) : (
            (children || []).map((child, idx) =>
              renderBomComponent(
                child,
                depth + 1,
                `${pathKey}/${child.posnr}-${child.idnrk}-${child.stlkn || idx}`,
                'article',
                comp.idnrk,
              )
            )
          )}
        </Collapse>
      </Box>
    );
  };

  const renderTreeNode = (node: LocationNode, depth: number = 0) => {
    const key = getNodeKey(node);
    const isExpanded = expandedNodes[key];
    const isLoading = loadingNodes[key];
    const children = loadedChildren[key];
    const hasChildren = node.children_count > 0 || (children && (children.locations.length > 0 || children.equipment.length > 0));
    const hasBom = (bomCounts[node.node_id] || 0) > 0;
    const isExpandable = hasChildren || hasBom;
    const isSelected = selectedNode && getNodeKey(selectedNode) === key;
    const levelColor = getLevelColor(node.level);

    const isDragTarget = dropTargetKey === key;
    const isDragging = draggedNode && getNodeKey(draggedNode) === key;

    return (
      <Box key={key}>
        <Box
          draggable
          onDragStart={(e) => handleDragStart(e, node)}
          onDragOver={(e) => handleDragOver(e, node)}
          onDragLeave={handleDragLeave}
          onDrop={(e) => handleDrop(e, node)}
          onDragEnd={handleDragEnd}
          sx={{
            display: 'flex', alignItems: 'center', py: 0.75, px: 1, pl: depth * 3 + 1,
            cursor: 'grab', borderRadius: 1, transition: 'all 0.15s ease',
            backgroundColor: isDragTarget ? alpha(theme.palette.info.main, 0.18) : isSelected ? alpha(theme.palette.primary.main, 0.15) : 'transparent',
            '&:hover': { backgroundColor: isSelected ? alpha(theme.palette.primary.main, 0.2) : alpha(theme.palette.action.hover, 0.08) },
            borderLeft: isDragTarget ? `3px solid ${theme.palette.info.main}` : isSelected ? `3px solid ${theme.palette.primary.main}` : '3px solid transparent',
            outline: isDragTarget ? `2px dashed ${theme.palette.info.main}` : 'none',
            opacity: isDragging ? 0.4 : 1,
          }}
          onClick={() => selectNode(node)}
        >
          <DragIcon fontSize="small" sx={{ mr: 0.5, opacity: 0.3, cursor: 'grab', fontSize: '1rem' }} />
          <IconButton
            size="small"
            onClick={(e) => { e.stopPropagation(); toggleNode(node); }}
            sx={{ mr: 0.5, p: 0.25, visibility: isExpandable || !children ? 'visible' : 'hidden' }}
          >
            {isLoading ? <CircularProgress size={16} /> : isExpanded ? <ExpandMoreIcon fontSize="small" /> : <ChevronRightIcon fontSize="small" />}
          </IconButton>

          <Box sx={{ mr: 1.5, display: 'flex', alignItems: 'center' }}>
            {isExpanded ? <FolderOpenIcon fontSize="small" sx={{ color: levelColor }} /> : <FolderIcon fontSize="small" sx={{ color: levelColor }} />}
          </Box>

          <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600, color: levelColor, minWidth: 140, fontSize: '0.85rem' }}>
            {node.display_name || node.node_id}
          </Typography>

          <Typography variant="body2" sx={{ ml: 2, flex: 1, fontWeight: isSelected ? 500 : 400 }}>
            {node.designation}
          </Typography>

          <Chip size="small" label={objectLevelLabel(node.level)} sx={{ ml: 1, height: 20, fontSize: '0.7rem', backgroundColor: alpha(theme.palette.secondary.main, 0.1), color: theme.palette.secondary.main }} />
          {node.children_count > 0 && (
            <Chip size="small" label={node.children_count} sx={{ ml: 0.5, height: 20, fontSize: '0.7rem', backgroundColor: alpha(theme.palette.info.main, 0.1), color: theme.palette.info.main }} />
          )}
          {bomCounts[node.node_id] > 0 && (
            <Tooltip title="Nomenclature (BOM)">
              <Chip
                size="small"
                icon={<BomIcon sx={{ fontSize: '0.8rem !important' }} />}
                label={bomCounts[node.node_id]}
                onClick={(e) => { e.stopPropagation(); toggleBom(node.node_id); }}
                sx={{
                  ml: 0.5, height: 20, fontSize: '0.7rem', cursor: 'pointer',
                  backgroundColor: alpha(theme.palette.success.main, 0.12),
                  color: theme.palette.success.dark,
                  '&:hover': { backgroundColor: alpha(theme.palette.success.main, 0.25) },
                }}
              />
            </Tooltip>
          )}
          <Tooltip title="Supprimer">
            <IconButton size="small" sx={{ p: 0.25, ml: 0.5, opacity: 0.3, '&:hover': { opacity: 1 } }} onClick={(e) => { e.stopPropagation(); openDeleteConfirm('location', node); }}>
              <DeleteIcon fontSize="small" sx={{ fontSize: '0.9rem', color: theme.palette.error.main }} />
            </IconButton>
          </Tooltip>
        </Box>

        <Collapse in={expandedBom[node.node_id]} timeout="auto" unmountOnExit>
          {loadingBom[node.node_id] ? (
            <Box sx={{ pl: depth * 3 + 6, py: 1 }}>
              <CircularProgress size={14} />
            </Box>
          ) : (
            (loadedBom[node.node_id] || []).map((comp) =>
              renderBomComponent(
                { ...comp, tplnr: node.node_id },
                depth,
                `bom-${node.node_id}-${comp.posnr}-${comp.idnrk}`,
                'fl',
              )
            )
          )}
        </Collapse>

        <Collapse in={isExpanded} timeout="auto" unmountOnExit>
          {children && (
            <>
              {children.locations.map((child) => renderTreeNode(child, depth + 1))}
              {children.equipment.map((eq) => renderEquipmentNode(eq, depth + 1))}
            </>
          )}
        </Collapse>
      </Box>
    );
  };

  // Un article n'est pas un noeud de l'arbre : on liste ses porteurs (postes
  // techniques / articles parents), cliquables pour ouvrir leur fiche.
  const renderArticleResult = (art: ArticleResult) => {
    const isExpanded = !!expandedSearchArticle[art.idnrk];
    const carriers = art.used_in || [];

    return (
      <Box key={`search-art-${art.idnrk}`} sx={{ mb: 0.5 }}>
        <Box
          sx={{ display: 'flex', alignItems: 'center', py: 1, px: 2, cursor: carriers.length ? 'pointer' : 'default', borderRadius: 1, backgroundColor: alpha(theme.palette.background.paper, 0.5), '&:hover': { backgroundColor: alpha(theme.palette.success.main, 0.1) } }}
          onClick={() => carriers.length && setExpandedSearchArticle((prev) => ({ ...prev, [art.idnrk]: !isExpanded }))}
        >
          {carriers.length > 0
            ? (isExpanded ? <ExpandMoreIcon fontSize="small" sx={{ mr: 0.5 }} /> : <ChevronRightIcon fontSize="small" sx={{ mr: 0.5 }} />)
            : <Box sx={{ width: 24 }} />}
          <BomIcon fontSize="small" sx={{ color: theme.palette.success.main, mr: 1.5 }} />
          <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600, mr: 2 }}>
            {art.matnr_short || art.idnrk}
          </Typography>
          <Typography variant="body2" sx={{ flex: 1 }}>{art.designation}</Typography>
          {art.material_type && <Chip size="small" label={art.material_type} sx={{ ml: 1, height: 20, fontSize: '0.65rem' }} />}
          <Chip
            size="small"
            label={art.usage_count > 0 ? `${art.usage_count} emplacement(s)` : 'non rattaché'}
            color={art.usage_count > 0 ? 'success' : 'default'}
            variant="outlined"
            sx={{ ml: 1, height: 20, fontSize: '0.65rem' }}
          />
        </Box>

        <Collapse in={isExpanded} timeout="auto" unmountOnExit>
          {carriers.map((p, i) => p.node_type === 'location' ? (
            <Box
              key={`art-use-${art.idnrk}-loc-${p.row_id}-${i}`}
              sx={{ display: 'flex', alignItems: 'center', py: 0.75, pl: 7, pr: 2, cursor: 'pointer', borderRadius: 1, '&:hover': { backgroundColor: alpha(theme.palette.primary.main, 0.1) } }}
              onClick={() => selectNode({ ...p, node_type: 'location' } as unknown as LocationNode)}
            >
              <LocationIcon fontSize="small" sx={{ color: getLevelColor(p.level ?? 0), mr: 1.5 }} />
              <Chip size="small" label={`Niv. ${p.level ?? 0}`} sx={{ mr: 1, height: 20, fontSize: '0.7rem' }} />
              <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600, mr: 2 }}>
                {p.display_name || p.node_id}
              </Typography>
              <Typography variant="body2" sx={{ flex: 1 }} color="text.secondary">{p.designation}</Typography>
            </Box>
          ) : (
            <Box
              key={`art-use-${art.idnrk}-art-${p.idnrk}-${i}`}
              sx={{ display: 'flex', alignItems: 'center', py: 0.75, pl: 7, pr: 2 }}
            >
              <BomIcon fontSize="small" sx={{ color: theme.palette.success.main, mr: 1.5 }} />
              <Chip size="small" label="Article parent" sx={{ mr: 1, height: 20, fontSize: '0.65rem' }} />
              <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600, mr: 2 }}>
                {p.matnr_short || p.idnrk}
              </Typography>
              <Typography variant="body2" sx={{ flex: 1 }} color="text.secondary">{p.designation}</Typography>
            </Box>
          ))}
        </Collapse>
      </Box>
    );
  };

  const renderSearchResults = () => {
    if (searchError) return <Alert severity="error" sx={{ mt: 2 }}>{searchError}</Alert>;
    if (!searchResults) return null;
    const articles = searchResults.articles || [];
    const total = searchResults.locations.length + searchResults.equipment.length + articles.length;
    if (total === 0) return <Alert severity="info" sx={{ mt: 2 }}>Aucun résultat pour "{searchQuery}"</Alert>;

    return (
      <Box sx={{ mt: 2 }}>
        <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1 }}>{total} résultat(s)</Typography>

        {searchResults.locations.map((node) => (
          <Box
            key={`search-loc-${node.row_id}`}
            sx={{ display: 'flex', alignItems: 'center', py: 1, px: 2, cursor: 'pointer', borderRadius: 1, mb: 0.5, backgroundColor: alpha(theme.palette.background.paper, 0.5), '&:hover': { backgroundColor: alpha(theme.palette.primary.main, 0.1) } }}
            onClick={() => selectNode(node)}
          >
            <LocationIcon fontSize="small" sx={{ color: getLevelColor(node.level), mr: 1.5 }} />
            <Chip size="small" label={`Niv. ${node.level}`} sx={{ mr: 1, height: 20, fontSize: '0.7rem' }} />
            <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600, mr: 2 }}>{node.display_name || node.node_id}</Typography>
            <Typography variant="body2" sx={{ flex: 1 }}>{node.designation}</Typography>
            <Chip size="small" label={objectLevelLabel(node.level)} sx={{ ml: 1, height: 20, fontSize: '0.7rem' }} />
          </Box>
        ))}

        {searchResults.equipment.length > 0 && (
          <>
            <Divider sx={{ my: 1 }} />
            <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1, display: 'flex', alignItems: 'center', gap: 1 }}>
              <EquipmentIcon fontSize="small" sx={{ color: theme.palette.warning.main }} /> Équipements ({searchResults.equipment.length})
            </Typography>
          </>
        )}

        {searchResults.equipment.map((eq: any) => (
          <Box
            key={`search-eq-${eq.equnr}`}
            sx={{ display: 'flex', alignItems: 'center', py: 1, px: 2, cursor: 'pointer', borderRadius: 1, mb: 0.5, backgroundColor: alpha(theme.palette.background.paper, 0.5), '&:hover': { backgroundColor: alpha(theme.palette.warning.main, 0.1) } }}
            onClick={() => selectNode({ ...eq, node_type: 'equipment' } as EquipmentNode)}
          >
            <EquipmentIcon fontSize="small" sx={{ color: theme.palette.warning.main, mr: 1.5 }} />
            <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600, mr: 2, color: theme.palette.warning.dark }}>
              {eq.equnr_short || eq.equnr}
            </Typography>
            <Typography variant="body2" sx={{ flex: 1 }}>{eq.designation}</Typography>
            {eq.poste_technique && <Chip size="small" label={eq.poste_technique} sx={{ ml: 1, height: 20, fontSize: '0.65rem' }} />}
          </Box>
        ))}

        {articles.length > 0 && (
          <>
            <Divider sx={{ my: 1 }} />
            <Typography variant="subtitle2" color="text.secondary" sx={{ mb: 1, display: 'flex', alignItems: 'center', gap: 1 }}>
              <BomIcon fontSize="small" sx={{ color: theme.palette.success.main }} /> Articles ({articles.length})
            </Typography>
          </>
        )}

        {articles.map((art) => renderArticleResult(art))}
      </Box>
    );
  };

  const renderLocationDetails = (node: LocationNode) => {
    const e = editMode;
    const d = editLocationData;
    const v = (key: string) => e ? d[key] : (node as any)[key];

    return (
      <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
        <Box sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
          <Box sx={{ display: 'flex', alignItems: 'flex-start' }}>
            <FolderIcon sx={{ fontSize: 32, color: getLevelColor(node.level), mr: 2, flexShrink: 0 }} />
            <Box sx={{ flex: 1, minWidth: 0 }}>
              <Typography variant="h6" noWrap sx={{ fontFamily: 'monospace' }}>{node.display_name || node.node_id}</Typography>
              <Box sx={{ display: 'flex', gap: 1, mt: 0.5, flexWrap: 'wrap' }}>
                <Chip size="small" label={`Niveau ${[910, 920, 930, 940, 950, 960, 970, 980][Math.min(node.level, 7)]}`} sx={{ backgroundColor: alpha(getLevelColor(node.level), 0.15), color: getLevelColor(node.level) }} />
                <Chip size="small" label={`Type: ${objectLevelLabel(node.level)}`} color="secondary" />
                {node.structure_indicator && <Chip size="small" label={`Struct: ${node.structure_indicator}`} color="info" variant="outlined" />}
                <Chip size="small" label="Poste technique" color="primary" variant="outlined" />
              </Box>
            </Box>
            {!e ? (
              <Box sx={{ display: 'flex', gap: 0.25, flexShrink: 0, flexWrap: 'wrap', justifyContent: 'flex-end' }}>
                <Tooltip title="Ajouter un poste technique enfant">
                  <IconButton size="small" color="success" onClick={openAddLocation}><AddIcon /></IconButton>
                </Tooltip>
                <Tooltip title="Ajouter un équipement">
                  <IconButton size="small" sx={{ color: theme.palette.warning.main }} onClick={openAddEquipment}><EquipmentIcon /></IconButton>
                </Tooltip>
                <Tooltip title="Modifier en masse (noeud + enfants)">
                  <IconButton size="small" color="secondary" onClick={() => openBulkEdit(node)}><BulkEditIcon /></IconButton>
                </Tooltip>
                <Tooltip title="Modifier">
                  <IconButton size="small" color="primary" onClick={() => startEditLocation(node)}><EditIcon /></IconButton>
                </Tooltip>
                <Tooltip title="Supprimer">
                  <IconButton size="small" color="error" onClick={() => openDeleteConfirm('location', node)}><DeleteIcon /></IconButton>
                </Tooltip>
              </Box>
            ) : (
              <Box sx={{ display: 'flex', gap: 1 }}>
                <Button variant="contained" size="small" startIcon={saving ? <CircularProgress size={16} /> : <SaveIcon />} onClick={saveLocation} disabled={saving}>Enregistrer</Button>
                <Button variant="outlined" size="small" startIcon={<CloseIcon />} onClick={cancelEdit} disabled={saving}>Annuler</Button>
              </Box>
            )}
          </Box>
        </Box>
        <Box sx={{ flex: 1, overflow: 'auto', p: 2 }}>
          <Grid container spacing={2}>
            <Grid item xs={12}>
              <Typography variant="subtitle2" sx={{ color: theme.palette.primary.main, fontWeight: 600, mb: 0.5, display: 'flex', alignItems: 'center', gap: 1 }}>
                <InfoIcon fontSize="small" /> Données générales
              </Typography>
              <Divider />
            </Grid>
            <Grid item xs={12}><DetailField label="Désignation" value={v('designation')} editing={e} fieldKey="designation" onFieldChange={onLocationFieldChange} /></Grid>
            <Grid item xs={6}><DetailField label="Type de poste" value={objectLevelLabel(node.level)} /></Grid>
            <Grid item xs={6}><DetailField label="Niveau hiérarchique" value={[910, 920, 930, 940, 950, 960, 970, 980][Math.min(node.level, 7)]} /></Grid>
            <Grid item xs={6}><DetailField label="Identifiant structuré (STRNO)" value={e ? v('code') : (node.display_name || node.node_id)} monospace editing={e} fieldKey="code" onFieldChange={onLocationFieldChange} /></Grid>
            <Grid item xs={6}><DetailField label="Parent" value={e ? v('parent_node_id') : (node.display_parent || node.parent_node_id)} monospace editing={e && node.level > 0} fieldKey="parent_node_id" onFieldChange={onLocationFieldChange} /></Grid>
            <Grid item xs={6}><DetailField label="Art / Type construction" value={v('art_type_construction')} editing={e} fieldKey="art_type_construction" onFieldChange={onLocationFieldChange} /></Grid>
            {(e || (node.quantite && parseFloat(String(node.quantite)) > 0)) && (
              <>
                <Grid item xs={6}><DetailField label="Quantité" value={v('quantite')} editing={e} fieldKey="quantite" onFieldChange={onLocationFieldChange} /></Grid>
                <Grid item xs={6}><DetailField label="Unité" value={v('unite')} editing={e} fieldKey="unite" onFieldChange={onLocationFieldChange} /></Grid>
              </>
            )}
            {!e && node.equipment_count !== undefined && node.equipment_count > 0 && (
              <Grid item xs={6}>
                <Box>
                  <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>Équipements rattachés</Typography>
                  <Chip size="small" icon={<EquipmentIcon sx={{ fontSize: '0.9rem !important' }} />} label={node.equipment_count}
                    sx={{ fontWeight: 600, backgroundColor: alpha(theme.palette.warning.main, 0.1), color: theme.palette.warning.dark }} />
                </Box>
              </Grid>
            )}
            <Grid item xs={12} sx={{ mt: 1 }}>
              <Typography variant="subtitle2" sx={{ color: theme.palette.primary.main, fontWeight: 600, mb: 0.5, display: 'flex', alignItems: 'center', gap: 1 }}>
                <BusinessIcon fontSize="small" /> Organisation
              </Typography>
              <Divider />
            </Grid>
            <Grid item xs={6}><DetailField label="Centre de coûts" value={v('centre_couts')} monospace editing={e} fieldKey="centre_couts" onFieldChange={onLocationFieldChange} /></Grid>
            <Grid item xs={6}>
              {e ? (
                <Autocomplete
                  size="small"
                  options={workCenters}
                  getOptionLabel={(opt) => opt.code + (opt.designation ? ` - ${opt.designation}` : '')}
                  value={workCenters.find((wc) => wc.code === d.poste_travail) || null}
                  onChange={(_, val) => onLocationFieldChange('poste_travail', val?.code || '')}
                  renderInput={(params) => <TextField {...params} label="Poste de travail" />}
                  isOptionEqualToValue={(opt, val) => opt.code === val.code}
                />
              ) : (
                <DetailField label="Poste de travail" value={node.poste_travail ? `${node.poste_travail} - ${node.poste_travail_texte || ''}` : undefined} monospace />
              )}
            </Grid>
            <Grid item xs={6}>
              {e ? (
                <Autocomplete
                  size="small"
                  options={workCenters}
                  getOptionLabel={(opt) => opt.code + (opt.designation ? ` - ${opt.designation}` : '')}
                  value={workCenters.find((wc) => wc.code === d.poste_travail_resp_maintenance) || null}
                  onChange={(_, val) => onLocationFieldChange('poste_travail_resp_maintenance', val?.code || '')}
                  renderInput={(params) => <TextField {...params} label="Poste responsable" />}
                  isOptionEqualToValue={(opt, val) => opt.code === val.code}
                />
              ) : (
                <DetailField label="Poste responsable" value={node.poste_travail_resp_maintenance ? `${node.poste_travail_resp_maintenance} - ${node.poste_resp_texte || ''}` : undefined} monospace />
              )}
            </Grid>
          </Grid>
        </Box>
      </Box>
    );
  };

  const renderEquipmentDetails = (eq: EquipmentDetails) => {
    const e = editMode;
    const d = editEquipmentData;
    const v = (key: string) => e ? d[key] : (eq as any)[key];
    const f = onEquipmentFieldChange;

    return (
      <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
        <Box sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
          <Box sx={{ display: 'flex', alignItems: 'flex-start' }}>
            <EquipmentIcon sx={{ fontSize: 32, color: theme.palette.warning.main, mr: 2, flexShrink: 0 }} />
            <Box sx={{ flex: 1, minWidth: 0 }}>
              <Typography variant="h6" noWrap sx={{ fontFamily: 'monospace' }}>{eq.equnr_short}</Typography>
              <Box sx={{ display: 'flex', gap: 1, mt: 0.5, flexWrap: 'wrap' }}>
                <Chip size="small" label="Équipement" color="warning" />
                {eq.type_equipement && <Chip size="small" label={`Type: ${eq.type_equipement}`} color="secondary" />}
              </Box>
            </Box>
            {!e ? (
              <Box sx={{ display: 'flex', gap: 0.25, flexShrink: 0 }}>
                <Tooltip title="Modifier">
                  <IconButton size="small" color="primary" onClick={() => startEditEquipment(eq)}><EditIcon /></IconButton>
                </Tooltip>
                <Tooltip title="Supprimer">
                  <IconButton size="small" color="error" onClick={() => { if (selectedNode) openDeleteConfirm('equipment', selectedNode); }}><DeleteIcon /></IconButton>
                </Tooltip>
              </Box>
            ) : (
              <Box sx={{ display: 'flex', gap: 1 }}>
                <Button variant="contained" size="small" startIcon={saving ? <CircularProgress size={16} /> : <SaveIcon />} onClick={saveEquipment} disabled={saving}>Enregistrer</Button>
                <Button variant="outlined" size="small" startIcon={<CloseIcon />} onClick={cancelEdit} disabled={saving}>Annuler</Button>
              </Box>
            )}
          </Box>
        </Box>

        <Tabs value={activeTab} onChange={(_, val) => setActiveTab(val)} sx={{ borderBottom: `1px solid ${theme.palette.divider}`, px: 2 }} variant="scrollable" scrollButtons="auto">
          <Tab icon={<InfoIcon />} iconPosition="start" label="Général" />
          <Tab icon={<LocationIcon />} iconPosition="start" label="Localisation" />
          <Tab icon={<BusinessIcon />} iconPosition="start" label="Organisation" />
          <Tab icon={<HandymanIcon />} iconPosition="start" label="Fabrication" />
        </Tabs>

        <Box sx={{ flex: 1, overflow: 'auto', p: 2 }}>
          {activeTab === 0 && (
            <Grid container spacing={2}>
              <Grid item xs={12}><DetailField label="Désignation" value={v('designation')} editing={e} fieldKey="designation" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="N° équipement" value={eq.equnr_short} monospace /></Grid>
              <Grid item xs={6}><DetailField label="Catégorie" value={v('categorie')} editing={e} fieldKey="categorie" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Type" value={v('type_equipement')} editing={e} fieldKey="type_equipement" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="N° inventaire" value={v('numero_inventaire')} monospace editing={e} fieldKey="numero_inventaire" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="N° série" value={v('numero_serie')} monospace editing={e} fieldKey="numero_serie" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="N° article" value={v('numero_article')} monospace editing={e} fieldKey="numero_article" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Date mise en service" value={v('date_mise_service')} editing={e} fieldKey="date_mise_service" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Plan de maintenance" value={v('plan_maintenance')} editing={e} fieldKey="plan_maintenance" onFieldChange={f} /></Grid>
              {!e && (
                <>
                  <Grid item xs={12} sx={{ mt: 1 }}><Divider /></Grid>
                  <Grid item xs={6}><DetailField label="Date création" value={eq.date_creation} /></Grid>
                  <Grid item xs={6}><DetailField label="Créé par" value={eq.cree_par} /></Grid>
                  <Grid item xs={6}><DetailField label="Date modification" value={eq.date_modification} /></Grid>
                  <Grid item xs={6}><DetailField label="Modifié par" value={eq.modifie_par} /></Grid>
                </>
              )}
            </Grid>
          )}

          {activeTab === 1 && (
            <Grid container spacing={2}>
              <Grid item xs={12}><DetailField label="Poste technique" value={eq.poste_technique} monospace /></Grid>
              <Grid item xs={6}><DetailField label="Division" value={v('division')} editing={e} fieldKey="division" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Emplacement" value={v('emplacement')} editing={e} fieldKey="emplacement" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Section" value={v('section')} editing={e} fieldKey="section" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Division maintenance" value={v('division_maintenance')} editing={e} fieldKey="division_maintenance" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Groupe planification" value={v('groupe_planification')} editing={e} fieldKey="groupe_planification" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Équipement supérieur" value={eq.equipement_superieur} monospace /></Grid>
              <Grid item xs={12} sx={{ mt: 1 }}><Divider /></Grid>
              <Grid item xs={6}><DetailField label="Poste de travail" value={eq.arbpl} monospace /></Grid>
              <Grid item xs={6}><DetailField label="Désignation poste de travail" value={eq.poste_travail_texte} /></Grid>
              <Grid item xs={6}><DetailField label="Poste responsable" value={eq.arbpl ? `${eq.arbpl} - ${eq.poste_travail_texte || ''}` : undefined} monospace /></Grid>
            </Grid>
          )}

          {activeTab === 2 && (
            <Grid container spacing={2}>
              <Grid item xs={6}><DetailField label="Société" value={v('societe')} editing={e} fieldKey="societe" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Centre de coûts" value={v('centre_couts')} monospace editing={e} fieldKey="centre_couts" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Domaine d'activité" value={v('domaine_activite')} editing={e} fieldKey="domaine_activite" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Fournisseur" value={v('fournisseur')} editing={e} fieldKey="fournisseur" onFieldChange={f} /></Grid>
              <Grid item xs={12} sx={{ mt: 1 }}><Divider /></Grid>
              <Grid item xs={6}><DetailField label="Valeur acquisition" value={v('valeur_acquisition')} editing={e} fieldKey="valeur_acquisition" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Devise" value={v('devise')} editing={e} fieldKey="devise" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Date acquisition" value={v('date_acquisition')} editing={e} fieldKey="date_acquisition" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Durée garantie" value={eq.duree_garantie} /></Grid>
              <Grid item xs={6}><DetailField label="Fin garantie" value={eq.fin_garantie} /></Grid>
            </Grid>
          )}

          {activeTab === 3 && (
            <Grid container spacing={2}>
              <Grid item xs={6}><DetailField label="Fabricant" value={v('fabricant')} editing={e} fieldKey="fabricant" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Pays fabricant" value={v('pays_fabricant')} editing={e} fieldKey="pays_fabricant" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Modèle" value={v('modele')} editing={e} fieldKey="modele" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Taille / Dimensions" value={v('taille')} editing={e} fieldKey="taille" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Poids" value={v('poids')} editing={e} fieldKey="poids" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Unité poids" value={v('unite_poids')} editing={e} fieldKey="unite_poids" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Année construction" value={v('annee_construction')} editing={e} fieldKey="annee_construction" onFieldChange={f} /></Grid>
              <Grid item xs={6}><DetailField label="Mois construction" value={v('mois_construction')} editing={e} fieldKey="mois_construction" onFieldChange={f} /></Grid>
            </Grid>
          )}
        </Box>
      </Box>
    );
  };

  const renderBomDetails = (sel: SelectedBom) => {
    const e = editMode;
    const d = editBomData;
    const comp = sel.comp;
    const v = (key: string) => e ? d[key] : (comp as any)[key];

    return (
      <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
        <Box sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
          <Box sx={{ display: 'flex', alignItems: 'center' }}>
            <BomIcon sx={{ fontSize: 32, color: theme.palette.success.main, mr: 2 }} />
            <Box sx={{ flex: 1 }}>
              <Typography variant="h6" sx={{ fontFamily: 'monospace' }}>{comp.matnr_short || comp.idnrk}</Typography>
              <Box sx={{ display: 'flex', gap: 1, mt: 0.5 }}>
                <Chip size="small" label="Composant de nomenclature" color="success" variant="outlined" />
                {comp.item_category && <Chip size="small" label={`Cat: ${comp.item_category}`} color="info" variant="outlined" />}
              </Box>
            </Box>
            {!e ? (
              <Tooltip title="Modifier">
                <IconButton color="primary" onClick={() => startEditBom(sel)}><EditIcon /></IconButton>
              </Tooltip>
            ) : (
              <Box sx={{ display: 'flex', gap: 1 }}>
                <Button variant="contained" size="small" startIcon={saving ? <CircularProgress size={16} /> : <SaveIcon />} onClick={saveBom} disabled={saving}>Enregistrer</Button>
                <Button variant="outlined" size="small" startIcon={<CloseIcon />} onClick={() => { setEditMode(false); setEditBomData({}); }} disabled={saving}>Annuler</Button>
              </Box>
            )}
          </Box>
        </Box>

        <Box sx={{ flex: 1, overflow: 'auto', p: 2 }}>
          <Grid container spacing={2}>
            {/* Fiche article (partagée) — lecture seule */}
            <Grid item xs={12}>
              <Typography variant="subtitle2" sx={{ color: theme.palette.text.secondary, fontWeight: 600, mb: 0.5, display: 'flex', alignItems: 'center', gap: 1 }}>
                <InfoIcon fontSize="small" /> Article (fiche partagée — lecture seule)
              </Typography>
              <Divider />
            </Grid>
            <Grid item xs={6}>
              <DetailField
                label={e ? 'Code article (⚠ partagé — s\'applique partout)' : 'Code article'}
                value={e ? d['article_code'] : (comp.matnr_short || comp.idnrk)}
                monospace
                editing={e}
                fieldKey="article_code"
                onFieldChange={onBomFieldChange}
              />
            </Grid>
            <Grid item xs={6}><DetailField label="Type matière" value={comp.material_type} /></Grid>
            <Grid item xs={12}><DetailField label="Désignation article" value={comp.designation} /></Grid>

            {/* Ligne de nomenclature — éditable */}
            <Grid item xs={12} sx={{ mt: 1 }}>
              <Typography variant="subtitle2" sx={{ color: theme.palette.primary.main, fontWeight: 600, mb: 0.5, display: 'flex', alignItems: 'center', gap: 1 }}>
                <BomIcon fontSize="small" /> Ligne de nomenclature (cette occurrence)
              </Typography>
              <Divider />
            </Grid>

            <Grid item xs={12}>
              {e ? (
                <Autocomplete
                  size="small"
                  freeSolo
                  options={editBomArticleSuggestions}
                  filterOptions={(x) => x}
                  getOptionLabel={(opt: any) => typeof opt === 'string' ? opt : `${opt.matnr_short} - ${opt.designation || ''}`}
                  inputValue={editBomArticleQuery}
                  onInputChange={(_, val, reason) => { setEditBomArticleQuery(val); if (reason === 'input') onBomFieldChange('idnrk', val); }}
                  onChange={(_, val: any) => {
                    if (val && typeof val !== 'string') {
                      const code = val.matnr_short || val.matnr;
                      onBomFieldChange('idnrk', code);
                      setEditBomArticleQuery(code);
                      if (val.meins) onBomFieldChange('unit', val.meins);
                    }
                  }}
                  loading={editBomArticleLoading}
                  renderInput={(params) => <TextField {...params} label="Article (composant)" helperText="Change l'article pointé par cette ligne" />}
                />
              ) : (
                <DetailField label="Article (composant)" value={comp.matnr_short || comp.idnrk} monospace />
              )}
            </Grid>
            <Grid item xs={6}><DetailField label="Quantité" value={v('quantity')} editing={e} fieldKey="quantity" onFieldChange={onBomFieldChange} /></Grid>
            <Grid item xs={6}><DetailField label="Unité" value={v('unit')} editing={e} fieldKey="unit" onFieldChange={onBomFieldChange} /></Grid>
            <Grid item xs={6}><DetailField label="Catégorie (postp)" value={e ? v('category') : comp.item_category} editing={e} fieldKey="category" onFieldChange={onBomFieldChange} /></Grid>
            <Grid item xs={6}><DetailField label="Position (posnr)" value={e ? v('posnr') : comp.posnr} monospace editing={e} fieldKey="posnr" onFieldChange={onBomFieldChange} /></Grid>
            <Grid item xs={12}><DetailField label="Texte composant 1" value={v('potx1')} editing={e} fieldKey="potx1" onFieldChange={onBomFieldChange} /></Grid>
            <Grid item xs={12}><DetailField label="Texte composant 2" value={v('potx2')} editing={e} fieldKey="potx2" onFieldChange={onBomFieldChange} /></Grid>

            {!e && (
              <>
                <Grid item xs={12} sx={{ mt: 1 }}><Divider /></Grid>
                <Grid item xs={4}><DetailField label="N° nomenclature (stlnr)" value={comp.stlnr} monospace /></Grid>
                <Grid item xs={4}><DetailField label="Position interne (stlkn)" value={comp.stlkn} monospace /></Grid>
                <Grid item xs={4}><DetailField label="Alternative (stlal)" value={comp.stlal} monospace /></Grid>
              </>
            )}
          </Grid>
        </Box>
      </Box>
    );
  };

  const renderDetailsPanel = () => {
    if (selectedBom) {
      return renderBomDetails(selectedBom);
    }
    if (!selectedNode) {
      return (
        <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', color: 'text.secondary' }}>
          <TreeIcon sx={{ fontSize: 64, mb: 2, opacity: 0.3 }} />
          <Typography variant="body1">Sélectionnez un élément pour voir ses détails</Typography>
        </Box>
      );
    }
    if (detailsLoading) {
      return <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100%' }}><CircularProgress /></Box>;
    }

    if (selectedNode && isEquipment(selectedNode) && detailedEquipment) {
      return renderEquipmentDetails(detailedEquipment);
    }
    if (selectedNode && isLocation(selectedNode) && detailedLocation) {
      return renderLocationDetails(detailedLocation);
    }
    return null;
  };

  return (
    <Box sx={{ p: 3, height: 'calc(100vh - 64px)', display: 'flex', flexDirection: 'column' }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
        <EngineeringIcon sx={{ fontSize: 32, mr: 2, color: theme.palette.primary.main }} />
        <Box sx={{ flex: 1 }}>
          <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
            Arborescence des Postes Techniques
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Postes techniques, équipements et nomenclatures
          </Typography>
        </Box>
        <Button
          variant="outlined"
          size="small"
          startIcon={exporting ? <CircularProgress size={16} /> : <DownloadIcon />}
          onClick={(e) => setExportAnchorEl(e.currentTarget)}
          disabled={exporting}
          sx={{ mr: 1 }}
        >
          Export CSV
        </Button>
        <Menu
          anchorEl={exportAnchorEl}
          open={Boolean(exportAnchorEl)}
          onClose={() => setExportAnchorEl(null)}
        >
          <MenuItem onClick={() => handleExport('structures')}>
            <ListItemIcon><FolderIcon fontSize="small" color="primary" /></ListItemIcon>
            <ListItemText>Postes techniques (structures)</ListItemText>
          </MenuItem>
          <MenuItem onClick={() => handleExport('equipment')}>
            <ListItemIcon><EquipmentIcon fontSize="small" color="warning" /></ListItemIcon>
            <ListItemText>Équipements</ListItemText>
          </MenuItem>
        </Menu>
        <MaintenanceActions
          onRefresh={() => { loadRootNodes(); loadStats(); }}
          onJobStarted={(job) => setTrackedJobId(job.id)}
          jobActive={jobActive}
          loading={loading}
        />
      </Box>

      <MaintenanceJobBanner
        jobId={trackedJobId}
        onFinished={handleJobFinished}
        onActiveChange={setJobActive}
      />

      {stats && (
        <Box sx={{ display: 'flex', gap: 2, mb: 2, flexWrap: 'wrap' }}>
          <Chip label={`${Number(stats.total_nodes).toLocaleString()} postes techniques`} color="primary" variant="outlined" />
          <Chip label={`${stats.distinct_types} types`} color="secondary" variant="outlined" />
          <Chip label={`${stats.distinct_cost_centers} centres de coûts`} variant="outlined" />
        </Box>
      )}

      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <Box sx={{ display: 'flex', gap: 3, flex: 1, minHeight: 0 }}>
        <Paper elevation={0} sx={{ flex: 2, display: 'flex', flexDirection: 'column', border: `1px solid ${theme.palette.divider}`, borderRadius: 2, overflow: 'hidden' }}>
          <Box sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
            <TextField
              fullWidth size="small"
              placeholder="Rechercher un poste technique, un équipement ou un article..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              InputProps={{ startAdornment: <InputAdornment position="start">{searchLoading ? <CircularProgress size={20} /> : <SearchIcon />}</InputAdornment> }}
            />
          </Box>
          <Box sx={{ flex: 1, overflow: 'auto', p: 1 }}>
            {loading ? (
              <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}><CircularProgress /></Box>
            ) : searchQuery.length >= 2 ? renderSearchResults() : rootNodes.map((node) => renderTreeNode(node))}
          </Box>
        </Paper>

        <Paper elevation={0} sx={{ flex: 1, minWidth: 400, border: `1px solid ${theme.palette.divider}`, borderRadius: 2, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
          {renderDetailsPanel()}
        </Paper>
      </Box>

      {/* Confirmation drag & drop */}
      <Dialog open={!!pendingDrop} onClose={() => setPendingDrop(null)}>
        <DialogTitle>Confirmer le déplacement</DialogTitle>
        <DialogContent>
          <Typography>
            Déplacer <strong>{pendingDrop?.source.node_id}</strong> sous <strong>{pendingDrop?.target.node_id}</strong> ?
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
            Le nœud et tous ses enfants seront déplacés.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPendingDrop(null)} disabled={dropConfirmLoading}>Annuler</Button>
          <Button onClick={confirmDrop} variant="contained" disabled={dropConfirmLoading}
            startIcon={dropConfirmLoading ? <CircularProgress size={16} /> : undefined}>
            Confirmer
          </Button>
        </DialogActions>
      </Dialog>

      {/* Confirmation deplacement d'une ligne de nomenclature */}
      <Dialog open={!!pendingBomDrop} onClose={() => setPendingBomDrop(null)}>
        <DialogTitle>Confirmer le déplacement</DialogTitle>
        <DialogContent>
          <Typography>
            Déplacer l'article <strong>{pendingBomDrop?.drag.label}</strong> sous{' '}
            <strong>{pendingBomDrop?.targetLabel}</strong> ?
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
            {pendingBomDrop?.targetType === 'FUNC_LOC'
              ? 'La ligne rejoint la nomenclature de ce poste technique.'
              : 'La ligne rejoint la nomenclature matière de cet article.'}
            {' '}La fiche article, partagée avec ses autres emplacements, n'est pas modifiée.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPendingBomDrop(null)} disabled={dropConfirmLoading}>Annuler</Button>
          <Button onClick={confirmBomDrop} variant="contained" disabled={dropConfirmLoading}
            startIcon={dropConfirmLoading ? <CircularProgress size={16} /> : undefined}>
            Confirmer
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={bulkDialogOpen} onClose={() => setBulkDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <BulkEditIcon color="secondary" />
          Modification en masse
          {selectedNode && isLocation(selectedNode) && (
            <Chip size="small" label={selectedNode.node_id} sx={{ ml: 1, fontFamily: 'monospace' }} />
          )}
          {bulkCount > 0 && (
            <Chip size="small" label={`${bulkCount} noeud(s)`} color="info" variant="outlined" sx={{ ml: 'auto' }} />
          )}
        </DialogTitle>
        <DialogContent dividers>
          <Box sx={{ display: 'flex', gap: 1, mb: 2, alignItems: 'flex-end' }}>
            <FormControl size="small" sx={{ minWidth: 200 }}>
              <InputLabel>Champ</InputLabel>
              <Select
                value={bulkField}
                label="Champ"
                onChange={(e: SelectChangeEvent) => setBulkField(e.target.value)}
              >
                {BULK_FIELDS.filter((f) => !bulkEdits.some((be) => be.field === f.key)).map((f) => (
                  <MenuItem key={f.key} value={f.key}>{f.label}</MenuItem>
                ))}
              </Select>
            </FormControl>
            <TextField
              size="small"
              label="Nouvelle valeur"
              value={bulkValue}
              onChange={(e) => setBulkValue(e.target.value)}
              sx={{ flex: 1 }}
            />
            <IconButton color="primary" onClick={addBulkEdit} disabled={!bulkField}>
              <AddIcon />
            </IconButton>
          </Box>

          {bulkEdits.length > 0 && (
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell sx={{ fontWeight: 600 }}>Champ</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Nouvelle valeur</TableCell>
                  <TableCell width={40} />
                </TableRow>
              </TableHead>
              <TableBody>
                {bulkEdits.map((edit) => (
                  <TableRow key={edit.field}>
                    <TableCell>{edit.label}</TableCell>
                    <TableCell sx={{ fontFamily: 'monospace' }}>{edit.value || <Typography variant="caption" color="text.secondary">(vider)</Typography>}</TableCell>
                    <TableCell>
                      <IconButton size="small" color="error" onClick={() => removeBulkEdit(edit.field)}>
                        <DeleteIcon fontSize="small" />
                      </IconButton>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}

          {bulkEdits.length === 0 && (
            <Alert severity="info" sx={{ mt: 1 }}>Ajoutez au moins un champ à modifier.</Alert>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setBulkDialogOpen(false)} disabled={bulkSaving}>Annuler</Button>
          <Button
            variant="contained"
            color="secondary"
            onClick={applyBulkEdit}
            disabled={bulkEdits.length === 0 || bulkSaving}
            startIcon={bulkSaving ? <CircularProgress size={16} /> : <SaveIcon />}
          >
            Appliquer sur {bulkCount} noeud(s)
          </Button>
        </DialogActions>
      </Dialog>

      {/* Dialog ajout poste technique / équipement */}
      <Dialog open={addDialogOpen} onClose={() => setAddDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          {addDialogType === 'location' ? <FolderIcon color="primary" /> : <EquipmentIcon sx={{ color: theme.palette.warning.main }} />}
          {addDialogType === 'location' ? 'Ajouter un poste technique' : 'Ajouter un équipement'}
          {selectedNode && isLocation(selectedNode) && (
            <Chip size="small" label={`sous ${selectedNode.node_id}`} sx={{ ml: 1, fontFamily: 'monospace' }} />
          )}
        </DialogTitle>
        <DialogContent dividers>
          {addDialogType === 'location' ? (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
              <TextField label="Identifiant *" size="small" value={addNodeData.node_id}
                onChange={(e) => setAddNodeData((p) => ({ ...p, node_id: e.target.value }))} placeholder="Ex: T130-H" />
              <TextField label="Désignation *" size="small" value={addNodeData.designation}
                onChange={(e) => setAddNodeData((p) => ({ ...p, designation: e.target.value }))} />
              <TextField label="Type de poste (automatique)" size="small" disabled
                value={selectedNode && isLocation(selectedNode) ? objectLevelLabel(selectedNode.level + 1) : ''}
                helperText="Déterminé par le niveau dans la hiérarchie" />
              <TextField label="Centre de coûts" size="small" value={addNodeData.centre_couts}
                onChange={(e) => setAddNodeData((p) => ({ ...p, centre_couts: e.target.value }))} />
            </Box>
          ) : (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
              <Autocomplete
                freeSolo
                size="small"
                options={equipmentSuggestions}
                loading={equipmentSearchLoading}
                value={addEquipmentData.equnr}
                getOptionLabel={(opt: any) =>
                  typeof opt === 'string' ? opt : `${opt.equnr_short || opt.equnr} — ${opt.designation || ''}`
                }
                filterOptions={(x) => x}
                onInputChange={(_, value) => {
                  setEquipmentSearchQuery(value);
                  setAddEquipmentData((p) => ({ ...p, equnr: value }));
                }}
                onChange={(_, value: any) => {
                  if (value && typeof value === 'object') {
                    setAddEquipmentData({
                      equnr: value.equnr_short || value.equnr || '',
                      designation: value.designation || '',
                      eqart: value.eqart || '',
                      herst: value.herst || '',
                      typbz: value.typbz || '',
                      matnr: value.matnr || '',
                      sernr: '',
                    });
                  }
                }}
                renderOption={(props, opt: any) => (
                  <li {...props} key={opt.equnr}>
                    <Box>
                      <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600 }}>
                        {opt.equnr_short || opt.equnr}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {opt.designation}
                      </Typography>
                    </Box>
                  </li>
                )}
                renderInput={(params) => (
                  <TextField
                    {...params}
                    label="Numéro équipement"
                    placeholder="Rechercher par n° ou désignation..."
                    InputProps={{
                      ...params.InputProps,
                      endAdornment: (
                        <>
                          {equipmentSearchLoading ? <CircularProgress size={16} /> : null}
                          {params.InputProps.endAdornment}
                        </>
                      ),
                    }}
                  />
                )}
              />
              <TextField label="Désignation *" size="small" value={addEquipmentData.designation}
                onChange={(e) => setAddEquipmentData((p) => ({ ...p, designation: e.target.value }))} />
              <TextField label="Type d'équipement" size="small" value={addEquipmentData.eqart}
                onChange={(e) => setAddEquipmentData((p) => ({ ...p, eqart: e.target.value }))} />
              <TextField label="Fabricant" size="small" value={addEquipmentData.herst}
                onChange={(e) => setAddEquipmentData((p) => ({ ...p, herst: e.target.value }))} />
              <TextField label="Modèle" size="small" value={addEquipmentData.typbz}
                onChange={(e) => setAddEquipmentData((p) => ({ ...p, typbz: e.target.value }))} />
              <Autocomplete
                freeSolo
                size="small"
                options={articleSuggestions}
                loading={articleSearchLoading}
                value={addEquipmentData.matnr}
                getOptionLabel={(opt: any) =>
                  typeof opt === 'string' ? opt : `${opt.matnr_short || opt.matnr} — ${opt.designation || ''}`
                }
                filterOptions={(x) => x}
                onInputChange={(_, value) => {
                  setArticleSearchQuery(value);
                  setAddEquipmentData((p) => ({ ...p, matnr: value }));
                }}
                onChange={(_, value: any) => {
                  if (value && typeof value === 'object') {
                    setAddEquipmentData((p) => ({
                      ...p,
                      matnr: value.matnr_short || value.matnr || '',
                      typbz: p.typbz || value.designation || '',
                    }));
                  }
                }}
                renderOption={(props, opt: any) => (
                  <li {...props} key={opt.matnr}>
                    <Box>
                      <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600 }}>
                        {opt.matnr_short || opt.matnr}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {opt.designation} {opt.mtart ? `· ${opt.mtart}` : ''} {opt.meins ? `· ${opt.meins}` : ''}
                      </Typography>
                    </Box>
                  </li>
                )}
                renderInput={(params) => (
                  <TextField
                    {...params}
                    label="Numéro article"
                    placeholder="Rechercher un article..."
                    InputProps={{
                      ...params.InputProps,
                      endAdornment: (
                        <>
                          {articleSearchLoading ? <CircularProgress size={16} /> : null}
                          {params.InputProps.endAdornment}
                        </>
                      ),
                    }}
                  />
                )}
              />
              <TextField label="Numéro de série" size="small" value={addEquipmentData.sernr}
                onChange={(e) => setAddEquipmentData((p) => ({ ...p, sernr: e.target.value }))} />
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setAddDialogOpen(false)} disabled={addSaving}>Annuler</Button>
          <Button variant="contained" onClick={confirmAddNode} disabled={addSaving}
            startIcon={addSaving ? <CircularProgress size={16} /> : <AddIcon />}>
            Créer
          </Button>
        </DialogActions>
      </Dialog>

      {/* Dialog confirmation suppression */}
      <Dialog open={deleteConfirmOpen} onClose={() => { setDeleteConfirmOpen(false); setDeleteTarget(null); }}>
        <DialogTitle sx={{ color: theme.palette.error.main }}>Confirmer la suppression</DialogTitle>
        <DialogContent>
          {deleteTarget && (
            <>
              <Typography>
                Supprimer <strong>
                  {deleteTarget.type === 'location'
                    ? (deleteTarget.node as LocationNode).node_id
                    : (deleteTarget.node as EquipmentNode).equnr_short}
                </strong> ?
              </Typography>
              <Alert severity="warning" sx={{ mt: 2 }}>
                {deleteTarget.type === 'location'
                  ? 'Le poste technique et TOUS ses descendants seront définitivement supprimés.'
                  : 'L\'équipement et tous ses sous-équipements seront supprimés.'}
              </Alert>
            </>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => { setDeleteConfirmOpen(false); setDeleteTarget(null); }} disabled={deleteSaving}>Annuler</Button>
          <Button variant="contained" color="error" onClick={confirmDelete} disabled={deleteSaving}
            startIcon={deleteSaving ? <CircularProgress size={16} /> : <DeleteIcon />}>
            Supprimer
          </Button>
        </DialogActions>
      </Dialog>


      <Snackbar open={snackbar.open} autoHideDuration={4000} onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}>
        <Alert severity={snackbar.severity} onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}>{snackbar.message}</Alert>
      </Snackbar>
    </Box>
  );
};

export default IH02HierarchyPage;
