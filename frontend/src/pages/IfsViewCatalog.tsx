import {
  ArrowBack, ContentCopy, Download, FileDownload as ExcelIcon, LocalOffer as TagIcon, Lock as LockIcon,
  LockOpen as LockOpenIcon, Search as SearchIcon, UploadFile, Visibility,
} from '@mui/icons-material';
import {
  Alert, Box, Button, Checkbox, Chip, CircularProgress, Dialog, DialogActions, DialogContent,
  DialogTitle, FormControlLabel, InputAdornment, LinearProgress, Paper, Stack, Tab, Table, TableBody,
  TableCell, TableContainer, TableHead, TablePagination, TableRow, TableSortLabel, Tabs, TextField,
  Tooltip, Typography,
} from '@mui/material';
import axios from 'axios';
import React, { useEffect, useMemo, useState } from 'react';
import { useSelector } from 'react-redux';
import { useNavigate } from 'react-router-dom';
import { couleur, FacetteAuto, nb, RepartitionBar, telecharger } from '../components/data/facettes';
import { RootState } from '../store';
import {
  IfsView, IfsViewDetail, IfsViewFacets, ifsViewService as service,
} from '../services/ifsDictionaryService';

// Données IFS > Vues IFS : catalogue ALL_VIEWS (migrations 116/117), sur le modèle de
// Maintenance > Équipements (barres de répartition, étiquettes, facettes, export Excel)
// et rapport SQL comme le Catalogue des tables IFS. API : api/ifs_dictionary.py.

type FacetKey = 'nature' | 'owner' | 'lecture' | 'taille' | 'module';
type Filters = Partial<Record<FacetKey, string[]>>;

const NATURE_COULEURS: Record<string, string> = {
  TAB: '#1976d2', VRT: '#7e57c2', LOV: '#26a69a', DM: '#ef6c00', OL: '#ffa726', MV: '#ffcc80',
  REP: '#d81b60', PUB: '#2e7d32', UIV: '#00acc1', QRY: '#5c6bc0', CF: '#8d6e63', TMP: '#bdbdbd',
  EXT: '#9ccc65', METIER: '#546e7a', SYSTEME: '#c62828',
};
const OWNER_COULEURS: Record<string, string> = {
  IFSAPP: '#1976d2', IFSINFO: '#00897b', IFSCAMSYS: '#7e57c2', CTXSYS: '#c62828', WMSYS: '#ef6c00',
  GSMADMIN_INTERNAL: '#8d6e63', XDB: '#78909c',
};
const LECTURE_COULEURS: Record<string, string> = { true: '#546e7a', false: '#ef6c00' };
const ETIQUETTE_COULEURS: Record<string, 'default' | 'primary' | 'secondary' | 'warning' | 'info' | 'error'> = {
  union: 'info', api: 'secondary', cf: 'primary', modifiable: 'warning', volumineux: 'error', tronque: 'error',
  rls: 'secondary', non_documentee: 'default',
};

function errorMessage(error: unknown): string {
  return axios.isAxiosError(error)
    ? error.response?.data?.error || 'Le catalogue des vues IFS est indisponible. Réessayez.'
    : 'Une erreur est survenue.';
}

const NatureChip: React.FC<{ code: string; libelle?: string }> = ({ code, libelle }) => (
  <Tooltip title={libelle ?? code}>
    <Chip size="small" label={code} sx={{ bgcolor: couleur(NATURE_COULEURS, code), color: '#fff', fontWeight: 600, height: 20 }} />
  </Tooltip>
);

