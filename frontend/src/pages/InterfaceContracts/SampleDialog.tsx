import {
    Alert,
    Box,
    Button,
    Chip,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    Divider,
    FormControlLabel,
    Paper,
    Switch,
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableRow,
    Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useState } from 'react';

import interfaceContractService, {
    ContractColumn,
    ContractSample,
    ContractSampleSet,
} from '../../services/interfaceContractService';

interface Props {
  colonne: ContractColumn | null;
  onClose: () => void;
}

const ListeValeurs: React.FC<{ titre: string; jeu: ContractSampleSet }> = ({ titre, jeu }) => (
  <Paper variant="outlined" sx={{ p: 1.5, height: '100%' }}>
    <Typography variant="subtitle2" gutterBottom>
      {titre}
      <Chip
        size="small"
        label={`${jeu.schema}.${jeu.table}.${jeu.column}`}
        sx={{ ml: 1, fontFamily: 'monospace' }}
      />
      {jeu.masked && <Chip size="small" color="warning" label="masqué" sx={{ ml: 1 }} />}
    </Typography>
    {jeu.values.length === 0 ? (
      <Typography variant="body2" color="text.secondary">
        Aucune valeur (colonne vide en base).
      </Typography>
    ) : (
      <Box component="ul" sx={{ m: 0, pl: 2.5 }}>
        {jeu.values.map((valeur, index) => (
          <Typography component="li" variant="body2" key={index} sx={{ fontFamily: 'monospace' }}>
            {valeur}
          </Typography>
        ))}
      </Box>
    )}
  </Paper>
);

/**
 * Apercu de donnees REELLES a cote de la regle : le metier lit
 * « lfa1.name1 tronque a 100 » et voit tout de suite les valeurs concernees.
 * C'est ce que le classeur Excel ne peut pas faire.
 */
const SampleDialog: React.FC<Props> = ({ colonne, onClose }) => {
  const [donnees, setDonnees] = useState<ContractSample | null>(null);
  const [demasquer, setDemasquer] = useState(false);
  const [erreur, setErreur] = useState<string | null>(null);

  const charger = useCallback(async () => {
    if (!colonne) return;
    try {
      setErreur(null);
      setDonnees(await interfaceContractService.getSample(colonne.contract_column_id, demasquer));
    } catch {
      setErreur("Impossible de lire l'échantillon de données.");
    }
  }, [colonne, demasquer]);

  useEffect(() => {
    setDonnees(null);
    setDemasquer(false);
  }, [colonne?.contract_column_id]);

  useEffect(() => {
    charger();
  }, [charger]);

  return (
    <Dialog open={Boolean(colonne)} onClose={onClose} maxWidth="lg" fullWidth>
      <DialogTitle>
        Données réelles — {colonne?.target_column}
        <Typography variant="body2" color="text.secondary">
          {colonne?.transformation_rule}
        </Typography>
      </DialogTitle>
      <DialogContent dividers>
        {erreur && <Alert severity="error" sx={{ mb: 2 }}>{erreur}</Alert>}

        {donnees?.can_unmask && (
          <FormControlLabel
            sx={{ mb: 1 }}
            control={
              <Switch
                size="small"
                checked={demasquer}
                onChange={(e) => setDemasquer(e.target.checked)}
              />
            }
            label="Afficher les valeurs sensibles en clair (IBAN, identifiants fiscaux)"
          />
        )}

        <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
          <Box sx={{ flex: '1 1 300px' }}>
            {donnees?.source ? (
              <ListeValeurs titre="Source" jeu={donnees.source} />
            ) : (
              <Alert severity="info">
                Pas de source structurée sur cette ligne (expression calculée ou
                multi-sources) : voir « Champ / Table source ».
              </Alert>
            )}
          </Box>
          <Box sx={{ flex: '1 1 300px', display: 'flex', flexDirection: 'column', gap: 2 }}>
            {donnees?.targets.length ? (
              donnees.targets.map((jeu) => (
                <ListeValeurs key={jeu.column} titre="Cible IFS" jeu={jeu} />
              ))
            ) : (
              <Alert severity="info">
                La table cible n'est pas encore chargée (aucune colonne lisible).
              </Alert>
            )}
          </Box>
        </Box>

        {Boolean(donnees?.default_values.length) && (
          <>
            <Divider sx={{ my: 2 }} />
            <Typography variant="subtitle2" gutterBottom>
              Valeurs par défaut paramétrables résumées par cette ligne
            </Typography>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Colonne</TableCell>
                  <TableCell>Variante</TableCell>
                  <TableCell>Type</TableCell>
                  <TableCell>Valeur</TableCell>
                  <TableCell>Actif</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {donnees?.default_values.map((dv) => (
                  <TableRow key={`${dv.colonne}-${dv.variante}`}>
                    <TableCell sx={{ fontFamily: 'monospace' }}>{dv.colonne}</TableCell>
                    <TableCell>{dv.variante}</TableCell>
                    <TableCell>{dv.type_valeur}</TableCell>
                    <TableCell sx={{ fontFamily: 'monospace' }}>
                      {dv.type_valeur === 'NULL' ? '(NULL)' : dv.valeur}
                    </TableCell>
                    <TableCell>{dv.is_active ? 'Oui' : 'Non'}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </>
        )}

        {donnees && (
          <Typography variant="caption" color="text.secondary" sx={{ mt: 2, display: 'block' }}>
            {donnees.limit} valeurs distinctes au maximum.
          </Typography>
        )}
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Fermer</Button>
      </DialogActions>
    </Dialog>
  );
};

export default SampleDialog;
