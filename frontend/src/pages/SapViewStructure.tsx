import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  FormControlLabel,
  Grid,
  List,
  ListItemButton,
  ListItemText,
  MenuItem,
  Paper,
  Switch,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TablePagination,
  TableRow,
  Tabs,
  TextField,
  Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useState } from 'react';
import { useSelector } from 'react-redux';
import { useSearchParams } from 'react-router-dom';
import api from '../services/api';
import { RootState } from '../store';

const BASE = '/sap-view-structure/views';

interface ViewRow {
  viewname: string;
  viewclass: string | null;
  roottab: string | null;
  nb_tables: number;
  nb_present: number;
  creatable: boolean;
  created: boolean;
  description: string | null;
}

interface Condition {
  position: string;
  tabname: string;
  fieldname: string;
  negation: string | null;
  operator: string | null;
  constants: string | null;
  and_or: string | null;
}

interface ViewDetail {
  viewname: string;
  viewclass: string | null;
  viewclass_label: string;
  roottab: string | null;
  description: string | null;
  created: boolean;
  tables: { tabname: string; tabpos: string; description: string | null; present: boolean }[];
  fields: { objpos: string; viewfield: string; tabname: string; fieldname: string; key_flag: boolean; label: string | null }[];
  join_conditions: Condition[];
  selection_conditions: Condition[];
  joins: string[];
  filters: string[];
  warnings: string[];
  blocking: string[];
  sql: string | null;
}

const errMsg = (e: any) => e?.response?.data?.error || e?.message || 'Erreur';

const SimpleTable: React.FC<{ head: string[]; rows: React.ReactNode[][] }> = ({ head, rows }) => (
  <TableContainer component={Paper} variant="outlined" sx={{ maxHeight: 520 }}>
    <Table size="small" stickyHeader>
      <TableHead>
        <TableRow>{head.map((h) => <TableCell key={h}>{h}</TableCell>)}</TableRow>
      </TableHead>
      <TableBody>
        {rows.map((r, i) => (
          <TableRow key={i}>{r.map((c, j) => <TableCell key={j}>{c}</TableCell>)}</TableRow>
        ))}
      </TableBody>
    </Table>
  </TableContainer>
);