// ---------------------------------------------------------------------------
// Fiche d'une vue : SQL, colonnes + rapport, objets lus
// ---------------------------------------------------------------------------
const FicheVue: React.FC<{ view: IfsView | null; etiquettes: Record<string, string>; onClose: () => void }> = ({ view, etiquettes, onClose }) => {
  const navigate = useNavigate();
  const [data, setData] = useState<IfsViewDetail | null>(null);
  const [error, setError] = useState('');
  const [onglet, setOnglet] = useState(0);
  const [selected, setSelected] = useState<string[]>([]);
  const [fieldSearch, setFieldSearch] = useState('');
  const [includeOwner, setIncludeOwner] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [report, setReport] = useState<{ sql: string; filename: string } | null>(null);

  useEffect(() => {
    if (!view) return;
    const controller = new AbortController();
    setData(null); setError(''); setOnglet(0); setReport(null); setFieldSearch('');
    service.detail(view.view_id, controller.signal)
      .then((d) => { setData(d); setSelected(d.columns); })
      .catch((err) => { if (!controller.signal.aborted) setError(errorMessage(err)); });
    return () => controller.abort();
  }, [view]);

  const visibles = useMemo(() => (data?.columns ?? []).filter((c) => c.toLowerCase().includes(fieldSearch.toLowerCase())),
    [data, fieldSearch]);

  const generate = async () => {
    if (!view) return;
    setGenerating(true); setError('');
    try { setReport(await service.report(view.view_id, selected, includeOwner)); }
    catch (err) { setError(errorMessage(err)); }
    finally { setGenerating(false); }
  };

  const download = () => {
    if (!report) return;
    const url = URL.createObjectURL(new Blob([report.sql], { type: 'text/markdown;charset=utf-8' }));
    const link = document.createElement('a');
    link.href = url; link.download = report.filename;
    document.body.appendChild(link); link.click(); link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
  };

  const v = data?.view;
  return (
    <Dialog open={!!view} onClose={() => { if (!generating) onClose(); }} maxWidth="xl" fullWidth>
      <DialogTitle sx={{ overflowWrap: 'anywhere' }}>
        <Stack direction="row" spacing={1} alignItems="center" useFlexGap flexWrap="wrap">
          {view && <NatureChip code={view.nature} libelle={data?.natures[view.nature]} />}
          <span>{report ? 'Rapport SQL — ' : ''}{view?.owner}.{view?.view_name}</span>
        </Stack>
        {view?.prompt && <Typography variant="body2" color="text.secondary">{view.prompt}{view.module ? ` · module ${view.module}` : ''}{view.lu_name ? ` · entité ${view.lu_name}` : ''}</Typography>}
      </DialogTitle>
      <DialogContent>
        {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
        {report ? (
          <>
            <Alert severity="info" sx={{ mb: 2 }}>Requête générée au format du modèle report.md. Elle n’est pas exécutée.</Alert>
            <Box component="pre" tabIndex={0} sx={{ m: 0, p: 2, bgcolor: 'action.hover', overflow: 'auto', maxHeight: '60vh', fontSize: 13 }}>{report.sql}</Box>
          </>
        ) : !v ? (!error && <CircularProgress aria-label="Chargement de la vue" />) : (
          <>
            <Stack direction="row" spacing={1} useFlexGap flexWrap="wrap" sx={{ mb: 1.5 }}>
              <Chip size="small" icon={v.read_only ? <LockIcon /> : <LockOpenIcon />}
                label={v.read_only ? 'Lecture seule' : v.read_only === false ? 'Modifiable' : 'Accès inconnu'} />
              <Chip size="small" label={`${nb(v.text_length)} caractères`} />
              {v.etiquettes.map((k) => (
                <Chip key={k} size="small" icon={<TagIcon />} color={ETIQUETTE_COULEURS[k] ?? 'default'} variant="outlined" label={etiquettes[k] ?? k} />
              ))}
            </Stack>
            <Tabs value={onglet} onChange={(_, o) => setOnglet(o)} sx={{ mb: 1.5 }}>
              <Tab label="Informations IFS" />
              <Tab label="SQL" />
              <Tab label={`Colonnes (${data!.columns.length})`} />
              <Tab label={`Objets lus (${data!.tables.length})`} />
              <Tab label="Métadonnées" />
            </Tabs>
            {onglet === 0 && (v.fnd_attributes ? (
              <Box sx={{ display: 'grid', gridTemplateColumns: 'minmax(180px, 1fr) 3fr', gap: 1 }}>
                {[['Prompt', v.prompt], ['Module', v.module], ['Entité (LU)', v.lu_name], ['Table de base', v.base_table],
                  ['Colonnes (dictionnaire IFS)', v.nb_colonnes_fnd ? String(v.nb_colonnes_fnd) : null]].map(([k, val]) => (
                  <React.Fragment key={k}>
                    <Typography variant="body2" color="text.secondary">{k}</Typography>
                    <Typography variant="body2" sx={{ fontWeight: 600, fontFamily: k === 'Table de base' ? 'monospace' : undefined }}>{val || '—'}</Typography>
                  </React.Fragment>
                ))}
                {Object.entries(v.fnd_attributes).filter(([k]) => !['PROMPT', 'MODULE', 'LU', 'TABLE'].includes(k)).map(([k, val]) => (
                  <React.Fragment key={k}>
                    <Typography variant="body2" color="text.secondary" sx={{ fontFamily: 'monospace' }}>{k}</Typography>
                    <Typography variant="body2" sx={{ overflowWrap: 'anywhere', fontFamily: 'monospace' }}>{val || '—'}</Typography>
                  </React.Fragment>
                ))}
              </Box>
            ) : <Alert severity="info">Vue absente du dictionnaire IFS (FND_TAB_COMMENTS) : aucune information complémentaire.</Alert>)}
            {onglet === 1 && (
              <Box component="pre" tabIndex={0} sx={{ m: 0, p: 2, bgcolor: 'action.hover', overflow: 'auto', maxHeight: '60vh', fontSize: 13 }}>
                {v.view_text || 'Aucun texte SQL dans le fichier importé.'}
              </Box>
            )}
            {onglet === 2 && (data!.columns.length === 0 ? (
              <Alert severity="warning">Colonnes non identifiées dans le SQL de la vue : rapport impossible.</Alert>
            ) : (
              <>
                <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }} sx={{ mb: 1 }}>
                  <TextField size="small" label="Filtrer les colonnes" value={fieldSearch}
                    onChange={(e) => setFieldSearch(e.target.value)} sx={{ flexGrow: 1 }} />
                  <Chip label={`${selected.length} / ${data!.columns.length} colonnes sélectionnées`} />
                  <Button onClick={() => setSelected(data!.columns)}>Tout sélectionner</Button>
                  <Button onClick={() => setSelected([])}>Tout désélectionner</Button>
                </Stack>
                {v.etiquettes.includes('tronque') && (
                  <Alert severity="warning" sx={{ mb: 1 }}>SQL tronqué dans le fichier importé : seules les colonnes lisibles avant la coupure sont listées.</Alert>
                )}
                <Typography variant="caption" color="text.secondary">
                  {data!.columns_source === 'fnd'
                    ? 'Colonnes du dictionnaire IFS (FND_TAB_VIEW_COLUMNS), dans leur ordre.'
                    : 'Colonnes lues dans la liste du SELECT de la vue (alias) : vue absente du dictionnaire des colonnes IFS.'} Le filtre ne change pas la sélection du rapport.
                </Typography>
                <TableContainer sx={{ maxHeight: '45vh' }}>
                  <Table size="small" stickyHeader aria-label="Colonnes de la vue IFS">
                    <TableHead><TableRow>
                      <TableCell>Rapport</TableCell><TableCell>Ordre</TableCell><TableCell>Colonne</TableCell>
                      {data!.columns_source === 'fnd' && <TableCell>Colonne d'origine (entité)</TableCell>}
                    </TableRow></TableHead>
                    <TableBody>
                      {visibles.map((c) => (
                        <TableRow key={c}>
                          <TableCell padding="checkbox"><Checkbox checked={selected.includes(c)}
                            inputProps={{ 'aria-label': `Inclure ${c} dans le rapport` }}
                            onChange={(_, checked) => setSelected((p) => checked ? data!.columns.filter((x) => x === c || p.includes(x)) : p.filter((x) => x !== c))} /></TableCell>
                          <TableCell>{data!.columns.indexOf(c) + 1}</TableCell>
                          <TableCell sx={{ fontFamily: 'monospace' }}>{c}</TableCell>
                          {data!.columns_source === 'fnd' && (
                            <TableCell sx={{ fontFamily: 'monospace', color: data!.column_origins[c] === c ? 'text.secondary' : undefined }}>
                              {data!.column_origins[c] ?? '—'}
                            </TableCell>
                          )}
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TableContainer>
                <FormControlLabel sx={{ mt: 1 }} control={<Checkbox checked={includeOwner} onChange={(_, val) => setIncludeOwner(val)} />}
                  label="Préfixer la vue par son propriétaire dans le SQL" />
              </>
            ))}
            {onglet === 3 && (
              <Stack direction="row" spacing={1} useFlexGap flexWrap="wrap">
                {data!.tables.map((t) => t.table_id ? (
                  <Tooltip key={t.name} title="Table présente dans le catalogue des tables IFS">
                    <Chip label={t.name} color="primary" variant="outlined" clickable sx={{ fontFamily: 'monospace' }}
                      onClick={() => navigate('/ifs-data/table-catalog')} />
                  </Tooltip>
                ) : <Chip key={t.name} label={t.name} variant="outlined" sx={{ fontFamily: 'monospace' }} />)}
                {data!.tables.length === 0 && <Typography color="text.secondary">Aucun objet identifié après FROM / JOIN.</Typography>}
              </Stack>
            )}
            {onglet === 4 && (
              <Box sx={{ display: 'grid', gridTemplateColumns: 'minmax(160px, 1fr) 2fr', gap: 1 }}>
                {Object.entries(v.metadata ?? {}).map(([k, val]) => (
                  <React.Fragment key={k}>
                    <Typography variant="body2" color="text.secondary">{k}</Typography>
                    <Typography variant="body2" sx={{ overflowWrap: 'anywhere' }}>{val}</Typography>
                  </React.Fragment>
                ))}
              </Box>
            )}
          </>
        )}
      </DialogContent>
      <DialogActions>
        {!report && v && onglet === 1 && (
          <Button startIcon={<ContentCopy />} disabled={!v.view_text}
            onClick={() => navigator.clipboard?.writeText(v.view_text || '')}>Copier le SQL</Button>
        )}
        <Button onClick={onClose} disabled={generating}>Fermer</Button>
        {report ? (
          <>
            <Button onClick={() => setReport(null)}>Retour à la vue</Button>
            <Button variant="contained" startIcon={<Download />} onClick={download}>Télécharger report.md</Button>
          </>
        ) : (
          <Button variant="contained" onClick={generate} disabled={!data || !selected.length || generating}>
            {generating ? 'Génération…' : 'Générer le rapport'}
          </Button>
        )}
      </DialogActions>
    </Dialog>
  );
};

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------
const IfsViewCatalog: React.FC = () => {
  const navigate = useNavigate();
  const user = useSelector((state: RootState) => state.auth.user);
  const [search, setSearch] = useState('');
  const [searchDebounced, setSearchDebounced] = useState('');
  const [inSql, setInSql] = useState(false);
  const [filters, setFilters] = useState<Filters>({});
  const [etiquette, setEtiquette] = useState('');
  const [facets, setFacets] = useState<IfsViewFacets | null>(null);
  const [rows, setRows] = useState<IfsView[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [size, setSize] = useState(50);
  const [sort, setSort] = useState('view_name');
  const [dir, setDir] = useState<'asc' | 'desc'>('asc');
  const [revision, setRevision] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [exporting, setExporting] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [file, setFile] = useState<File | null>(null);
  const [commentsFile, setCommentsFile] = useState<File | null>(null);
  const [columnsFile, setColumnsFile] = useState<File | null>(null);
  const [importing, setImporting] = useState(false);
  const [importError, setImportError] = useState('');
  const [active, setActive] = useState<IfsView | null>(null);

  useEffect(() => {
    const t = setTimeout(() => setSearchDebounced(search), 350);
    return () => clearTimeout(t);
  }, [search]);

  const params = useMemo(() => {
    const p: Record<string, string> = {};
    if (searchDebounced) { p.q = searchDebounced; if (inSql) p.in_sql = '1'; }
    (Object.keys(filters) as FacetKey[]).forEach((k) => { if (filters[k]?.length) p[k] = filters[k]!.join(','); });
    if (etiquette) p.etiquette = etiquette;
    return p;
  }, [searchDebounced, inSql, filters, etiquette]);

  useEffect(() => { setPage(0); }, [params]);

  useEffect(() => {
    const controller = new AbortController();
    service.facets(params, controller.signal).then(setFacets)
      .catch((err) => { if (!controller.signal.aborted) setError(errorMessage(err)); });
    return () => controller.abort();
  }, [params, revision]);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true); setError('');
    service.list({ ...params, page, page_size: size, sort, dir }, controller.signal)
      .then((r) => { setRows(r.items); setTotal(r.total); })
      .catch((err) => { if (!controller.signal.aborted) setError(errorMessage(err)); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [params, page, size, sort, dir, revision]);

  const toggleFiltre = (k: FacetKey, code: string) => setFilters((f) => {
    const cur = f[k] ?? [];
    return { ...f, [k]: cur.includes(code) ? cur.filter((c) => c !== code) : [...cur, code] };
  });
  const effacer = () => { setFilters({}); setSearch(''); setEtiquette(''); };
  const nbFiltres = Object.values(filters).reduce((s, v) => s + (v?.length ?? 0), 0)
    + (searchDebounced ? 1 : 0) + (etiquette ? 1 : 0);
  const facette = (k: FacetKey) => facets?.facettes[k];
  const natures = useMemo(() => Object.fromEntries((facette('nature')?.valeurs ?? []).map((v) => [v.code, v.libelle ?? v.code])),
    [facets]); // eslint-disable-line react-hooks/exhaustive-deps
  const etiquettesLib = useMemo(() => Object.fromEntries((facets?.etiquettes ?? []).map((e) => [e.cle, e.libelle])), [facets]);

  const filtreAuto = (k: FacetKey, largeur = 200) => (
    <FacetteAuto key={k} titre={facette(k)?.titre ?? k} valeurs={facette(k)?.valeurs ?? []} largeur={largeur}
      selection={filters[k] ?? []} onChange={(codes) => setFilters((cur) => ({ ...cur, [k]: codes }))} />
  );

  const exporter = async () => {
    try { setExporting(true); await telecharger(service.exportUrl, params, 'vues_ifs.xlsx'); }
    catch { setError("L'export Excel a échoué."); }
    finally { setExporting(false); }
  };

  const importFile = async () => {
    if (!file && !commentsFile && !columnsFile) return;
    setImporting(true); setImportError(''); setNotice('');
    try {
      const r = await service.importFiles(file, commentsFile, columnsFile);
      const parts = [
        r.views_imported !== undefined && `${nb(r.views_imported)} vues`,
        r.comments_imported !== undefined && `${nb(r.comments_imported)} descriptions IFS`,
        r.columns_imported !== undefined && `${nb(r.columns_imported)} colonnes sur ${nb(r.views_with_columns)} vues`,
      ].filter(Boolean);
      setNotice(`Importé : ${parts.join(', ')}. ${r.message}`);
      setImportOpen(false); setFile(null); setCommentsFile(null); setColumnsFile(null); setRevision((x) => x + 1);
    } catch (err) { setImportError(errorMessage(err)); }
    finally { setImporting(false); }
  };

  const triable = (col: string, label: string) => (
    <TableSortLabel active={sort === col} direction={sort === col ? dir : 'asc'}
      onClick={() => { if (sort === col) setDir(dir === 'asc' ? 'desc' : 'asc'); else { setSort(col); setDir('asc'); } }}>
      {label}
    </TableSortLabel>
  );

  return (
    <Box sx={{ p: { xs: 1.5, md: 3 } }}>
      {/* En-tête */}
      <Stack direction={{ xs: 'column', md: 'row' }} justifyContent="space-between" alignItems={{ md: 'center' }} spacing={2} sx={{ mb: 2 }}>
        <Stack direction="row" spacing={1.5} alignItems="center">
          <Button startIcon={<ArrowBack />} onClick={() => navigate('/ifs-data')}>Données IFS</Button>
          <Box sx={{ p: 1.2, borderRadius: 2, bgcolor: '#e0f7fa', display: 'flex' }}>
            <Visibility sx={{ color: '#00838f', fontSize: 32 }} />
          </Box>
          <Box>
            <Typography variant="h4" sx={{ fontWeight: 700 }}>Vues IFS</Typography>
            <Typography variant="body2" color="text.secondary">
              Vues Oracle/IFS (ALL_VIEWS) · {facets ? nb(facets.total) : '…'} vues{nbFiltres > 0 ? ' (sélection)' : ''}
              {facets ? ` · ${nb(facets.catalogue.comments)} descriptions et ${nb(facets.catalogue.columns)} colonnes IFS` : ''}
              {facets?.catalogue.imported_at ? ` · import du ${new Date(facets.catalogue.imported_at).toLocaleString('fr-FR')}` : ''}
            </Typography>
          </Box>
        </Stack>
        <Stack direction="row" spacing={1}>
          {user?.role === 'admin' && (
            <Button variant="outlined" startIcon={<UploadFile />} onClick={() => { setImportError(''); setFile(null); setCommentsFile(null); setColumnsFile(null); setImportOpen(true); }}>
              Importer les vues
            </Button>
          )}
          <Button variant="contained" startIcon={<ExcelIcon />} onClick={exporter} disabled={exporting}>
            {exporting ? 'Export…' : 'Excel'}
          </Button>
        </Stack>
      </Stack>

      {notice && <Alert severity="success" onClose={() => setNotice('')} sx={{ mb: 2 }}>{notice}</Alert>}
      {error && <Alert severity="error" onClose={() => setError('')} sx={{ mb: 2 }}>{error}</Alert>}
      {facets?.catalogue.views === 0 && (
        <Alert severity="info" sx={{ mb: 2 }}>Catalogue vide. Importez le fichier des vues depuis un compte administrateur.</Alert>
      )}

      {/* Répartition */}
      {facets && (
        <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
          <Stack direction={{ xs: 'column', lg: 'row' }} spacing={3}>
            <RepartitionBar titre="Nature (suffixe IFS)" valeurs={facets.facettes.nature.valeurs}
              actifs={filters.nature ?? []} palette={NATURE_COULEURS} onToggle={(c) => toggleFiltre('nature', c)}
              legende={(v) => v.code} />
            <Box sx={{ flex: 0.7, minWidth: 260 }}>
              <RepartitionBar titre="Propriétaire" valeurs={facets.facettes.owner.valeurs}
                actifs={filters.owner ?? []} palette={OWNER_COULEURS} onToggle={(c) => toggleFiltre('owner', c)} />
            </Box>
            <Box sx={{ flex: 0.5, minWidth: 220 }}>
              <RepartitionBar titre="Accès" valeurs={facets.facettes.lecture.valeurs}
                actifs={filters.lecture ?? []} palette={LECTURE_COULEURS} onToggle={(c) => toggleFiltre('lecture', c)} />
            </Box>
          </Stack>
        </Paper>
      )}

      {/* Étiquettes */}
      {facets && (
        <Stack direction="row" spacing={1} sx={{ mb: 2, flexWrap: 'wrap', rowGap: 1 }} alignItems="center">
          <Typography variant="overline" color="text.secondary" sx={{ mr: 1 }}>Étiquettes</Typography>
          {facets.etiquettes.map((e) => (
            <Chip key={e.cle} clickable size="small" icon={<TagIcon />}
              color={etiquette === e.cle ? (ETIQUETTE_COULEURS[e.cle] ?? 'default') : 'default'}
              variant={etiquette === e.cle ? 'filled' : 'outlined'}
              onClick={() => setEtiquette(etiquette === e.cle ? '' : e.cle)}
              label={`${e.libelle} · ${nb(e.nb)}`} />
          ))}
        </Stack>
      )}

      {/* Filtres */}
      <Paper variant="outlined" sx={{ p: 1.5, mb: 2 }}>
        <Stack direction="row" spacing={1.5} sx={{ flexWrap: 'wrap', rowGap: 1.5 }} alignItems="center">
          <TextField size="small" placeholder="Vue, prompt, entité (LU), propriétaire…" value={search}
            onChange={(e) => setSearch(e.target.value)} sx={{ width: 300 }}
            InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment> }} />
          <FormControlLabel label="Chercher aussi dans le SQL"
            control={<Checkbox size="small" checked={inSql} onChange={(_, val) => setInSql(val)} />} />
          {filtreAuto('module', 200)}
          {filtreAuto('nature', 240)}
          {filtreAuto('owner', 200)}
          {filtreAuto('taille', 200)}
          <Box sx={{ flexGrow: 1 }} />
          {nbFiltres > 0 && <Button size="small" onClick={effacer}>Effacer les filtres ({nbFiltres})</Button>}
        </Stack>
      </Paper>

      {loading && <LinearProgress sx={{ mb: 0.5 }} />}

      <Paper variant="outlined">
        <TableContainer sx={{ maxHeight: 'calc(100vh - 430px)', minHeight: 300 }}>
          <Table size="small" stickyHeader aria-label="Vues IFS">
            <TableHead>
              <TableRow>
                <TableCell sx={{ width: 40 }} />
                <TableCell sx={{ fontWeight: 600 }}>{triable('owner', 'Propriétaire')}</TableCell>
                <TableCell sx={{ fontWeight: 600 }}>{triable('view_name', 'Vue')}</TableCell>
                <TableCell sx={{ fontWeight: 600 }}>{triable('module', 'Module')}</TableCell>
                <TableCell sx={{ fontWeight: 600 }}>{triable('nature', 'Nature')}</TableCell>
                <TableCell sx={{ fontWeight: 600 }} align="right">{triable('nb_colonnes_fnd', 'Colonnes')}</TableCell>
                <TableCell sx={{ fontWeight: 600 }} align="right">{triable('text_length', 'Taille du SQL')}</TableCell>
                <TableCell sx={{ fontWeight: 600 }}>Étiquettes</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {rows.map((r) => (
                <TableRow key={r.view_id} hover sx={{ cursor: 'pointer' }} onClick={() => setActive(r)}>
                  <TableCell>
                    <Tooltip title={r.read_only ? 'Lecture seule' : r.read_only === false ? 'Modifiable' : 'Accès inconnu'}>
                      {r.read_only === false
                        ? <LockOpenIcon fontSize="small" sx={{ color: '#ef6c00' }} />
                        : <LockIcon fontSize="small" sx={{ color: 'action.disabled' }} />}
                    </Tooltip>
                  </TableCell>
                  <TableCell>{r.owner}</TableCell>
                  <TableCell>
                    <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 600 }}>{r.view_name}</Typography>
                    {(r.prompt || r.lu_name) && (
                      <Typography variant="caption" color="text.secondary" noWrap sx={{ display: 'block', maxWidth: 420 }}>
                        {r.prompt}{r.lu_name ? ` · ${r.lu_name}` : ''}
                      </Typography>
                    )}
                  </TableCell>
                  <TableCell>{r.module ? <Chip size="small" variant="outlined" label={r.module} sx={{ height: 20 }} /> : '—'}</TableCell>
                  <TableCell><NatureChip code={r.nature} libelle={natures[r.nature]} /></TableCell>
                  <TableCell align="right">{r.nb_colonnes_fnd ? nb(r.nb_colonnes_fnd) : '—'}</TableCell>
                  <TableCell align="right">{r.text_length === null ? '—' : nb(r.text_length)}</TableCell>
                  <TableCell>
                    <Stack direction="row" spacing={0.5} sx={{ flexWrap: 'wrap', rowGap: 0.5 }}>
                      {r.etiquettes.map((k) => (
                        <Chip key={k} size="small" variant="outlined" color={ETIQUETTE_COULEURS[k] ?? 'default'}
                          label={etiquettesLib[k] ?? k} sx={{ height: 20, fontSize: '0.7rem' }} />
                      ))}
                    </Stack>
                  </TableCell>
                </TableRow>
              ))}
              {!loading && rows.length === 0 && (
                <TableRow><TableCell colSpan={8} align="center" sx={{ py: 6, color: 'text.secondary' }}>
                  Aucune vue ne correspond aux filtres.
                </TableCell></TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
        <TablePagination component="div" count={total} page={page} rowsPerPage={size}
          rowsPerPageOptions={[25, 50, 100, 200]} labelRowsPerPage="Lignes par page"
          labelDisplayedRows={({ from, to, count }) => `${from}–${to} sur ${nb(count)}`}
          onPageChange={(_, p) => setPage(p)} onRowsPerPageChange={(ev) => { setSize(Number(ev.target.value)); setPage(0); }} />
      </Paper>

      <Dialog open={importOpen} onClose={() => { if (!importing) setImportOpen(false); }} maxWidth="sm" fullWidth>
        <DialogTitle>Importer les vues IFS</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ pt: 1 }}>
            <Alert severity="info">Trois fichiers facultatifs et indépendants, classeur .xlsx (premier onglet) ou CSV point-virgule,
              32 Mo maximum chacun. Les entrées existantes sont mises à jour, les absentes sont conservées
              (sauf les colonnes d'une vue présente dans le fichier des colonnes, remplacées en entier).</Alert>
            {([
              ['Vues — export Oracle ALL_VIEWS (Owner, View Name, Text)', setFile],
              ['Descriptions IFS — FND_TAB_COMMENTS (Table Name, Comments : LU, PROMPT, MODULE…)', setCommentsFile],
              ['Colonnes IFS — FND_TAB_VIEW_COLUMNS (View Name, View Column Name, Column Name)', setColumnsFile],
            ] as [string, (f: File | null) => void][]).map(([label, set]) => (
              <Typography key={label} component="label" variant="body2">
                {label}
                <Box component="input" type="file" accept=".csv,.xlsx,.xlsm" disabled={importing} sx={{ display: 'block', mt: 1, maxWidth: '100%' }}
                  onChange={(event: React.ChangeEvent<HTMLInputElement>) => set(event.target.files?.[0] || null)} />
              </Typography>
            ))}
            {importError && <Alert severity="error">{importError}</Alert>}
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button disabled={importing} onClick={() => setImportOpen(false)}>Annuler</Button>
          <Button variant="contained" disabled={importing || (!file && !commentsFile && !columnsFile)} onClick={importFile}>
            {importing ? 'Import en cours…' : 'Importer'}
          </Button>
        </DialogActions>
      </Dialog>

      <FicheVue view={active} etiquettes={etiquettesLib} onClose={() => setActive(null)} />
    </Box>
  );
};

export default IfsViewCatalog;
