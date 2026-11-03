import { Edit as EditIcon, FileDownload as ExcelIcon } from '@mui/icons-material';
import {
  Alert,
  Box,
  Button,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  LinearProgress,
  MenuItem,
  Paper,
  Select,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
  Tooltip,
  Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import api from '../../services/api';

// Onglet « Reprise IFS » de Finance > Historique des coûts : OD de reprise des coûts
// historiques (clean_data.reprise_cout_projet, sql/historiqueCoutProjet/03_*).

interface Ligne {
  numero_projet: string;
  projet: string;
  projet_libelle: string | null;
  element_otp: string;
  otp_libelle: string | null;
  nature: 'CAPEX' | 'OPEX' | null;
  nature_source: 'SUFFIXE' | 'MANUELLE' | null;
  montant: number;
  project_id_ifs: string;
  project_id_source: 'SAISIE' | 'N_PROJET';
  activity_seq: number | null;
  anomalies: string[];
  exporte: boolean;
}

interface Reponse {
  arrete: { date: string; exercice: number | null; periode: number | null };
  rows: Ligne[];
  libelles_anomalies: Record<string, string>;
  saisies: Record<string, { project_id_ifs: string | null; activity_seq_capex: number | null;
    activity_seq_opex: number | null; saisi_par: string; saisi_le: string }>;
}

interface Saisie { numero_projet: string; project_id_ifs: string; activity_seq_capex: string; activity_seq_opex: string }

type Filtre = 'anomalies' | 'pretes' | 'toutes';

const euros = (v: number | null | undefined) =>
  v == null ? '—' : v.toLocaleString('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

// Dernier mois clos par défaut ; RPSCO ne permet qu'un arrêté mensuel (fin de mois).
const moisPrecedent = () => {
  const d = new Date();
  d.setDate(0);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
};
const finDeMois = (mois: string) => {
  const [a, m] = mois.split('-').map(Number);
  return `${mois}-${String(new Date(a, m, 0).getDate()).padStart(2, '0')}`;
};

const RepriseCoutsIfs: React.FC = () => {
  const [mois, setMois] = useState(moisPrecedent());
  const [data, setData] = useState<Reponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [filtre, setFiltre] = useState<Filtre>('anomalies');
  const [filtreNature, setFiltreNature] = useState('');      // '' = toutes, 'A_QUALIFIER' = sans nature
  const [filtreAnomalie, setFiltreAnomalie] = useState('');  // '' = toutes, sinon code d'anomalie
  const [saisie, setSaisie] = useState<Saisie | null>(null);
  const [exporting, setExporting] = useState(false);

  const dateArrete = mois ? finDeMois(mois) : '';

  const load = useCallback(async () => {
    if (!dateArrete) return;
    try {
      setLoading(true);
      setError(null);
      const res = await api.get<Reponse>('/finance/historique-couts/reprise', { params: { date_arrete: dateArrete } });
      setData(res.data);
    } catch (err: any) {
      setError(err?.response?.data?.error ?? 'Erreur lors du calcul de la reprise');
    } finally {
      setLoading(false);
    }
  }, [dateArrete]);

  useEffect(() => {
    load();
  }, [load]);

  const rows = data?.rows ?? [];
  const enAnomalie = rows.filter((r) => r.anomalies.length > 0);
  const affichees = (filtre === 'anomalies' ? enAnomalie : filtre === 'pretes' ? rows.filter((r) => r.exporte) : rows)
    .filter((r) => !filtreNature || (r.nature ?? 'A_QUALIFIER') === filtreNature)
    .filter((r) => !filtreAnomalie || r.anomalies.includes(filtreAnomalie));
  const compte = (pred: (r: Ligne) => boolean) => rows.filter(pred).length;
  const codesAnomalies = Array.from(new Set(rows.flatMap((r) => r.anomalies))).sort();
  const totaux = useMemo(() => {
    const t = { CAPEX: 0, OPEX: 0, aQualifier: 0, exporte: 0 };
    rows.forEach((r) => {
      if (r.nature) t[r.nature] += r.montant;
      else t.aQualifier += r.montant;
      if (r.exporte) t.exporte += r.montant;
    });
    return t;
  }, [rows]);

  const qualifier = async (r: Ligne, nature: string) => {
    try {
      await api.put(`/finance/historique-couts/reprise/nature/${encodeURIComponent(r.element_otp)}`, { nature: nature || null });
      load();
    } catch (err: any) {
      setError(err?.response?.data?.error ?? 'Qualification non enregistrée');
    }
  };

  const ouvrirSaisie = (r: Ligne) => {
    const s = data?.saisies[r.numero_projet];
    setSaisie({
      numero_projet: r.numero_projet,
      project_id_ifs: s?.project_id_ifs ?? '',
      activity_seq_capex: String(s?.activity_seq_capex ?? ''),
      activity_seq_opex: String(s?.activity_seq_opex ?? ''),
    });
  };

  const enregistrerSaisie = async () => {
    if (!saisie) return;
    try {
      await api.put(`/finance/historique-couts/reprise/projet/${encodeURIComponent(saisie.numero_projet)}`, saisie);
      setSaisie(null);
      load();
    } catch (err: any) {
      setError(err?.response?.data?.error ?? 'Correspondance non enregistrée');
    }
  };

  const handleExport = async () => {
    try {
      setExporting(true);
      setError(null);
      const res = await api.get('/finance/historique-couts/reprise/export.xlsx', {
        params: { date_arrete: dateArrete }, responseType: 'blob',
      });
      const match = /filename="?([^";]+)"?/.exec(res.headers['content-disposition'] ?? '');
      const url = window.URL.createObjectURL(res.data);
      const link = document.createElement('a');
      link.href = url;
      link.download = match?.[1] ?? 'reprise_couts_projet.xlsx';
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (err: any) {
      setError(err?.response?.status === 409 ? 'Export refusé : des lignes sont en anomalie' : "Erreur lors de l'export");
    } finally {
      setExporting(false);
    }
  };

  return (
    <Box>
      <Alert severity="info" sx={{ mb: 2 }}>
        Projets « À migrer » uniquement. Montant = somme du réel périodique (hors répartition KOAO) jusqu'à
        l'arrêté, par élément d'OTP : ni cumul, ni plan, ni budget, ni demandes d'achat, ni commandes non
        réceptionnées (reprises séparément). <b>Arrêté mensuel uniquement</b> : SAP ne fournit que des montants par
        période (exercice juillet → juin, juillet = période 1). Nature : CAPEX si l'OTP finit par IM, OPEX par EX,
        sinon à qualifier. ID projet IFS = n° projet, sauf saisie. Les séquences d'activité ne sont jamais déduites.
      </Alert>

      <Box sx={{ display: 'flex', gap: 2, mb: 2, flexWrap: 'wrap', alignItems: 'center' }}>
        <TextField
          size="small" type="month" label="Mois d'arrêté" value={mois}
          onChange={(e) => setMois(e.target.value)} InputLabelProps={{ shrink: true }}
        />
        {data?.arrete.exercice != null && (
          <Typography variant="body2" color="text.secondary">
            Arrêté au {new Date(data.arrete.date).toLocaleDateString('fr-FR')} = exercice {data.arrete.exercice},
            période {data.arrete.periode}
          </Typography>
        )}
        <ToggleButtonGroup size="small" exclusive value={filtre} onChange={(_, v) => v && setFiltre(v)}>
          <ToggleButton value="anomalies">Anomalies ({enAnomalie.length})</ToggleButton>
          <ToggleButton value="pretes">Prêtes à exporter ({rows.filter((r) => r.exporte).length})</ToggleButton>
          <ToggleButton value="toutes">Toutes ({rows.length})</ToggleButton>
        </ToggleButtonGroup>
        <TextField select size="small" label="Nature" value={filtreNature} sx={{ minWidth: 160 }}
          onChange={(e) => setFiltreNature(e.target.value)}>
          <MenuItem value="">Toutes</MenuItem>
          <MenuItem value="CAPEX">CAPEX ({compte((r) => r.nature === 'CAPEX')})</MenuItem>
          <MenuItem value="OPEX">OPEX ({compte((r) => r.nature === 'OPEX')})</MenuItem>
          <MenuItem value="A_QUALIFIER">À qualifier ({compte((r) => !r.nature)})</MenuItem>
        </TextField>
        <TextField select size="small" label="Anomalies" value={filtreAnomalie} sx={{ minWidth: 220 }}
          onChange={(e) => setFiltreAnomalie(e.target.value)}>
          <MenuItem value="">Toutes</MenuItem>
          {codesAnomalies.map((a) => (
            <MenuItem key={a} value={a}>
              {data?.libelles_anomalies[a] ?? a} ({compte((r) => r.anomalies.includes(a))})
            </MenuItem>
          ))}
        </TextField>
        <Tooltip title={enAnomalie.length ? 'Corriger les anomalies avant export' : 'Fichier OD : crédit, ID projet IFS, montant, séquence'}>
          <span>
            <Button variant="outlined" color="success" startIcon={<ExcelIcon />} onClick={handleExport}
              disabled={exporting || !rows.length || enAnomalie.length > 0} sx={{ ml: 'auto' }}>
              {exporting ? 'Export…' : 'Exporter le fichier OD'}
            </Button>
          </span>
        </Tooltip>
      </Box>

      {data && (
        <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
          <Chip label={`${new Set(rows.map((r) => r.numero_projet)).size} projets / ${rows.length} OTP`} color="primary" />
          <Chip label={`CAPEX : ${euros(totaux.CAPEX)} €`} color="success" />
          <Chip label={`OPEX : ${euros(totaux.OPEX)} €`} color="info" />
          <Chip label={`À qualifier : ${euros(totaux.aQualifier)} €`} color={totaux.aQualifier ? 'warning' : 'default'} />
          <Chip label={`Exportable : ${euros(totaux.exporte)} €`} />
        </Box>
      )}
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <Paper>
        {loading && <LinearProgress />}
        <TableContainer sx={{ maxHeight: 'calc(100vh - 480px)', minHeight: 300 }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                {['N° projet', 'Projet SAP', 'Élément OTP (crédit)', 'Désignation OTP', 'Nature', 'Montant',
                  'ID projet IFS', "Séquence d'activité", 'Anomalies', ''].map((h) => (
                  <TableCell key={h} align={h === 'Montant' ? 'right' : 'left'} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>{h}</TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {affichees.map((r) => (
                <TableRow key={`${r.numero_projet}-${r.element_otp}`} hover>
                  <TableCell>{r.numero_projet}</TableCell>
                  <TableCell>{r.projet}</TableCell>
                  <TableCell sx={{ whiteSpace: 'nowrap' }}>{r.element_otp}</TableCell>
                  <TableCell>{r.otp_libelle}</TableCell>
                  <TableCell>
                    {r.nature_source === 'SUFFIXE' ? (
                      <Chip size="small" label={r.nature} color={r.nature === 'CAPEX' ? 'success' : 'info'} />
                    ) : (
                      <Select size="small" displayEmpty value={r.nature ?? ''} onChange={(e) => qualifier(r, e.target.value)}>
                        <MenuItem value=""><em>À qualifier</em></MenuItem>
                        <MenuItem value="CAPEX">CAPEX</MenuItem>
                        <MenuItem value="OPEX">OPEX</MenuItem>
                      </Select>
                    )}
                  </TableCell>
                  <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>{euros(r.montant)}</TableCell>
                  <TableCell>
                    {r.project_id_ifs}
                    {r.project_id_source === 'SAISIE' && <Typography component="span" variant="caption" color="text.secondary"> (saisi)</Typography>}
                  </TableCell>
                  <TableCell>{r.activity_seq ?? ''}</TableCell>
                  <TableCell>
                    {r.anomalies.map((a) => (
                      <Tooltip key={a} title={data?.libelles_anomalies[a] ?? a}>
                        <Chip size="small" color="error" variant="outlined" label={a} sx={{ mr: 0.5 }} />
                      </Tooltip>
                    ))}
                  </TableCell>
                  <TableCell>
                    <Tooltip title="ID projet IFS et séquences d'activité de reprise du projet">
                      <IconButton size="small" onClick={() => ouvrirSaisie(r)}><EditIcon fontSize="small" /></IconButton>
                    </Tooltip>
                  </TableCell>
                </TableRow>
              ))}
              {!loading && affichees.length === 0 && (
                <TableRow><TableCell colSpan={10} align="center">Aucune ligne</TableCell></TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      <Dialog open={!!saisie} onClose={() => setSaisie(null)} maxWidth="xs" fullWidth>
        <DialogTitle>Correspondance IFS du projet {saisie?.numero_projet}</DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: '8px !important' }}>
          {saisie && data?.saisies[saisie.numero_projet] && (
            <Typography variant="caption" color="text.secondary">
              Saisi par {data.saisies[saisie.numero_projet].saisi_par} le{' '}
              {new Date(data.saisies[saisie.numero_projet].saisi_le).toLocaleString('fr-FR')}
            </Typography>
          )}
          <TextField label="ID projet IFS" helperText="Vide = n° projet" value={saisie?.project_id_ifs ?? ''}
            onChange={(e) => saisie && setSaisie({ ...saisie, project_id_ifs: e.target.value })} />
          <TextField label="Séquence d'activité CAPEX" type="number" value={saisie?.activity_seq_capex ?? ''}
            onChange={(e) => saisie && setSaisie({ ...saisie, activity_seq_capex: e.target.value })} />
          <TextField label="Séquence d'activité OPEX" type="number" value={saisie?.activity_seq_opex ?? ''}
            onChange={(e) => saisie && setSaisie({ ...saisie, activity_seq_opex: e.target.value })} />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setSaisie(null)}>Annuler</Button>
          <Button variant="contained" onClick={enregistrerSaisie}>Enregistrer</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default RepriseCoutsIfs;
