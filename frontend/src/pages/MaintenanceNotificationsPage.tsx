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
import SyncSapOperationsButton, { TABLES_AVIS } from '../components/maintenance/SyncSapOperationsButton';

// Avis de maintenance SAP (QMEL/QMIH), selectionnes cote serveur (ecran de selection type IW29).
interface Avis {
  avis: string;
  type_avis: string | null;
  statut: string | null;
  texte: string | null;
  division: string | null;
  poste_technique: string | null;
  equipement: string | null;
  poste_responsable: string | null;
  priorite: string | null;
  date_avis: string | null;
  debut_souhaite: string | null;
  fin_souhaitee: string | null;
  ordre: string | null;
  auteur: string | null;
}

type Col = keyof Avis;

// SAP stocke les dates en texte YYYYMMDD : triables telles quelles, formatees a l'affichage.
const fmtDate = (d: string | null) => (d && d.length === 8 ? `${d.slice(6)}/${d.slice(4, 6)}/${d.slice(0, 4)}` : '');

const COLONNES: { key: Col; label: string; texte?: (a: Avis) => string }[] = [
  { key: 'avis', label: 'Avis' },
  { key: 'type_avis', label: 'Type' },
  { key: 'statut', label: 'Statut' },
  { key: 'texte', label: 'Description' },
  { key: 'poste_technique', label: 'Poste technique' },
  { key: 'equipement', label: 'Équipement' },
  { key: 'division', label: 'Division' },
  { key: 'poste_responsable', label: 'Poste resp.' },
  { key: 'priorite', label: 'Prio.' },
  { key: 'date_avis', label: 'Date avis', texte: (a) => fmtDate(a.date_avis) },
  { key: 'debut_souhaite', label: 'Début souhaité', texte: (a) => fmtDate(a.debut_souhaite) },
  { key: 'fin_souhaitee', label: 'Fin souhaitée', texte: (a) => fmtDate(a.fin_souhaitee) },
  { key: 'ordre', label: 'Ordre' },
  { key: 'auteur', label: 'Auteur' },
];

// Valeur telle qu'affichee : c'est elle que filtrent la recherche et les filtres de colonne.
const affiche = (a: Avis, c: typeof COLONNES[number]) => (c.texte ? c.texte(a) : String(a[c.key] ?? ''));

// Criteres de l'ecran de selection. Par defaut : avis en cours, sans autre borne.
interface Selection {
  en_cours: boolean;
  clotures: boolean;
  date_debut: string;
  date_fin: string;
  division: string;
  type_avis: string;
  poste_responsable: string;
  poste_technique: string;
  avis: string;
}
const SELECTION_DEFAUT: Selection = {
  en_cours: true, clotures: false,
  date_debut: '', date_fin: '', division: '', type_avis: '', poste_responsable: '', poste_technique: '', avis: '',
};
// La selection est gardee pour la session : revenir du detail d'un avis relance la meme.
const CLE_SELECTION = 'maintenance.avis.selection';
const lireSelection = (): Selection => {
  try { return { ...SELECTION_DEFAUT, ...JSON.parse(sessionStorage.getItem(CLE_SELECTION) || '{}') }; } catch { return SELECTION_DEFAUT; }
};
const versParams = (s: Selection) => Object.fromEntries(Object.entries(s)
  .filter(([, v]) => v !== '')
  .map(([k, v]) => [k, typeof v === 'boolean' ? (v ? '1' : '0') : v.trim()]));

