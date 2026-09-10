import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert, Box, Button, Chip, CircularProgress, Dialog, DialogActions, DialogContent,
  DialogTitle, FormControlLabel, Grid, IconButton, MenuItem, Paper, Snackbar, Switch,
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow, TextField,
  ToggleButton, ToggleButtonGroup, Tooltip, Typography, alpha, useTheme,
} from '@mui/material';
import {
  Add as AddIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
  ListAlt as ListIcon,
} from '@mui/icons-material';

import {
  createLovValue, deleteLovValue, getLovTypes, getLovValues, updateLovValue,
  LovType, LovValue, LovValueInput,
} from '../services/lovService';

// Sites de maintenance. '' = valeur commune a tous les sites (contract NULL en
// base) ; c'est le cas par defaut, une valeur n'a besoin d'un site que si elle
// ne vaut que la-bas. A ne pas confondre avec 'SJ'/'CS' du module articlePhl.
const SITES = [
  { code: '', label: 'Tous les sites' },
  { code: 'SJM', label: 'SJM — Saint-Jean-de-Maurienne' },
  { code: 'CAST', label: 'CAST — Castelsarrasin' },
];

const siteLabel = (contract: string | null) =>
  SITES.find((s) => s.code === (contract || ''))?.label || contract;

const VIDE: LovValueInput = { code: '', libelle: '', contract: null, ordre: null, actif: true };

