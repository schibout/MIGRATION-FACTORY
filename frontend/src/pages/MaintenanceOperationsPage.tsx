import React, { useEffect, useMemo, useState } from 'react';
import {
  Alert, Autocomplete, Box, Button, Checkbox, CircularProgress, Collapse, FormControlLabel, Paper, Table,
  TableBody, TableCell, TableContainer,
  IconButton, TableHead, TablePagination, TableRow, TableSortLabel, TextField, Tooltip, Typography,
} from '@mui/material';
import {
  ExpandLess as ReplierIcon, ExpandMore as DeplierIcon, PlayArrow as ExecuterIcon, Visibility as DetailIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';

import api from '../services/api';
import SyncSapOperationsButton from '../components/maintenance/SyncSapOperationsButton';

// Operations SAP (AFVC), selectionnees cote serveur (ecran de selection type IW37N).
interface Operation {
  ordre: string;
  statut_ordre: string | null;
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
  { key: 'statut_ordre', label: 'Statut ordre' },
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

// Criteres de l'ecran de selection. Par defaut : operations en cours, sans autre borne.
interface Selection {
  en_cours: boolean;
  clotures: boolean;
  exclure_confirmees: boolean;
  date_debut: string;
  date_fin: string;
  division: string;
  poste_travail: string;
  type_ordre: string;
  ordre: string;
}
const SELECTION_DEFAUT: Selection = {
  en_cours: true, clotures: false, exclure_confirmees: false,
  date_debut: '', date_fin: '', division: '', poste_travail: '', type_ordre: '', ordre: '',
};
// La selection est gardee pour la session : revenir du detail d'un ordre relance la meme.
const CLE_SELECTION = 'maintenance.operations.selection';
const lireSelection = (): Selection => {
  try { return { ...SELECTION_DEFAUT, ...JSON.parse(sessionStorage.getItem(CLE_SELECTION) || '{}') }; } catch { return SELECTION_DEFAUT; }
};
// Cases envoyees en '1'/'0' (le serveur considere en_cours absent comme coche).
const versParams = (s: Selection) => Object.fromEntries(Object.entries(s)
  .filter(([, v]) => v !== '')
  .map(([k, v]) => [k, typeof v === 'boolean' ? (v ? '1' : '0') : v.trim()]));

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
  const [selection, setSelection] = useState<Selection>(lireSelection);
  const [selectionOuverte, setSelectionOuverte] = useState(true);
  const [tronque, setTronque] = useState<number | null>(null);
  const [listes, setListes] = useState<{ divisions: string[]; postes_travail: string[]; types_ordre: string[] }>(
    { divisions: [], postes_travail: [], types_ordre: [] });

  const charger = (s: Selection = selection) => {
    if (!s.en_cours && !s.clotures) {
      setErreur('Cocher au moins un statut : en cours ou clôturés.');
      return;
    }
    try { sessionStorage.setItem(CLE_SELECTION, JSON.stringify(s)); } catch { /* confort seulement */ }
    setLoading(true);
    setErreur(null);
    api.get('/maintenance/operations', { params: versParams(s) })
      .then((res) => {
        setRows(res.data?.data || []);
        setTronque(res.data?.tronque ? res.data.max : null);
        setPage(0);
      })
      .catch((e) => setErreur(e?.response?.data?.error || 'Chargement des opérations impossible'))
      .finally(() => setLoading(false));
  };
  useEffect(() => {
    charger();
    api.get('/maintenance/operations/choix').then((res) => res.data?.data && setListes(res.data.data)).catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const maj = (champ: keyof Selection, valeur: string | boolean) => setSelection((s) => ({ ...s, [champ]: valeur }));

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
        <SyncSapOperationsButton onDone={() => charger()} />
      </Box>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 2 }}>
        Opérations SAP des ordres de maintenance. « En cours » = ordre ni clôturé techniquement (TCLO),
        ni clôturé (CLOT), ni marqué pour suppression (TSUP).
      </Typography>

      <Paper variant="outlined" sx={{ mb: 2 }}>
        <Box
          sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', px: 2, py: 1, cursor: 'pointer' }}
          onClick={() => setSelectionOuverte((o) => !o)}
        >
          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Sélection</Typography>
          {selectionOuverte ? <ReplierIcon /> : <DeplierIcon />}
        </Box>
        <Collapse in={selectionOuverte}>
          <Box
            component="form"
            onSubmit={(e: React.FormEvent) => { e.preventDefault(); charger(); }}
            sx={{ px: 2, pb: 2, display: 'flex', flexDirection: 'column', gap: 2 }}
          >
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flexWrap: 'wrap' }}>
              <Typography variant="body2" color="text.secondary" sx={{ mr: 1 }}>Statut de l'ordre :</Typography>
              <FormControlLabel
                control={<Checkbox checked={selection.en_cours} onChange={(e) => maj('en_cours', e.target.checked)} />}
                label="En cours (Ouvert + Lancé)"
              />
              <FormControlLabel
                control={<Checkbox checked={selection.clotures} onChange={(e) => maj('clotures', e.target.checked)} />}
                label="Clôturés"
              />
              <FormControlLabel
                control={<Checkbox checked={selection.exclure_confirmees} onChange={(e) => maj('exclure_confirmees', e.target.checked)} />}
                label="Exclure les opérations déjà confirmées"
              />
            </Box>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, flexWrap: 'wrap' }}>
              <TextField
                size="small" type="date" label="Début planifié du" InputLabelProps={{ shrink: true }}
                value={selection.date_debut} onChange={(e) => maj('date_debut', e.target.value)}
              />
              <TextField
                size="small" type="date" label="au" InputLabelProps={{ shrink: true }}
                value={selection.date_fin} onChange={(e) => maj('date_fin', e.target.value)}
              />
              {([
                ['division', 'Division', listes.divisions],
                ['poste_travail', 'Pos. trav.', listes.postes_travail],
                ['type_ordre', "Type d'ordre", listes.types_ordre],
              ] as [keyof Selection, string, string[]][]).map(([champ, label, options]) => (
                <Autocomplete
                  key={champ}
                  freeSolo
                  size="small"
                  options={options}
                  inputValue={String(selection[champ])}
                  onInputChange={(_, v) => maj(champ, v)}
                  sx={{ width: 170 }}
                  renderInput={(params) => <TextField {...params} label={label} />}
                />
              ))}
              <TextField
                size="small" label="N° d'ordre" sx={{ width: 150 }}
                value={selection.ordre} onChange={(e) => maj('ordre', e.target.value)}
              />
              <Button type="submit" variant="contained" startIcon={<ExecuterIcon />} disabled={loading}>
                Exécuter
              </Button>
              <Button onClick={() => setSelection(SELECTION_DEFAUT)}>Réinitialiser</Button>
            </Box>
          </Box>
        </Collapse>
      </Paper>

      {erreur && <Alert severity="error" sx={{ mb: 2 }}>{erreur}</Alert>}
      {tronque && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          Plus de {tronque.toLocaleString()} opérations correspondent : seules les {tronque.toLocaleString()} premières
          (par n° d'ordre) sont affichées. Précisez la sélection (période, division, poste de travail…).
        </Alert>
      )}

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