const MaintenanceNotificationsPage: React.FC = () => {
  const navigate = useNavigate();
  const [rows, setRows] = useState<Avis[]>([]);
  const [loading, setLoading] = useState(true);
  const [erreur, setErreur] = useState<string | null>(null);
  const [recherche, setRecherche] = useState('');
  const [filtres, setFiltres] = useState<Partial<Record<Col, string>>>({});
  const [tri, setTri] = useState<{ col: Col; asc: boolean }>({ col: 'avis', asc: false });
  const [page, setPage] = useState(0);
  const [parPage, setParPage] = useState(50);
  const [selection, setSelection] = useState<Selection>(lireSelection);
  const [selectionOuverte, setSelectionOuverte] = useState(true);
  const [tronque, setTronque] = useState<number | null>(null);
  const [listes, setListes] = useState<{ divisions: string[]; types_avis: string[]; postes_responsables: string[] }>(
    { divisions: [], types_avis: [], postes_responsables: [] });

  const charger = (s: Selection = selection) => {
    if (!s.en_cours && !s.clotures) {
      setErreur('Cocher au moins un statut : en cours ou clôturés.');
      return;
    }
    try { sessionStorage.setItem(CLE_SELECTION, JSON.stringify(s)); } catch { /* confort seulement */ }
    setLoading(true);
    setErreur(null);
    api.get('/maintenance/notifications', { params: versParams(s) })
      .then((res) => {
        setRows(res.data?.data || []);
        setTronque(res.data?.tronque ? res.data.max : null);
        setPage(0);
      })
      .catch((e) => setErreur(e?.response?.data?.error || 'Chargement des avis impossible'))
      .finally(() => setLoading(false));
  };
  useEffect(() => {
    charger();
    api.get('/maintenance/notifications/choix').then((res) => res.data?.data && setListes(res.data.data)).catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const maj = (champ: keyof Selection, valeur: string | boolean) => setSelection((s) => ({ ...s, [champ]: valeur }));

  const choix = useMemo(() => Object.fromEntries(COLONNES.map((c) => [c.key,
    [...new Set(rows.map((a) => affiche(a, c)).filter(Boolean))]
      .sort((x, y) => x.localeCompare(y, 'fr', { numeric: true }))])) as Record<Col, string[]>, [rows]);

  const visibles = useMemo(() => {
    const q = recherche.trim().toLowerCase();
    const actifs = COLONNES
      .map((c) => ({ c, v: (filtres[c.key] || '').trim().toLowerCase() }))
      .filter((f) => f.v);
    const retenues = rows.filter((a) =>
      (!q || COLONNES.some((c) => affiche(a, c).toLowerCase().includes(q)))
      && actifs.every(({ c, v }) => affiche(a, c).toLowerCase().includes(v)));
    const { col, asc } = tri;
    return retenues.sort((a, b) =>
      String(a[col] ?? '').localeCompare(String(b[col] ?? ''), 'fr', { numeric: true }) * (asc ? 1 : -1));
  }, [rows, recherche, filtres, tri]);

  const setFiltre = (col: Col, v: string) => { setFiltres((f) => ({ ...f, [col]: v })); setPage(0); };

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 2, flexWrap: 'wrap' }}>
        <Typography variant="h4" sx={{ fontWeight: 600, mb: 1 }}>Avis</Typography>
        <SyncSapOperationsButton onDone={() => charger()} tables={TABLES_AVIS} ecran="Avis" />
      </Box>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 2 }}>
        Avis de maintenance SAP. « En cours » = avis ni clôturé (ACLO), ni marqué pour suppression (TSUP).
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
              <Typography variant="body2" color="text.secondary" sx={{ mr: 1 }}>Statut de l'avis :</Typography>
              <FormControlLabel
                control={<Checkbox checked={selection.en_cours} onChange={(e) => maj('en_cours', e.target.checked)} />}
                label="En cours (Ouvert + En traitement)"
              />
              <FormControlLabel
                control={<Checkbox checked={selection.clotures} onChange={(e) => maj('clotures', e.target.checked)} />}
                label="Clôturés"
              />
            </Box>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, flexWrap: 'wrap' }}>
              <TextField
                size="small" type="date" label="Date d'avis du" InputLabelProps={{ shrink: true }}
                value={selection.date_debut} onChange={(e) => maj('date_debut', e.target.value)}
              />
              <TextField
                size="small" type="date" label="au" InputLabelProps={{ shrink: true }}
                value={selection.date_fin} onChange={(e) => maj('date_fin', e.target.value)}
              />
              {([
                ['division', 'Division', listes.divisions],
                ['type_avis', "Type d'avis", listes.types_avis],
                ['poste_responsable', 'Poste resp.', listes.postes_responsables],
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
                size="small" label="Poste technique (et dessous)" sx={{ width: 220 }}
                value={selection.poste_technique} onChange={(e) => maj('poste_technique', e.target.value)}
              />
              <TextField
                size="small" label="N° d'avis" sx={{ width: 150 }}
                value={selection.avis} onChange={(e) => maj('avis', e.target.value)}
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
          Plus de {tronque.toLocaleString()} avis correspondent : seuls les {tronque.toLocaleString()} plus récents
          (par n° d'avis) sont affichés. Précisez la sélection (période, division, type…).
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
          {visibles.length.toLocaleString()} avis
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
                        <Autocomplete
                          freeSolo
                          size="small"
                          options={choix[c.key] || []}
                          filterOptions={(opts, { inputValue }) => {
                            const v = inputValue.toLowerCase();
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
                  {visibles.slice(page * parPage, (page + 1) * parPage).map((a) => (
                    <TableRow hover key={a.avis}>
                      <TableCell padding="checkbox">
                        <Tooltip title="Voir détail">
                          <IconButton size="small" onClick={() => navigate(`/maintenance/avis/${a.avis}`)}>
                            <DetailIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                      </TableCell>
                      {COLONNES.map((c) => (
                        <TableCell key={c.key}>{affiche(a, c)}</TableCell>
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

export default MaintenanceNotificationsPage;