const MaintenanceLovPage: React.FC = () => {
  const theme = useTheme();
  const [types, setTypes] = useState<LovType[]>([]);
  const [listCode, setListCode] = useState<string>('');
  const [values, setValues] = useState<LovValue[]>([]);
  const [loading, setLoading] = useState(true);
  const [erreur, setErreur] = useState<string | null>(null);

  const [dialogOuvert, setDialogOuvert] = useState(false);
  const [enEdition, setEnEdition] = useState<LovValue | null>(null);
  const [form, setForm] = useState<LovValueInput>(VIDE);
  const [enregistrement, setEnregistrement] = useState(false);

  const [aSupprimer, setASupprimer] = useState<LovValue | null>(null);
  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>(
    { open: false, message: '', severity: 'success' },
  );

  // --- Chargement ----------------------------------------------------------
  useEffect(() => {
    (async () => {
      try {
        const ts = await getLovTypes();
        setTypes(ts);
        if (ts.length > 0) setListCode((prev) => prev || ts[0].code);
        if (ts.length === 0) setErreur("Aucune liste n'est déclarée : la migration 075 n'a pas été jouée.");
      } catch {
        setErreur("Impossible de charger les listes de valeurs (API /lov indisponible).");
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  // Toutes les valeurs, sites confondus ET desactivees comprises : c'est un
  // ecran de parametrage, pas une combobox.
  const chargerValeurs = useCallback(async (code: string) => {
    if (!code) return;
    setLoading(true);
    try {
      setValues(await getLovValues(code, undefined, true));
      setErreur(null);
    } catch {
      setErreur(`Impossible de charger les valeurs de "${code}".`);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { chargerValeurs(listCode); }, [listCode, chargerValeurs]);

  const rafraichirTypes = async () => {
    try { setTypes(await getLovTypes()); } catch { /* compteurs non critiques */ }
  };

  // --- Actions -------------------------------------------------------------
  const ouvrirAjout = () => { setEnEdition(null); setForm(VIDE); setDialogOuvert(true); };

  const ouvrirEdition = (v: LovValue) => {
    setEnEdition(v);
    setForm({ code: v.code, libelle: v.libelle, contract: v.contract, ordre: v.ordre, actif: v.actif });
    setDialogOuvert(true);
  };

  const enregistrer = async () => {
    if (!form.code.trim() || !form.libelle.trim()) {
      setSnackbar({ open: true, message: 'Le code et le libellé sont obligatoires', severity: 'error' });
      return;
    }
    setEnregistrement(true);
    try {
      const resp = enEdition
        ? await updateLovValue(enEdition.id, form)
        : await createLovValue(listCode, form);
      setSnackbar({ open: true, message: resp?.message || 'Enregistré', severity: 'success' });
      setDialogOuvert(false);
      await chargerValeurs(listCode);
      rafraichirTypes();
    } catch (err: any) {
      setSnackbar({
        open: true,
        message: err.response?.data?.error || "Erreur lors de l'enregistrement",
        severity: 'error',
      });
    } finally {
      setEnregistrement(false);
    }
  };

  const supprimer = async () => {
    if (!aSupprimer) return;
    try {
      const resp = await deleteLovValue(aSupprimer.id);
      setSnackbar({ open: true, message: resp?.message || 'Valeur supprimée', severity: 'success' });
      await chargerValeurs(listCode);
      rafraichirTypes();
    } catch (err: any) {
      // 409 = valeur encore portee par des postes techniques : le message du
      // serveur dit combien et invite a desactiver plutot qu'a supprimer.
      setSnackbar({
        open: true,
        message: err.response?.data?.error || 'Erreur lors de la suppression',
        severity: 'error',
      });
    } finally {
      setASupprimer(null);
    }
  };

  const basculerActif = async (v: LovValue) => {
    try {
      await updateLovValue(v.id, { actif: !v.actif });
      await chargerValeurs(listCode);
    } catch (err: any) {
      setSnackbar({
        open: true,
        message: err.response?.data?.error || 'Erreur lors du changement d\'état',
        severity: 'error',
      });
    }
  };

  // --- Rendu ---------------------------------------------------------------
  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
        <ListIcon sx={{ fontSize: 32, mr: 2, color: theme.palette.info.main }} />
        <Box sx={{ flex: 1 }}>
          <Typography variant="h5" sx={{ fontWeight: 600 }}>Listes de valeurs</Typography>
          <Typography variant="body2" color="text.secondary">
            Valeurs proposées par les combobox de la fiche d'un poste technique (écran IH02).
          </Typography>
        </Box>
        <Button variant="contained" startIcon={<AddIcon />} onClick={ouvrirAjout} disabled={!listCode}>
          Ajouter une valeur
        </Button>
      </Box>

      {erreur && <Alert severity="warning" sx={{ mb: 2 }}>{erreur}</Alert>}

      <ToggleButtonGroup
        exclusive
        size="small"
        value={listCode}
        onChange={(_, code) => code && setListCode(code)}
        sx={{ mb: 2 }}
      >
        {types.map((t) => (
          <ToggleButton key={t.code} value={t.code} sx={{ textTransform: 'none', px: 2 }}>
            {t.libelle}
            <Chip size="small" label={t.nb_valeurs} sx={{ ml: 1, height: 18, fontSize: '0.7rem' }} />
          </ToggleButton>
        ))}
      </ToggleButtonGroup>

      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell sx={{ fontWeight: 600 }}>Code</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Libellé</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Site</TableCell>
              <TableCell sx={{ fontWeight: 600 }} align="center">Ordre</TableCell>
              <TableCell sx={{ fontWeight: 600 }} align="center">Actif</TableCell>
              <TableCell sx={{ fontWeight: 600 }} align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading && (
              <TableRow>
                <TableCell colSpan={6} align="center" sx={{ py: 4 }}><CircularProgress size={24} /></TableCell>
              </TableRow>
            )}
            {!loading && values.length === 0 && (
              <TableRow>
                <TableCell colSpan={6} align="center" sx={{ py: 4 }}>
                  <Typography variant="body2" color="text.secondary">
                    Aucune valeur. Tant que cette liste est vide, la combobox correspondante
                    de l'écran IH02 ne propose rien.
                  </Typography>
                </TableCell>
              </TableRow>
            )}
            {!loading && values.map((v) => (
              <TableRow key={v.id} hover sx={{ opacity: v.actif ? 1 : 0.5 }}>
                <TableCell sx={{ fontFamily: 'monospace', fontWeight: 600 }}>{v.code}</TableCell>
                <TableCell>{v.libelle}</TableCell>
                <TableCell>
                  <Chip
                    size="small"
                    label={siteLabel(v.contract)}
                    variant={v.contract ? 'filled' : 'outlined'}
                    sx={{
                      height: 20, fontSize: '0.7rem',
                      backgroundColor: v.contract ? alpha(theme.palette.info.main, 0.15) : undefined,
                    }}
                  />
                </TableCell>
                <TableCell align="center">{v.ordre ?? '-'}</TableCell>
                <TableCell align="center">
                  <Switch size="small" checked={v.actif} onChange={() => basculerActif(v)} />
                </TableCell>
                <TableCell align="right">
                  <Tooltip title="Modifier">
                    <IconButton size="small" color="primary" onClick={() => ouvrirEdition(v)}>
                      <EditIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                  <Tooltip title="Supprimer">
                    <IconButton size="small" color="error" onClick={() => setASupprimer(v)}>
                      <DeleteIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      {/* Ajout / modification */}
      <Dialog open={dialogOuvert} onClose={() => setDialogOuvert(false)} maxWidth="sm" fullWidth>
        <DialogTitle>{enEdition ? `Modifier "${enEdition.code}"` : 'Ajouter une valeur'}</DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 0.5 }}>
            <Grid item xs={4}>
              <TextField
                label="Code" size="small" fullWidth autoFocus
                value={form.code}
                onChange={(e) => setForm({ ...form, code: e.target.value })}
                helperText="Valeur stockée"
                inputProps={{ maxLength: 20 }}
              />
            </Grid>
            <Grid item xs={8}>
              <TextField
                label="Libellé" size="small" fullWidth
                value={form.libelle}
                onChange={(e) => setForm({ ...form, libelle: e.target.value })}
                helperText="Valeur affichée"
                inputProps={{ maxLength: 200 }}
              />
            </Grid>
            <Grid item xs={8}>
              <TextField
                select label="Site" size="small" fullWidth
                value={form.contract || ''}
                onChange={(e) => setForm({ ...form, contract: e.target.value || null })}
              >
                {SITES.map((s) => <MenuItem key={s.code} value={s.code}>{s.label}</MenuItem>)}
              </TextField>
            </Grid>
            <Grid item xs={4}>
              <TextField
                label="Ordre" size="small" fullWidth type="number"
                value={form.ordre ?? ''}
                onChange={(e) => setForm({ ...form, ordre: e.target.value === '' ? null : Number(e.target.value) })}
              />
            </Grid>
            <Grid item xs={12}>
              <FormControlLabel
                control={<Switch checked={form.actif} onChange={(e) => setForm({ ...form, actif: e.target.checked })} />}
                label="Proposée dans les combobox"
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOuvert(false)} disabled={enregistrement}>Annuler</Button>
          <Button variant="contained" onClick={enregistrer} disabled={enregistrement}
            startIcon={enregistrement ? <CircularProgress size={16} /> : undefined}>
            Enregistrer
          </Button>
        </DialogActions>
      </Dialog>

      {/* Confirmation de suppression */}
      <Dialog open={!!aSupprimer} onClose={() => setASupprimer(null)}>
        <DialogTitle>Supprimer cette valeur ?</DialogTitle>
        <DialogContent>
          <Typography variant="body2">
            «&nbsp;{aSupprimer?.code} — {aSupprimer?.libelle}&nbsp;» sera définitivement supprimée.
            Si des postes techniques la portent, la suppression sera refusée : désactivez-la à la place.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setASupprimer(null)}>Annuler</Button>
          <Button color="error" variant="contained" onClick={supprimer}>Supprimer</Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={snackbar.open}
        autoHideDuration={5000}
        onClose={() => setSnackbar({ ...snackbar, open: false })}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      >
        <Alert severity={snackbar.severity} onClose={() => setSnackbar({ ...snackbar, open: false })}>
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default MaintenanceLovPage;
