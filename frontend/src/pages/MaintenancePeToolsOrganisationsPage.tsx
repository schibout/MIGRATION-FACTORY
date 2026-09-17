import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert, Box, Button, Chip, CircularProgress, Dialog, DialogActions, DialogContent,
  DialogContentText, DialogTitle, FormControlLabel, IconButton, Paper, Snackbar, Switch,
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow, TextField,
  Tooltip, Typography, useTheme,
} from '@mui/material';
import {
  Add as AddIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
  AccountTree as OrganisationIcon,
  Sync as RecalculIcon,
} from '@mui/icons-material';

import {
  createOrganisation, deleteOrganisation, getOrganisations, recalculerOrganisations,
  updateOrganisation, CodeSansRegle, ORG_CODE_MAX, PeToolsOrganisation,
  PeToolsOrganisationInput,
} from '../services/peToolsOrganisationService';

const VIDE: PeToolsOrganisationInput = {
  code_fichier: '', org_code: '', description: null, is_active: true,
};

const dateCourte = (iso: string | null) =>
  (iso ? new Date(iso).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' }) : '—');

/**
 * Parametrage « fichier PE Tools -> organisation de maintenance IFS ».
 *
 * L'organisation est figee sur chaque ligne AU MOMENT de l'import : modifier
 * une regle ici n'agit que sur les imports suivants, d'ou le bouton de
 * recalcul qui rejoue le parametrage sur les lignes deja chargees.
 */
const MaintenancePeToolsOrganisationsPage: React.FC = () => {
  const theme = useTheme();
  const [regles, setRegles] = useState<PeToolsOrganisation[]>([]);
  const [codesSansRegle, setCodesSansRegle] = useState<CodeSansRegle[]>([]);
  const [lignesSansOrganisation, setLignesSansOrganisation] = useState(0);
  const [loading, setLoading] = useState(true);
  const [erreur, setErreur] = useState<string | null>(null);

  const [dialogOuvert, setDialogOuvert] = useState(false);
  const [enEdition, setEnEdition] = useState<PeToolsOrganisation | null>(null);
  const [form, setForm] = useState<PeToolsOrganisationInput>(VIDE);
  const [enregistrement, setEnregistrement] = useState(false);

  const [aSupprimer, setASupprimer] = useState<PeToolsOrganisation | null>(null);
  const [recalculOuvert, setRecalculOuvert] = useState(false);
  const [recalculEnCours, setRecalculEnCours] = useState(false);
  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>(
    { open: false, message: '', severity: 'success' },
  );

  const charger = useCallback(async () => {
    setLoading(true);
    try {
      const liste = await getOrganisations();
      setRegles(liste.regles);
      setCodesSansRegle(liste.codesSansRegle);
      setLignesSansOrganisation(liste.lignesSansOrganisation);
      setErreur(null);
    } catch (err: any) {
      setErreur(err.response?.data?.error
        || "Impossible de charger le paramétrage (la migration 077 a-t-elle été jouée ?).");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { charger(); }, [charger]);

  const ouvrirAjout = (code?: string) => {
    setEnEdition(null);
    setForm({ ...VIDE, code_fichier: code || '' });
    setDialogOuvert(true);
  };

  const ouvrirEdition = (r: PeToolsOrganisation) => {
    setEnEdition(r);
    setForm({
      code_fichier: r.code_fichier, org_code: r.org_code,
      description: r.description, is_active: r.is_active,
    });
    setDialogOuvert(true);
  };

  const enregistrer = async () => {
    setEnregistrement(true);
    try {
      const resp = enEdition
        ? await updateOrganisation(enEdition.code_fichier, form)
        : await createOrganisation(form);
      if (resp?.success === false) throw new Error(resp.error);
      setDialogOuvert(false);
      // Un changement de regle ne touche pas les lignes deja importees : on le
      // rappelle des qu'il y en a.
      const impactees = enEdition?.lignes_importees ?? 0;
      setSnackbar({
        open: true,
        severity: 'success',
        message: impactees > 0
          ? `Enregistré. ${impactees} ligne(s) déjà importée(s) gardent leur organisation : lancez le recalcul pour l'appliquer.`
          : 'Enregistré',
      });
      await charger();
    } catch (err: any) {
      setSnackbar({
        open: true,
        message: err.response?.data?.error || err.message || "Erreur lors de l'enregistrement",
        severity: 'error',
      });
    } finally {
      setEnregistrement(false);
    }
  };

  const supprimer = async () => {
    if (!aSupprimer) return;
    try {
      const resp = await deleteOrganisation(aSupprimer.code_fichier);
      setSnackbar({ open: true, message: resp?.message || 'Règle supprimée', severity: 'success' });
      await charger();
    } catch (err: any) {
      setSnackbar({
        open: true,
        message: err.response?.data?.error || 'Erreur lors de la suppression',
        severity: 'error',
      });
    } finally {
      setASupprimer(null);
    }
  };

  const basculerActif = async (r: PeToolsOrganisation) => {
    try {
      await updateOrganisation(r.code_fichier, {
        code_fichier: r.code_fichier, org_code: r.org_code,
        description: r.description, is_active: !r.is_active,
      });
      await charger();
    } catch (err: any) {
      setSnackbar({
        open: true,
        message: err.response?.data?.error || "Erreur lors du changement d'état",
        severity: 'error',
      });
    }
  };

  const recalculer = async () => {
    setRecalculEnCours(true);
    try {
      const resp = await recalculerOrganisations();
      if (resp?.success === false) throw new Error(resp.error);
      setSnackbar({
        open: true,
        severity: 'success',
        message: `${resp.lignes_modifiees} ligne(s) mise(s) à jour`
          + (resp.lignes_sans_organisation > 0
            ? ` — ${resp.lignes_sans_organisation} ligne(s) restent sans organisation.`
            : ''),
      });
      setRecalculOuvert(false);
      await charger();
    } catch (err: any) {
      setSnackbar({
        open: true,
        message: err.response?.data?.error || err.message || 'Erreur lors du recalcul',
        severity: 'error',
      });
    } finally {
      setRecalculEnCours(false);
    }
  };

  const lignesImportees = regles.reduce((n, r) => n + r.lignes_importees, 0)
    + codesSansRegle.reduce((n, c) => n + c.lignes_importees, 0);

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 1, flexWrap: 'wrap', gap: 1 }}>
        <OrganisationIcon sx={{ fontSize: 32, mr: 2, color: theme.palette.success.main }} />
        <Box sx={{ flex: 1, minWidth: 260 }}>
          <Typography variant="h5" sx={{ fontWeight: 600 }}>Organisations PE Tools</Typography>
          <Typography variant="body2" color="text.secondary">
            Organisation de maintenance IFS déduite du nom du fichier importé
            («&nbsp;PeTool&nbsp;-&nbsp;7.<b>CODE</b>.csv&nbsp;»), reprise ensuite par l'ETL PM Actions.
          </Typography>
        </Box>
        <Tooltip title="Rejoue le paramétrage sur les lignes déjà importées">
          <span>
            <Button
              variant="outlined"
              startIcon={<RecalculIcon />}
              onClick={() => setRecalculOuvert(true)}
              disabled={loading || lignesImportees === 0}
            >
              Recalculer les lignes importées
            </Button>
          </span>
        </Tooltip>
        <Button variant="contained" startIcon={<AddIcon />} onClick={() => ouvrirAjout()}>
          Ajouter une règle
        </Button>
      </Box>

      {erreur && <Alert severity="warning" sx={{ mb: 2 }}>{erreur}</Alert>}

      {codesSansRegle.length > 0 && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          Fichier(s) importé(s) sans règle : leurs lignes n'ont aucune organisation.
          <Box sx={{ mt: 1, display: 'flex', gap: 1, flexWrap: 'wrap' }}>
            {codesSansRegle.map((c) => (
              <Chip
                key={c.code_fichier}
                size="small"
                color="warning"
                label={`${c.code_fichier} — ${c.lignes_importees} ligne(s)`}
                onClick={() => ouvrirAjout(c.code_fichier)}
              />
            ))}
          </Box>
        </Alert>
      )}

      {!loading && lignesSansOrganisation > 0 && codesSansRegle.length === 0 && (
        <Alert severity="info" sx={{ mb: 2 }}>
          {lignesSansOrganisation} ligne(s) importée(s) sans organisation : un recalcul les corrigera.
        </Alert>
      )}

      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}><CircularProgress /></Box>
      ) : (
        <TableContainer component={Paper}>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell sx={{ fontWeight: 600 }}>Code fichier</TableCell>
                <TableCell sx={{ fontWeight: 600 }}>Organisation IFS</TableCell>
                <TableCell sx={{ fontWeight: 600 }}>Description</TableCell>
                <TableCell sx={{ fontWeight: 600 }} align="center">Lignes importées</TableCell>
                <TableCell sx={{ fontWeight: 600 }} align="center">Active</TableCell>
                <TableCell sx={{ fontWeight: 600 }}>Modifiée</TableCell>
                <TableCell sx={{ fontWeight: 600 }} align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {regles.length === 0 && (
                <TableRow>
                  <TableCell colSpan={7} align="center" sx={{ py: 3, color: 'text.secondary' }}>
                    Aucune règle paramétrée.
                  </TableCell>
                </TableRow>
              )}
              {regles.map((r) => (
                <TableRow key={r.code_fichier} hover sx={{ opacity: r.is_active ? 1 : 0.5 }}>
                  <TableCell sx={{ fontFamily: 'monospace' }}>{r.code_fichier}</TableCell>
                  <TableCell><Chip size="small" label={r.org_code} /></TableCell>
                  <TableCell sx={{ color: 'text.secondary' }}>{r.description || '—'}</TableCell>
                  <TableCell align="center">{r.lignes_importees || '—'}</TableCell>
                  <TableCell align="center">
                    <Switch size="small" checked={r.is_active} onChange={() => basculerActif(r)} />
                  </TableCell>
                  <TableCell sx={{ color: 'text.secondary', fontSize: '0.8rem' }}>
                    {dateCourte(r.updated_at)}{r.updated_by ? ` — ${r.updated_by}` : ''}
                  </TableCell>
                  <TableCell align="right">
                    <Tooltip title="Modifier">
                      <IconButton size="small" aria-label={`Modifier ${r.code_fichier}`}
                        onClick={() => ouvrirEdition(r)}>
                        <EditIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Supprimer">
                      <IconButton size="small" color="error" aria-label={`Supprimer ${r.code_fichier}`}
                        onClick={() => setASupprimer(r)}>
                        <DeleteIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      {/* Création / modification */}
      <Dialog open={dialogOuvert} onClose={() => setDialogOuvert(false)} maxWidth="sm" fullWidth>
        <DialogTitle>{enEdition ? `Modifier la règle ${enEdition.code_fichier}` : 'Nouvelle règle'}</DialogTitle>
        <DialogContent>
          <TextField
            fullWidth margin="normal" label="Code fichier" required
            value={form.code_fichier}
            onChange={(e) => setForm({ ...form, code_fichier: e.target.value.toUpperCase() })}
            helperText="Segment « 7.CODE.csv » du nom de fichier (ex. MCAR) — lettres, chiffres, tiret, souligné"
          />
          <TextField
            fullWidth margin="normal" label="Organisation de maintenance IFS" required
            value={form.org_code}
            inputProps={{ maxLength: ORG_CODE_MAX }}
            onChange={(e) => setForm({ ...form, org_code: e.target.value.toUpperCase() })}
            helperText={`${ORG_CODE_MAX} caractères maximum (cible IFS pm_action.org_code)`}
          />
          <TextField
            fullWidth margin="normal" label="Description" multiline minRows={2}
            value={form.description || ''}
            onChange={(e) => setForm({ ...form, description: e.target.value || null })}
          />
          <FormControlLabel
            control={<Switch checked={form.is_active}
              onChange={(e) => setForm({ ...form, is_active: e.target.checked })} />}
            label="Règle active (appliquée aux imports)"
          />
          {enEdition && enEdition.lignes_importees > 0 && (
            <Alert severity="info" sx={{ mt: 1 }}>
              {enEdition.lignes_importees} ligne(s) déjà importée(s) portent ce code : elles gardent
              l'organisation figée à leur import tant que le recalcul n'est pas lancé.
            </Alert>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOuvert(false)}>Annuler</Button>
          <Button variant="contained" onClick={enregistrer} disabled={enregistrement}>
            {enregistrement ? 'Enregistrement…' : 'Enregistrer'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Suppression */}
      <Dialog open={!!aSupprimer} onClose={() => setASupprimer(null)}>
        <DialogTitle>Supprimer la règle {aSupprimer?.code_fichier} ?</DialogTitle>
        <DialogContent>
          <DialogContentText>
            Les imports suivants de ce fichier n'auront plus d'organisation.
            {(aSupprimer?.lignes_importees ?? 0) > 0 && (
              <> {aSupprimer?.lignes_importees} ligne(s) déjà importée(s) gardent leur organisation
              actuelle ; un recalcul la remettrait à vide.</>
            )}
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setASupprimer(null)}>Annuler</Button>
          <Button color="error" variant="contained" onClick={supprimer}>Supprimer</Button>
        </DialogActions>
      </Dialog>

      {/* Recalcul */}
      <Dialog open={recalculOuvert} onClose={() => setRecalculOuvert(false)}>
        <DialogTitle>Recalculer les organisations ?</DialogTitle>
        <DialogContent>
          <DialogContentText>
            Le paramétrage courant sera réappliqué aux {lignesImportees} ligne(s) importée(s) par
            l'écran PE Tools. Un code sans règle active repassera à vide. Les lignes chargées hors
            application (sans nom de fichier) ne sont pas touchées.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setRecalculOuvert(false)}>Annuler</Button>
          <Button variant="contained" onClick={recalculer} disabled={recalculEnCours}>
            {recalculEnCours ? 'Recalcul…' : 'Recalculer'}
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={snackbar.open}
        autoHideDuration={6000}
        onClose={() => setSnackbar({ ...snackbar, open: false })}
      >
        <Alert severity={snackbar.severity} onClose={() => setSnackbar({ ...snackbar, open: false })}>
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default MaintenancePeToolsOrganisationsPage;