const SapViewStructure: React.FC = () => {
  const user = useSelector((state: RootState) => state.auth.user);
  const isAdmin = user?.role === 'admin';
  const [searchParams, setSearchParams] = useSearchParams();

  const [search, setSearch] = useState('');
  const [viewclass, setViewclass] = useState('D');
  const [creatableOnly, setCreatableOnly] = useState(true);
  const [page, setPage] = useState(0);
  const [views, setViews] = useState<ViewRow[]>([]);
  const [total, setTotal] = useState(0);
  const [classes, setClasses] = useState<Record<string, string>>({});
  const [loadingList, setLoadingList] = useState(false);

  const selected = searchParams.get('view') || '';
  const [detail, setDetail] = useState<ViewDetail | null>(null);
  const [tab, setTab] = useState(0);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);
  const [data, setData] = useState<{ columns: string[]; rows: Record<string, unknown>[] } | null>(null);

  const loadList = useCallback(async () => {
    setLoadingList(true);
    try {
      const { data: r } = await api.get(BASE, {
        params: { search, viewclass, creatable: creatableOnly ? 1 : 0, page: page + 1, pageSize: 50 },
      });
      setViews(r.views);
      setTotal(r.total);
      setClasses(r.classes);
    } catch (e) {
      setMessage({ type: 'error', text: errMsg(e) });
    } finally {
      setLoadingList(false);
    }
  }, [search, viewclass, creatableOnly, page]);

  useEffect(() => {
    const t = setTimeout(loadList, 300);
    return () => clearTimeout(t);
  }, [loadList]);

  const loadDetail = useCallback(async (name: string) => {
    setDetail(null);
    setData(null);
    try {
      const { data: d } = await api.get(`${BASE}/${encodeURIComponent(name)}`);
      setDetail(d);
    } catch (e) {
      setMessage({ type: 'error', text: errMsg(e) });
    }
  }, []);

  useEffect(() => {
    if (selected) loadDetail(selected);
  }, [selected, loadDetail]);

  const loadData = async () => {
    if (!detail) return;
    setBusy(true);
    try {
      const { data: d } = await api.get(`${BASE}/${encodeURIComponent(detail.viewname)}/data`, { params: { limit: 100 } });
      setData(d);
    } catch (e) {
      setMessage({ type: 'error', text: errMsg(e) });
    } finally {
      setBusy(false);
    }
  };

  const createOrDrop = async (drop: boolean) => {
    if (!detail) return;
    setBusy(true);
    setMessage(null);
    try {
      const url = `${BASE}/${encodeURIComponent(detail.viewname)}`;
      if (drop) await api.delete(url);
      else await api.post(`${url}/create`);
      setMessage({
        type: 'success',
        text: drop ? `Vue sap_view.${detail.viewname.toLowerCase()} supprimée` : `Vue sap_view.${detail.viewname.toLowerCase()} créée`,
      });
      await loadDetail(detail.viewname);
      loadList();
      if (!drop) setTab(4);
    } catch (e) {
      setMessage({ type: 'error', text: errMsg(e) });
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    if (tab === 4 && detail?.created && !data) loadData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, detail]);

  const condRows = (conds: Condition[]) =>
    conds.map((c) => [c.position, c.tabname, c.fieldname, c.negation || '', c.operator || '', c.constants || '', c.and_or || '']);

  return (
    <Box sx={{ width: '100%', p: 3 }}>
      <Typography variant="h4" component="h1" gutterBottom>
        VUES SAP
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Structure des vues du dictionnaire SAP (tables de base, jointures, conditions, champs) et création de leur
        équivalent PostgreSQL dans le schéma <b>sap_view</b>, à partir des tables extraites dans raw_data.
      </Typography>
      {message && (
        <Alert severity={message.type} onClose={() => setMessage(null)} sx={{ mb: 2 }}>
          {message.text}
        </Alert>
      )}

      <Grid container spacing={2}>
        <Grid item xs={12} md={4}>
          <Paper variant="outlined" sx={{ p: 2 }}>
            <TextField
              fullWidth size="small" label="Vue ou table de base (ex. IFLO, EQUI)"
              value={search}
              onChange={(e) => { setSearch(e.target.value); setPage(0); }}
            />
            <Box sx={{ display: 'flex', gap: 1, mt: 1, alignItems: 'center', flexWrap: 'wrap' }}>
              <TextField
                select size="small" label="Classe" value={viewclass} sx={{ minWidth: 160 }}
                onChange={(e) => { setViewclass(e.target.value); setPage(0); }}
              >
                <MenuItem value="">Toutes</MenuItem>
                {Object.entries(classes).map(([k, v]) => <MenuItem key={k} value={k}>{k} - {v}</MenuItem>)}
              </TextField>
              <FormControlLabel
                control={<Switch checked={creatableOnly} onChange={(e) => { setCreatableOnly(e.target.checked); setPage(0); }} />}
                label="Créables"
              />
            </Box>
            {loadingList ? (
              <Box sx={{ textAlign: 'center', p: 2 }}><CircularProgress size={24} /></Box>
            ) : (
              <List dense sx={{ maxHeight: 560, overflow: 'auto' }}>
                {views.map((v) => (
                  <ListItemButton
                    key={v.viewname}
                    selected={v.viewname === selected}
                    onClick={() => { setSearchParams({ view: v.viewname }); setTab(0); setMessage(null); }}
                  >
                    <ListItemText
                      primary={
                        <Box sx={{ display: 'flex', gap: 1, alignItems: 'center' }}>
                          <b>{v.viewname}</b>
                          <Chip size="small" label={`${v.nb_present}/${v.nb_tables} tables`} color={v.creatable ? 'success' : 'default'} variant="outlined" />
                          {v.created && <Chip size="small" label="créée" color="primary" />}
                        </Box>
                      }
                      secondary={v.description || (v.roottab ? `Table racine ${v.roottab}` : '')}
                    />
                  </ListItemButton>
                ))}
              </List>
            )}
            <TablePagination
              component="div" count={total} page={page} rowsPerPage={50} rowsPerPageOptions={[50]}
              onPageChange={(_, p) => setPage(p)}
            />
          </Paper>
        </Grid>

        <Grid item xs={12} md={8}>
          {!selected && <Alert severity="info">Sélectionnez une vue pour afficher sa structure.</Alert>}
          {selected && !detail && <CircularProgress />}
          {detail && (
            <Paper variant="outlined" sx={{ p: 2 }}>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: 1 }}>
                <Box>
                  <Typography variant="h5">{detail.viewname}</Typography>
                  <Typography variant="body2" color="text.secondary">
                    {detail.viewclass_label}{detail.roottab ? ` · table racine ${detail.roottab}` : ''}
                    {detail.description ? ` · ${detail.description}` : ''}
                  </Typography>
                </Box>
                <Box sx={{ display: 'flex', gap: 1, alignItems: 'center' }}>
                  {isAdmin && (
                    <Button variant="contained" disabled={busy || !detail.sql} onClick={() => createOrDrop(false)}>
                      {detail.created ? 'Recréer la vue' : 'Créer la vue'}
                    </Button>
                  )}
                  {isAdmin && detail.created && (
                    <Button color="error" disabled={busy} onClick={() => createOrDrop(true)}>Supprimer</Button>
                  )}
                  {detail.created && <Button disabled={busy} onClick={() => setTab(4)}>Voir les données</Button>}
                </Box>
              </Box>

              {detail.blocking.map((b) => <Alert key={b} severity="error" sx={{ mt: 1 }}>{b}</Alert>)}
              {detail.warnings.length > 0 && (
                <Alert severity="warning" sx={{ mt: 1 }}>
                  {detail.warnings.map((w) => <div key={w}>{w}</div>)}
                </Alert>
              )}

              <Tabs value={tab} onChange={(_, t) => setTab(t)} sx={{ mt: 1 }} variant="scrollable">
                <Tab label={`Tables et jointures (${detail.tables.length})`} />
                <Tab label={`Conditions (${detail.selection_conditions.length})`} />
                <Tab label={`Champs (${detail.fields.length})`} />
                <Tab label="SQL" />
                <Tab label="Données" disabled={!detail.created} />
              </Tabs>
              <Box sx={{ mt: 2 }}>
                {tab === 0 && (
                  <>
                    <SimpleTable
                      head={['Pos.', 'Table', 'Description', 'Dans raw_data']}
                      rows={detail.tables.map((t) => [
                        t.tabpos, <b key="t">{t.tabname}</b>, t.description || '',
                        <Chip key="p" size="small" label={t.present ? 'oui' : 'non'} color={t.present ? 'success' : 'error'} />,
                      ])}
                    />
                    <Typography variant="subtitle2" sx={{ mt: 2 }}>Conditions de jointure (SAP)</Typography>
                    <SimpleTable head={['Pos.', 'Table', 'Champ', 'Côté', 'Op.', 'Constante', 'Lien']} rows={condRows(detail.join_conditions)} />
                  </>
                )}
                {tab === 1 && (
                  detail.selection_conditions.length === 0
                    ? <Alert severity="info">Aucune condition de sélection : la vue ne filtre pas.</Alert>
                    : <>
                        <SimpleTable head={['Pos.', 'Table', 'Champ', 'Négation', 'Op.', 'Constante', 'Lien']} rows={condRows(detail.selection_conditions)} />
                        <Typography variant="subtitle2" sx={{ mt: 2 }}>Traduction SQL</Typography>
                        <Box component="pre" sx={{ fontSize: 12, whiteSpace: 'pre-wrap' }}>{detail.filters.join('\nAND ')}</Box>
                      </>
                )}
                {tab === 2 && (
                  <SimpleTable
                    head={['Pos.', 'Champ vue', 'Table', 'Champ source', 'Clé', 'Libellé']}
                    rows={detail.fields.map((f) => [f.objpos, <b key="v">{f.viewfield}</b>, f.tabname, f.fieldname, f.key_flag ? 'X' : '', f.label || ''])}
                  />
                )}
                {tab === 3 && (
                  detail.sql
                    ? <Box component="pre" sx={{ fontSize: 12, p: 2, bgcolor: 'action.hover', borderRadius: 1, overflow: 'auto', maxHeight: 560 }}>{detail.sql}</Box>
                    : <Alert severity="error">SQL non générable : voir les blocages ci-dessus.</Alert>
                )}
                {tab === 4 && (
                  busy || !data
                    ? <CircularProgress />
                    : <>
                        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                          {data.rows.length} premières lignes de sap_view.{detail.viewname.toLowerCase()}
                        </Typography>
                        <SimpleTable head={data.columns} rows={data.rows.map((r) => data.columns.map((c) => String(r[c] ?? '')))} />
                      </>
                )}
              </Box>
            </Paper>
          )}
        </Grid>
      </Grid>
    </Box>
  );
};

export default SapViewStructure;
