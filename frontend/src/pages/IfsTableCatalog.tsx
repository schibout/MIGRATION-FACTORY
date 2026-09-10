import { ArrowBack, Download, Refresh, TableChart, UploadFile } from '@mui/icons-material';
import {
  Alert, Box, Button, Checkbox, Chip, CircularProgress, Dialog, DialogActions,
  DialogContent, DialogTitle, FormControlLabel, MenuItem, Paper, Stack, Table,
  TableBody, TableCell, TableContainer, TableHead, TablePagination, TableRow,
  TextField, Typography,
} from '@mui/material';
import axios from 'axios';
import React, { useEffect, useMemo, useState } from 'react';
import { useSelector } from 'react-redux';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { RootState } from '../store';
import {
  IfsDictionaryColumn, IfsDictionaryList, IfsDictionaryTable, ifsDictionaryService as service,
} from '../services/ifsDictionaryService';

function errorMessage(error: unknown): string {
  return axios.isAxiosError(error)
    ? error.response?.data?.error || 'Le catalogue IFS est indisponible. Réessayez.'
    : 'Une erreur est survenue.';
}

function Metadata({ values }: { values: Record<string, string> }) {
  return (
    <Box component="details" sx={{ my: 1 }}>
      <Box component="summary" sx={{ cursor: 'pointer' }}>Métadonnées Oracle</Box>
      <Box component="dl" sx={{ display: 'grid', gridTemplateColumns: 'minmax(140px, 1fr) 2fr', gap: 1 }}>
        {Object.entries(values).filter(([, value]) => value !== '').map(([key, value]) => (
          <React.Fragment key={key}>
            <Typography component="dt" variant="caption">{key}</Typography>
            <Typography component="dd" variant="caption" sx={{ m: 0, overflowWrap: 'anywhere' }}>{value}</Typography>
          </React.Fragment>
        ))}
      </Box>
    </Box>
  );
}

