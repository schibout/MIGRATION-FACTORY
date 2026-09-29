import React, { useEffect, useMemo, useState } from 'react';
import {
  Alert, Box, Button, Chip, CircularProgress, Paper, Table, TableBody, TableCell, TableContainer, TableHead,
  TablePagination, TableRow, TableSortLabel, TextField, Typography,
} from '@mui/material';
import { Sync as SyncIcon, Upload as ImportIcon } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';

import api from '../services/api';

// Date de derniere execution par plan d'entretien (raw_data.plan_entretien_derniere_exec),
// completee par les gammes PE Tools du meme plan. Lecture seule, liste complete (~1 300 lignes).
interface Plan {
  plan_entretien: string;
  date_derniere_execution: string | null;
  jours_depuis: number | null;
  designation: string | null;
  poste_technique: string | null;
  frequence: string | null;
  organisation_maintenance: string | null;
  nb_gammes: number;
}
type Col = keyof Plan;

const fmtDate = (d: string | null) => (d ? `${d.slice(8, 10)}/${d.slice(5, 7)}/${d.slice(0, 4)}` : '');

// ponytail: seuils fixes (1 mois / 1 an), la frequence PE Tools n'est pas encore comparee.
const couleur = (j: number | null) => (j == null ? 'default' : j > 365 ? 'error' : j > 31 ? 'warning' : 'success');

const COLONNES: { key: Col; label: string }[] = [
  { key: 'plan_entretien', label: 'Plan d\'entretien' },
  { key: 'date_derniere_execution', label: 'Dernière exécution' },
  { key: 'jours_depuis', label: 'Depuis (jours)' },
  { key: 'designation', label: 'Désignation (PE Tools)' },
  { key: 'poste_technique', label: 'Poste technique' },
  { key: 'frequence', label: 'Fréquence' },
  { key: 'organisation_maintenance', label: 'Organisation' },
  { key: 'nb_gammes', label: 'Gammes PE Tools' },
];

