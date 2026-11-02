import {
  AccountTree as ParentIcon,
  Add as AddIcon,
  Build as MaintenanceIcon,
  Description as FileIcon,
  EventAvailable as AvailabilityIcon,
  Link as ConnectionIcon,
  Person as PersonIcon,
  Close as CloseIcon,
  DeleteOutline as DeleteIcon,
  FileDownload as ExcelIcon,
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

// Écrans Ressources (/ressources/*), sur le modèle de Maintenance > Équipements, mais
// éditables. Une seule page pour les 6 fichiers : la description de l'écran (champs,
// colonnes calculées, facettes) vient de l'API backend/api/resource_files.py. On modifie
// les fichiers sources (raw_data) ; « Recalculer » recharge les tables IFS du module.

type Row = Record<string, any>;
interface Champ {
  col: string; label: string; theme: string; type: 'bool' | 'num' | 'txt' | 'date' | 'statut';
  options?: string[] | null; ref?: string | null; obligatoire?: boolean;
  statuts?: Record<string, { libelle: string; couleur: 'success' | 'error' | 'warning' | 'info' | 'default' }>;
}
interface FacetsResponse {
  facettes: Record<string, { titre: string; valeurs: FacetValue[] }>;
  total: number;
  total_general: number;
  anomalies: { cle: string; libelle: string; nb: number }[];
  anomalies_total: number;
  a_recalculer: number;
  cle: string[];
  auto: boolean;
  titre: string;
  sous_titre: string;
  champs: Champ[];
  colonnes: Champ[];
  barres: string[];
  essentiel: string[];
  defauts: Row;
}

const COULEURS_CONNUES: Record<string, string> = {
  PERSON: '#1976d2', PERSON_GROUP: '#00897b', EQUIPMENT: '#ef6c00',
  TROUVEE: '#2e7d32', NON_TROUVEE: '#c62828', SANS_OBJET: '#cfd8dc',
  EN_COURS: '#2e7d32', PASSEE: '#90a4ae', FUTURE: '#0288d1', SANS_DATE: '#ef6c00',
  Yes: '#2e7d32', No: '#90a4ae', OUI: '#2e7d32', NON: '#cfd8dc', TRUE: '#2e7d32', FALSE: '#90a4ae',
  __vide__: '#e0e0e0',
};
const PALETTE = ['#1976d2', '#00897b', '#ef6c00', '#8e24aa', '#c62828', '#5d4037', '#3949ab', '#7cb342', '#f9a825', '#00acc1'];
const palette = (valeurs: FacetValue[]) =>
  Object.fromEntries(valeurs.map((v, i) => [v.code, COULEURS_CONNUES[v.code] ?? PALETTE[i % PALETTE.length]]));

const TYPE_LIBELLES: Record<string, string> = { PERSON: 'Personne', PERSON_GROUP: 'Groupe de personnes', EQUIPMENT: 'Équipement' };
const message = (e: any, defaut: string) => e?.response?.data?.error ?? e?.response?.data?.message ?? defaut;
const dateFr = (v: string) => (/^\d{4}-\d{2}-\d{2}$/.test(v) ? v.split('-').reverse().join('/') : v);

const Cellule: React.FC<{ champ: Champ; row: Row }> = ({ champ, row }) => {
  const v = row[champ.col];
  if (champ.type === 'statut') {
    const s = champ.statuts?.[v];
    if (!s || s.libelle === '—') return <Typography variant="body2" color="text.disabled">—</Typography>;
    return <Chip size="small" variant="outlined" color={s.couleur} label={s.libelle} sx={{ height: 20, fontSize: '0.7rem' }} />;
  }
  if (v === null || v === undefined || v === '') return <Typography variant="body2" color="text.disabled">—</Typography>;
  if (champ.col === 'resource_type_db' || champ.col === 'type_ressource') {
    return <Chip size="small" label={TYPE_LIBELLES[v] ?? v} sx={{ bgcolor: COULEURS_CONNUES[v] ?? '#bdbdbd', color: '#fff', height: 22 }} />;
  }
  if (champ.type === 'bool') {
    return <Chip size="small" variant="outlined" label={v === 'TRUE' ? 'Oui' : 'Non'} color={v === 'TRUE' ? 'primary' : 'default'}
      sx={{ height: 20, fontSize: '0.7rem' }} />;
  }
  if (champ.type === 'date') return <Typography variant="body2">{dateFr(v)}</Typography>;
  const mono = champ.type === 'num' || /(_id|_ifs)$/.test(champ.col);
  return <Typography variant="body2" noWrap sx={{ maxWidth: 320, fontFamily: mono ? 'monospace' : undefined }}>{v}</Typography>;
};

// ---------------------------------------------------------------------------
// Fiche (tiroir) : modification, création (row = null) et suppression
// ---------------------------------------------------------------------------
const Fiche: React.FC<{
  fichier: string; ouverte: boolean; row: Row | null; meta: FacetsResponse | null; anomalies: Record<string, string>;
  couleur: string; onClose: () => void; onSaved: () => void;
}> = ({ fichier, ouverte, row, meta, anomalies, couleur, onClose, onSaved }) => {
  const [valeurs, setValeurs] = useState<Row>({});
  const [erreur, setErreur] = useState<string | null>(null);
  const [enCours, setEnCours] = useState(false);
  const [confirmation, setConfirmation] = useState(false);
  const champs = useMemo(() => meta?.champs ?? [], [meta]);
  const creation = !row;

  useEffect(() => {
    if (!ouverte) return;
    const init: Row = {};
    champs.forEach((c) => { init[c.col] = row?.[c.col] ?? (row ? '' : meta?.defauts[c.col] ?? ''); });
    setValeurs(init);
    setErreur(null);
    setConfirmation(false);
  }, [ouverte, row, champs, meta]);

  const modifiees = useMemo(() => {
    const out: Row = {};
    champs.forEach((c) => {
      if (creation || String(valeurs[c.col] ?? '') !== String(row?.[c.col] ?? '')) out[c.col] = valeurs[c.col];
    });
    return out;
  }, [valeurs, row, champs, creation]);

  const agir = async (action: () => Promise<unknown>, defaut: string) => {
    setEnCours(true);
    setErreur(null);
    try {
      await action();
      onSaved();
      onClose();
    } catch (e) {
      setErreur(message(e, defaut));
      setConfirmation(false);
    } finally {
      setEnCours(false);
    }
  };
  const url = `/resource-files/${fichier}`;
  const enregistrer = () => agir(() => (creation ? api.post(url, modifiees) : api.put(`${url}/${row!._id}`, modifiees)),
    'Enregistrement impossible');
  const supprimer = () => agir(() => api.delete(`${url}/${row!._id}`), 'Suppression impossible');

  const themes = Array.from(new Set(champs.map((c) => c.theme)));
  const saisie = (c: Champ) => {
    const commun = {
      size: 'small' as const, fullWidth: true, label: c.label, value: valeurs[c.col] ?? '', required: c.obligatoire,
      helperText: c.ref ? `N° d'une ligne du fichier ${c.ref.toLowerCase()}` : undefined,
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
    if (c.options) {
      return (
        <TextField {...commun} select>
          {!c.obligatoire && <MenuItem value=""><em>(vide)</em></MenuItem>}
          {c.options.map((o) => <MenuItem key={o} value={o}>{TYPE_LIBELLES[o] ? `${TYPE_LIBELLES[o]} (${o})` : o}</MenuItem>)}
        </TextField>
      );
    }
    if (c.type === 'date') return <TextField {...commun} type="date" InputLabelProps={{ shrink: true }} />;
    return <TextField {...commun} type={c.type === 'num' ? 'number' : 'text'} multiline={['note', 'description', 'remark'].includes(c.col)} />;
  };

  const titre = row ? row[meta?.titre ?? ''] ?? row._id : valeurs[meta?.titre ?? ''] || 'Nouvelle ligne';
  const sousTitre = row ? row[meta?.sous_titre ?? ''] : valeurs[meta?.sous_titre ?? ''];
  const nbModifs = Object.keys(modifiees).length;

  return (
    <Drawer anchor="right" open={ouverte} onClose={onClose} PaperProps={{ sx: { width: { xs: '100%', sm: 620 } } }}>
      <Box sx={{ p: 2.5, color: '#fff', background: `linear-gradient(135deg, ${COULEURS_CONNUES[valeurs.resource_type_db] ?? couleur} 0%, #263238 100%)` }}>
        <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
          <Box>
            <Typography variant="overline" sx={{ opacity: 0.85 }}>{creation ? 'Création' : `Ligne n° ${String(row!._id).replace('~', ' / ')}`}</Typography>
            <Typography variant="h5" sx={{ fontFamily: 'monospace', fontWeight: 700 }}>{titre}</Typography>
            {sousTitre && <Typography variant="body1">{sousTitre}</Typography>}
          </Box>
          <IconButton onClick={onClose} sx={{ color: '#fff' }}><CloseIcon /></IconButton>
        </Stack>
        {row && (
          <Stack direction="row" spacing={1} sx={{ mt: 1.5, flexWrap: 'wrap', rowGap: 1 }}>
            {meta?.colonnes.filter((c) => c.type !== 'statut' && !meta.cle.includes(c.col) && row[c.col] !== null && row[c.col] !== undefined && c.col !== meta.titre && c.col !== meta.sous_titre)
              .map((c) => <Chip key={c.col} size="small" label={`${c.label} : ${row[c.col]}`} sx={{ bgcolor: 'rgba(255,255,255,.25)', color: '#fff' }} />)}
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
                <Box key={c.col} sx={{ gridColumn: ['description', 'note', 'remark'].includes(c.col) ? '1 / -1' : undefined }}>{saisie(c)}</Box>
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
        <Button variant="contained" startIcon={<SaveIcon />} onClick={enregistrer} disabled={enCours || (!creation && nbModifs === 0)}>
          {creation ? 'Créer' : `Enregistrer${nbModifs ? ` (${nbModifs})` : ''}`}
        </Button>
      </Stack>
    </Drawer>
  );
};

// ---------------------------------------------------------------------------
// Import
// ---------------------------------------------------------------------------
const DialogueImport: React.FC<{ fichier: string; ouvert: boolean; onClose: () => void; onImported: () => void }> = ({ fichier, ouvert, onClose, onImported }) => {
  const [choisi, setChoisi] = useState<File | null>(null);
  const [enCours, setEnCours] = useState(false);
  const [resultat, setResultat] = useState<Row | null>(null);
  const [erreur, setErreur] = useState<Row | null>(null);

  useEffect(() => { if (ouvert) { setChoisi(null); setResultat(null); setErreur(null); } }, [ouvert]);

  const importer = async () => {
    if (!choisi) return;
    const form = new FormData();
    form.append('file', choisi, choisi.name);
    setEnCours(true);
    setErreur(null);
    setResultat(null);
    try {
      const res = await api.post(`/resource-files/${fichier}/import`, form, { headers: { 'Content-Type': 'multipart/form-data' } });
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
      <DialogTitle>Importer un fichier</DialogTitle>
      <DialogContent>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Fichier Excel (.xlsx) ou CSV (séparateur « ; » ou « , »). Les en-têtes sont ceux de l'export Excel
          ou les noms techniques. Chaque ligne met à jour la ligne de même <b>N°</b> (clé) ; une ligne inconnue
          ou sans N° est ajoutée. Seules les colonnes présentes dans le fichier sont modifiées. Une seule
          ligne en erreur et rien n'est importé.
        </Typography>
        <Button variant="outlined" component="label" startIcon={<ImportIcon />}>
          {choisi ? choisi.name : 'Choisir un fichier'}
          <input hidden type="file" accept=".xlsx,.csv" onChange={(e) => { setChoisi(e.target.files?.[0] ?? null); setResultat(null); setErreur(null); }} />
        </Button>
        {enCours && <LinearProgress sx={{ mt: 2 }} />}
        {resultat && (
          <Alert severity="success" sx={{ mt: 2 }}>
            {nb(resultat.inserees)} ligne(s) ajoutée(s), {nb(resultat.modifiees)} modifiée(s).
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
        <Button variant="contained" onClick={importer} disabled={!choisi || enCours}>Lancer l'import</Button>
      </DialogActions>
    </Dialog>
  );
};

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------
interface Props { fichier: string; titre: string; sousTitre: string; icone: React.ReactElement; couleur: string }

export const ECRANS: Record<string, Omit<Props, 'fichier'>> = {
  'detail-file': { titre: 'Ressources', sousTitre: 'Fichier détail des ressources (personnes, groupes, équipements)', icone: <FileIcon />, couleur: '#1976d2' },
  connection: { titre: 'Connexions des ressources', sousTitre: 'Rattachement de chaque ressource à sa ressource parente', icone: <ConnectionIcon />, couleur: '#388e3c' },
  availability: { titre: 'Disponibilités', sousTitre: 'Périodes de disponibilité et efficacité des ressources', icone: <AvailabilityIcon />, couleur: '#ef6c00' },
  parent: { titre: 'Ressources parentes', sousTitre: 'Hiérarchie des ressources et compétence de planification', icone: <ParentIcon />, couleur: '#8e24aa' },
  'maint-person': { titre: 'Ressources de maintenance par personne', sousTitre: 'Organisation de maintenance et paramètres mobiles par connexion', icone: <MaintenanceIcon />, couleur: '#c62828' },
  'ifs-person': { titre: 'Personnes IFS', sousTitre: 'Référentiel des personnes vers lequel pointent les ressources', icone: <PersonIcon />, couleur: '#00838f' },
};

const EcranRessource: React.FC<Props> = ({ fichier, titre, sousTitre, icone, couleur }) => {
  const [search, setSearch] = useState('');
  const [searchDebounced, setSearchDebounced] = useState('');
  const [filters, setFilters] = useState<Record<string, string[]>>({});
  const [anomalie, setAnomalie] = useState('');
  const [facets, setFacets] = useState<FacetsResponse | null>(null);
  const [rows, setRows] = useState<Row[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [sort, setSort] = useState('');
  const [dir, setDir] = useState<'asc' | 'desc'>('asc');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const colsKey = `ressources.${fichier}.colonnes.v1`;
  const [colonnes, setColonnes] = useState<string[] | null>(() => {
    try {
      const v = JSON.parse(localStorage.getItem(colsKey) || 'null');
      return Array.isArray(v) && v.length ? v : null;
    } catch { return null; }
  });
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
    if (!colonnes) return;
    try { localStorage.setItem(colsKey, JSON.stringify(colonnes)); } catch { /* ignoré */ }
  }, [colonnes, colsKey]);

  const params = useMemo(() => {
    const p: Record<string, string> = {};
    if (searchDebounced) p.search = searchDebounced;
    Object.entries(filters).forEach(([k, v]) => { if (v.length) p[k] = v.join(','); });
    if (anomalie) p.anomalie = anomalie;
    return p;
  }, [searchDebounced, filters, anomalie]);

  useEffect(() => { setPage(0); }, [params]);

  useEffect(() => {
    api.get(`/resource-files/${fichier}/facettes`, { params })
      .then((res) => setFacets(res.data))
      .catch(() => setError('Impossible de charger les compteurs.'));
  }, [fichier, params, version]);

  const charger = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get(`/resource-files/${fichier}`, { params: { ...params, page: page + 1, page_size: pageSize, sort, dir } });
      setRows(res.data.rows);
      setTotal(res.data.total);
    } catch {
      setError('Impossible de charger les lignes.');
    } finally {
      setLoading(false);
    }
  }, [fichier, params, page, pageSize, sort, dir, version]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => { charger(); }, [charger]);

  const rafraichir = () => setVersion((v) => v + 1);

  const toggleFiltre = (k: string, code: string) =>
    setFilters((f) => {
      const cur = f[k] ?? [];
      return { ...f, [k]: cur.includes(code) ? cur.filter((c) => c !== code) : [...cur, code] };
    });

  const effacer = () => { setFilters({}); setSearch(''); setAnomalie(''); };
  const nbFiltres = Object.values(filters).reduce((s, v) => s + v.length, 0) + (searchDebounced ? 1 : 0) + (anomalie ? 1 : 0);

  const exporter = async () => {
    try {
      setExporting(true);
      await telecharger(`/resource-files/${fichier}/export.xlsx`, params, `${fichier}.xlsx`);
    } catch {
      setError("L'export Excel a échoué.");
    } finally {
      setExporting(false);
    }
  };

  const recalculer = async () => {
    try {
      setRecalcul(true);
      const res = await api.post('/resource-files/recalculer');
      setInfo(`Module ressources recalculé : ${Object.entries(res.data).map(([t, n]) => `${t} ${nb(n as number)}`).join(' · ')}.`);
      rafraichir();
    } catch (e) {
      setError(message(e, 'Le recalcul a échoué.'));
    } finally {
      setRecalcul(false);
    }
  };

  const tousChamps = useMemo(() => {
    if (!facets) return [];
    const vus = new Set(facets.colonnes.map((c) => c.col));
    return [...facets.colonnes, ...facets.champs.filter((c) => !vus.has(c.col))];
  }, [facets]);
  const visibles = colonnes ?? facets?.essentiel ?? [];
  const themes = Array.from(new Set(tousChamps.map((f) => f.theme)));
  const champs = visibles.map((c) => tousChamps.find((f) => f.col === c)).filter(Boolean) as Champ[];
  const anomaliesLibelles = useMemo(
    () => Object.fromEntries((facets?.anomalies ?? []).map((a) => [a.cle, a.libelle])), [facets]);
  const filtrables = Object.keys(facets?.facettes ?? {}).filter((k) => !facets?.barres.includes(k));
  const cleTri = sort || facets?.cle[0] || '';

  return (
    <Box sx={{ p: { xs: 1.5, md: 3 } }}>
      <Stack direction={{ xs: 'column', md: 'row' }} justifyContent="space-between" alignItems={{ md: 'center' }} spacing={2} sx={{ mb: 2 }}>
        <Stack direction="row" spacing={1.5} alignItems="center">
          <Box sx={{ p: 1.2, borderRadius: 2, bgcolor: `${couleur}22`, display: 'flex', color: couleur, '& svg': { fontSize: 32 } }}>
            {icone}
          </Box>
          <Box>
            <Typography variant="h4" sx={{ fontWeight: 700 }}>{titre}</Typography>
            <Typography variant="body2" color="text.secondary">
              {sousTitre} · {facets ? nb(facets.total) : '…'} lignes{nbFiltres > 0 ? ' (sélection)' : ''}
            </Typography>
          </Box>
        </Stack>
        <Stack direction="row" spacing={1} sx={{ flexWrap: 'wrap', rowGap: 1 }}>
          <Button variant="outlined" startIcon={<ImportIcon />} onClick={() => setImportOuvert(true)}>Importer</Button>
          <Button variant="outlined" startIcon={<AddIcon />} onClick={() => setFiche({ row: null })} disabled={!facets}>Nouvelle ligne</Button>
          <Tooltip title="Recharge les tables IFS du module ressources depuis les fichiers">
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

      {facets && facets.barres.length > 0 && (
        <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
          <Stack direction={{ xs: 'column', lg: 'row' }} spacing={3}>
            {facets.barres.map((k) => (
              <RepartitionBar key={k} titre={facets.facettes[k].titre} valeurs={facets.facettes[k].valeurs}
                actifs={filters[k] ?? []} palette={palette(facets.facettes[k].valeurs)} onToggle={(c) => toggleFiltre(k, c)} />
            ))}
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
          <TextField size="small" placeholder="Rechercher (identifiant, libellé, n°…)" value={search}
            onChange={(e) => setSearch(e.target.value)} sx={{ width: 300 }}
            InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment> }} />
          {filtrables.map((k) => (
            <FacetteAuto key={k} titre={facets!.facettes[k].titre} valeurs={facets!.facettes[k].valeurs} largeur={190}
              selection={filters[k] ?? []} onChange={(codes) => setFilters((cur) => ({ ...cur, [k]: codes }))} />
          ))}
          <Box sx={{ flexGrow: 1 }} />
          <Chip color={nbFiltres > 0 ? 'primary' : 'default'} variant={nbFiltres > 0 ? 'filled' : 'outlined'}
            sx={{ fontWeight: 600, fontSize: '0.9rem' }}
            label={loading ? 'Comptage…' : nbFiltres > 0 && facets ? `${nb(total)} / ${nb(facets.total_general)} lignes` : `${nb(total)} lignes`} />
          {nbFiltres > 0 && <Button size="small" onClick={effacer}>Effacer les filtres ({nbFiltres})</Button>}
          <Badge badgeContent={visibles.length} color="primary">
            <Button size="small" variant="outlined" startIcon={<ColumnsIcon />} onClick={(ev) => setColsAnchor(ev.currentTarget)}>
              Colonnes
            </Button>
          </Badge>
        </Stack>
      </Paper>

      <Menu anchorEl={colsAnchor} open={!!colsAnchor} onClose={() => setColsAnchor(null)} PaperProps={{ sx: { maxHeight: 520, width: 300 } }}>
        <Box sx={{ px: 2, py: 1, display: 'flex', gap: 0.5, flexWrap: 'wrap' }}>
          <Chip size="small" label="Essentiel" clickable onClick={() => setColonnes(facets?.essentiel ?? [])} />
          <Chip size="small" label="Tout" clickable onClick={() => setColonnes(tousChamps.map((f) => f.col))} />
        </Box>
        <Divider />
        {themes.map((t) => [
          <ListSubheader key={`h-${t}`} sx={{ lineHeight: '32px' }}>{t}</ListSubheader>,
          ...tousChamps.filter((f) => f.theme === t).map((f) => (
            <MenuItem key={f.col} dense
              onClick={() => setColonnes((c) => { const cur = c ?? visibles; return cur.includes(f.col) ? cur.filter((x) => x !== f.col) : [...cur, f.col]; })}>
              <Checkbox size="small" checked={visibles.includes(f.col)} sx={{ py: 0 }} />
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
                    <TableSortLabel active={cleTri === f.col} direction={cleTri === f.col ? dir : 'asc'}
                      onClick={() => { if (cleTri === f.col) setDir(dir === 'asc' ? 'desc' : 'asc'); else { setSort(f.col); setDir('asc'); } }}>
                      {f.label}
                    </TableSortLabel>
                  </TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {rows.map((r) => (
                <TableRow key={r._id} hover sx={{ cursor: 'pointer' }} onClick={() => setFiche({ row: r })}>
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
                  Aucune ligne ne correspond aux filtres.
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

      <Fiche fichier={fichier} ouverte={!!fiche} row={fiche?.row ?? null} meta={facets} anomalies={anomaliesLibelles}
        couleur={couleur} onClose={() => setFiche(null)} onSaved={rafraichir} />
      <DialogueImport fichier={fichier} ouvert={importOuvert} onClose={() => setImportOuvert(false)} onImported={rafraichir} />
    </Box>
  );
};

// key : changer d'écran remonte la page (filtres, colonnes, tri propres à chaque fichier)
const ResourceFilePage: React.FC<{ fichier: string }> = ({ fichier }) => <EcranRessource key={fichier} fichier={fichier} {...ECRANS[fichier]} />;

export default ResourceFilePage;
