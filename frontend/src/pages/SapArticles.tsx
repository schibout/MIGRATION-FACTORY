import {
  AccountTree as StructureIcon,
  Close as CloseIcon,
  FileDownload as ExcelIcon,
  Inventory2 as ArticleIcon,
  MenuBook as CatalogueIcon,
  OpenInNew as OpenIcon,
  Search as SearchIcon,
  ViewColumn as ColumnsIcon,
  WarningAmber as WarningIcon,
} from '@mui/icons-material';
import {
  Alert,
  Autocomplete,
  Badge,
  Box,
  Button,
  Checkbox,
  Chip,
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
  ToggleButton,
  ToggleButtonGroup,
  Tooltip,
  Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';

// Écran Données SAP > Articles : clean_data.v_article_sap (périmètre STJN + maintenance),
// API backend/api/sap_articles.py.

type Row = Record<string, any>;
type FacetKey = 'site' | 'classe' | 'categorie' | 'groupe_achat' | 'statut' | 'planification' | 'gestionnaire';
type Filters = Partial<Record<FacetKey, string[]>>;
type Mode = 'liste' | 'gestionnaire' | 'groupe_achat';

interface FacetValue { code: string; libelle: string | null; nb: number }
interface FacetsResponse {
  facettes: Record<FacetKey, { titre: string; valeurs: FacetValue[] }>;
  total: number;
  structure: number;
  catalogue: number;
  anomalies: { cle: string; libelle: string; nb: number }[];
  anomalies_total: number;
}

const VIDE = '__vide__';

// Colonnes affichables : code + libellé fusionnés dans une même cellule.
interface Field { col: string; lib?: string; label?: string; theme: string; long?: boolean; numeric?: boolean }
const FIELDS: Field[] = [
  { col: 'N° article', theme: 'Identification' },
  { col: 'Description article', label: 'Description', theme: 'Identification', long: true },
  { col: 'Ancien numéro article', label: 'Ancien n°', theme: 'Identification' },
  { col: 'Désignation du type', label: 'Désignation type', theme: 'Identification' },
  { col: 'Site', lib: 'Site Description', theme: 'Identification' },
  { col: "Classe d'actifs", lib: "Classe d'actifs Description", label: 'Classe', theme: 'Classification' },
  { col: 'Catégorie article', lib: 'Catégorie article Description', label: 'Catégorie', theme: 'Classification' },
  { col: 'Groupe produit 1', lib: 'Groupe produit 1 Description', label: 'Groupe marchandises', theme: 'Classification' },
  { col: 'Hiérarchie produit', lib: 'Hiérarchie produit Description', theme: 'Classification' },
  { col: 'Groupe comptable', lib: 'Groupe comptable Description', theme: 'Classification' },
  { col: 'Classe ABC', label: 'ABC', theme: 'Classification' },
  { col: 'Statut article', label: 'Statut', theme: 'Classification' },
  { col: 'U/M Stock', lib: 'U/M Stock Description', label: 'Unité', theme: 'Unité' },
  { col: "Groupe d'achat", lib: "Groupe d'achat Description", theme: 'Achat' },
  { col: 'Type approvisionnement', lib: 'Type approvisionnement Description', label: 'Appro.', theme: 'Achat' },
  { col: 'Gestionnaire', theme: 'Achat' },
  { col: 'Type de planification', label: 'Planification', theme: 'Achat' },
  { col: 'Point de commande', label: 'Pt commande', theme: 'Achat', numeric: true },
  { col: "Délai d'achat", label: 'Délai (j)', theme: 'Achat', numeric: true },
  { col: 'EMPLACEMENT', label: 'Emplacement', theme: 'Stock' },
  { col: 'Qté en stock', label: 'Stock', theme: 'Stock', numeric: true },
  { col: 'Texte de base', theme: 'Textes', long: true },
  { col: 'Texte de commande', theme: 'Textes', long: true },
  { col: 'Note interne', theme: 'Textes', long: true },
  { col: 'Date de création', label: 'Créé le', theme: 'Traçabilité' },
  { col: 'Créé par', lib: 'Créé par Nom', theme: 'Traçabilité' },
  { col: 'Date de dernière modification', label: 'Modifié le', theme: 'Traçabilité' },
  { col: 'Dernière modification par', lib: 'Dernière modification par Nom', label: 'Modifié par', theme: 'Traçabilité' },
];
const THEMES = Array.from(new Set(FIELDS.map((f) => f.theme)));

const PRESETS: Record<string, string[]> = {
  Essentiel: ['N° article', 'Description article', 'Site', "Classe d'actifs", 'Catégorie article',
    'Groupe produit 1', "Groupe d'achat", 'EMPLACEMENT', 'Qté en stock', 'Date de dernière modification'],
  Achat: ['N° article', 'Description article', "Groupe d'achat", 'Type approvisionnement', 'Gestionnaire',
    'Type de planification', 'Point de commande', "Délai d'achat", 'U/M Stock'],
  Stock: ['N° article', 'Description article', 'Site', 'EMPLACEMENT', 'Qté en stock', 'Classe ABC',
    'Statut article', 'U/M Stock', 'Groupe comptable'],
  Traçabilité: ['N° article', 'Description article', 'Ancien numéro article', 'Date de création', 'Créé par',
    'Date de dernière modification', 'Dernière modification par'],
  Tout: FIELDS.map((f) => f.col),
};

const CLASSE_COULEURS: Record<string, string> = {
  MAINTENANCE: '#1976d2', MAGASIN: '#2e7d32', SERVICE: '#ed6c02', PRODUCTION: '#9c27b0', NON_STOCKE: '#78909c',
};
const SITE_COULEURS: Record<string, string> = { SJ: '#00897b', CS: '#5c6bc0' };
const couleur = (palette: Record<string, string>, code: string) => palette[code] ?? '#bdbdbd';

const COLS_KEY = 'sapArticles.colonnes';
const lireColonnes = (): string[] => {
  try {
    const v = JSON.parse(localStorage.getItem(COLS_KEY) || 'null');
    if (Array.isArray(v) && v.length) return v;
  } catch { /* stockage indisponible */ }
  return PRESETS.Essentiel;
};

const fmtNombre = (v: any) => {
  if (v === null || v === undefined || v === '') return '';
  const n = Number(v);
  return Number.isNaN(n) ? String(v) : n.toLocaleString('fr-FR', { maximumFractionDigits: 3 });
};

const libelleValeur = (v: FacetValue) =>
  v.code === VIDE ? '(non renseigné)' : v.libelle ? `${v.code} — ${v.libelle}` : v.code;

// ---------------------------------------------------------------------------
// Barre de répartition cliquable (classe d'actifs, site)
// ---------------------------------------------------------------------------
const RepartitionBar: React.FC<{
  titre: string; valeurs: FacetValue[]; actifs: string[]; palette: Record<string, string>;
  onToggle: (code: string) => void;
}> = ({ titre, valeurs, actifs, palette, onToggle }) => {
  const total = valeurs.reduce((s, v) => s + v.nb, 0) || 1;
  return (
    <Box sx={{ flex: 1, minWidth: 280 }}>
      <Typography variant="overline" color="text.secondary">{titre}</Typography>
      <Box sx={{ display: 'flex', height: 30, borderRadius: 1, overflow: 'hidden', bgcolor: 'action.hover' }}>
        {valeurs.map((v) => {
          const actif = actifs.length === 0 || actifs.includes(v.code);
          return (
            <Tooltip key={v.code} title={`${libelleValeur(v)} : ${v.nb.toLocaleString('fr-FR')} articles`}>
              <Box
                onClick={() => onToggle(v.code)}
                sx={{
                  width: `${(v.nb / total) * 100}%`, minWidth: 4, bgcolor: couleur(palette, v.code),
                  opacity: actif ? 1 : 0.25, cursor: 'pointer', transition: 'opacity .2s',
                  borderRight: '2px solid', borderColor: 'background.paper',
                  '&:hover': { opacity: 0.85 },
                }}
              />
            </Tooltip>
          );
        })}
      </Box>
      <Stack direction="row" spacing={1.5} sx={{ mt: 0.75, flexWrap: 'wrap', rowGap: 0.5 }}>
        {valeurs.map((v) => (
          <Box key={v.code} onClick={() => onToggle(v.code)}
            sx={{ display: 'flex', alignItems: 'center', gap: 0.5, cursor: 'pointer',
              opacity: actifs.length === 0 || actifs.includes(v.code) ? 1 : 0.45 }}>
            <Box sx={{ width: 10, height: 10, borderRadius: '50%', bgcolor: couleur(palette, v.code) }} />
            <Typography variant="caption">
              {v.code === VIDE ? '(vide)' : v.libelle ?? v.code} <b>{v.nb.toLocaleString('fr-FR')}</b>
            </Typography>
          </Box>
        ))}
      </Stack>
    </Box>
  );
};

// ---------------------------------------------------------------------------
// Cellule code + libellé
// ---------------------------------------------------------------------------
const Cellule: React.FC<{ field: Field; row: Row }> = ({ field, row }) => {
  const v = row[field.col];
  if (field.col === "Classe d'actifs" && v) {
    return <Chip size="small" label={row[field.lib!] ?? v}
      sx={{ bgcolor: couleur(CLASSE_COULEURS, v), color: '#fff', fontWeight: 500 }} />;
  }
  if (field.numeric) return <>{fmtNombre(v)}</>;
  if (v === null || v === undefined || v === '') return <Typography variant="body2" color="text.disabled">—</Typography>;
  if (field.lib) {
    const lib = row[field.lib];
    return (
      <Box sx={{ lineHeight: 1.2 }}>
        <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600 }}>{v}</Typography>
        {lib && <Typography variant="caption" color="text.secondary" noWrap sx={{ display: 'block', maxWidth: 220 }}>{lib}</Typography>}
      </Box>
    );
  }
  if (field.long) {
    return (
      <Tooltip title={<span style={{ whiteSpace: 'pre-wrap' }}>{v}</span>} enterDelay={400}>
        <Typography variant="body2" noWrap sx={{ maxWidth: 320 }}>{v}</Typography>
      </Tooltip>
    );
  }
  return <>{v}</>;
};