const IfsTableCatalog: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const user = useSelector((state: RootState) => state.auth.user);
  const [data, setData] = useState<IfsDictionaryList | null>(null);
  const [search, setSearch] = useState('');
  const [owner, setOwner] = useState('');
  const [page, setPage] = useState(0);
  const [size, setSize] = useState(25);
  const [revision, setRevision] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [importOpen, setImportOpen] = useState(false);
  const [tablesFile, setTablesFile] = useState<File | null>(null);
  const [columnsFile, setColumnsFile] = useState<File | null>(null);
  const [importing, setImporting] = useState(false);
  const [importError, setImportError] = useState('');
  const [active, setActive] = useState<IfsDictionaryTable | null>(null);
  const [columns, setColumns] = useState<IfsDictionaryColumn[]>([]);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailError, setDetailError] = useState('');
  const [fieldSearch, setFieldSearch] = useState('');
  const [selected, setSelected] = useState<string[]>([]);
  const [includeOwner, setIncludeOwner] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [report, setReport] = useState<{ sql: string; filename: string } | null>(null);

  useEffect(() => {
    if (searchParams.get('import') !== '1' || user?.role !== 'admin') return;
    setImportError('');
    setTablesFile(null);
    setColumnsFile(null);
    setImportOpen(true);
    const nextParams = new URLSearchParams(searchParams);
    nextParams.delete('import');
    setSearchParams(nextParams, { replace: true });
  }, [searchParams, setSearchParams, user?.role]);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError('');
    const timer = window.setTimeout(() => {
      service.list({ q: search, owner, page, page_size: size }, controller.signal)
        .then(result => { if (!controller.signal.aborted) setData(result); })
        .catch(err => { if (!controller.signal.aborted) { setError(errorMessage(err)); setData(null); } })
        .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    }, 250);
    return () => { window.clearTimeout(timer); controller.abort(); };
  }, [search, owner, page, size, revision]);

  const activeId = active?.table_id;
  useEffect(() => {
    if (activeId === undefined) return;
    const controller = new AbortController();
    setDetailLoading(true);
    setDetailError('');
    setColumns([]);
    setSelected([]);
    setFieldSearch('');
    setReport(null);
    service.detail(activeId, controller.signal)
      .then(result => {
        if (controller.signal.aborted) return;
        setActive(previous => previous ? { ...previous, ...result.table } : null);
        setColumns(result.columns);
        setSelected(result.columns.map(column => column.column_name));
      })
      .catch(err => { if (!controller.signal.aborted) setDetailError(errorMessage(err)); })
      .finally(() => { if (!controller.signal.aborted) setDetailLoading(false); });
    return () => controller.abort();
  }, [activeId, revision]);

  const visibleColumns = useMemo(() => columns.filter(column =>
    column.column_name.toLowerCase().includes(fieldSearch.toLowerCase()) ||
    column.data_type.toLowerCase().includes(fieldSearch.toLowerCase())), [columns, fieldSearch]);

  const importFiles = async () => {
    if (!tablesFile && !columnsFile) return;
    setImporting(true);
    setImportError('');
    setNotice('');
    try {
      const result = await service.importFiles(tablesFile, columnsFile);
      setNotice(`${result.tables_imported} tables et ${result.columns_imported} colonnes importées. ${result.message}`);
      setImportOpen(false);
      setTablesFile(null);
      setColumnsFile(null);
      setPage(0);
      setRevision(value => value + 1);
    } catch (err) { setImportError(errorMessage(err)); }
    finally { setImporting(false); }
  };

  const generate = async () => {
    if (!active) return;
    setGenerating(true);
    setDetailError('');
    try { setReport(await service.report(active.table_id, selected, includeOwner)); }
    catch (err) { setDetailError(errorMessage(err)); }
    finally { setGenerating(false); }
  };

  const download = () => {
    if (!report) return;
    const url = URL.createObjectURL(new Blob([report.sql], { type: 'text/markdown;charset=utf-8' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = report.filename;
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
  };

  return (
    <Box sx={{ p: { xs: 2, md: 3 } }}>
      <Stack direction="row" spacing={2} alignItems="center" useFlexGap flexWrap="wrap" sx={{ mb: 2 }}>
        <Button startIcon={<ArrowBack />} onClick={() => navigate('/ifs-data')}>Données IFS</Button>
        <TableChart color="primary" />
        <Typography component="h1" variant="h4" sx={{ flexGrow: 1 }}>Catalogue des tables IFS</Typography>
        <Button startIcon={<Refresh />} onClick={() => setRevision(value => value + 1)} disabled={loading}>Actualiser</Button>
        {user?.role === 'admin' && (
          <Button variant="contained" startIcon={<UploadFile />} onClick={() => {
            setImportError(''); setTablesFile(null); setColumnsFile(null); setImportOpen(true);
          }}>
            Importer le catalogue
          </Button>
        )}
      </Stack>
      <Typography color="text.secondary" sx={{ mb: 2 }}>
        Consultez les tables et colonnes Oracle/IFS, puis générez une requête au format report.md.
      </Typography>
      {notice && <Alert severity="success" onClose={() => setNotice('')} sx={{ mb: 2 }}>{notice}</Alert>}
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
      {data && (
        <Stack direction="row" spacing={1} useFlexGap flexWrap="wrap" sx={{ mb: 2 }}>
          <Chip label={`${data.stats.tables} tables`} />
          <Chip label={`${data.stats.columns} colonnes`} />
          <Chip label={`${data.owners.length} propriétaires`} />
          {data.stats.imported_at && <Chip variant="outlined" label={`Dernier import : ${new Date(data.stats.imported_at).toLocaleString('fr-FR')}`} />}
        </Stack>
      )}
      <Paper sx={{ p: 2 }}>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} sx={{ mb: 2 }}>
          <TextField label="Rechercher une table ou une colonne" size="small" fullWidth value={search}
            onChange={event => { setSearch(event.target.value); setPage(0); }} />
          <TextField select label="Propriétaire" size="small" value={owner} sx={{ minWidth: 200 }}
            onChange={event => { setOwner(event.target.value); setPage(0); }}>
            <MenuItem value="">Tous les propriétaires</MenuItem>
            {[...new Set([...(data?.owners || []), ...(owner ? [owner] : [])])].map(value => <MenuItem key={value} value={value}>{value}</MenuItem>)}
          </TextField>
        </Stack>
        {loading ? <Box sx={{ p: 4, textAlign: 'center' }}><CircularProgress aria-label="Chargement des tables" /></Box> : (
          <TableContainer>
            <Table size="small" aria-label="Tables du catalogue IFS">
              <TableHead><TableRow>
                {['Propriétaire', 'Table', 'Colonnes', 'Tablespace', 'Statut', 'Lignes estimées', ''].map(label => <TableCell key={label}>{label}</TableCell>)}
              </TableRow></TableHead>
              <TableBody>
                {data?.items.map(table => (
                  <TableRow key={table.table_id} hover>
                    <TableCell>{table.owner}</TableCell>
                    <TableCell sx={{ fontFamily: 'monospace' }}>{table.table_name}</TableCell>
                    <TableCell>{table.column_count}</TableCell>
                    <TableCell>{table.tablespace_name || '—'}</TableCell>
                    <TableCell>{table.status || '—'}</TableCell>
                    <TableCell>{table.num_rows?.toLocaleString('fr-FR') ?? '—'}</TableCell>
                    <TableCell><Button size="small" onClick={() => { setReport(null); setDetailLoading(true); setActive(table); }}
                      aria-label={`Consulter ${table.owner}.${table.table_name}`}>Consulter</Button></TableCell>
                  </TableRow>
                ))}
                {data && !data.items.length && <TableRow><TableCell colSpan={7} sx={{ py: 4, textAlign: 'center' }}>
                  {data.stats.tables === 0 ? 'Catalogue vide. Importez le fichier des tables (et celui des colonnes) depuis un compte administrateur.' : 'Aucune table ne correspond à la recherche.'}
                </TableCell></TableRow>}
              </TableBody>
            </Table>
          </TableContainer>
        )}
        <TablePagination component="div" count={data?.total || 0} page={page} rowsPerPage={size}
          rowsPerPageOptions={[25, 50, 100]} labelRowsPerPage="Tables par page"
          labelDisplayedRows={({ from, to, count }) => `${from}–${to} sur ${count}`}
          onPageChange={(_, value) => setPage(value)}
          onRowsPerPageChange={event => { setSize(Number(event.target.value)); setPage(0); }} />
      </Paper>

      <Dialog open={importOpen} onClose={() => { if (!importing) setImportOpen(false); }} maxWidth="sm" fullWidth>
        <DialogTitle>Importer le catalogue IFS</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ pt: 1 }}>
            <Typography>Sélectionnez au moins un des deux fichiers, CSV ou Excel, puis cliquez sur « Importer ».
              Les deux fichiers sont indépendants : vous pouvez n’en charger qu’un seul.</Typography>
            <Alert severity="info">CSV séparés par un point-virgule (UTF-8 ou Windows-1252) ou classeur Excel .xlsx
              (premier onglet, en-têtes en première ligne), 32 Mo maximum par fichier. Les en-têtes attendus sont les mêmes
              dans les deux formats. Les entrées existantes sont mises à jour ; les entrées absentes sont conservées ; une ligne répétée dans un fichier écrase la précédente.
              Un fichier de colonnes seul exige que ses tables figurent déjà au catalogue.</Alert>
            <Typography component="label" variant="body2">
              Tables — ifs_table_name.csv ou .xlsx (facultatif)
              <Box component="input" type="file" accept=".csv,.xlsx,.xlsm" disabled={importing} sx={{ display: 'block', mt: 1, maxWidth: '100%' }}
                onChange={(event: React.ChangeEvent<HTMLInputElement>) => setTablesFile(event.target.files?.[0] || null)} />
            </Typography>
            <Typography component="label" variant="body2">
              Colonnes — COLUMN_NAME.csv ou .xlsx (facultatif)
              <Box component="input" type="file" accept=".csv,.xlsx,.xlsm" disabled={importing} sx={{ display: 'block', mt: 1, maxWidth: '100%' }}
                onChange={(event: React.ChangeEvent<HTMLInputElement>) => setColumnsFile(event.target.files?.[0] || null)} />
            </Typography>
            {importError && <Alert severity="error">{importError}</Alert>}
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button disabled={importing} onClick={() => setImportOpen(false)}>Annuler</Button>
          <Button variant="contained" disabled={importing || (!tablesFile && !columnsFile)} onClick={importFiles}>
            {importing ? 'Import en cours…' : 'Importer'}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={!!active} onClose={() => { if (!generating) setActive(null); }} maxWidth="xl" fullWidth>
        <DialogTitle sx={{ overflowWrap: 'anywhere' }}>{report ? 'Rapport SQL — ' : ''}{active?.owner}.{active?.table_name}</DialogTitle>
        <DialogContent>
          {detailError && <Alert severity="error" sx={{ mb: 2 }}>{detailError}</Alert>}
          {report ? (
            <>
              <Alert severity="info" sx={{ mb: 2 }}>Requête générée au format du modèle report.md. Elle n’est pas exécutée.</Alert>
              <Box component="pre" tabIndex={0} sx={{ m: 0, p: 2, bgcolor: 'action.hover', overflow: 'auto', maxHeight: '60vh', fontSize: 13 }}>{report.sql}</Box>
            </>
          ) : detailLoading ? <CircularProgress aria-label="Chargement des colonnes" /> : (
            <>
              {active?.metadata && <Metadata values={active.metadata} />}
              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }} sx={{ my: 2 }}>
                <TextField size="small" label="Filtrer les colonnes (nom ou type)" value={fieldSearch}
                  onChange={event => setFieldSearch(event.target.value)} sx={{ flexGrow: 1 }} />
                <Chip label={`${selected.length} / ${columns.length} colonnes sélectionnées`} />
                <Button onClick={() => setSelected(columns.map(column => column.column_name))}>Tout sélectionner</Button>
                <Button onClick={() => setSelected([])}>Tout désélectionner</Button>
              </Stack>
              <Typography variant="caption" color="text.secondary">Le filtre ne change pas la sélection du rapport. Les colonnes suivent l’ordre Oracle.</Typography>
              <TableContainer sx={{ maxHeight: '50vh' }}>
                <Table size="small" stickyHeader aria-label="Colonnes de la table IFS">
                  <TableHead><TableRow>
                    {['Rapport', 'Ordre', 'Colonne', 'Type', 'Longueur (octets)', 'Précision', 'Échelle', 'Nullable', 'Valeur par défaut', 'Détails'].map(label => <TableCell key={label}>{label}</TableCell>)}
                  </TableRow></TableHead>
                  <TableBody>
                    {visibleColumns.map(column => (
                      <TableRow key={column.column_name}>
                        <TableCell padding="checkbox"><Checkbox checked={selected.includes(column.column_name)}
                          inputProps={{ 'aria-label': `Inclure ${column.column_name} dans le rapport` }}
                          onChange={(_, checked) => setSelected(previous => checked ? [...previous, column.column_name] : previous.filter(name => name !== column.column_name))} /></TableCell>
                        <TableCell>{column.column_id}</TableCell>
                        <TableCell sx={{ fontFamily: 'monospace' }}>{column.column_name}</TableCell>
                        <TableCell>{column.data_type}</TableCell>
                        <TableCell>{column.data_length ?? '—'}</TableCell>
                        <TableCell>{column.data_precision ?? '—'}</TableCell>
                        <TableCell>{column.data_scale ?? '—'}</TableCell>
                        <TableCell>{column.nullable ? 'Oui' : 'Non'}</TableCell>
                        <TableCell sx={{ whiteSpace: 'pre-wrap', minWidth: 150 }}>{column.data_default ?? '—'}</TableCell>
                        <TableCell sx={{ minWidth: 180 }}><Metadata values={column.metadata} /></TableCell>
                      </TableRow>
                    ))}
                    {!visibleColumns.length && <TableRow><TableCell colSpan={10}>
                      {columns.length ? 'Aucune colonne ne correspond au filtre.' : 'Aucune colonne importée pour cette table.'}
                    </TableCell></TableRow>}
                  </TableBody>
                </Table>
              </TableContainer>
              <FormControlLabel sx={{ mt: 2 }} control={<Checkbox checked={includeOwner} onChange={(_, value) => setIncludeOwner(value)} />}
                label="Préfixer la table par son propriétaire dans le SQL" />
            </>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setActive(null)} disabled={generating}>Fermer</Button>
          {report ? (
            <>
              <Button onClick={() => setReport(null)}>Retour aux colonnes</Button>
              <Button variant="contained" startIcon={<Download />} onClick={download}>Télécharger report.md</Button>
            </>
          ) : (
            <Button variant="contained" onClick={generate} disabled={detailLoading || !selected.length || generating}>
              {generating ? 'Génération…' : 'Générer le rapport'}
            </Button>
          )}
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default IfsTableCatalog;
