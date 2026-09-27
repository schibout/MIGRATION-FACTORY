import React, { useEffect, useMemo, useState } from 'react';
import {
  Alert, Box, CircularProgress, Paper, Table, TableBody, TableCell, TableContainer,
  TableHead, TablePagination, TableRow, TableSortLabel, TextField, Typography,
} from '@mui/material';

import api from '../services/api';

// Operations SAP (AFVC) des ordres non clos -- meme perimetre que l'ETL Operations.
interface Operation {
  ordre: string;
  type_ordre: string | null;
  texte_ordre: string | null;
  operation: string;
  texte_operation: string | null;
  division: string | null;
  poste_travail: string | null;
  poste_technique: string | null;
  equipement: string | null;
  debut_planifie: string | null;
  fin_planifiee: string | null;
  travail: string | null;
  unite_travail: string | null;
}

type Col = keyof Operation;

// SAP stocke les dates en texte YYYYMMDD : triables telles quelles, formatees a l'affichage.
const fmtDate = (d: string | null) => (d && d.length === 8 ? `${d.slice(6)}/${d.slice(4, 6)}/${d.slice(0, 4)}` : '');

const COLONNES: { key: Col; label: string; render?: (o: Operation) => React.ReactNode }[] = [
  // Les 4 premieres colonnes reprennent la liste SAP (IW37N) : minimum demande.
  { key: 'ordre', label: 'Ordre' },
  { key: 'operation', label: 'Opé.' },
  { key: 'poste_travail', label: 'Pos. trav.' },
  { key: 'texte_operation', label: 'Désignation opération' },
  { key: 'type_ordre', label: 'Type' },
  { key: 'texte_ordre', label: 'Désignation ordre' },
  { key: 'division', label: 'Division' },
  { key: 'poste_technique', label: 'Poste technique' },
  { key: 'equipement', label: 'Équipement' },
  { key: 'debut_planifie', label: 'Début planifié', render: (o) => fmtDate(o.debut_planifie) },
  { key: 'fin_planifiee', label: 'Fin planifiée', render: (o) => fmtDate(o.fin_planifiee) },
  { key: 'travail', label: 'Travail', render: (o) => (o.travail ? `${Number(o.travail)} ${o.unite_travail || ''}` : '') },
];

const MaintenanceOperationsPage: React.FC = () => {
  const [rows, setRows] = useState<Operation[]>([]);
  const [loading, setLoading] = useState(true);
  const [erreur, setErreur] = useState<string | null>(null);
  const [recherche, setRecherche] = useState('');
  const [tri, setTri] = useState<{ col: Col; asc: boolean }>({ col: 'ordre', asc: true });
  const [page, setPage] = useState(0);
  const [parPage, setParPage] = useState(50);

  useEffect(() => {
    api.get('/maintenance/operations')
      .then((res) => setRows(res.data?.data || []))
      .catch((e) => setErreur(e?.response?.data?.error || 'Chargement des opérations impossible'))
      .finally(() => setLoading(false));
  }, []);

  const visibles = useMemo(() => {
    const q = recherche.trim().toLowerCase();
    const filtres = q
      ? rows.filter((o) => COLONNES.some((c) => String(o[c.key] ?? '').toLowerCase().includes(q)))
      : rows;
    const { col, asc } = tri;
    return [...filtres].sort((a, b) =>
      String(a[col] ?? '').localeCompare(String(b[col] ?? ''), 'fr', { numeric: true }) * (asc ? 1 : -1));
  }, [rows, recherche, tri]);

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" sx={{ fontWeight: 600, mb: 1 }}>Opérations</Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
        Opérations SAP des ordres de maintenance non clos (hors TECO, CLSD, DLFL).
      </Typography>

      {erreur && <Alert severity="error" sx={{ mb: 2 }}>{erreur}</Alert>}

      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
        <TextField
          size="small"
          label="Rechercher"
          value={recherche}
          onChange={(e) => { setRecherche(e.target.value); setPage(0); }}
          sx={{ width: 360 }}
        />
        <Typography variant="body2" color="text.secondary">
          {visibles.length.toLocaleString()} opération(s)
        </Typography>
      </Box>

      <Paper variant="outlined">
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', p: 6 }}><CircularProgress /></Box>
        ) : (
          <>
            <TableContainer sx={{ maxHeight: 'calc(100vh - 300px)' }}>
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
                  {visibles.slice(page * parPage, (page + 1) * parPage).map((o) => (
                    <TableRow hover key={`${o.ordre}-${o.operation}`}>
                      {COLONNES.map((c) => (
                        <TableCell key={c.key}>{c.render ? c.render(o) : o[c.key]}</TableCell>
                      ))}
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

export default MaintenanceOperationsPage;
