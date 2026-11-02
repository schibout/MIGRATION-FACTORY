import {
  Add as AddIcon,
  Close as CloseIcon,
  DeleteOutline as DeleteIcon,
  FileDownload as ExcelIcon,
  Groups as ResourceIcon,
  Refresh as RecalcIcon,
  Save as SaveIcon,
  Search as SearchIcon,
  UploadFile as ImportIcon,
  ViewColumn as ColumnsIcon,
  WarningAmber as WarningIcon,
} from '@mui/icons-material';
import {
  Alert,
  Badge,
  Box,
  Button,
  Checkbox,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  Drawer,
  IconButton,
  InputAdornment,
  LinearProgress,
  ListItemText,
  ListSubheader,
  Menu,
  MenuItem,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TablePagination,
  TableRow,
  TableSortLabel,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { FacetteAuto, FacetValue, nb, RepartitionBar, telecharger } from '../../components/data/facettes';
import api from '../../services/api';

// Écran Ressources > Détail des ressources, sur le modèle de Maintenance > Équipements.
// API backend/api/resource_detail_file.py : on modifie la SOURCE raw_data.resource_detail_file,
// « Recalculer » recharge clean_data (tout le module ressources).

type Row = Record<string, any>;
type FacetKey = 'type' | 'personne' | 'site' | 'societe' | 'calendrier' | 'origine';
type Filters = Partial<Record<FacetKey, string[]>>;
interface Champ { col: string; label: string; theme: string; type: 'bool' | 'num' | 'txt' }
interface FacetsResponse {
  facettes: Record<FacetKey, { titre: string; valeurs: FacetValue[] }>;
  total: number;
  total_general: number;
  anomalies: { cle: string; libelle: string; nb: number }[];
  anomalies_total: number;
  a_recalculer: number;
  champs: Champ[];
  types_ressource: string[];
}

// Colonnes calculées (lecture seule) ajoutées aux champs saisissables renvoyés par l'API
const CALCULEES: Champ[] = [
  { col: 'resource_seq', label: 'N° séquence', theme: 'Identification', type: 'num' },
  { col: 'resource_id_ifs', label: 'Identifiant IFS (calculé)', theme: 'Identification', type: 'txt' },
  { col: 'personne', label: 'Personne IFS', theme: 'Identification', type: 'txt' },
];
const PRESETS: Record<string, string[]> = {
  Essentiel: ['resource_seq', 'resource_id', 'resource_id_ifs', 'description', 'resource_type_db', 'personne', 'sites', 'calendar_id'],
  Utilisation: ['resource_seq', 'resource_id', 'description', 'used_in_maintenance_db', 'used_in_manufacturing_db',
    'used_in_projects_db', 'used_in_service_db', 'ignore_scheduling_resource'],
  Planification: ['resource_seq', 'resource_id', 'description', 'calendar_id', 'use_shift_pattern_db', 'use_hr_schedule_db', 'utilization'],
};

const TYPE_COULEURS: Record<string, string> = { PERSON: '#1976d2', PERSON_GROUP: '#00897b', EQUIPMENT: '#ef6c00' };
const PERSONNE_COULEURS: Record<string, string> = { TROUVEE: '#2e7d32', NON_TROUVEE: '#c62828', SANS_OBJET: '#cfd8dc' };
const TYPE_LIBELLES: Record<string, string> = { PERSON: 'Personne', PERSON_GROUP: 'Groupe de personnes', EQUIPMENT: 'Équipement' };

const COLS_KEY = 'ressources.colonnes.v1';
const lireColonnes = (): string[] => {
  try {
    const v = JSON.parse(localStorage.getItem(COLS_KEY) || 'null');
    if (Array.isArray(v) && v.length) return v;
  } catch { /* stockage indisponible */ }
  return PRESETS.Essentiel;
};

const message = (e: any, defaut: string) => e?.response?.data?.error ?? e?.response?.data?.message ?? defaut;

const Cellule: React.FC<{ champ: Champ; row: Row }> = ({ champ, row }) => {
  const v = row[champ.col];
  if (champ.col === 'personne') {
    if (v === 'SANS_OBJET') return <Typography variant="body2" color="text.disabled">—</Typography>;
    return <Chip size="small" variant="outlined" color={v === 'TROUVEE' ? 'success' : 'error'}
      label={v === 'TROUVEE' ? 'Trouvée' : 'Non trouvée'} sx={{ height: 20, fontSize: '0.7rem' }} />;
  }
  if (champ.col === 'resource_type_db' && v) {
    return <Chip size="small" label={TYPE_LIBELLES[v] ?? v} sx={{ bgcolor: TYPE_COULEURS[v] ?? '#bdbdbd', color: '#fff', height: 22 }} />;
  }
  if (v === null || v === undefined || v === '') return <Typography variant="body2" color="text.disabled">—</Typography>;
  if (champ.type === 'bool') {
    return <Chip size="small" variant="outlined" label={v === 'TRUE' ? 'Oui' : 'Non'} color={v === 'TRUE' ? 'primary' : 'default'}
      sx={{ height: 20, fontSize: '0.7rem' }} />;
  }
  const mono = ['resource_seq', 'resource_id', 'resource_id_ifs', 'origin_key1'].includes(champ.col);
  return (
    <Typography variant="body2" noWrap sx={{ maxWidth: 320, fontFamily: mono ? 'monospace' : undefined,
      fontWeight: champ.col === 'resource_id' ? 600 : undefined }}>{v}</Typography>
  );
};

// ---------------------------------------------------------------------------
// Fiche ressource (tiroir) : modification, création (seq = null) et suppression
// ---------------------------------------------------------------------------
const FicheRessource: React.FC<{
  ouverte: boolean; row: Row | null; champs: Champ[]; types: string[]; anomalies: Record<string, string>;
  onClose: () => void; onSaved: () => void;
}> = ({ ouverte, row, champs, types, anomalies, onClose, onSaved }) => {
  const [valeurs, setValeurs] = useState<Row>({});
  const [erreur, setErreur] = useState<string | null>(null);
  const [enCours, setEnCours] = useState(false);
  const [confirmation, setConfirmation] = useState(false);
  const creation = !row;

  useEffect(() => {
    if (!ouverte) return;
    const init: Row = {};
    champs.forEach((c) => { init[c.col] = row?.[c.col] ?? ''; });
    if (!row) Object.assign(init, { resource_type_db: 'PERSON', used_in_maintenance_db: 'TRUE', used_in_manufacturing_db: 'FALSE',
      used_in_projects_db: 'FALSE', used_in_service_db: 'FALSE', use_shift_pattern_db: 'FALSE', ignore_scheduling_resource: 'FALSE',
      calendar_id: '*', companies: 'TRIMET', sites: 'SJ' });
    setValeurs(init);
    setErreur(null);
    setConfirmation(false);
  }, [ouverte, row, champs]);

  const modifiees = useMemo(() => {
    const out: Row = {};
    champs.forEach((c) => {
      const avant = row?.[c.col] ?? '';
      if (creation || String(valeurs[c.col] ?? '') !== String(avant)) out[c.col] = valeurs[c.col];
    });
    return out;
  }, [valeurs, row, champs, creation]);

  const enregistrer = async () => {
    setEnCours(true);
    setErreur(null);
    try {
      if (creation) await api.post('/resource-detail-file', modifiees);
      else await api.put(`/resource-detail-file/${row!.resource_seq}`, modifiees);
      onSaved();
      onClose();
    } catch (e) {
      setErreur(message(e, 'Enregistrement impossible'));
    } finally {
      setEnCours(false);
    }
  };

  const supprimer = async () => {
    setEnCours(true);
    try {
      await api.delete(`/resource-detail-file/${row!.resource_seq}`);
      onSaved();
      onClose();
    } catch (e) {
      setErreur(message(e, 'Suppression impossible'));
      setConfirmation(false);
    } finally {
      setEnCours(false);
    }
  };

  const themes = Array.from(new Set(champs.map((c) => c.theme)));
  const saisie = (c: Champ) => {
    const commun = {
      size: 'small' as const, fullWidth: true, label: c.label, value: valeurs[c.col] ?? '',
      onChange: (e: React.ChangeEvent<HTMLInputElement>) => setValeurs((v) => ({ ...v, [c.col]: e.target.value })),
    };
    if (c.type === 'bool') {
      return (
        <TextField {...commun} select>
          <MenuItem value=""><em>(vide)</em></MenuItem>
          <MenuItem value="TRUE">Oui (TRUE)</MenuItem>
          <MenuItem value="FALSE">Non (FALSE)</MenuItem>
        </TextField>
      );
    }
    if (c.col === 'resource_type_db') {
      return (
        <TextField {...commun} select required>
          {types.map((t) => <MenuItem key={t} value={t}>{TYPE_LIBELLES[t] ?? t} ({t})</MenuItem>)}
        </TextField>
      );
    }
    return <TextField {...commun} required={c.col === 'resource_id'} type={c.type === 'num' ? 'number' : 'text'}
      multiline={c.col === 'note' || c.col === 'description'} />;
  };

  return (
    <Drawer anchor="right" open={ouverte} onClose={onClose} PaperProps={{ sx: { width: { xs: '100%', sm: 620 } } }}>
      <Box sx={{ p: 2.5, color: '#fff', background: `linear-gradient(135deg, ${TYPE_COULEURS[valeurs.resource_type_db] ?? '#546e7a'} 0%, #263238 100%)` }}>
        <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
          <Box>
            <Typography variant="overline" sx={{ opacity: 0.85 }}>
              {creation ? 'Nouvelle ressource' : `Ressource n° ${row!.resource_seq}`}
            </Typography>
            <Typography variant="h5" sx={{ fontFamily: 'monospace', fontWeight: 700 }}>{valeurs.resource_id || '—'}</Typography>
            <Typography variant="body1">{valeurs.description}</Typography>
          </Box>
          <IconButton onClick={onClose} sx={{ color: '#fff' }}><CloseIcon /></IconButton>
        </Stack>
        {row && (
          <Stack direction="row" spacing={1} sx={{ mt: 1.5, flexWrap: 'wrap', rowGap: 1 }}>
            <Chip size="small" label={`Identifiant IFS : ${row.resource_id_ifs ?? '—'}`} sx={{ bgcolor: 'rgba(255,255,255,.25)', color: '#fff' }} />
            {row.source_file && <Chip size="small" label={`Source : ${row.source_file}`} sx={{ bgcolor: 'rgba(0,0,0,.25)', color: '#fff' }} />}
          </Stack>
        )}
      </Box>

      <Box sx={{ p: 2.5, flex: 1, overflowY: 'auto' }}>
        {row?.anomalies?.length > 0 && (
          <Alert severity="warning" icon={<WarningIcon />} sx={{ mb: 2 }}>
            {row!.anomalies.map((k: string) => anomalies[k] ?? k).join(' · ')}
          </Alert>
        )}
        {erreur && <Alert severity="error" sx={{ mb: 2 }}>{erreur}</Alert>}
        {themes.map((t, i) => (
          <Box key={t}>
            {i > 0 && <Divider sx={{ my: 1.5 }} />}
            <Typography variant="overline" color="primary">{t}</Typography>
            <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' }, gap: 1.5, mt: 0.5 }}>
              {champs.filter((c) => c.theme === t).map((c) => (
                <Box key={c.col} sx={{ gridColumn: c.col === 'description' || c.col === 'note' ? '1 / -1' : undefined }}>{saisie(c)}</Box>
              ))}
            </Box>
          </Box>
        ))}
        <Alert severity="info" sx={{ mt: 2 }}>
          Les modifications sont enregistrées dans le fichier source ; elles atteignent les tables IFS après « Recalculer ».
        </Alert>
      </Box>

      <Stack direction="row" spacing={1} sx={{ p: 2, borderTop: 1, borderColor: 'divider' }}>
        {!creation && (
          confirmation ? (
            <>
              <Button color="error" variant="contained" onClick={supprimer} disabled={enCours}>Confirmer la suppression</Button>
              <Button onClick={() => setConfirmation(false)}>Annuler</Button>
            </>
          ) : <Button color="error" startIcon={<DeleteIcon />} onClick={() => setConfirmation(true)}>Supprimer</Button>
        )}
        <Box sx={{ flexGrow: 1 }} />
        <Button onClick={onClose}>Fermer</Button>
        <Button variant="contained" startIcon={<SaveIcon />} onClick={enregistrer}
          disabled={enCours || (!creation && Object.keys(modifiees).length === 0)}>
          {creation ? 'Créer' : `Enregistrer${Object.keys(modifiees).length ? ` (${Object.keys(modifiees).length})` : ''}`}
        </Button>
      </Stack>
    </Drawer>
  );
};

// ---------------------------------------------------------------------------
// Import
// ---------------------------------------------------------------------------
const DialogueImport: React.FC<{ ouvert: boolean; onClose: () => void; onImported: () => void }> = ({ ouvert, onClose, onImported }) => {
  const [fichier, setFichier] = useState<File | null>(null);
  const [enCours, setEnCours] = useState(false);
  const [resultat, setResultat] = useState<Row | null>(null);
  const [erreur, setErreur] = useState<Row | null>(null);

  useEffect(() => { if (ouvert) { setFichier(null); setResultat(null); setErreur(null); } }, [ouvert]);

  const importer = async () => {
    if (!fichier) return;
    const form = new FormData();
    form.append('file', fichier, fichier.name);
    setEnCours(true);
    setErreur(null);
    setResultat(null);
    try {
      const res = await api.post('/resource-detail-file/import', form, { headers: { 'Content-Type': 'multipart/form-data' } });
      setResultat(res.data);
      onImported();
    } catch (e: any) {
      setErreur(e?.response?.data ?? { error: "L'import a échoué" });
    } finally {
      setEnCours(false);
    }
  };

  return (
    <Dialog open={ouvert} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Importer des ressources</DialogTitle>
      <DialogContent>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Fichier Excel (.xlsx) ou CSV (séparateur « ; » ou « , »). Les en-têtes sont ceux de l'export Excel
          ou les noms techniques. Chaque ligne met à jour la ressource de même <b>N° séquence</b> (à défaut de même
          <b> identifiant</b>) ; une ressource inconnue est ajoutée. Seules les colonnes présentes dans le fichier
          sont modifiées. Une seule ligne en erreur et rien n'est importé.
        </Typography>
        <Button variant="outlined" component="label" startIcon={<ImportIcon />}>
          {fichier ? fichier.name : 'Choisir un fichier'}
          <input hidden type="file" accept=".xlsx,.csv" onChange={(e) => { setFichier(e.target.files?.[0] ?? null); setResultat(null); setErreur(null); }} />
        </Button>
        {enCours && <LinearProgress sx={{ mt: 2 }} />}
        {resultat && (
          <Alert severity="success" sx={{ mt: 2 }}>
            {nb(resultat.inserees)} ressource(s) ajoutée(s), {nb(resultat.modifiees)} modifiée(s).
            <br />Colonnes lues : {resultat.colonnes.join(', ') || 'aucune'}. Pensez à « Recalculer ».
          </Alert>
        )}
        {erreur && (
          <Alert severity="error" sx={{ mt: 2 }}>
            {erreur.error}
            {erreur.erreurs?.length > 0 && (
              <Box component="ul" sx={{ m: 0, pl: 2, maxHeight: 220, overflowY: 'auto' }}>
                {erreur.erreurs.map((x: Row, i: number) => <li key={i}>Ligne {x.ligne} : {x.message}</li>)}
              </Box>
            )}
          </Alert>
        )}
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Fermer</Button>
        <Button variant="contained" onClick={importer} disabled={!fichier || enCours}>Importer</Button>
      </DialogActions>
    </Dialog>
  );
};

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------
const ResourceDetailFilePage: React.FC = () => {
  const [search, setSearch] = useState('');
  const [searchDebounced, setSearchDebounced] = useState('');
  const [filters, setFilters] = useState<Filters>({});
  const [anomalie, setAnomalie] = useState('');
  const [facets, setFacets] = useState<FacetsResponse | null>(null);
  const [rows, setRows] = useState<Row[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [sort, setSort] = useState('resource_seq');
  const [dir, setDir] = useState<'asc' | 'desc'>('asc');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [colonnes, setColonnes] = useState<string[]>(lireColonnes);
  const [colsAnchor, setColsAnchor] = useState<HTMLElement | null>(null);
  const [fiche, setFiche] = useState<{ row: Row | null } | null>(null);
  const [importOuvert, setImportOuvert] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [recalcul, setRecalcul] = useState(false);
  const [version, setVersion] = useState(0);

  useEffect(() => {
    const t = setTimeout(() => setSearchDebounced(search), 350);
    return () => clearTimeout(t);
  }, [search]);

  useEffect(() => {
    try { localStorage.setItem(COLS_KEY, JSON.stringify(colonnes)); } catch { /* ignoré */ }
  }, [colonnes]);

  const params = useMemo(() => {
    const p: Record<string, string> = {};
    if (searchDebounced) p.search = searchDebounced;
    (Object.keys(filters) as FacetKey[]).forEach((k) => {
      if (filters[k]?.length) p[k] = filters[k]!.join(',');
    });
    if (anomalie) p.anomalie = anomalie;
    return p;
  }, [searchDebounced, filters, anomalie]);

  useEffect(() => { setPage(0); }, [params]);

  useEffect(() => {
    api.get('/resource-detail-file/facettes', { params })
      .then((res) => setFacets(res.data))
      .catch(() => setError('Impossible de charger les compteurs.'));
  }, [params, version]);

  const charger = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get('/resource-detail-file', { params: { ...params, page: page + 1, page_size: pageSize, sort, dir } });
      setRows(res.data.rows);
      setTotal(res.data.total);
    } catch {
      setError('Impossible de charger les ressources.');
    } finally {
      setLoading(false);
    }
  }, [params, page, pageSize, sort, dir, version]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => { charger(); }, [charger]);

  const rafraichir = () => setVersion((v) => v + 1);

  const toggleFiltre = (k: FacetKey, code: string) =>
    setFilters((f) => {
      const cur = f[k] ?? [];
      return { ...f, [k]: cur.includes(code) ? cur.filter((c) => c !== code) : [...cur, code] };
    });

  const effacer = () => { setFilters({}); setSearch(''); setAnomalie(''); };
  const nbFiltres = Object.values(filters).reduce((s, v) => s + (v?.length ?? 0), 0)
    + (searchDebounced ? 1 : 0) + (anomalie ? 1 : 0);

  const exporter = async () => {
    try {
      setExporting(true);
      await telecharger('/resource-detail-file/export.xlsx', params, 'ressources.xlsx');
    } catch {
      setError("L'export Excel a échoué.");
    } finally {
      setExporting(false);
    }
  };

  const recalculer = async () => {
    try {
      setRecalcul(true);
      const res = await api.post('/resource-detail-file/recalculer');
      setInfo(`Module ressources recalculé : ${nb(res.data.lignes)} ressources dans les tables IFS.`);
      rafraichir();
    } catch (e) {
      setError(message(e, 'Le recalcul a échoué.'));
    } finally {
      setRecalcul(false);
    }
  };

  const tousChamps = useMemo(() => [...CALCULEES, ...(facets?.champs ?? [])], [facets]);
  const themes = Array.from(new Set(tousChamps.map((f) => f.theme)));
  const champs = tousChamps.filter((f) => colonnes.includes(f.col));
  const facette = (k: FacetKey) => facets?.facettes[k];
  const anomaliesLibelles = useMemo(
    () => Object.fromEntries((facets?.anomalies ?? []).map((a) => [a.cle, a.libelle])), [facets]);

  const filtreAuto = (k: FacetKey, largeur = 180) => (
    <FacetteAuto key={k} titre={facette(k)?.titre ?? k} valeurs={facette(k)?.valeurs ?? []} largeur={largeur}
      selection={filters[k] ?? []} onChange={(codes) => setFilters((cur) => ({ ...cur, [k]: codes }))} />
  );

  return (
    <Box sx={{ p: { xs: 1.5, md: 3 } }}>
      <Stack direction={{ xs: 'column', md: 'row' }} justifyContent="space-between" alignItems={{ md: 'center' }} spacing={2} sx={{ mb: 2 }}>
        <Stack direction="row" spacing={1.5} alignItems="center">
          <Box sx={{ p: 1.2, borderRadius: 2, bgcolor: '#e3f2fd', display: 'flex' }}>
            <ResourceIcon sx={{ color: '#1976d2', fontSize: 32 }} />
          </Box>
          <Box>
            <Typography variant="h4" sx={{ fontWeight: 700 }}>Ressources de maintenance</Typography>
            <Typography variant="body2" color="text.secondary">
              Fichier des ressources (personnes, groupes, équipements) · {facets ? nb(facets.total) : '…'} ressources
              {nbFiltres > 0 ? ' (sélection)' : ''}
            </Typography>
          </Box>
        </Stack>
        <Stack direction="row" spacing={1} sx={{ flexWrap: 'wrap', rowGap: 1 }}>
          <Button variant="outlined" startIcon={<ImportIcon />} onClick={() => setImportOuvert(true)}>Importer</Button>
          <Button variant="outlined" startIcon={<AddIcon />} onClick={() => setFiche({ row: null })}>Nouvelle ressource</Button>
          <Tooltip title="Recharge les tables IFS du module ressources depuis le fichier">
            <Badge badgeContent={facets?.a_recalculer ?? 0} color="warning">
              <Button variant="outlined" color={facets?.a_recalculer ? 'warning' : 'primary'} startIcon={<RecalcIcon />}
                onClick={recalculer} disabled={recalcul}>
                {recalcul ? 'Recalcul…' : 'Recalculer'}
              </Button>
            </Badge>
          </Tooltip>
          <Button variant="contained" startIcon={<ExcelIcon />} onClick={exporter} disabled={exporting}>
            {exporting ? 'Export…' : 'Excel'}
          </Button>
        </Stack>
      </Stack>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}
      {info && <Alert severity="success" sx={{ mb: 2 }} onClose={() => setInfo(null)}>{info}</Alert>}

      {facets && (
        <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
          <Stack direction={{ xs: 'column', lg: 'row' }} spacing={3}>
            <RepartitionBar titre="Type de ressource" valeurs={facets.facettes.type.valeurs}
              actifs={filters.type ?? []} palette={TYPE_COULEURS} onToggle={(c) => toggleFiltre('type', c)}
              legende={(v) => TYPE_LIBELLES[v.code] ?? v.code} />
            <RepartitionBar titre="Personne retrouvée dans IFS" valeurs={facets.facettes.personne.valeurs}
              actifs={filters.personne ?? []} palette={PERSONNE_COULEURS} onToggle={(c) => toggleFiltre('personne', c)} />
          </Stack>
        </Paper>
      )}

      {facets && (
        <Stack direction="row" spacing={1} sx={{ mb: 2, flexWrap: 'wrap', rowGap: 1 }} alignItems="center">
          <Typography variant="overline" color="text.secondary" sx={{ mr: 1 }}>Qualité des données</Typography>
          <Chip icon={<WarningIcon />} clickable
            color={anomalie === 'toutes' ? 'warning' : 'default'} variant={anomalie === 'toutes' ? 'filled' : 'outlined'}
            onClick={() => setAnomalie(anomalie === 'toutes' ? '' : 'toutes')}
            label={`Au moins une anomalie · ${nb(facets.anomalies_total)}`} />
          {facets.anomalies.map((a) => (
            <Chip key={a.cle} clickable size="small"
              color={anomalie === a.cle ? 'warning' : 'default'} variant={anomalie === a.cle ? 'filled' : 'outlined'}
              onClick={() => setAnomalie(anomalie === a.cle ? '' : a.cle)}
              label={`${a.libelle} · ${nb(a.nb)}`} />
          ))}
        </Stack>
      )}

      <Paper variant="outlined" sx={{ p: 1.5, mb: 2 }}>
        <Stack direction="row" spacing={1.5} sx={{ flexWrap: 'wrap', rowGap: 1.5 }} alignItems="center">
          <TextField size="small" placeholder="Identifiant, description, n° séquence, clé origine…" value={search}
            onChange={(e) => setSearch(e.target.value)} sx={{ width: 320 }}
            InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment> }} />
          {filtreAuto('site', 150)}
          {filtreAuto('societe', 170)}
          {filtreAuto('calendrier', 160)}
          {filtreAuto('origine', 170)}
          <Box sx={{ flexGrow: 1 }} />
          <Chip color={nbFiltres > 0 ? 'primary' : 'default'} variant={nbFiltres > 0 ? 'filled' : 'outlined'}
            sx={{ fontWeight: 600, fontSize: '0.9rem' }}
            label={loading ? 'Comptage…' : nbFiltres > 0 && facets
              ? `${nb(total)} / ${nb(facets.total_general)} ressources`
              : `${nb(total)} ressources`} />
          {nbFiltres > 0 && <Button size="small" onClick={effacer}>Effacer les filtres ({nbFiltres})</Button>}
          <Badge badgeContent={colonnes.length} color="primary">
            <Button size="small" variant="outlined" startIcon={<ColumnsIcon />} onClick={(ev) => setColsAnchor(ev.currentTarget)}>
              Colonnes
            </Button>
          </Badge>
        </Stack>
      </Paper>

      <Menu anchorEl={colsAnchor} open={!!colsAnchor} onClose={() => setColsAnchor(null)}
        PaperProps={{ sx: { maxHeight: 520, width: 300 } }}>
        <Box sx={{ px: 2, py: 1, display: 'flex', gap: 0.5, flexWrap: 'wrap' }}>
          {Object.keys(PRESETS).map((p) => (
            <Chip key={p} size="small" label={p} clickable onClick={() => setColonnes(PRESETS[p])} />
          ))}
          <Chip size="small" label="Tout" clickable onClick={() => setColonnes(tousChamps.map((f) => f.col))} />
        </Box>
        <Divider />
        {themes.map((t) => [
          <ListSubheader key={`h-${t}`} sx={{ lineHeight: '32px' }}>{t}</ListSubheader>,
          ...tousChamps.filter((f) => f.theme === t).map((f) => (
            <MenuItem key={f.col} dense disabled={f.col === 'resource_seq'}
              onClick={() => setColonnes((c) => (c.includes(f.col) ? c.filter((x) => x !== f.col) : [...c, f.col]))}>
              <Checkbox size="small" checked={colonnes.includes(f.col)} sx={{ py: 0 }} />
              <ListItemText primary={f.label} />
            </MenuItem>
          )),
        ])}
      </Menu>

      {loading && <LinearProgress sx={{ mb: 0.5 }} />}

      <Paper variant="outlined">
        <TableContainer sx={{ maxHeight: 'calc(100vh - 430px)', minHeight: 300 }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                <TableCell sx={{ width: 40 }} />
                {champs.map((f) => (
                  <TableCell key={f.col} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>
                    <TableSortLabel active={sort === f.col} direction={sort === f.col ? dir : 'asc'}
                      onClick={() => { if (sort === f.col) setDir(dir === 'asc' ? 'desc' : 'asc'); else { setSort(f.col); setDir('asc'); } }}>
                      {f.label}
                    </TableSortLabel>
                  </TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {rows.map((r) => (
                <TableRow key={r.resource_seq} hover sx={{ cursor: 'pointer' }} onClick={() => setFiche({ row: r })}>
                  <TableCell>
                    {r.anomalies.length > 0 && (
                      <Tooltip title={r.anomalies.map((k: string) => anomaliesLibelles[k] ?? k).join(' · ')}>
                        <WarningIcon fontSize="small" sx={{ color: 'warning.main' }} />
                      </Tooltip>
                    )}
                  </TableCell>
                  {champs.map((f) => <TableCell key={f.col}><Cellule champ={f} row={r} /></TableCell>)}
                </TableRow>
              ))}
              {!loading && rows.length === 0 && (
                <TableRow><TableCell colSpan={champs.length + 1} align="center" sx={{ py: 6, color: 'text.secondary' }}>
                  Aucune ressource ne correspond aux filtres.
                </TableCell></TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
        <TablePagination component="div" count={total} page={page} rowsPerPage={pageSize}
          rowsPerPageOptions={[25, 50, 100, 200]} labelRowsPerPage="Lignes par page"
          labelDisplayedRows={({ from, to, count }) => `${from}–${to} sur ${nb(count)}`}
          onPageChange={(_, p) => setPage(p)} onRowsPerPageChange={(ev) => { setPageSize(Number(ev.target.value)); setPage(0); }} />
      </Paper>

      <FicheRessource ouverte={!!fiche} row={fiche?.row ?? null} champs={facets?.champs ?? []}
        types={facets?.types_ressource ?? []} anomalies={anomaliesLibelles}
        onClose={() => setFiche(null)} onSaved={rafraichir} />
      <DialogueImport ouvert={importOuvert} onClose={() => setImportOuvert(false)} onImported={rafraichir} />
    </Box>
  );
};

export default ResourceDetailFilePage;
