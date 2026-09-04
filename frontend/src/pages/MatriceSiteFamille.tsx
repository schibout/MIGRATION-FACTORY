import {
  DeleteOutline as DeleteIcon,
  HelpOutline as HelpIcon,
} from '@mui/icons-material';
import {
  Alert,
  Box,
  Button,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  FormControl,
  FormControlLabel,
  InputLabel,
  MenuItem,
  Paper,
  Radio,
  RadioGroup,
  Select,
  Snackbar,
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
import matrixService, {
  MatrixMeta,
  MatrixValue,
  PartTypeRule,
} from '../services/matrixService';

// Colonne / ligne "joker" de la grille : la valeur null cote API.
const JOKER = '__TOUS__';
const enJoker = (v: string): string | null => (v === JOKER ? null : v);

// Meme regle de priorite que public.get_default_value_ctx() cote base :
// (site + famille) > site seul > famille seule > joker.
// La grille doit montrer ce que l'ETL appliquera, pas une approximation.
function regleLaPlusSpecifique<T extends { contract: string | null; part_family: string | null; is_active: boolean }>(
  regles: T[],
  contract: string | null,
  famille: string | null
): T | undefined {
  return regles
    .filter(
      (r) =>
        r.is_active &&
        (r.contract === null || r.contract === contract) &&
        (r.part_family === null || r.part_family === famille)
    )
    .sort((a, b) => {
      const specA = (a.contract ? 1 : 0) + (a.part_family ? 1 : 0);
      const specB = (b.contract ? 1 : 0) + (b.part_family ? 1 : 0);
      if (specA !== specB) return specB - specA;
      return (b.contract ? 1 : 0) - (a.contract ? 1 : 0);
    })[0];
}

const libelleRegle = (r: { contract: string | null; part_family: string | null }): string => {
  if (r.contract && r.part_family) return `site ${r.contract} + famille ${r.part_family}`;
  if (r.contract) return `site ${r.contract} (toutes familles)`;
  if (r.part_family) return `famille ${r.part_family} (tous sites)`;
  return 'règle générale (tous sites, toutes familles)';
};

const messageErreur = (e: unknown, repli: string): string => {
  const detail = (e as { response?: { data?: { error?: string } } })?.response?.data?.error;
  return detail || repli;
};

const MatriceSiteFamille: React.FC = () => {
  const [onglet, setOnglet] = useState(0);
  const [meta, setMeta] = useState<MatrixMeta>({
    sites: [],
    familles: [],
    cibles: [],
    part_type_tables: [],
  });
  const [message, setMessage] = useState<{ texte: string; type: 'success' | 'error' } | null>(null);

  // --- Onglet 1 : valeurs par défaut ---------------------------------------
  const [tableCible, setTableCible] = useState('');
  const [colonne, setColonne] = useState('');
  const [regles, setRegles] = useState<MatrixValue[]>([]);
  const [constante, setConstante] = useState<{ valeur: string | null; type_valeur: string } | null>(null);
  const [cellule, setCellule] = useState<{ contract: string | null; part_family: string | null } | null>(null);
  const [valeurEdit, setValeurEdit] = useState('');
  const [descriptionEdit, setDescriptionEdit] = useState('');
  const [typeEdit, setTypeEdit] = useState<'CONSTANTE' | 'NULL'>('CONSTANTE');

  // --- Onglet 2 : routage de création --------------------------------------
  const [tableRoutage, setTableRoutage] = useState('');
  const [routages, setRoutages] = useState<PartTypeRule[]>([]);

  useEffect(() => {
    matrixService
      .meta()
      .then((m) => {
        setMeta(m);
        if (m.part_type_tables.length > 0) setTableRoutage(m.part_type_tables[0].target_table);
      })
      .catch(() => setMessage({ texte: 'Erreur lors du chargement des métadonnées', type: 'error' }));
  }, []);

  const tablesCibles = useMemo(
    () => Array.from(new Set(meta.cibles.map((c) => c.table_cible))).sort(),
    [meta.cibles]
  );
  const colonnesCibles = useMemo(
    () =>
      meta.cibles
        .filter((c) => c.table_cible === tableCible)
        .map((c) => c.colonne)
        .filter((v, i, t) => t.indexOf(v) === i)
        .sort(),
    [meta.cibles, tableCible]
  );

  const chargerRegles = useCallback(async () => {
    if (!tableCible || !colonne) {
      setRegles([]);
      setConstante(null);
      return;
    }
    try {
      const [valeurs, constantes] = await Promise.all([
        matrixService.listValues({ table_cible: tableCible, colonne }),
        // Le repli de la matrice : la constante de Configuration > Valeurs par défaut.
        defaultValueService.list({ table_cible: tableCible, colonne, per_page: 100 }),
      ]);
      setRegles(valeurs);
      const exacte = constantes.default_values.find(
        (c) => c.colonne === colonne && c.variante === 'STANDARD'
      );
      setConstante(
        exacte && exacte.is_active
          ? { valeur: exacte.valeur, type_valeur: exacte.type_valeur }
          : null
      );
    } catch (e) {
      setMessage({ texte: messageErreur(e, 'Erreur lors du chargement de la matrice'), type: 'error' });
    }
  }, [tableCible, colonne]);

  useEffect(() => {
    chargerRegles();
  }, [chargerRegles]);

  const chargerRoutages = useCallback(async () => {
    if (!tableRoutage) return;
    try {
      setRoutages(await matrixService.listPartTypes(tableRoutage));
    } catch (e) {
      setMessage({ texte: messageErreur(e, 'Erreur lors du chargement du routage'), type: 'error' });
    }
  }, [tableRoutage]);

  useEffect(() => {
    chargerRoutages();
  }, [chargerRoutages]);

  // ------------------------------------------------------------------ Valeurs
  const ouvrirCellule = (contract: string | null, part_family: string | null) => {
    const propre = regles.find((r) => r.contract === contract && r.part_family === part_family);
    setCellule({ contract, part_family });
    setTypeEdit(propre?.type_valeur ?? 'CONSTANTE');
    setValeurEdit(propre?.valeur ?? '');
    setDescriptionEdit(propre?.description ?? '');
  };

  const enregistrerCellule = async () => {
    if (!cellule) return;
    try {
      await matrixService.saveValue({
        table_cible: tableCible,
        colonne,
        contract: cellule.contract,
        part_family: cellule.part_family,
        type_valeur: typeEdit,
        valeur: typeEdit === 'NULL' ? null : valeurEdit,
        description: descriptionEdit || null,
      });
      setMessage({ texte: 'Règle enregistrée', type: 'success' });
      setCellule(null);
      chargerRegles();
    } catch (e) {
      setMessage({ texte: messageErreur(e, "Erreur lors de l'enregistrement"), type: 'error' });
    }
  };

  const supprimerCellule = async () => {
    if (!cellule) return;
    const propre = regles.find(
      (r) => r.contract === cellule.contract && r.part_family === cellule.part_family
    );
    if (!propre) {
      setCellule(null);
      return;
    }
    try {
      await matrixService.deleteValue(propre.id);
      setMessage({ texte: 'Règle supprimée : la cellule hérite de nouveau', type: 'success' });
      setCellule(null);
      chargerRegles();
    } catch (e) {
      setMessage({ texte: messageErreur(e, 'Erreur lors de la suppression'), type: 'error' });
    }
  };

  const rendreCelluleValeur = (contract: string | null, part_family: string | null) => {
    const propre = regles.find((r) => r.contract === contract && r.part_family === part_family);
    const heritee = regleLaPlusSpecifique(regles, contract, part_family);

    if (propre) {
      return (
        <Chip
          size="small"
          color={propre.type_valeur === 'NULL' ? 'default' : 'primary'}
          label={propre.type_valeur === 'NULL' ? 'NULL' : propre.valeur || '(vide)'}
          variant={propre.is_active ? 'filled' : 'outlined'}
        />
      );
    }
    if (heritee) {
      return (
        <Tooltip title={`Hérité de la ${libelleRegle(heritee)}`}>
          <Typography variant="body2" sx={{ color: 'text.disabled', fontStyle: 'italic' }}>
            {heritee.type_valeur === 'NULL' ? 'NULL' : heritee.valeur || '(vide)'}
          </Typography>
        </Tooltip>
      );
    }
    return (
      <Tooltip title="Aucune règle de matrice : la constante de Configuration > Valeurs par défaut s'applique">
        <Typography variant="body2" sx={{ color: 'text.disabled' }}>
          {constante ? (constante.type_valeur === 'NULL' ? 'NULL' : constante.valeur || '(vide)') : '—'}
        </Typography>
      </Tooltip>
    );
  };

  // ------------------------------------------------------------------ Routage
  // Clic = cycle hérité -> Créé -> Non créé -> hérité. La suppression de la
  // règle (retour à "hérité") est le seul moyen de revenir au repli général.
  const basculerRoutage = async (contract: string | null, part_family: string | null) => {
    const propre = routages.find((r) => r.contract === contract && r.part_family === part_family);
    try {
      if (!propre) {
        await matrixService.savePartType({
          target_table: tableRoutage,
          contract,
          part_family,
          should_create: true,
        });
      } else if (propre.should_create) {
        await matrixService.savePartType({
          target_table: tableRoutage,
          contract,
          part_family,
          should_create: false,
        });
      } else {
        await matrixService.deletePartType(propre.id);
      }
      chargerRoutages();
    } catch (e) {
      setMessage({ texte: messageErreur(e, 'Erreur lors de la mise à jour du routage'), type: 'error' });
    }
  };

  const rendreCelluleRoutage = (contract: string | null, part_family: string | null) => {
    const propre = routages.find((r) => r.contract === contract && r.part_family === part_family);
    const heritee = regleLaPlusSpecifique(routages, contract, part_family);

    if (propre) {
      return (
        <Chip
          size="small"
          color={propre.should_create ? 'success' : 'error'}
          label={propre.should_create ? 'Créé' : 'Non créé'}
        />
      );
    }
    const libelle = heritee
      ? heritee.should_create
        ? 'Créé'
        : 'Non créé'
      : 'Créé';
    const info = heritee
      ? `Hérité de la ${libelleRegle(heritee)}`
      : 'Aucune règle : la création est autorisée par défaut';
    return (
      <Tooltip title={info}>
        <Typography variant="body2" sx={{ color: 'text.disabled', fontStyle: 'italic' }}>
          {libelle}
        </Typography>
      </Tooltip>
    );
  };

  // -------------------------------------------------------------------- Grille
  const grille = (rendreCellule: (c: string | null, f: string | null) => React.ReactNode,
                  onClick: (c: string | null, f: string | null) => void) => (
    <TableContainer component={Paper} sx={{ mt: 2 }}>
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell sx={{ fontWeight: 600 }}>Famille \ Site</TableCell>
            <TableCell align="center" sx={{ fontWeight: 600 }}>Tous les sites</TableCell>
            {meta.sites.map((s) => (
              <TableCell key={s} align="center" sx={{ fontWeight: 600 }}>
                {s}
              </TableCell>
            ))}
          </TableRow>
        </TableHead>
        <TableBody>
          {[JOKER, ...meta.familles].map((fam) => (
            <TableRow key={fam} hover>
              <TableCell sx={{ fontWeight: fam === JOKER ? 600 : 400 }}>
                {fam === JOKER ? 'Toutes les familles' : fam}
              </TableCell>
              {[JOKER, ...meta.sites].map((site) => (
                <TableCell
                  key={`${fam}-${site}`}
                  align="center"
                  onClick={() => onClick(enJoker(site), enJoker(fam))}
                  sx={{ cursor: 'pointer', '&:hover': { bgcolor: 'action.hover' } }}
                >
                  {rendreCellule(enJoker(site), enJoker(fam))}
                </TableCell>
              ))}
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );

  const regleCourante = cellule
    ? regles.find((r) => r.contract === cellule.contract && r.part_family === cellule.part_family)
    : undefined;

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" gutterBottom>
        Matrice Site × Famille
      </Typography>
      <Alert severity="info" sx={{ mb: 2 }} icon={<HelpIcon />}>
        La cellule la plus précise gagne : <strong>site + famille</strong> &gt; site seul &gt; famille seule &gt;
        règle générale. Si aucune règle ne s'applique, c'est la constante de{' '}
        <strong>Configuration &gt; Valeurs par défaut</strong> qui est utilisée. Comme pour les
        constantes, les modifications ne prennent effet qu'au <strong>prochain chargement ETL</strong>.
      </Alert>

      <Tabs value={onglet} onChange={(_, v) => setOnglet(v)} sx={{ mb: 2 }}>
        <Tab label="Valeurs par défaut" />
        <Tab label="Routage de création" />
      </Tabs>

      {onglet === 0 && (
        <>
          <Paper sx={{ p: 2, display: 'flex', gap: 2, flexWrap: 'wrap' }}>
            <FormControl size="small" sx={{ minWidth: 320 }}>
              <InputLabel>Table cible</InputLabel>
              <Select
                value={tableCible}
                label="Table cible"
                onChange={(e) => {
                  setTableCible(e.target.value);
                  setColonne('');
                }}
              >
                {tablesCibles.map((t) => (
                  <MenuItem key={t} value={t}>
                    {t}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
            <FormControl size="small" sx={{ minWidth: 280 }} disabled={!tableCible}>
              <InputLabel>Colonne</InputLabel>
              <Select value={colonne} label="Colonne" onChange={(e) => setColonne(e.target.value)}>
                {colonnesCibles.map((c) => (
                  <MenuItem key={c} value={c}>
                    {c}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          </Paper>

          {!tableCible || !colonne ? (
            <Alert severity="info" sx={{ mt: 2 }}>
              Choisissez une table cible et une colonne pour afficher la grille famille × site.
            </Alert>
          ) : (
            <>
              {grille(rendreCelluleValeur, ouvrirCellule)}
              <Typography variant="caption" sx={{ display: 'block', mt: 1, color: 'text.secondary' }}>
                Valeur en gris = héritée (aucune règle propre à cette cellule). Cliquez sur une
                cellule pour définir, modifier ou supprimer sa règle.
              </Typography>
            </>
          )}
        </>
      )}

      {onglet === 1 && (
        <>
          <Paper sx={{ p: 2, display: 'flex', gap: 2, flexWrap: 'wrap' }}>
            <FormControl size="small" sx={{ minWidth: 420 }}>
              <InputLabel>Table à créer</InputLabel>
              <Select
                value={tableRoutage}
                label="Table à créer"
                onChange={(e) => setTableRoutage(e.target.value)}
              >
                {meta.part_type_tables.map((t) => (
                  <MenuItem key={t.target_table} value={t.target_table}>
                    {t.libelle}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          </Paper>
          <Alert severity="warning" sx={{ mt: 2 }}>
            Les trois tables sont indépendantes : un article peut être à la fois fabriqué, vendu et
            acheté. Passer une cellule à <strong>Non créé</strong> supprime aussi, au prochain
            chargement, les lignes déjà chargées pour ce site et cette famille.
          </Alert>
          {grille(rendreCelluleRoutage, basculerRoutage)}
          <Typography variant="caption" sx={{ display: 'block', mt: 1, color: 'text.secondary' }}>
            Chaque clic fait défiler : hérité → Créé → Non créé → hérité.
          </Typography>
        </>
      )}

      <Dialog open={cellule !== null} onClose={() => setCellule(null)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {colonne} — {cellule ? libelleRegle(cellule) : ''}
        </DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 1 }}>
          <DialogContentText variant="body2">
            Table cible : <strong>{tableCible}</strong>
          </DialogContentText>
          <RadioGroup row value={typeEdit} onChange={(e) => setTypeEdit(e.target.value as 'CONSTANTE' | 'NULL')}>
            <FormControlLabel value="CONSTANTE" control={<Radio />} label="Valeur" />
            <FormControlLabel value="NULL" control={<Radio />} label="NULL (colonne laissée vide)" />
          </RadioGroup>
          {typeEdit === 'CONSTANTE' && (
            <TextField
              label="Valeur"
              size="small"
              value={valeurEdit}
              onChange={(e) => setValeurEdit(e.target.value)}
              helperText="La valeur doit être compatible avec le type de la colonne cible (contrôlé à l'enregistrement)."
            />
          )}
          <TextField
            label="Description"
            size="small"
            multiline
            minRows={2}
            value={descriptionEdit}
            onChange={(e) => setDescriptionEdit(e.target.value)}
          />
        </DialogContent>
        <DialogActions>
          {regleCourante && (
            <Button color="error" startIcon={<DeleteIcon />} onClick={supprimerCellule}>
              Supprimer la règle
            </Button>
          )}
          <Box sx={{ flex: 1 }} />
          <Button onClick={() => setCellule(null)}>Annuler</Button>
          <Button variant="contained" onClick={enregistrerCellule}>
            Enregistrer
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar open={message !== null} autoHideDuration={4000} onClose={() => setMessage(null)}>
        <Alert severity={message?.type ?? 'success'} onClose={() => setMessage(null)}>
          {message?.texte}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default MatriceSiteFamille;
