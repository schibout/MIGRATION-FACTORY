import { ArrowBack, ContentCopy, Refresh, UploadFile, Visibility } from '@mui/icons-material';
import {
  Alert, Box, Button, Checkbox, Chip, CircularProgress, Dialog, DialogActions, DialogContent,
  DialogTitle, FormControlLabel, MenuItem, Paper, Stack, Table, TableBody, TableCell,
  TableContainer, TableHead, TablePagination, TableRow, TextField, Typography,
} from '@mui/material';
import axios from 'axios';
import React, { useEffect, useState } from 'react';
import { useSelector } from 'react-redux';
import { useNavigate } from 'react-router-dom';
import { RootState } from '../store';
import { IfsView, IfsViewList, ifsViewService as service } from '../services/ifsDictionaryService';

function errorMessage(error: unknown): string {
  return axios.isAxiosError(error)
    ? error.response?.data?.error || 'Le catalogue des vues IFS est indisponible. Réessayez.'
    : 'Une erreur est survenue.';
}

const IfsViewCatalog: React.FC = () => {
  const navigate = useNavigate();
  const user = useSelector((state: RootState) => state.auth.user);
  const [data, setData] = useState<IfsViewList | null>(null);
  const [search, setSearch] = useState('');
  const [inSql, setInSql] = useState(false);
  const [owner, setOwner] = useState('');
  const [page, setPage] = useState(0);
  const [size, setSize] = useState(25);
  const [revision, setRevision] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [importOpen, setImportOpen] = useState(false);
  const [file, setFile] = useState<File | null>(null);
  const [importing, setImporting] = useState(false);
  const [importError, setImportError] = useState('');
  const [active, setActive] = useState<IfsView | null>(null);
  const [detailError, setDetailError] = useState('');

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError('');
    const timer = window.setTimeout(() => {
      service.list({ q: search, owner, in_sql: inSql ? '1' : '0', page, page_size: size }, controller.signal)
        .then(result => { if (!controller.signal.aborted) setData(result); })
        .catch(err => { if (!controller.signal.aborted) { setError(errorMessage(err)); setData(null); } })
        .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    }, 300);
    return () => { window.clearTimeout(timer); controller.abort(); };
  }, [search, inSql, owner, page, size, revision]);

  const open = (view: IfsView) => {
    setActive(view);
    setDetailError('');
    service.detail(view.view_id).then(setActive).catch(err => setDetailError(errorMessage(err)));
  };

  const importFile = async () => {
    if (!file) return;
    setImporting(true);
    setImportError('');
    setNotice('');
    try {
      const result = await service.importFile(file);
      setNotice(`${result.views_imported.toLocaleString('fr-FR')} vues importées. ${result.message}`);
      setImportOpen(false);
      setFile(null);
      setPage(0);
      setRevision(value => value + 1);
    } catch (err) { setImportError(errorMessage(err)); }
    finally { setImporting(false); }
  };

  return (
    <Box sx={{ p: { xs: 2, md: 3 } }}>
      <Stack direction="row" spacing={2} alignItems="center" useFlexGap flexWrap="wrap" sx={{ mb: 2 }}>
        <Button startIcon={<ArrowBack />} onClick={() => navigate('/ifs-data')}>Données IFS</Button>
        <Visibility color="primary" />
        <Typography component="h1" variant="h4" sx={{ flexGrow: 1 }}>Vues IFS</Typography>
        <Button startIcon={<Refresh />} onClick={() => setRevision(value => value + 1)} disabled={loading}>Actualiser</Button>
        {user?.role === 'admin' && (
          <Button variant="contained" startIcon={<UploadFile />}
            onClick={() => { setImportError(''); setFile(null); setImportOpen(true); }}>
            Importer les vues
          </Button>
        )}
      </Stack>
      <Typography color="text.secondary" sx={{ mb: 2 }}>
        Vues Oracle/IFS (export ALL_VIEWS) : recherche par nom ou dans le SQL, consultation du texte de la vue.
      </Typography>
      {notice && <Alert severity="success" onClose={() => setNotice('')} sx={{ mb: 2 }}>{notice}</Alert>}
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
      {data && (
        <Stack direction="row" spacing={1} useFlexGap flexWrap="wrap" sx={{ mb: 2 }}>
          <Chip label={`${data.stats.views.toLocaleString('fr-FR')} vues`} />
          <Chip label={`${data.owners.length} propriétaires`} />
          {data.stats.imported_at && <Chip variant="outlined" label={`Dernier import : ${new Date(data.stats.imported_at).toLocaleString('fr-FR')}`} />}
        </Stack>
      )}
      <Paper sx={{ p: 2 }}>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }} sx={{ mb: 2 }}>
          <TextField label="Rechercher une vue" size="small" fullWidth value={search}
            onChange={event => { setSearch(event.target.value); setPage(0); }} />
          <FormControlLabel sx={{ whiteSpace: 'nowrap' }} label="Chercher aussi dans le SQL"
            control={<Checkbox checked={inSql} onChange={(_, value) => { setInSql(value); setPage(0); }} />} />
          <TextField select label="Propriétaire" size="small" value={owner} sx={{ minWidth: 200 }}
            onChange={event => { setOwner(event.target.value); setPage(0); }}>
            <MenuItem value="">Tous les propriétaires</MenuItem>
            {(data?.owners || []).map(value => <MenuItem key={value} value={value}>{value}</MenuItem>)}
          </TextField>
        </Stack>
        {loading ? <Box sx={{ p: 4, textAlign: 'center' }}><CircularProgress aria-label="Chargement des vues" /></Box> : (
          <TableContainer>
            <Table size="small" aria-label="Vues IFS">
              <TableHead><TableRow>
                {['Propriétaire', 'Vue', 'Lecture seule', 'Taille du SQL', ''].map(label => <TableCell key={label}>{label}</TableCell>)}
              </TableRow></TableHead>
              <TableBody>
                {data?.items.map(view => (
                  <TableRow key={view.view_id} hover>
                    <TableCell>{view.owner}</TableCell>
                    <TableCell sx={{ fontFamily: 'monospace' }}>{view.view_name}</TableCell>
                    <TableCell>{view.read_only === null ? '—' : view.read_only ? 'Oui' : 'Non'}</TableCell>
                    <TableCell>{view.text_length?.toLocaleString('fr-FR') ?? '—'}</TableCell>
                    <TableCell><Button size="small" onClick={() => open(view)}>Consulter</Button></TableCell>
                  </TableRow>
                ))}
                {data && !data.items.length && <TableRow><TableCell colSpan={5} sx={{ py: 4, textAlign: 'center' }}>
                  {data.stats.views === 0 ? 'Catalogue vide. Importez le fichier des vues depuis un compte administrateur.' : 'Aucune vue ne correspond à la recherche.'}
                </TableCell></TableRow>}
              </TableBody>
            </Table>
          </TableContainer>
        )}
        <TablePagination component="div" count={data?.total || 0} page={page} rowsPerPage={size}
          rowsPerPageOptions={[25, 50, 100]} labelRowsPerPage="Vues par page"
          labelDisplayedRows={({ from, to, count }) => `${from}–${to} sur ${count}`}
          onPageChange={(_, value) => setPage(value)}
          onRowsPerPageChange={event => { setSize(Number(event.target.value)); setPage(0); }} />
      </Paper>

      <Dialog open={importOpen} onClose={() => { if (!importing) setImportOpen(false); }} maxWidth="sm" fullWidth>
        <DialogTitle>Importer les vues IFS</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ pt: 1 }}>
            <Alert severity="info">Classeur .xlsx (premier onglet) ou CSV point-virgule, 32 Mo maximum, export Oracle ALL_VIEWS :
              colonnes « Owner » et « View Name » obligatoires, « Text » (ou à défaut « Text Vc ») pour le SQL.
              Les vues existantes sont mises à jour, les vues absentes du fichier sont conservées.</Alert>
            <Box component="input" type="file" accept=".csv,.xlsx,.xlsm" disabled={importing} sx={{ maxWidth: '100%' }}
              onChange={(event: React.ChangeEvent<HTMLInputElement>) => setFile(event.target.files?.[0] || null)} />
            {importError && <Alert severity="error">{importError}</Alert>}
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button disabled={importing} onClick={() => setImportOpen(false)}>Annuler</Button>
          <Button variant="contained" disabled={importing || !file} onClick={importFile}>
            {importing ? 'Import en cours…' : 'Importer'}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={!!active} onClose={() => setActive(null)} maxWidth="xl" fullWidth>
        <DialogTitle sx={{ overflowWrap: 'anywhere' }}>{active?.owner}.{active?.view_name}</DialogTitle>
        <DialogContent>
          {detailError && <Alert severity="error" sx={{ mb: 2 }}>{detailError}</Alert>}
          {active?.view_text === undefined ? <CircularProgress aria-label="Chargement du SQL" /> : (
            <>
              {active.metadata && (
                <Stack direction="row" spacing={1} useFlexGap flexWrap="wrap" sx={{ mb: 2 }}>
                  {Object.entries(active.metadata).filter(([key]) => !['Owner', 'View Name'].includes(key))
                    .map(([key, value]) => <Chip key={key} size="small" variant="outlined" label={`${key} : ${value}`} />)}
                </Stack>
              )}
              <Box component="pre" tabIndex={0} sx={{ m: 0, p: 2, bgcolor: 'action.hover', overflow: 'auto', maxHeight: '65vh', fontSize: 13 }}>
                {active.view_text || 'Aucun texte SQL dans le fichier importé.'}
              </Box>
            </>
          )}
        </DialogContent>
        <DialogActions>
          <Button startIcon={<ContentCopy />} disabled={!active?.view_text}
            onClick={() => navigator.clipboard?.writeText(active?.view_text || '')}>Copier le SQL</Button>
          <Button onClick={() => setActive(null)}>Fermer</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default IfsViewCatalog;
