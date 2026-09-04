import {
    Cancel as CancelIcon,
    CheckCircle as CheckCircleIcon,
    ExpandLess as ExpandLessIcon,
    ExpandMore as ExpandMoreIcon,
    RemoveCircleOutline as NaIcon,
    Search as SearchIcon,
    TableView as SampleIcon,
    WarningAmber as WarningIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Chip,
    CircularProgress,
    Collapse,
    Divider,
    FormControl,
    IconButton,
    InputAdornment,
    InputLabel,
    MenuItem,
    Paper,
    Select,
    Stack,
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

import interfaceContractService, {
    ContractColumn,
    ContractColumnFilters,
    ContractEvent,
    ContractStatut,
    ContractTableSummary,
} from '../../services/interfaceContractService';
import SampleDialog from './SampleDialog';

const LIBELLE_STATUT: Record<ContractStatut, string> = {
  A_VALIDER: 'À valider',
  VALIDE: 'Validé',
  A_CORRIGER: 'À corriger',
  NON_APPLICABLE: 'Sans objet',
};

const COULEUR_STATUT: Record<ContractStatut, 'default' | 'success' | 'error' | 'info'> = {
  A_VALIDER: 'default',
  VALIDE: 'success',
  A_CORRIGER: 'error',
  NON_APPLICABLE: 'info',
};

const LIBELLE_EVENEMENT: Record<ContractEvent['event_type'], string> = {
  STATUT: 'Changement de statut',
  COMMENTAIRE: 'Commentaire',
  DEFINITION: 'Modification technique',
  IMPORT_EXCEL: 'Reprise depuis Excel',
};

interface Props {
  table: ContractTableSummary;
  /** Lecture seule : consultation par un utilisateur sans droit de validation. */
  readOnly: boolean;
  onChanged: () => void;
}

/** Fil de discussion + historique d'une ligne, charge a la demande. */
const FilDiscussion: React.FC<{ columnId: number; readOnly: boolean; onChanged: () => void }> = ({
  columnId,
  readOnly,
  onChanged,
}) => {
  const [evenements, setEvenements] = useState<ContractEvent[] | null>(null);
  const [message, setMessage] = useState('');
  const [envoi, setEnvoi] = useState(false);

  const charger = useCallback(async () => {
    setEvenements(await interfaceContractService.getEvents(columnId));
  }, [columnId]);

  useEffect(() => {
    charger().catch(() => setEvenements([]));
  }, [charger]);

  const envoyer = async () => {
    if (!message.trim()) return;
    setEnvoi(true);
    try {
      await interfaceContractService.addComment(columnId, message.trim());
      setMessage('');
      await charger();
      onChanged();
    } finally {
      setEnvoi(false);
    }
  };

  if (evenements === null) return <CircularProgress size={18} />;

  return (
    <Box>
      <Typography variant="subtitle2" gutterBottom>
        Historique et échanges
      </Typography>
      {evenements.length === 0 && (
        <Typography variant="body2" color="text.secondary">
          Aucun échange sur cette ligne.
        </Typography>
      )}
      <Stack spacing={0.5} sx={{ mb: 1 }}>
        {evenements.map((evenement) => (
          <Box key={evenement.id} sx={{ display: 'flex', gap: 1, alignItems: 'baseline' }}>
            <Chip size="small" label={LIBELLE_EVENEMENT[evenement.event_type]} />
            <Typography variant="body2">
              {evenement.event_type === 'STATUT' && (
                <strong>
                  {evenement.ancien_statut} → {evenement.nouveau_statut}
                  {evenement.commentaire ? ' — ' : ''}
                </strong>
              )}
              {evenement.commentaire}
            </Typography>
            <Typography variant="caption" color="text.secondary" sx={{ ml: 'auto' }}>
              {evenement.auteur} · {new Date(evenement.created_at).toLocaleString('fr-FR')}
            </Typography>
          </Box>
        ))}
      </Stack>
      {!readOnly && (
        <Box sx={{ display: 'flex', gap: 1 }}>
          <TextField
            size="small"
            fullWidth
            placeholder="Ajouter une remarque (conservée dans le fil)"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                envoyer();
              }
            }}
          />
          <Button variant="outlined" onClick={envoyer} disabled={envoi || !message.trim()}>
            Envoyer
          </Button>
        </Box>
      )}
    </Box>
  );
};

