import {
  AccountTree as StructureIcon,
  Build as EquipmentIcon,
  Close as CloseIcon,
  FileDownload as ExcelIcon,
  Inventory2 as ArticleIcon,
  OpenInNew as OpenIcon,
  Search as SearchIcon,
  SubdirectoryArrowRight as FilsIcon,
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
  Divider,
  Drawer,
  IconButton,
  InputAdornment,
  LinearProgress,
  Link,
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
import { useNavigate } from 'react-router-dom';
import { couleur, FacetteAuto, FacetValue, nb, RepartitionBar, telecharger } from '../components/data/facettes';
import api from '../services/api';

// Écran Maintenance > Équipements : consultation seule (demande du 2026-10-09), sur le
// modèle de Données SAP > Articles. API backend/api/equipment_browser.py ; la fiche
// complète vient aussi de /maintenance/equipment/<id>/details (api/maintenance_hierarchy.py).

type Row = Record<string, any>;
type FacetKey = 'position' | 'categorie' | 'division' | 'poste_travail' | 'statut' | 'type_objet' | 'lien_article';
type Filters = Partial<Record<FacetKey, string[]>>;
interface Statut { code: string; libelle: string }
interface FacetsResponse {
  facettes: Record<FacetKey, { titre: string; valeurs: FacetValue[] }>;
  total: number;
  anomalies: { cle: string; libelle: string; nb: number }[];
  anomalies_total: number;
}

interface Field { col: string; lib?: string; label: string; theme: string; long?: boolean; mono?: boolean; tri?: boolean }
const FIELDS: Field[] = [
  { col: 'numero', label: 'N° équipement', theme: 'Identification', mono: true, tri: true },
  { col: 'description', label: 'Description', theme: 'Identification', long: true, tri: true },
  { col: 'categorie', label: 'Catégorie', theme: 'Identification', tri: true },
  { col: 'type_objet', label: "Type d'objet", theme: 'Identification', tri: true },
  { col: 'statuts', label: 'Statuts SAP', theme: 'Identification' },
  { col: 'article', lib: 'article_description', label: 'N° article', theme: 'Article', mono: true, tri: true },
  { col: 'construction', lib: 'construction_description', label: 'Type de construction', theme: 'Article', mono: true, tri: true },
  { col: 'position', label: 'Position', theme: 'Structure', tri: true },
  { col: 'parent_code', lib: 'parent_designation', label: 'Parent', theme: 'Structure', mono: true, tri: true },
  { col: 'division', lib: 'division_description', label: 'Division', theme: 'Organisation', tri: true },
  { col: 'poste_travail', lib: 'poste_travail_description', label: 'Poste de travail', theme: 'Organisation', tri: true },
  { col: 'fabricant', label: 'Fabricant', theme: 'Technique', tri: true },
  { col: 'modele', label: 'Modèle', theme: 'Technique', tri: true },
  { col: 'numero_serie', label: 'N° de série', theme: 'Technique', mono: true, tri: true },
  { col: 'numero_inventaire', label: "N° d'inventaire", theme: 'Technique', mono: true, tri: true },
];
const THEMES = Array.from(new Set(FIELDS.map((f) => f.theme)));

const PRESETS: Record<string, string[]> = {
  Essentiel: ['numero', 'description', 'article', 'construction', 'position', 'parent_code', 'poste_travail', 'statuts'],
  Structure: ['numero', 'description', 'position', 'parent_code', 'division', 'poste_travail'],
  Technique: ['numero', 'description', 'categorie', 'fabricant', 'modele', 'numero_serie', 'numero_inventaire'],
  Tout: FIELDS.map((f) => f.col),
};

const POSITION_COULEURS: Record<string, string> = {
  FUNC_LOC: '#1976d2', EQUIPMENT: '#00897b', SANS_PARENT: '#ef6c00', HORS_STRUCTURE: '#c62828',
};
const CATEGORIE_COULEURS: Record<string, string> = {
  M: '#5c6bc0', Q: '#26a69a', Z: '#8d6e63', R: '#ab47bc', Y: '#ffa726', P: '#78909c',
};
const POSITION_ICONE: Record<string, string> = { FUNC_LOC: 'Poste technique', EQUIPMENT: 'Équipement' };

const COLS_KEY = 'equipements.colonnes';
const lireColonnes = (): string[] => {
  try {
    const v = JSON.parse(localStorage.getItem(COLS_KEY) || 'null');
    if (Array.isArray(v) && v.length) return v;
  } catch { /* stockage indisponible */ }
  return PRESETS.Essentiel;
};

const Statuts: React.FC<{ statuts: Statut[] }> = ({ statuts }) => (
  <Stack direction="row" spacing={0.5} sx={{ flexWrap: 'wrap', rowGap: 0.5 }}>
    {statuts.map((s) => (
      <Tooltip key={s.code} title={`${s.code} · ${s.libelle}`}>
        <Chip size="small" variant="outlined" label={s.libelle.split(' — ')[0]}
          color={s.code === 'I0320' || s.code === 'I0076' ? 'error' : 'default'} sx={{ height: 20, fontSize: '0.7rem' }} />
      </Tooltip>
    ))}
  </Stack>
);

// ---------------------------------------------------------------------------
// Cellule
// ---------------------------------------------------------------------------
const Cellule: React.FC<{ field: Field; row: Row; positions: Record<string, string> }> = ({ field, row, positions }) => {
  const v = row[field.col];
  if (field.col === 'statuts') return <Statuts statuts={v ?? []} />;
  if (field.col === 'position') {
    return <Chip size="small" label={positions[v] ?? v}
      sx={{ bgcolor: couleur(POSITION_COULEURS, v), color: '#fff', fontWeight: 500 }} />;
  }
  if (v === null || v === undefined || v === '') return <Typography variant="body2" color="text.disabled">—</Typography>;
  if (field.lib) {
    const lib = row[field.lib];
    return (
      <Box sx={{ lineHeight: 1.2 }}>
        <Typography variant="body2" sx={{ fontFamily: field.mono ? 'monospace' : undefined, fontWeight: 600 }}>{v}</Typography>
        {lib
          ? <Typography variant="caption" color="text.secondary" noWrap sx={{ display: 'block', maxWidth: 230 }}>{lib}</Typography>
          : (field.col === 'article' || field.col === 'construction')
            ? <Typography variant="caption" color="warning.main">absent du catalogue</Typography> : null}
      </Box>
    );
  }
  if (field.long) return <Typography variant="body2" noWrap sx={{ maxWidth: 340 }}>{v}</Typography>;
  return <Typography variant="body2" sx={{ fontFamily: field.mono ? 'monospace' : undefined }}>{v}</Typography>;
};

// ---------------------------------------------------------------------------
// Fiche équipement (tiroir)
// ---------------------------------------------------------------------------
const Info: React.FC<{ label: string; value: any; mono?: boolean }> = ({ label, value, mono }) => (
  <>
    <Typography variant="body2" color="text.secondary">{label}</Typography>
    <Typography variant="body2" sx={{ fontFamily: mono ? 'monospace' : undefined }}>
      {value === null || value === undefined || String(value).trim() === '' ? <span style={{ color: '#aaa' }}>—</span> : value}
    </Typography>
  </>
);

const FicheEquipement: React.FC<{ numero: string | null; onClose: () => void }> = ({ numero, onClose }) => {
  const navigate = useNavigate();
  const [data, setData] = useState<any>(null);
  const [details, setDetails] = useState<Row | null>(null);
  const [erreur, setErreur] = useState<string | null>(null);

  useEffect(() => {
    if (!numero) return;
    setData(null);
    setDetails(null);
    setErreur(null);
    api.get(`/maintenance/equipment-browser/${encodeURIComponent(numero)}/structure`)
      .then((res) => setData(res.data))
      .catch(() => setErreur("Impossible de charger la fiche de l'équipement."));
    api.get(`/maintenance/equipment/${encodeURIComponent(numero.padStart(18, '0'))}/details`)
      .then((res) => setDetails(res.data?.data ?? null))
      .catch(() => setDetails(null));
  }, [numero]);

  const e = data?.equipement;
  const versArticle = (n: string) => navigate(`/sap-data/articles?search=${encodeURIComponent(n)}`);
  const lienArticle = (n: string | null, lib: string | null, cat: string | null) => (n ? (
    <Box>
      <Link component="button" variant="body2" onClick={() => versArticle(n)} sx={{ fontFamily: 'monospace', fontWeight: 600 }}>
        {n}
      </Link>
      <Typography variant="caption" color={lib ? 'text.secondary' : 'warning.main'} sx={{ display: 'block' }}>
        {lib ? `${lib}${cat ? ` · ${cat}` : ''}` : 'Absent du catalogue des articles'}
      </Typography>
    </Box>
  ) : <span style={{ color: '#aaa' }}>—</span>);

  return (
    <Drawer anchor="right" open={!!numero} onClose={onClose} PaperProps={{ sx: { width: { xs: '100%', sm: 580 } } }}>
      {!e && !erreur && <LinearProgress />}
      {erreur && <Alert severity="error" sx={{ m: 2 }}>{erreur}</Alert>}
      {e && (
        <Box>
          <Box sx={{ p: 2.5, color: '#fff', background: `linear-gradient(135deg, ${couleur(POSITION_COULEURS, e.position)} 0%, #263238 100%)` }}>
            <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
              <Box>
                <Typography variant="overline" sx={{ opacity: 0.85 }}>
                  Équipement · catégorie {e.categorie ?? '—'}{e.type_objet ? ` · ${e.type_objet}` : ''}
                </Typography>
                <Typography variant="h5" sx={{ fontFamily: 'monospace', fontWeight: 700 }}>{e.numero}</Typography>
                <Typography variant="body1">{e.description}</Typography>
              </Box>
              <IconButton onClick={onClose} sx={{ color: '#fff' }}><CloseIcon /></IconButton>
            </Stack>
            <Stack direction="row" spacing={1} sx={{ mt: 1.5, flexWrap: 'wrap', rowGap: 1 }}>
              <Chip size="small" icon={<StructureIcon sx={{ color: '#fff !important' }} />}
                label={data.positions[e.position] ?? e.position} sx={{ bgcolor: 'rgba(255,255,255,.25)', color: '#fff' }} />
              {e.statuts.map((s: Statut) => (
                <Chip key={s.code} size="small" label={s.libelle} sx={{ bgcolor: 'rgba(0,0,0,.25)', color: '#fff' }} />
              ))}
            </Stack>
          </Box>

          <Box sx={{ p: 2.5 }}>
            {e.anomalies.length > 0 && (
              <Alert severity="warning" icon={<WarningIcon />} sx={{ mb: 2 }}>
                {e.anomalies.map((k: string) => data.anomalies_libelles[k]).join(' · ')}
              </Alert>
            )}

            <Stack direction="row" justifyContent="space-between" alignItems="center">
              <Typography variant="overline" color="primary">Place dans la structure</Typography>
              {e.position !== 'HORS_STRUCTURE' && (
                <Button size="small" endIcon={<OpenIcon />}
                  onClick={() => navigate(`/maintenance/ih02?search=${encodeURIComponent(e.numero)}`)}>
                  Ouvrir dans IH02
                </Button>
              )}
            </Stack>
            {data.chemin.length === 0 ? (
              <Typography variant="body2" color="text.secondary">Équipement absent de la structure IH02.</Typography>
            ) : (
              <Box sx={{ mb: 1 }}>
                {data.chemin.map((c: Row, i: number) => {
                  const dernier = i === data.chemin.length - 1;
                  return (
                    <Box key={`${c.object_type}-${c.code}-${i}`} sx={{ display: 'flex', alignItems: 'center', pl: i * 1.5, py: 0.25 }}>
                      {i > 0 && <FilsIcon sx={{ fontSize: 16, color: 'text.disabled', mr: 0.5 }} />}
                      <Tooltip title={POSITION_ICONE[c.object_type] ?? c.object_type}>
                        <Box sx={{ width: 8, height: 8, borderRadius: '50%', mr: 1, flexShrink: 0,
                          bgcolor: c.object_type === 'FUNC_LOC' ? '#1976d2' : '#00897b' }} />
                      </Tooltip>
                      <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: dernier ? 700 : 500, mr: 1 }}>{c.code}</Typography>
                      <Typography variant="caption" color="text.secondary" noWrap>{c.designation}</Typography>
                    </Box>
                  );
                })}
                {e.position === 'SANS_PARENT' && (
                  <Typography variant="caption" color="warning.main">Aucun parent : l'équipement est à la racine de la structure.</Typography>
                )}
              </Box>
            )}
            <Divider sx={{ my: 1.5 }} />

            <Typography variant="overline" color="primary">Article</Typography>
            <Box sx={{ display: 'grid', gridTemplateColumns: '170px 1fr', rowGap: 1, columnGap: 2, mb: 1.5 }}>
              <Typography variant="body2" color="text.secondary">N° article</Typography>
              {lienArticle(e.article, e.article_description, e.article_categorie)}
              <Typography variant="body2" color="text.secondary">Type de construction</Typography>
              {lienArticle(e.construction, e.construction_description, e.construction_categorie)}
            </Box>
            <Divider sx={{ my: 1.5 }} />

            <Typography variant="overline" color="primary">Organisation</Typography>
            <Box sx={{ display: 'grid', gridTemplateColumns: '170px 1fr', rowGap: 0.75, columnGap: 2, mb: 1.5 }}>
              <Info label="Division" value={e.division ? `${e.division}${e.division_description ? ` — ${e.division_description}` : ''}` : null} />
              <Info label="Poste de travail" value={e.poste_travail ? `${e.poste_travail}${e.poste_travail_description ? ` — ${e.poste_travail_description}` : ''}` : null} />
              <Info label="Groupe de planification" value={details?.planner_group} />
              <Info label="Centre de coûts" value={details?.cost_center} mono />
              <Info label="Société" value={details?.company_code} />
              <Info label="Emplacement" value={details?.location} />
            </Box>
            <Divider sx={{ my: 1.5 }} />

            <Typography variant="overline" color="primary">Caractéristiques techniques</Typography>
            <Box sx={{ display: 'grid', gridTemplateColumns: '170px 1fr', rowGap: 0.75, columnGap: 2, mb: 1.5 }}>
              <Info label="Fabricant" value={e.fabricant} />
              <Info label="Pays fabricant" value={details?.manufacturer_country} />
              <Info label="Modèle" value={e.modele} />
              <Info label="N° de série" value={e.numero_serie} mono />
              <Info label="N° d'inventaire" value={e.numero_inventaire} mono />
              <Info label="Année / mois de construction" value={[details?.construction_year, details?.construction_month].filter((x) => x && String(x).trim()).join(' / ')} />
              <Info label="Mise en service" value={details?.start_date} />
              <Info label="Valeur d'acquisition" value={details?.acquisition_value ? `${details.acquisition_value} ${details.currency ?? ''}` : null} />
            </Box>
            <Divider sx={{ my: 1.5 }} />

            <Typography variant="overline" color="primary">Traçabilité SAP</Typography>
            <Box sx={{ display: 'grid', gridTemplateColumns: '170px 1fr', rowGap: 0.75, columnGap: 2, mb: 1.5 }}>
              <Info label="Créé le / par" value={details ? [details.created_date, details.created_by].filter(Boolean).join(' · ') : null} />
              <Info label="Modifié le / par" value={details ? [details.modified_date, details.modified_by].filter(Boolean).join(' · ') : null} />
            </Box>
            <Divider sx={{ my: 1.5 }} />

            <Typography variant="overline" color="primary">Éléments rattachés ({data.fils.length})</Typography>
            {data.fils.length === 0 ? (
              <Typography variant="body2" color="text.secondary">Aucun élément sous cet équipement.</Typography>
            ) : (
              <Table size="small">
                <TableHead>
                  <TableRow><TableCell>Type</TableCell><TableCell>Code</TableCell><TableCell>Désignation</TableCell><TableCell align="right">Qté</TableCell></TableRow>
                </TableHead>
                <TableBody>
                  {data.fils.map((f: Row, i: number) => (
                    <TableRow key={`${f.object_type}-${f.code}-${i}`}>
                      <TableCell>{f.object_type === 'EQUIPMENT' ? 'Équipement' : f.object_type === 'BOM_ITEM' ? 'Nomenclature' : f.object_type}</TableCell>
                      <TableCell sx={{ fontFamily: 'monospace' }}>{f.code}</TableCell>
                      <TableCell>{f.designation}</TableCell>
                      <TableCell align="right">{f.quantity ?? ''}</TableCell>
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
const POSITIONS_PAR_DEFAUT: Record<string, string> = {
  FUNC_LOC: 'Sous un poste technique', EQUIPMENT: 'Sous un équipement',
  SANS_PARENT: 'Sans parent', HORS_STRUCTURE: 'Hors structure IH02',
};

const EquipmentPage: React.FC = () => {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [searchDebounced, setSearchDebounced] = useState('');
  const [filters, setFilters] = useState<Filters>({});
  const [anomalie, setAnomalie] = useState('');
  const [facets, setFacets] = useState<FacetsResponse | null>(null);
  const [rows, setRows] = useState<Row[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [sort, setSort] = useState('numero');
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
    return p;
  }, [searchDebounced, filters, anomalie]);

  useEffect(() => { setPage(0); }, [params]);

  useEffect(() => {
    api.get('/maintenance/equipment-browser/facettes', { params })
      .then((res) => setFacets(res.data))
      .catch(() => setError('Impossible de charger les compteurs.'));
  }, [params]);

  const charger = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get('/maintenance/equipment-browser', {
        params: { ...params, page: page + 1, page_size: pageSize, sort, dir },
      });
      setRows(res.data.rows);
      setTotal(res.data.total);
    } catch {
      setError('Impossible de charger les équipements.');
    } finally {
      setLoading(false);
    }
  }, [params, page, pageSize, sort, dir]);

  useEffect(() => { charger(); }, [charger]);

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
      await telecharger('/maintenance/equipment-browser/export.xlsx', params, 'equipements.xlsx');
    } catch {
      setError("L'export Excel a échoué.");
    } finally {
      setExporting(false);
    }
  };

  const champs = FIELDS.filter((f) => colonnes.includes(f.col));
  const facette = (k: FacetKey) => facets?.facettes[k];
  const positions = useMemo(() => {
    const m = { ...POSITIONS_PAR_DEFAUT };
    facette('position')?.valeurs.forEach((v) => { if (v.libelle) m[v.code] = v.libelle; });
    return m;
  }, [facets]); // eslint-disable-line react-hooks/exhaustive-deps

  const filtreAuto = (k: FacetKey, largeur = 200) => (
    <FacetteAuto key={k} titre={facette(k)?.titre ?? k} valeurs={facette(k)?.valeurs ?? []} largeur={largeur}
      selection={filters[k] ?? []} onChange={(codes) => setFilters((cur) => ({ ...cur, [k]: codes }))} />
  );

  return (
    <Box sx={{ p: { xs: 1.5, md: 3 } }}>
      {/* En-tête */}
      <Stack direction={{ xs: 'column', md: 'row' }} justifyContent="space-between" alignItems={{ md: 'center' }} spacing={2} sx={{ mb: 2 }}>
        <Stack direction="row" spacing={1.5} alignItems="center">
          <Box sx={{ p: 1.2, borderRadius: 2, bgcolor: '#fff3e0', display: 'flex' }}>
            <EquipmentIcon sx={{ color: '#ef6c00', fontSize: 32 }} />
          </Box>
          <Box>
            <Typography variant="h4" sx={{ fontWeight: 700 }}>Équipements</Typography>
            <Typography variant="body2" color="text.secondary">
              Équipements SAP et leur place dans la structure de maintenance · {facets ? nb(facets.total) : '…'} équipements
              {nbFiltres > 0 ? ' (sélection)' : ''}
            </Typography>
          </Box>
        </Stack>
        <Stack direction="row" spacing={1}>
          <Button variant="outlined" startIcon={<StructureIcon />} onClick={() => navigate('/maintenance/ih02')}>Structure IH02</Button>
          <Button variant="contained" startIcon={<ExcelIcon />} onClick={exporter} disabled={exporting}>
            {exporting ? 'Export…' : 'Excel'}
          </Button>
        </Stack>
      </Stack>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}

      {/* Répartition */}
      {facets && (
        <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
          <Stack direction={{ xs: 'column', lg: 'row' }} spacing={3}>
            <RepartitionBar titre="Position dans la structure IH02" valeurs={facets.facettes.position.valeurs}
              actifs={filters.position ?? []} palette={POSITION_COULEURS} onToggle={(c) => toggleFiltre('position', c)} />
            <Box sx={{ flex: 0.7, minWidth: 260 }}>
              <RepartitionBar titre="Catégorie d'équipement" valeurs={facets.facettes.categorie.valeurs}
                actifs={filters.categorie ?? []} palette={CATEGORIE_COULEURS} onToggle={(c) => toggleFiltre('categorie', c)}
                legende={(v) => v.code} />
            </Box>
            <Box sx={{ flex: 0.6, minWidth: 240 }}>
              <RepartitionBar titre="Lien article" valeurs={facets.facettes.lien_article.valeurs}
                actifs={filters.lien_article ?? []}
                palette={{ ARTICLE: '#d81b60', CONSTRUCTION: '#f48fb1', AUCUN: '#cfd8dc' }}
                onToggle={(c) => toggleFiltre('lien_article', c)} />
            </Box>
          </Stack>
        </Paper>
      )}

      {/* Qualité */}
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

      {/* Filtres */}
      <Paper variant="outlined" sx={{ p: 1.5, mb: 2 }}>
        <Stack direction="row" spacing={1.5} sx={{ flexWrap: 'wrap', rowGap: 1.5 }} alignItems="center">
          <TextField size="small" placeholder="N° équipement, description, article, série, parent…" value={search}
            onChange={(e) => setSearch(e.target.value)} sx={{ width: 320 }}
            InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment> }} />
          {filtreAuto('poste_travail', 260)}
          {filtreAuto('statut', 240)}
          {filtreAuto('division', 220)}
          {filtreAuto('type_objet', 160)}
          <Box sx={{ flexGrow: 1 }} />
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
        </Box>
        <Divider />
        {THEMES.map((t) => [
          <ListSubheader key={`h-${t}`} sx={{ lineHeight: '32px' }}>{t}</ListSubheader>,
          ...FIELDS.filter((f) => f.theme === t).map((f) => (
            <MenuItem key={f.col} dense disabled={f.col === 'numero'}
              onClick={() => setColonnes((c) => (c.includes(f.col) ? c.filter((x) => x !== f.col) : [...c, f.col]))}>
              <Checkbox size="small" checked={colonnes.includes(f.col)} sx={{ py: 0 }} />
              <ListItemText primary={f.label} secondary={f.lib ? '+ libellé' : undefined} />
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
                <TableCell sx={{ width: 64 }} />
                {champs.map((f) => (
                  <TableCell key={f.col} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>
                    {f.tri ? (
                      <TableSortLabel active={sort === f.col} direction={sort === f.col ? dir : 'asc'}
                        onClick={() => { if (sort === f.col) setDir(dir === 'asc' ? 'desc' : 'asc'); else { setSort(f.col); setDir('asc'); } }}>
                        {f.label}
                      </TableSortLabel>
                    ) : f.label}
                  </TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {rows.map((r) => (
                <TableRow key={r.id} hover sx={{ cursor: 'pointer' }} onClick={() => setFiche(r.numero)}>
                  <TableCell sx={{ whiteSpace: 'nowrap' }}>
                    <Tooltip title={positions[r.position] ?? r.position}>
                      <StructureIcon fontSize="small" sx={{ color: couleur(POSITION_COULEURS, r.position) }} />
                    </Tooltip>
                    <Tooltip title={r.article ? `Article ${r.article}` : r.construction ? `Type de construction ${r.construction}` : 'Sans article'}>
                      <ArticleIcon fontSize="small" sx={{ ml: 0.5, color: r.article ? '#d81b60' : r.construction ? '#f48fb1' : 'action.disabled' }} />
                    </Tooltip>
                    {r.anomalies.length > 0 && (
                      <Tooltip title={r.anomalies.map((k: string) => facets?.anomalies.find((a) => a.cle === k)?.libelle ?? k).join(' · ')}>
                        <WarningIcon fontSize="small" sx={{ color: 'warning.main', ml: 0.5 }} />
                      </Tooltip>
                    )}
                  </TableCell>
                  {champs.map((f) => (
                    <TableCell key={f.col}><Cellule field={f} row={r} positions={positions} /></TableCell>
                  ))}
                </TableRow>
              ))}
              {!loading && rows.length === 0 && (
                <TableRow><TableCell colSpan={champs.length + 1} align="center" sx={{ py: 6, color: 'text.secondary' }}>
                  Aucun équipement ne correspond aux filtres.
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

      <FicheEquipement numero={fiche} onClose={() => setFiche(null)} />
    </Box>
  );
};

export default EquipmentPage;