// ---------------------------------------------------------------------------
// Fiche article (tiroir)
// ---------------------------------------------------------------------------
const FicheArticle: React.FC<{ numero: string | null; onClose: () => void }> = ({ numero, onClose }) => {
  const navigate = useNavigate();
  const [data, setData] = useState<{ article: Row; usages: Row[]; anomalies_libelles: Record<string, string> } | null>(null);
  const [erreur, setErreur] = useState<string | null>(null);

  useEffect(() => {
    if (!numero) return;
    setData(null);
    setErreur(null);
    api.get(`/sap-data/articles/${encodeURIComponent(numero)}`)
      .then((res) => setData(res.data))
      .catch(() => setErreur("Impossible de charger la fiche de l'article."));
  }, [numero]);

  const a = data?.article;
  return (
    <Drawer anchor="right" open={!!numero} onClose={onClose}
      PaperProps={{ sx: { width: { xs: '100%', sm: 560 } } }}>
      {!a && !erreur && <LinearProgress />}
      {erreur && <Alert severity="error" sx={{ m: 2 }}>{erreur}</Alert>}
      {a && (
        <Box>
          <Box sx={{ p: 2.5, color: '#fff', background: `linear-gradient(135deg, ${couleur(CLASSE_COULEURS, a["Classe d'actifs"])} 0%, #263238 100%)` }}>
            <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
              <Box>
                <Typography variant="overline" sx={{ opacity: 0.8 }}>
                  {a["Classe d'actifs Description"] ?? 'Article'} · {a['Catégorie article Description'] ?? a['Catégorie article']}
                </Typography>
                <Typography variant="h5" sx={{ fontFamily: 'monospace', fontWeight: 700 }}>{a['N° article']}</Typography>
                <Typography variant="body1">{a['Description article']}</Typography>
              </Box>
              <IconButton onClick={onClose} sx={{ color: '#fff' }}><CloseIcon /></IconButton>
            </Stack>
            <Stack direction="row" spacing={1} sx={{ mt: 1.5, flexWrap: 'wrap', rowGap: 1 }}>
              <Chip size="small" label={`${a.Site} · ${a['Site Description'] ?? ''}`} sx={{ bgcolor: 'rgba(255,255,255,.2)', color: '#fff' }} />
              <Chip size="small" icon={<StructureIcon sx={{ color: '#fff !important' }} />}
                label={a.dans_structure ? `Structure IH02 · ${a.nb_usages} ligne(s) de nomenclature` : 'Hors structure IH02'}
                sx={{ bgcolor: a.dans_structure ? 'rgba(255,255,255,.3)' : 'rgba(0,0,0,.25)', color: '#fff' }} />
              <Chip size="small" icon={<CatalogueIcon sx={{ color: '#fff !important' }} />}
                label={a.dans_catalogue ? 'Dans part_catalog' : 'Absent de part_catalog'}
                sx={{ bgcolor: a.dans_catalogue ? 'rgba(255,255,255,.3)' : 'rgba(0,0,0,.25)', color: '#fff' }} />
            </Stack>
          </Box>

          <Box sx={{ p: 2.5 }}>
            {a.anomalies.length > 0 && (
              <Alert severity="warning" icon={<WarningIcon />} sx={{ mb: 2 }}>
                {a.anomalies.map((k: string) => data!.anomalies_libelles[k]).join(' · ')}
              </Alert>
            )}

            {THEMES.filter((t) => t !== 'Textes').map((theme) => (
              <Box key={theme} sx={{ mb: 2 }}>
                <Typography variant="overline" color="primary">{theme}</Typography>
                <Box sx={{ display: 'grid', gridTemplateColumns: '170px 1fr', rowGap: 0.75, columnGap: 2 }}>
                  {FIELDS.filter((f) => f.theme === theme).map((f) => (
                    <React.Fragment key={f.col}>
                      <Typography variant="body2" color="text.secondary">{f.label ?? f.col}</Typography>
                      <Typography variant="body2">
                        {a[f.col] === null || a[f.col] === '' ? <span style={{ color: '#aaa' }}>—</span>
                          : <>{f.numeric ? fmtNombre(a[f.col]) : a[f.col]}{f.lib && a[f.lib] ? <span style={{ color: '#777' }}> — {a[f.lib]}</span> : null}</>}
                      </Typography>
                    </React.Fragment>
                  ))}
                </Box>
                <Divider sx={{ mt: 1.5 }} />
              </Box>
            ))}

            <Typography variant="overline" color="primary">Textes SAP</Typography>
            {['Texte de base', 'Texte de commande', 'Note interne'].map((t) => (
              <Paper key={t} variant="outlined" sx={{ p: 1.5, mb: 1, bgcolor: a[t] ? 'background.paper' : 'action.hover' }}>
                <Typography variant="caption" color="text.secondary">{t}</Typography>
                <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap', fontFamily: a[t] ? 'monospace' : undefined }}>
                  {a[t] ?? 'Aucun texte'}
                </Typography>
              </Paper>
            ))}

            <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mt: 2 }}>
              <Typography variant="overline" color="primary">Utilisation en maintenance</Typography>
              {a.dans_structure && (
                <Button size="small" endIcon={<OpenIcon />}
                  onClick={() => navigate(`/maintenance/ih02?search=${encodeURIComponent(a['N° article'])}`)}>
                  Ouvrir dans IH02
                </Button>
              )}
            </Stack>
            {data!.usages.length === 0 ? (
              <Typography variant="body2" color="text.secondary">
                {a.dans_structure ? 'Article présent dans la structure, cité dans aucune nomenclature de poste.' : "Cet article n'apparaît pas dans la structure de maintenance."}
              </Typography>
            ) : (
              <Table size="small">
                <TableHead>
                  <TableRow><TableCell>Parent</TableCell><TableCell>Désignation</TableCell><TableCell align="right">Qté</TableCell></TableRow>
                </TableHead>
                <TableBody>
                  {data!.usages.map((u) => (
                    <TableRow key={`${u.object_type}-${u.code}`}>
                      <TableCell sx={{ fontFamily: 'monospace' }}>
                        <Tooltip title={u.object_type === 'FUNC_LOC' ? 'Poste technique' : 'Article (nomenclature)'}>
                          <span>{u.code}</span>
                        </Tooltip>
                      </TableCell>
                      <TableCell>{u.designation}</TableCell>
                      <TableCell align="right">{fmtNombre(u.quantite)}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </Box>
        </Box>
      )}
    </Drawer>
  );
};

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------
const SapArticles: React.FC = () => {
  const [mode, setMode] = useState<Mode>('liste');
  const [search, setSearch] = useState('');
  const [searchDebounced, setSearchDebounced] = useState('');
  const [filters, setFilters] = useState<Filters>({});
  const [anomalie, setAnomalie] = useState<string>('');
  const [structure, setStructure] = useState<string>('');
  const [facets, setFacets] = useState<FacetsResponse | null>(null);
  const [rows, setRows] = useState<Row[]>([]);
  const [total, setTotal] = useState(0);
  const [groupes, setGroupes] = useState<Row[]>([]);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [sort, setSort] = useState('N° article');
  const [dir, setDir] = useState<'asc' | 'desc'>('asc');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [colonnes, setColonnes] = useState<string[]>(lireColonnes);
  const [colsAnchor, setColsAnchor] = useState<HTMLElement | null>(null);
  const [fiche, setFiche] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);

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
    if (structure) p.structure = structure;
    return p;
  }, [searchDebounced, filters, anomalie, structure]);

  // Un changement de filtre ramène à la première page
  useEffect(() => { setPage(0); }, [params]);

  useEffect(() => {
    api.get('/sap-data/articles/facettes', { params })
      .then((res) => setFacets(res.data))
      .catch(() => setError('Impossible de charger les compteurs.'));
  }, [params]);

  const charger = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      if (mode === 'liste') {
        const res = await api.get('/sap-data/articles', {
          params: { ...params, page: page + 1, page_size: pageSize, sort, dir },
        });
        setRows(res.data.rows);
        setTotal(res.data.total);
      } else {
        const res = await api.get('/sap-data/articles/groupes', { params: { ...params, par: mode } });
        setGroupes(res.data.groupes);
      }
    } catch {
      setError('Impossible de charger les articles.');
    } finally {
      setLoading(false);
    }
  }, [mode, params, page, pageSize, sort, dir]);

  useEffect(() => { charger(); }, [charger]);

  const toggleFiltre = (k: FacetKey, code: string) =>
    setFilters((f) => {
      const cur = f[k] ?? [];
      return { ...f, [k]: cur.includes(code) ? cur.filter((c) => c !== code) : [...cur, code] };
    });

  const effacer = () => { setFilters({}); setSearch(''); setAnomalie(''); setStructure(''); };
  const nbFiltres = Object.values(filters).reduce((s, v) => s + (v?.length ?? 0), 0)
    + (searchDebounced ? 1 : 0) + (anomalie ? 1 : 0) + (structure ? 1 : 0);

  const exporter = async () => {
    try {
      setExporting(true);
      const res = await api.get('/sap-data/articles/export.xlsx', { params, responseType: 'blob' });
      const match = /filename="?([^";]+)"?/.exec(res.headers['content-disposition'] ?? '');
      const url = window.URL.createObjectURL(res.data);
      const link = document.createElement('a');
      link.href = url;
      link.download = match?.[1] ?? 'articles_sap.xlsx';
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch {
      setError("L'export Excel a échoué.");
    } finally {
      setExporting(false);
    }
  };

  const champs = FIELDS.filter((f) => colonnes.includes(f.col));
  const facette = (k: FacetKey) => facets?.facettes[k];

  const filtreAuto = (k: FacetKey, largeur = 220) => {
    const f = facette(k);
    const options = f?.valeurs ?? [];
    const valeur = options.filter((o) => filters[k]?.includes(o.code));
    return (
      <Autocomplete
        key={k}
        multiple
        size="small"
        limitTags={1}
        options={options}
        value={valeur}
        isOptionEqualToValue={(o, v) => o.code === v.code}
        getOptionLabel={libelleValeur}
        onChange={(_, vals) => setFilters((cur) => ({ ...cur, [k]: vals.map((v) => v.code) }))}
        renderOption={(props, o) => (
          <li {...props} key={o.code}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', width: '100%', gap: 1 }}>
              <span>{libelleValeur(o)}</span>
              <Typography variant="caption" color="text.secondary">{o.nb.toLocaleString('fr-FR')}</Typography>
            </Box>
          </li>
        )}
        renderInput={(p) => <TextField {...p} label={f?.titre ?? k} />}
        sx={{ width: largeur }}
      />
    );
  };

  return (
    <Box sx={{ p: { xs: 1.5, md: 3 } }}>
      {/* En-tête */}
      <Stack direction={{ xs: 'column', md: 'row' }} justifyContent="space-between" alignItems={{ md: 'center' }} spacing={2} sx={{ mb: 2 }}>
        <Stack direction="row" spacing={1.5} alignItems="center">
          <Box sx={{ p: 1.2, borderRadius: 2, bgcolor: '#fce4ec', display: 'flex' }}>
            <ArticleIcon sx={{ color: '#d81b60', fontSize: 32 }} />
          </Box>
          <Box>
            <Typography variant="h4" sx={{ fontWeight: 700 }}>Articles SAP</Typography>
            <Typography variant="body2" color="text.secondary">
              Périmètre société STJN + articles de maintenance · {facets ? facets.total.toLocaleString('fr-FR') : '…'} articles
              {nbFiltres > 0 ? ' (sélection)' : ''}
            </Typography>
          </Box>
        </Stack>
        <Stack direction="row" spacing={1} alignItems="center">
          <ToggleButtonGroup size="small" exclusive value={mode} onChange={(_, m) => m && setMode(m)}>
            <ToggleButton value="liste">Liste</ToggleButton>
            <ToggleButton value="gestionnaire">Par gestionnaire</ToggleButton>
            <ToggleButton value="groupe_achat">Par groupe d'achat</ToggleButton>
          </ToggleButtonGroup>
          <Button variant="contained" startIcon={<ExcelIcon />} onClick={exporter} disabled={exporting}>
            {exporting ? 'Export…' : 'Excel'}
          </Button>
        </Stack>
      </Stack>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}

      {/* Répartition */}
      <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
        <Stack direction={{ xs: 'column', lg: 'row' }} spacing={3}>
          {facets && (
            <>
              <RepartitionBar titre="Classe d'actifs" valeurs={facets.facettes.classe.valeurs}
                actifs={filters.classe ?? []} palette={CLASSE_COULEURS} onToggle={(c) => toggleFiltre('classe', c)} />
              <Box sx={{ flex: 0.45, minWidth: 220 }}>
                <RepartitionBar titre="Site" valeurs={facets.facettes.site.valeurs}
                  actifs={filters.site ?? []} palette={SITE_COULEURS} onToggle={(c) => toggleFiltre('site', c)} />
              </Box>
              <Box sx={{ flex: 0.55, minWidth: 240 }}>
                <Typography variant="overline" color="text.secondary">Intégration</Typography>
                <Stack direction="row" spacing={1}>
                  <Chip icon={<StructureIcon />} clickable color={structure === 'oui' ? 'primary' : 'default'}
                    variant={structure === 'oui' ? 'filled' : 'outlined'}
                    onClick={() => setStructure(structure === 'oui' ? '' : 'oui')}
                    label={`Structure IH02 · ${facets.structure.toLocaleString('fr-FR')}`} />
                  <Chip clickable color={structure === 'non' ? 'primary' : 'default'}
                    variant={structure === 'non' ? 'filled' : 'outlined'}
                    onClick={() => setStructure(structure === 'non' ? '' : 'non')}
                    label={`Hors structure · ${(facets.total - facets.structure).toLocaleString('fr-FR')}`} />
                </Stack>
                <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.75 }}>
                  <CatalogueIcon sx={{ fontSize: 14, verticalAlign: 'middle', mr: 0.5 }} />
                  {facets.catalogue.toLocaleString('fr-FR')} dans le catalogue IFS (part_catalog)
                </Typography>
              </Box>
            </>
          )}
        </Stack>
      </Paper>

      {/* Qualité */}
      {facets && (
        <Stack direction="row" spacing={1} sx={{ mb: 2, flexWrap: 'wrap', rowGap: 1 }} alignItems="center">
          <Typography variant="overline" color="text.secondary" sx={{ mr: 1 }}>Qualité des données</Typography>
          <Chip icon={<WarningIcon />} clickable
            color={anomalie === 'toutes' ? 'warning' : 'default'} variant={anomalie === 'toutes' ? 'filled' : 'outlined'}
            onClick={() => setAnomalie(anomalie === 'toutes' ? '' : 'toutes')}
            label={`Au moins une anomalie · ${facets.anomalies_total.toLocaleString('fr-FR')}`} />
          {facets.anomalies.map((a) => (
            <Chip key={a.cle} clickable size="small"
              color={anomalie === a.cle ? 'warning' : 'default'} variant={anomalie === a.cle ? 'filled' : 'outlined'}
              onClick={() => setAnomalie(anomalie === a.cle ? '' : a.cle)}
              label={`${a.libelle} · ${a.nb.toLocaleString('fr-FR')}`} />
          ))}
        </Stack>
      )}

      {/* Filtres */}
      <Paper variant="outlined" sx={{ p: 1.5, mb: 2 }}>
        <Stack direction="row" spacing={1.5} sx={{ flexWrap: 'wrap', rowGap: 1.5 }} alignItems="center">
          <TextField size="small" placeholder="N°, description, ancien n°, textes SAP…" value={search}
            onChange={(e) => setSearch(e.target.value)} sx={{ width: 300 }}
            InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment> }} />
          {filtreAuto('categorie')}
          {filtreAuto('groupe_achat', 250)}
          {filtreAuto('gestionnaire', 180)}
          {filtreAuto('statut', 150)}
          {filtreAuto('planification', 170)}
          <Box sx={{ flexGrow: 1 }} />
          {nbFiltres > 0 && <Button size="small" onClick={effacer}>Effacer les filtres ({nbFiltres})</Button>}
          {mode === 'liste' && (
            <Badge badgeContent={colonnes.length} color="primary">
              <Button size="small" variant="outlined" startIcon={<ColumnsIcon />} onClick={(e) => setColsAnchor(e.currentTarget)}>
                Colonnes
              </Button>
            </Badge>
          )}
        </Stack>
      </Paper>

      {/* Choix des colonnes */}
      <Menu anchorEl={colsAnchor} open={!!colsAnchor} onClose={() => setColsAnchor(null)}
        PaperProps={{ sx: { maxHeight: 520, width: 300 } }}>
        <Box sx={{ px: 2, py: 1, display: 'flex', gap: 0.5, flexWrap: 'wrap' }}>
          {Object.keys(PRESETS).map((p) => (
            <Chip key={p} size="small" label={p} clickable onClick={() => setColonnes(PRESETS[p])} />
          ))}
        </Box>
        <Divider />
        {THEMES.map((t) => [
          <ListSubheader key={`h-${t}`} sx={{ lineHeight: '32px' }}>{t}</ListSubheader>,
          ...FIELDS.filter((f) => f.theme === t).map((f) => (
            <MenuItem key={f.col} dense disabled={f.col === 'N° article'}
              onClick={() => setColonnes((c) => (c.includes(f.col) ? c.filter((x) => x !== f.col) : [...c, f.col]))}>
              <Checkbox size="small" checked={colonnes.includes(f.col)} sx={{ py: 0 }} />
              <ListItemText primary={f.label ?? f.col} secondary={f.lib ? '+ libellé' : undefined} />
            </MenuItem>
          )),
        ])}
      </Menu>

      {loading && <LinearProgress sx={{ mb: 0.5 }} />}

      {mode === 'liste' ? (
        <Paper variant="outlined">
          <TableContainer sx={{ maxHeight: 'calc(100vh - 420px)', minHeight: 300 }}>
            <Table size="small" stickyHeader>
              <TableHead>
                <TableRow>
                  <TableCell sx={{ width: 70 }} />
                  {champs.map((f) => (
                    <TableCell key={f.col} align={f.numeric ? 'right' : 'left'} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>
                      <TableSortLabel active={sort === f.col} direction={sort === f.col ? dir : 'asc'}
                        onClick={() => { if (sort === f.col) setDir(dir === 'asc' ? 'desc' : 'asc'); else { setSort(f.col); setDir('asc'); } }}>
                        {f.label ?? f.col}
                      </TableSortLabel>
                    </TableCell>
                  ))}
                </TableRow>
              </TableHead>
              <TableBody>
                {rows.map((r) => (
                  <TableRow key={r['N° article']} hover sx={{ cursor: 'pointer' }} onClick={() => setFiche(r['N° article'])}>
                    <TableCell sx={{ whiteSpace: 'nowrap' }}>
                      <Tooltip title={r.dans_structure ? `Structure IH02 (${r.nb_usages} ligne(s) de nomenclature)` : 'Hors structure IH02'}>
                        <StructureIcon fontSize="small" sx={{ color: r.dans_structure ? 'primary.main' : 'action.disabled' }} />
                      </Tooltip>
                      <Tooltip title={r.dans_catalogue ? 'Dans part_catalog' : 'Absent de part_catalog'}>
                        <CatalogueIcon fontSize="small" sx={{ color: r.dans_catalogue ? 'success.main' : 'action.disabled', ml: 0.5 }} />
                      </Tooltip>
                      {r.anomalies.length > 0 && (
                        <Tooltip title={r.anomalies.map((k: string) => facets?.anomalies.find((a) => a.cle === k)?.libelle ?? k).join(' · ')}>
                          <WarningIcon fontSize="small" sx={{ color: 'warning.main', ml: 0.5 }} />
                        </Tooltip>
                      )}
                    </TableCell>
                    {champs.map((f) => (
                      <TableCell key={f.col} align={f.numeric ? 'right' : 'left'}
                        sx={f.col === 'N° article' ? { fontFamily: 'monospace', fontWeight: 600 } : undefined}>
                        <Cellule field={f} row={r} />
                      </TableCell>
                    ))}
                  </TableRow>
                ))}
                {!loading && rows.length === 0 && (
                  <TableRow><TableCell colSpan={champs.length + 1} align="center" sx={{ py: 6, color: 'text.secondary' }}>
                    Aucun article ne correspond aux filtres.
                  </TableCell></TableRow>
                )}
              </TableBody>
            </Table>
          </TableContainer>
          <TablePagination component="div" count={total} page={page} rowsPerPage={pageSize}
            rowsPerPageOptions={[25, 50, 100, 200]} labelRowsPerPage="Lignes par page"
            labelDisplayedRows={({ from, to, count }) => `${from}–${to} sur ${count.toLocaleString('fr-FR')}`}
            onPageChange={(_, p) => setPage(p)} onRowsPerPageChange={(e) => { setPageSize(Number(e.target.value)); setPage(0); }} />
        </Paper>
      ) : (
        <Paper variant="outlined">
          <TableContainer sx={{ maxHeight: 'calc(100vh - 420px)', minHeight: 300 }}>
            <Table size="small" stickyHeader>
              <TableHead>
                <TableRow>
                  <TableCell sx={{ fontWeight: 600 }}>{mode === 'gestionnaire' ? 'Gestionnaire' : "Groupe d'achat"}</TableCell>
                  <TableCell sx={{ fontWeight: 600, width: '35%' }}>Articles</TableCell>
                  <TableCell align="right" sx={{ fontWeight: 600 }}>En stock</TableCell>
                  <TableCell align="right" sx={{ fontWeight: 600 }}>En maintenance</TableCell>
                  <TableCell align="right" sx={{ fontWeight: 600 }}>Anomalies</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Sites</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {groupes.map((g) => {
                  const max = groupes[0]?.articles || 1;
                  return (
                    <TableRow key={g.code} hover sx={{ cursor: 'pointer' }}
                      onClick={() => { setFilters((f) => ({ ...f, [mode]: [g.code] })); setMode('liste'); }}>
                      <TableCell>
                        <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600 }}>
                          {g.code === VIDE ? '(non renseigné)' : g.code}
                        </Typography>
                        {g.libelle && <Typography variant="caption" color="text.secondary">{g.libelle}</Typography>}
                      </TableCell>
                      <TableCell>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Box sx={{ flex: 1, height: 10, bgcolor: 'action.hover', borderRadius: 5, overflow: 'hidden' }}>
                            <Box sx={{ width: `${(g.articles / max) * 100}%`, height: '100%', bgcolor: 'primary.main' }} />
                          </Box>
                          <Typography variant="body2" sx={{ minWidth: 56, textAlign: 'right' }}>{g.articles.toLocaleString('fr-FR')}</Typography>
                        </Stack>
                      </TableCell>
                      <TableCell align="right">{g.en_stock.toLocaleString('fr-FR')}</TableCell>
                      <TableCell align="right">{g.en_maintenance.toLocaleString('fr-FR')}</TableCell>
                      <TableCell align="right">
                        {g.anomalies > 0
                          ? <Chip size="small" color="warning" variant="outlined" label={g.anomalies.toLocaleString('fr-FR')} />
                          : '0'}
                      </TableCell>
                      <TableCell>{g.sites}</TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </TableContainer>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', p: 1.5 }}>
            Cliquer sur une ligne pour afficher ses articles dans la liste.
          </Typography>
        </Paper>
      )}

      <FicheArticle numero={fiche} onClose={() => setFiche(null)} />
    </Box>
  );
};

export default SapArticles;
