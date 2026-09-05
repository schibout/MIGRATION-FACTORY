import {
  Add as AddIcon,
  DeleteOutline as DeleteIcon,
  EditOutlined as EditIcon,
} from '@mui/icons-material';
import {
  Alert,
  Box,
  Button,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  FormControlLabel,
  IconButton,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Snackbar,
  Switch,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Tabs,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useMemo, useState } from 'react';

import defaultValueService from '../services/defaultValueService';
import matrixSettingsService, {
  MatrixTargetTable,
  PartFamily,
} from '../services/matrixSettingsService';

const messageErreur = (e: unknown, repli: string): string => {
  const detail = (e as { response?: { data?: { error?: string } } })?.response?.data?.error;
  return detail || repli;
};

// Formulaire commun aux deux référentiels : seule la clé change (code d'une
// famille / nom de la table cible), le reste est identique.
type Brouillon = {
  id: number | null;
  cle: string;
  libelle: string;
  description: string;
  ordre: string;
  is_active: boolean;
};

const BROUILLON_VIDE: Brouillon = {
  id: null,
  cle: '',
  libelle: '',
  description: '',
  ordre: '100',
  is_active: true,
};

const MatriceParametres: React.FC = () => {
  const [onglet, setOnglet] = useState(0);
  const [message, setMessage] = useState<{ texte: string; type: 'success' | 'error' } | null>(null);

  const [familles, setFamilles] = useState<PartFamily[]>([]);
  const [detectees, setDetectees] = useState<string[]>([]);
  const [tables, setTables] = useState<MatrixTargetTable[]>([]);
  const [tablesDisponibles, setTablesDisponibles] = useState<string[]>([]);

  const [brouillon, setBrouillon] = useState<Brouillon | null>(null);
  const [typeEdition, setTypeEdition] = useState<'FAMILLE' | 'TABLE'>('FAMILLE');

  const charger = useCallback(async () => {
    try {
      const [f, t] = await Promise.all([
        matrixSettingsService.listFamilies(),
        matrixSettingsService.listTargetTables(),
      ]);
      setFamilles(f.part_families);
      setDetectees(f.detectees);
      setTables(t);
    } catch (e) {
      setMessage({ texte: messageErreur(e, 'Erreur lors du chargement des paramètres'), type: 'error' });
    }
  }, []);

  useEffect(() => {
    charger();
  }, [charger]);

  // Le sélecteur de table ne propose que des tables réellement paramétrables :
  // celles qui ont au moins une constante dans etl_default_values.
  useEffect(() => {
    defaultValueService
      .meta()
      .then((m) => setTablesDisponibles(Array.from(new Set(m.tables.map((t) => t.table_cible))).sort()))
      .catch(() => setTablesDisponibles([]));
  }, []);

  // Familles présentes dans le fichier PHL mais absentes du référentiel :
  // elles sont chargées par l'ETL sans que personne ne les ait documentées.
  const nonDeclarees = useMemo(
    () => detectees.filter((code) => !familles.some((f) => f.code === code)),
    [detectees, familles]
  );

  const ouvrir = (type: 'FAMILLE' | 'TABLE', ligne?: PartFamily | MatrixTargetTable) => {
    setTypeEdition(type);
    if (!ligne) {
      setBrouillon({ ...BROUILLON_VIDE });
      return;
    }
    setBrouillon({
      id: ligne.id,
      cle: 'code' in ligne ? ligne.code : ligne.table_cible,
      libelle: ligne.libelle ?? '',
      description: ligne.description ?? '',
      ordre: String(ligne.ordre),
      is_active: ligne.is_active,
    });
  };

  const enregistrer = async () => {
    if (!brouillon) return;
    const commun = {
      libelle: brouillon.libelle || null,
      description: brouillon.description || null,
      ordre: Number(brouillon.ordre) || 100,
      is_active: brouillon.is_active,
    };
    try {
      if (typeEdition === 'FAMILLE') {
        const payload = { ...commun, code: brouillon.cle.trim() };
        if (!payload.code) {
          setMessage({ texte: 'Le code de la famille est obligatoire', type: 'error' });
          return;
        }
        if (brouillon.id === null) await matrixSettingsService.createFamily(payload);
        else await matrixSettingsService.updateFamily(brouillon.id, payload);
      } else {
        const payload = { ...commun, table_cible: brouillon.cle.trim() };
        if (!payload.table_cible) {
          setMessage({ texte: 'La table cible est obligatoire', type: 'error' });
          return;
        }
        if (brouillon.id === null) await matrixSettingsService.createTargetTable(payload);
        else await matrixSettingsService.updateTargetTable(brouillon.id, payload);
      }
      setMessage({ texte: 'Enregistré', type: 'success' });
      setBrouillon(null);
      charger();
    } catch (e) {
      setMessage({ texte: messageErreur(e, "Erreur lors de l'enregistrement"), type: 'error' });
    }
  };

  const supprimer = async (type: 'FAMILLE' | 'TABLE', id: number) => {
    try {
      if (type === 'FAMILLE') await matrixSettingsService.deleteFamily(id);
      else await matrixSettingsService.deleteTargetTable(id);
      setMessage({ texte: 'Supprimé', type: 'success' });
      charger();
    } catch (e) {
      // L'API refuse la suppression tant que des règles portent dessus : son
      // message dit quoi faire, on le remonte tel quel.
      setMessage({ texte: messageErreur(e, 'Erreur lors de la suppression'), type: 'error' });
    }
  };

  const basculerActif = async (type: 'FAMILLE' | 'TABLE', id: number, actif: boolean) => {
    try {
      if (type === 'FAMILLE') await matrixSettingsService.updateFamily(id, { is_active: actif });
      else await matrixSettingsService.updateTargetTable(id, { is_active: actif });
      charger();
    } catch (e) {
      setMessage({ texte: messageErreur(e, 'Erreur lors de la mise à jour'), type: 'error' });
    }
  };

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" gutterBottom>
        Paramètres de la matrice
      </Typography>
      <Alert severity="info" sx={{ mb: 2 }}>
        Ces deux listes déterminent ce que propose l'écran <strong>Matrice Site × Famille</strong> :
        les familles affichées en colonnes et les tables ouvertes au paramétrage. Elles ne sont lues
        par aucun chargement ETL — les modifier ne change aucune donnée déjà chargée.
      </Alert>

      <Tabs value={onglet} onChange={(_, v) => setOnglet(v)} sx={{ mb: 2 }}>
        <Tab label={`Familles d'articles (${familles.length})`} />
        <Tab label={`Tables cibles (${tables.length})`} />
      </Tabs>

      {onglet === 0 && (
        <>
          {nonDeclarees.length > 0 && (
            <Alert severity="warning" sx={{ mb: 2 }}>
              {nonDeclarees.length === 1 ? 'Famille présente' : 'Familles présentes'} dans le fichier
              PHL mais non déclarée{nonDeclarees.length > 1 ? 's' : ''} :{' '}
              <strong>{nonDeclarees.join(', ')}</strong>. Ces articles sont chargés, mais la famille
              reste sans libellé dans la matrice.
            </Alert>
          )}
          <Box sx={{ mb: 1.5 }}>
            <Button variant="contained" startIcon={<AddIcon />} onClick={() => ouvrir('FAMILLE')}>
              Ajouter une famille
            </Button>
          </Box>
          <TableContainer component={Paper}>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Code</TableCell>
                  <TableCell>Libellé</TableCell>
                  <TableCell>Description</TableCell>
                  <TableCell align="center">Ordre</TableCell>
                  <TableCell align="center">Dans les données</TableCell>
                  <TableCell align="center">Active</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {familles.map((f) => (
                  <TableRow key={f.id} hover>
                    <TableCell sx={{ fontWeight: 600 }}>{f.code}</TableCell>
                    <TableCell sx={{ color: f.libelle ? 'text.primary' : 'text.disabled' }}>
                      {f.libelle || 'à documenter'}
                    </TableCell>
                    <TableCell sx={{ color: 'text.secondary', maxWidth: 420 }}>
                      {f.description || '—'}
                    </TableCell>
                    <TableCell align="center">{f.ordre}</TableCell>
                    <TableCell align="center">
                      {detectees.includes(f.code) ? (
                        <Chip size="small" color="success" label="oui" sx={{ height: 20 }} />
                      ) : (
                        <Tooltip title="Déclarée mais aucun article de cette famille dans le fichier PHL chargé">
                          <Chip size="small" variant="outlined" label="non" sx={{ height: 20 }} />
                        </Tooltip>
                      )}
                    </TableCell>
                    <TableCell align="center">
                      <Switch
                        size="small"
                        checked={f.is_active}
                        onChange={(e) => basculerActif('FAMILLE', f.id, e.target.checked)}
                      />
                    </TableCell>
                    <TableCell align="right">
                      <IconButton size="small" onClick={() => ouvrir('FAMILLE', f)}>
                        <EditIcon fontSize="small" />
                      </IconButton>
                      <IconButton size="small" color="error" onClick={() => supprimer('FAMILLE', f.id)}>
                        <DeleteIcon fontSize="small" />
                      </IconButton>
                    </TableCell>
                  </TableRow>
                ))}
                {familles.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={7} align="center" sx={{ py: 4, color: 'text.secondary' }}>
                      Aucune famille déclarée. La matrice affiche alors les familles trouvées dans les données.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </TableContainer>
        </>
      )}

      {onglet === 1 && (
        <>
          <Box sx={{ mb: 1.5 }}>
            <Button variant="contained" startIcon={<AddIcon />} onClick={() => ouvrir('TABLE')}>
              Ajouter une table
            </Button>
          </Box>
          <TableContainer component={Paper}>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Table cible</TableCell>
                  <TableCell>Libellé</TableCell>
                  <TableCell>Description</TableCell>
                  <TableCell align="center">Ordre</TableCell>
                  <TableCell align="center">Active</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {tables.map((t) => (
                  <TableRow key={t.id} hover>
                    <TableCell sx={{ fontWeight: 600 }}>{t.table_cible}</TableCell>
                    <TableCell sx={{ color: t.libelle ? 'text.primary' : 'text.disabled' }}>
                      {t.libelle || 'à documenter'}
                    </TableCell>
                    <TableCell sx={{ color: 'text.secondary', maxWidth: 420 }}>
                      {t.description || '—'}
                    </TableCell>
                    <TableCell align="center">{t.ordre}</TableCell>
                    <TableCell align="center">
                      <Switch
                        size="small"
                        checked={t.is_active}
                        onChange={(e) => basculerActif('TABLE', t.id, e.target.checked)}
                      />
                    </TableCell>
                    <TableCell align="right">
                      <IconButton size="small" onClick={() => ouvrir('TABLE', t)}>
                        <EditIcon fontSize="small" />
                      </IconButton>
                      <IconButton size="small" color="error" onClick={() => supprimer('TABLE', t.id)}>
                        <DeleteIcon fontSize="small" />
                      </IconButton>
                    </TableCell>
                  </TableRow>
                ))}
                {tables.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={6} align="center" sx={{ py: 4, color: 'text.secondary' }}>
                      Aucune table déclarée. La matrice propose alors toutes les tables ayant des valeurs par défaut.
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </TableContainer>
        </>
      )}

      <Dialog open={brouillon !== null} onClose={() => setBrouillon(null)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {brouillon?.id === null ? 'Ajouter' : 'Modifier'}{' '}
          {typeEdition === 'FAMILLE' ? 'une famille' : 'une table cible'}
        </DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 1 }}>
          {typeEdition === 'FAMILLE' ? (
            <TextField
              label="Code"
              size="small"
              autoFocus
              value={brouillon?.cle ?? ''}
              onChange={(e) => setBrouillon((b) => (b ? { ...b, cle: e.target.value } : b))}
              helperText="Valeur brute de la colonne FAMILLE du fichier PHL (21, RF...). Non modifiable si des règles l'utilisent."
            />
          ) : (
            <FormControl size="small">
              <InputLabel>Table cible</InputLabel>
              <Select
                label="Table cible"
                value={brouillon?.cle ?? ''}
                onChange={(e) => setBrouillon((b) => (b ? { ...b, cle: e.target.value } : b))}
              >
                {tablesDisponibles.map((t) => (
                  <MenuItem key={t} value={t}>
                    {t}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          )}
          <TextField
            label="Libellé"
            size="small"
            value={brouillon?.libelle ?? ''}
            onChange={(e) => setBrouillon((b) => (b ? { ...b, libelle: e.target.value } : b))}
            helperText="Nom court affiché dans la matrice, sous le code."
          />
          <TextField
            label="Description"
            size="small"
            multiline
            minRows={3}
            value={brouillon?.description ?? ''}
            onChange={(e) => setBrouillon((b) => (b ? { ...b, description: e.target.value } : b))}
            helperText="Texte long, affiché en infobulle."
          />
          <TextField
            label="Ordre d'affichage"
            size="small"
            type="number"
            value={brouillon?.ordre ?? '100'}
            onChange={(e) => setBrouillon((b) => (b ? { ...b, ordre: e.target.value } : b))}
          />
          <FormControlLabel
            control={
              <Switch
                checked={brouillon?.is_active ?? true}
                onChange={(e) => setBrouillon((b) => (b ? { ...b, is_active: e.target.checked } : b))}
              />
            }
            label="Active"
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setBrouillon(null)}>Annuler</Button>
          <Button variant="contained" onClick={enregistrer}>
            Enregistrer
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar open={message !== null} autoHideDuration={6000} onClose={() => setMessage(null)}>
        <Alert severity={message?.type ?? 'success'} onClose={() => setMessage(null)}>
          {message?.texte}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default MatriceParametres;