const MaintenancePlansDerniereExecPage: React.FC = () => {
  const navigate = useNavigate();
  const [rows, setRows] = useState<Plan[]>([]);
  const [loading, setLoading] = useState(true);
  const [erreur, setErreur] = useState<string | null>(null);
  const [recherche, setRecherche] = useState('');
  const [tri, setTri] = useState<{ col: Col; asc: boolean }>({ col: 'date_derniere_execution', asc: true });
  const [page, setPage] = useState(0);
  const [parPage, setParPage] = useState(50);
  const [synchro, setSynchro] = useState(false);
  const [message, setMessage] = useState<{ ok: boolean; texte: string } | null>(null);

  const synchroniser = () => {
    setSynchro(true);
    setMessage(null);
    api.post('/maintenance/plans-derniere-execution/sync')
      .then((res) => {
        const d = res.data || {};
        setMessage({ ok: true, texte: `PE Tools synchronisé : ${d.lignes_mises_a_jour} ligne(s) mise(s) à jour, `
          + `${d.datees} gamme(s) sur ${d.total} portent une date de dernière exécution.` });
      })
      .catch((e) => setMessage({ ok: false, texte: e?.response?.data?.error || 'Synchronisation impossible' }))
      .finally(() => setSynchro(false));
  };

  useEffect(() => {
    api.get('/maintenance/plans-derniere-execution')
      .then((res) => setRows(res.data?.data || []))
      .catch((e) => setErreur(e?.response?.data?.error || 'Chargement impossible'))
      .finally(() => setLoading(false));
  }, []);

  const visibles = useMemo(() => {
    const q = recherche.trim().toLowerCase();
    const retenues = rows.filter((r) => !q || COLONNES.some((c) => String(r[c.key] ?? '').toLowerCase().includes(q)));
    const { col, asc } = tri;
    return retenues.sort((a, b) =>
      String(a[col] ?? '').localeCompare(String(b[col] ?? ''), 'fr', { numeric: true }) * (asc ? 1 : -1));
  }, [rows, recherche, tri]);

  const plusDunAn = rows.filter((r) => (r.jours_depuis ?? 0) > 365).length;

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 2, flexWrap: 'wrap' }}>
        <Typography variant="h4" sx={{ fontWeight: 600, mb: 1 }}>Dernière exécution des plans</Typography>
        <Box sx={{ display: 'flex', gap: 1 }}>
          {/* Recopie la date dans raw_data.pe_tools.date_derniere_execution (migration 082). */}
          <Button variant="outlined" startIcon={<SyncIcon />} disabled={synchro} onClick={synchroniser}>
            {synchro ? 'Synchronisation…' : 'Synchroniser avec PE Tools'}
          </Button>
          {/* Le fichier Excel se charge par l'import generique (table plan_entretien_derniere_exec). */}
          <Button variant="outlined" startIcon={<ImportIcon />} onClick={() => navigate('/import/generic')}>
            Importer
          </Button>
        </Box>
      </Box>
      {message && (
        <Alert severity={message.ok ? 'success' : 'error'} sx={{ mb: 2 }} onClose={() => setMessage(null)}>
          {message.texte}
        </Alert>
      )}
      <Typography variant="body1" color="text.secondary" sx={{ mb: 2 }}>
        Date de dernière exécution de chaque plan d'entretien SAP. Désignation, poste technique, fréquence et
        organisation viennent des gammes PE Tools du même plan, quand il y en a.
      </Typography>

      {erreur && <Alert severity="error" sx={{ mb: 2 }}>{erreur}</Alert>}

      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2, flexWrap: 'wrap' }}>
        <TextField
          size="small" label="Rechercher" value={recherche} sx={{ width: 360 }}
          onChange={(e) => { setRecherche(e.target.value); setPage(0); }}
        />
        <Typography variant="body2" color="text.secondary">{visibles.length.toLocaleString()} plan(s)</Typography>
        {plusDunAn > 0 && <Chip size="small" color="error" variant="outlined" label={`${plusDunAn} non exécutés depuis plus d'un an`} />}
      </Box>

      <Paper variant="outlined">
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', p: 6 }}><CircularProgress /></Box>
        ) : (
          <>
            <TableContainer sx={{ maxHeight: 'calc(100vh - 280px)' }}>
              <Table size="small" stickyHeader>
                <TableHead>
                  <TableRow>
                    {COLONNES.map((c) => (
                      <TableCell key={c.key} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>
                        <TableSortLabel
                          active={tri.col === c.key}
                          direction={tri.col === c.key && !tri.asc ? 'desc' : 'asc'}
                          onClick={() => setTri({ col: c.key, asc: tri.col !== c.key || !tri.asc })}
                        >
                          {c.label}
                        </TableSortLabel>
                      </TableCell>
                    ))}
                  </TableRow>
                </TableHead>
                <TableBody>
                  {visibles.slice(page * parPage, (page + 1) * parPage).map((r) => (
                    <TableRow hover key={r.plan_entretien}>
                      <TableCell sx={{ fontFamily: 'monospace' }}>{r.plan_entretien}</TableCell>
                      <TableCell>{fmtDate(r.date_derniere_execution)}</TableCell>
                      <TableCell>
                        {r.jours_depuis != null && (
                          <Chip size="small" color={couleur(r.jours_depuis)} label={r.jours_depuis.toLocaleString()} />
                        )}
                      </TableCell>
                      <TableCell>{r.designation}</TableCell>
                      <TableCell>{r.poste_technique}</TableCell>
                      <TableCell>{r.frequence}</TableCell>
                      <TableCell>{r.organisation_maintenance}</TableCell>
                      <TableCell>{Number(r.nb_gammes) || ''}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
            <TablePagination
              component="div"
              count={visibles.length}
              page={page}
              onPageChange={(_, p) => setPage(p)}
              rowsPerPage={parPage}
              onRowsPerPageChange={(e) => { setParPage(Number(e.target.value)); setPage(0); }}
              rowsPerPageOptions={[25, 50, 100, 250]}
              labelRowsPerPage="Lignes par page"
            />
          </>
        )}
      </Paper>
    </Box>
  );
};

export default MaintenancePlansDerniereExecPage;
