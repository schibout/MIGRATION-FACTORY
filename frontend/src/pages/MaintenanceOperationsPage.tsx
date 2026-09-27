import React, { useEffect, useMemo, useState } from 'react';
import {
  Alert, Autocomplete, Box, Button, CircularProgress, Paper, Table, TableBody, TableCell, TableContainer,
  IconButton, TableHead, TablePagination, TableRow, TableSortLabel, TextField, Tooltip, Typography,
} from '@mui/material';
import { Visibility as DetailIcon } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';

import api from '../services/api';
import SyncSapOperationsButton from '../components/maintenance/SyncSapOperationsButton';

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

const COLONNES: { key: Col; label: string; texte?: (o: Operation) => string }[] = [
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
  { key: 'debut_planifie', label: 'Début planifié', texte: (o) => fmtDate(o.debut_planifie) },
  { key: 'fin_planifiee', label: 'Fin planifiée', texte: (o) => fmtDate(o.fin_planifiee) },
  { key: 'travail', label: 'Travail', texte: (o) => (o.travail ? `${Number(o.travail)} ${o.unite_travail || ''}` : '') },
];

// Valeur telle qu'affichee : c'est elle que filtrent la recherche et les filtres de colonne.
const affiche = (o: Operation, c: typeof COLONNES[number]) => (c.texte ? c.texte(o) : String(o[c.key] ?? ''));

const MaintenanceOperationsPage: React.FC = () => {
  const navigate = useNavigate();
  const [rows, setRows] = useState<Operation[]>([]);
  const [loading, setLoading] = useState(true);
  const [erreur, setErreur] = useState<string | null>(null);
  const [recherche, setRecherche] = useState('');
  const [filtres, setFiltres] = useState<Partial<Record<Col, string>>>({});
  const [tri, setTri] = useState<{ col: Col; asc: boolean }>({ col: 'ordre', asc: true });
  const [page, setPage] = useState(0);
  const [parPage, setParPage] = useState(50);

  const charger = () => {
    setLoading(true);
    api.get('/maintenance/operations')
      .then((res) => setRows(res.data?.data || []))
      .catch((e) => setErreur(e?.response?.data?.error || 'Chargement des opérations impossible'))
      .finally(() => setLoading(false));
  };
  useEffect(charger, []);

  // Valeurs distinctes de chaque colonne, proposees dans la liste du filtre.
  const choix = useMemo(() => Object.fromEntries(COLONNES.map((c) => [c.key,
    [...new Set(rows.map((o) => affiche(o, c)).filter(Boolean))]
      .sort((a, b) => a.localeCompare(b, 'fr', { numeric: true }))])) as Record<Col, string[]>, [rows]);

  const visibles = useMemo(() => {
    const q = recherche.trim().toLowerCase();
    const actifs = COLONNES
      .map((c) => ({ c, v: (filtres[c.key] || '').trim().toLowerCase() }))
      .filter((f) => f.v);
    const retenues = rows.filter((o) =>
      (!q || COLONNES.some((c) => affiche(o, c).toLowerCase().includes(q)))
      && actifs.every(({ c, v }) => affiche(o, c).toLowerCase().includes(v)));
    const { col, asc } = tri;
    return retenues.sort((a, b) =>
      String(a[col] ?? '').localeCompare(String(b[col] ?? ''), 'fr', { numeric: true }) * (asc ? 1 : -1));
  }, [rows, recherche, filtres, tri]);

  const setFiltre = (col: Col, v: string) => { setFiltres((f) => ({ ...f, [col]: v })); setPage(0); };

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 2, flexWrap: 'wrap' }}>
        <Typography variant="h4" sx={{ fontWeight: 600, mb: 1 }}>Opérations</Typography>
        <SyncSapOperationsButton onDone={charger} />
      </Box>
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
        {Object.values(filtres).some(Boolean) && (
          <Button size="small" onClick={() => { setFiltres({}); setPage(0); }}>Effacer les filtres</Button>
        )}
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
                    <TableCell />
                    {COLONNES.map((c) => (
                      <TableCell key={c.key} sx={{ fontWeight: 600, whiteSpace: 'nowrap', verticalAlign: 'top' }}>
                        <TableSortLabel
                          active={tri.col === c.key}
                          direction={tri.col === c.key && !tri.asc ? 'desc' : 'asc'}
                          onClick={() => setTri({ col: c.key, asc: tri.col !== c.key || !tri.asc })}
                        >
                          {c.label}
                        </TableSortLabel>
                        {/* Saisie libre (contient) ou choix d'une valeur existante. */}
                        <Autocomplete
                          freeSolo
                          size="small"
                          options={choix[c.key] || []}
                          filterOptions={(opts, { inputValue }) => {
                            const v = inputValue.toLowerCase();
                            // ponytail: 200 premieres valeurs, la liste de 6 000 ordres ne sert pas a choisir.
                            return opts.filter((o) => o.toLowerCase().includes(v)).slice(0, 200);
                          }}
                          inputValue={filtres[c.key] || ''}
                          onInputChange={(_, v) => setFiltre(c.key, v)}
                          sx={{ mt: 0.5, minWidth: 120 }}
                          renderInput={(params) => <TextField {...params} placeholder="Filtrer" variant="standard" />}
                        />
                      </TableCell>
                    ))}
                  </TableRow>
                </TableHead>
                <TableBody>
                  {visibles.slice(page * parPage, (page + 1) * parPage).map((o) => (
                    <TableRow hover key={`${o.ordre}-${o.operation}`}>
                      <TableCell padding="checkbox">
                        <Tooltip title="Voir détail">
                          <IconButton size="small" onClick={() => navigate(`/maintenance/operations/${o.ordre}`)}>
                            <DetailIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                      </TableCell>
                      {COLONNES.map((c) => (
                        <TableCell key={c.key}>{affiche(o, c)}</TableCell>
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