/**
 * Le tableau du contrat, utilise a l'identique en consultation (readOnly) et en
 * validation : un seul composant, pour que les deux ecrans ne divergent jamais.
 */
const ContractTable: React.FC<Props> = ({ table, readOnly, onChanged }) => {
  const [colonnes, setColonnes] = useState<ContractColumn[]>([]);
  const [chargement, setChargement] = useState(false);
  const [erreur, setErreur] = useState<string | null>(null);
  const [filtres, setFiltres] = useState<ContractColumnFilters>({});
  const [recherche, setRecherche] = useState('');
  const [ouverte, setOuverte] = useState<number | null>(null);
  const [apercu, setApercu] = useState<ContractColumn | null>(null);
  const [remarques, setRemarques] = useState<Record<number, string>>({});

  const charger = useCallback(async () => {
    setChargement(true);
    try {
      setErreur(null);
      const donnees = await interfaceContractService.getColumns(table.contract_table_id, {
        ...filtres,
        search: recherche,
      });
      setColonnes(donnees.columns);
    } catch {
      setErreur('Erreur lors du chargement du contrat.');
    } finally {
      setChargement(false);
    }
  }, [table.contract_table_id, filtres, recherche]);

  useEffect(() => {
    const minuterie = setTimeout(charger, recherche ? 300 : 0);
    return () => clearTimeout(minuterie);
  }, [charger, recherche]);

  const definirStatut = async (colonne: ContractColumn, statut: ContractStatut) => {
    await interfaceContractService.setValidation(
      colonne.contract_column_id,
      statut,
      remarques[colonne.contract_column_id] ?? colonne.remarque_metier,
    );
    await charger();
    onChanged();
  };

  // Les bandeaux de section reprennent le decoupage du classeur.
  const lignesAvecSections = useMemo(() => {
    const resultat: { section: string | null; lignes: ContractColumn[] }[] = [];
    colonnes.forEach((colonne) => {
      const dernier = resultat[resultat.length - 1];
      if (!dernier || dernier.section !== colonne.section) {
        resultat.push({ section: colonne.section, lignes: [colonne] });
      } else {
        dernier.lignes.push(colonne);
      }
    });
    return resultat;
  }, [colonnes]);

  return (
    <Paper variant="outlined">
      <Box sx={{ p: 1.5, display: 'flex', gap: 1.5, flexWrap: 'wrap', alignItems: 'center' }}>
        <TextField
          size="small"
          placeholder="Rechercher une colonne, une source, une règle…"
          value={recherche}
          onChange={(e) => setRecherche(e.target.value)}
          sx={{ minWidth: 280, flexGrow: 1 }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchIcon fontSize="small" />
              </InputAdornment>
            ),
          }}
        />
        <FormControl size="small" sx={{ minWidth: 160 }}>
          <InputLabel>Statut</InputLabel>
          <Select
            label="Statut"
            value={filtres.statut ?? ''}
            onChange={(e) => setFiltres({ ...filtres, statut: e.target.value })}
          >
            <MenuItem value="">Tous</MenuItem>
            {(Object.keys(LIBELLE_STATUT) as ContractStatut[]).map((statut) => (
              <MenuItem key={statut} value={statut}>
                {LIBELLE_STATUT[statut]}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        <ToggleButtonGroup
          size="small"
          exclusive
          value={filtres.obsolete ?? ''}
          onChange={(_, valeur) => setFiltres({ ...filtres, obsolete: valeur ?? '' })}
        >
          <ToggleButton value="true">
            <WarningIcon fontSize="small" sx={{ mr: 0.5 }} />
            À revalider ({table.nb_obsolete})
          </ToggleButton>
        </ToggleButtonGroup>
        <FormControl size="small" sx={{ minWidth: 150 }}>
          <InputLabel>Type de ligne</InputLabel>
          <Select
            label="Type de ligne"
            value={filtres.row_type ?? ''}
            onChange={(e) => setFiltres({ ...filtres, row_type: e.target.value })}
          >
            <MenuItem value="">Toutes</MenuItem>
            <MenuItem value="COLUMN">Colonnes</MenuItem>
            <MenuItem value="CONFIG_SUMMARY">Valeurs par défaut</MenuItem>
            <MenuItem value="NOTE">Notes</MenuItem>
          </Select>
        </FormControl>
      </Box>
      <Divider />

      {erreur && <Alert severity="error">{erreur}</Alert>}
      {chargement && <CircularProgress size={20} sx={{ m: 2 }} />}

      <TableContainer sx={{ maxHeight: '62vh' }}>
        <Table size="small" stickyHeader>
          <TableHead>
            <TableRow>
              <TableCell sx={{ width: 36 }} />
              <TableCell sx={{ minWidth: 200 }}>Colonne cible</TableCell>
              <TableCell sx={{ minWidth: 140 }}>Type</TableCell>
              <TableCell sx={{ minWidth: 220 }}>Champ / table source</TableCell>
              <TableCell sx={{ minWidth: 300 }}>Règle de transformation</TableCell>
              <TableCell sx={{ minWidth: 130 }}>Statut</TableCell>
              <TableCell sx={{ minWidth: readOnly ? 200 : 260 }}>
                {readOnly ? 'Remarque métier' : 'Validation'}
              </TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {lignesAvecSections.map((groupe) => (
              <React.Fragment key={groupe.section ?? '__sans_section'}>
                {groupe.section && (
                  <TableRow>
                    <TableCell colSpan={7} sx={{ bgcolor: '#D9E1F2', fontWeight: 600 }}>
                      {groupe.section}
                    </TableCell>
                  </TableRow>
                )}
                {groupe.lignes.map((colonne) => {
                  const estNote = colonne.row_type === 'NOTE';
                  const ouvert = ouverte === colonne.contract_column_id;
                  if (estNote) {
                    return (
                      <TableRow key={colonne.contract_column_id}>
                        <TableCell colSpan={7} sx={{ fontStyle: 'italic', color: 'text.secondary' }}>
                          {colonne.transformation_rule}
                        </TableCell>
                      </TableRow>
                    );
                  }
                  return (
                    <React.Fragment key={colonne.contract_column_id}>
                      <TableRow
                        hover
                        sx={{
                          bgcolor: colonne.validation_obsolete
                            ? 'rgba(255, 167, 38, 0.12)'
                            : undefined,
                        }}
                      >
                        <TableCell>
                          <Tooltip
                            title={
                              colonne.nb_commentaires
                                ? `${colonne.nb_commentaires} échange(s) sur cette ligne`
                                : 'Détail et historique'
                            }
                          >
                            <IconButton
                              size="small"
                              color={colonne.nb_commentaires ? 'primary' : 'default'}
                              onClick={() => setOuverte(ouvert ? null : colonne.contract_column_id)}
                            >
                              {ouvert ? <ExpandLessIcon /> : <ExpandMoreIcon />}
                            </IconButton>
                          </Tooltip>
                        </TableCell>
                        <TableCell sx={{ fontFamily: 'monospace' }}>
                          {colonne.target_column}
                          {colonne.row_type === 'CONFIG_SUMMARY' && (
                            <Chip
                              size="small"
                              label={`${colonne.nb_default_values ?? 0} valeurs`}
                              sx={{ ml: 1 }}
                            />
                          )}
                        </TableCell>
                        <TableCell>
                          <Typography variant="caption">{colonne.type_longueur}</Typography>
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2">{colonne.source_expression}</Typography>
                          {colonne.systeme_source && (
                            <Chip size="small" variant="outlined" label={colonne.systeme_source} />
                          )}
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2">{colonne.transformation_rule}</Typography>
                        </TableCell>
                        <TableCell>
                          <Chip
                            size="small"
                            color={COULEUR_STATUT[colonne.statut]}
                            label={LIBELLE_STATUT[colonne.statut]}
                          />
                          {colonne.validation_obsolete && (
                            <Tooltip title="Validée, mais la règle a été modifiée depuis : à revalider">
                              <Chip
                                size="small"
                                color="warning"
                                icon={<WarningIcon />}
                                label="à revalider"
                                sx={{ mt: 0.5 }}
                              />
                            </Tooltip>
                          )}
                        </TableCell>
                        <TableCell>
                          {readOnly ? (
                            <Typography variant="body2">{colonne.remarque_metier}</Typography>
                          ) : (
                            <Stack direction="row" spacing={0.5}>
                              <Tooltip title="Valider">
                                <IconButton
                                  size="small"
                                  color="success"
                                  onClick={() => definirStatut(colonne, 'VALIDE')}
                                >
                                  <CheckCircleIcon fontSize="small" />
                                </IconButton>
                              </Tooltip>
                              <Tooltip title="À corriger">
                                <IconButton
                                  size="small"
                                  color="error"
                                  onClick={() => definirStatut(colonne, 'A_CORRIGER')}
                                >
                                  <CancelIcon fontSize="small" />
                                </IconButton>
                              </Tooltip>
                              <Tooltip title="Sans objet">
                                <IconButton
                                  size="small"
                                  onClick={() => definirStatut(colonne, 'NON_APPLICABLE')}
                                >
                                  <NaIcon fontSize="small" />
                                </IconButton>
                              </Tooltip>
                              <Tooltip title="Voir les données réelles">
                                <IconButton size="small" onClick={() => setApercu(colonne)}>
                                  <SampleIcon fontSize="small" />
                                </IconButton>
                              </Tooltip>
                            </Stack>
                          )}
                        </TableCell>
                      </TableRow>
                      <TableRow>
                        <TableCell colSpan={7} sx={{ py: 0, borderBottom: ouvert ? undefined : 0 }}>
                          <Collapse in={ouvert} unmountOnExit>
                            <Box sx={{ py: 2, display: 'flex', gap: 3, flexWrap: 'wrap' }}>
                              <Box sx={{ flex: '1 1 320px' }}>
                                <Typography variant="subtitle2">Détail</Typography>
                                <Typography variant="body2">
                                  <strong>Exemple :</strong> {colonne.exemple_valeur || '—'}
                                </Typography>
                                <Typography variant="body2">
                                  <strong>Condition :</strong>{' '}
                                  {colonne.condition_application || '—'}
                                </Typography>
                                <Typography variant="body2">
                                  <strong>Validé par :</strong>{' '}
                                  {colonne.validated_by
                                    ? `${colonne.validated_by} le ${new Date(
                                        colonne.validated_at as string,
                                      ).toLocaleString('fr-FR')}`
                                    : '—'}
                                </Typography>
                                <Typography variant="body2">
                                  <strong>Remarque :</strong> {colonne.remarque_metier || '—'}
                                </Typography>
                                {!readOnly && (
                                  <TextField
                                    size="small"
                                    fullWidth
                                    sx={{ mt: 1 }}
                                    label="Remarque à enregistrer avec le prochain statut"
                                    value={
                                      remarques[colonne.contract_column_id] ??
                                      colonne.remarque_metier ??
                                      ''
                                    }
                                    onChange={(e) =>
                                      setRemarques({
                                        ...remarques,
                                        [colonne.contract_column_id]: e.target.value,
                                      })
                                    }
                                  />
                                )}
                                <Button
                                  size="small"
                                  startIcon={<SampleIcon />}
                                  sx={{ mt: 1 }}
                                  onClick={() => setApercu(colonne)}
                                >
                                  Voir les données réelles
                                </Button>
                              </Box>
                              <Box sx={{ flex: '2 1 420px' }}>
                                <FilDiscussion
                                  columnId={colonne.contract_column_id}
                                  readOnly={readOnly}
                                  onChanged={charger}
                                />
                              </Box>
                            </Box>
                          </Collapse>
                        </TableCell>
                      </TableRow>
                    </React.Fragment>
                  );
                })}
              </React.Fragment>
            ))}
            {!chargement && colonnes.length === 0 && (
              <TableRow>
                <TableCell colSpan={7}>
                  <Typography variant="body2" color="text.secondary" sx={{ p: 2 }}>
                    Aucune ligne ne correspond aux filtres.
                  </Typography>
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>

      <SampleDialog colonne={apercu} onClose={() => setApercu(null)} />
    </Paper>
  );
};

export default ContractTable;
