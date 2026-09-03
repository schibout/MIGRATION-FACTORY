import {
    CloudUpload as ImportIcon,
    Download as ExportIcon,
    FactCheck as SignIcon,
    Refresh as RefreshIcon,
    ReportProblem as CoverageIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Card,
    CardActionArea,
    CardContent,
    Chip,
    CircularProgress,
    Collapse,
    Container,
    Divider,
    FormControl,
    InputLabel,
    LinearProgress,
    List,
    ListItemButton,
    ListItemText,
    MenuItem,
    Paper,
    Select,
    Snackbar,
    Stack,
    TextField,
    Tooltip,
    Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSelector } from 'react-redux';
import { useNavigate, useParams } from 'react-router-dom';

import interfaceContractService, {
    ContractCoverage,
    ContractMeta,
    ContractTableSummary,
} from '../../services/interfaceContractService';
import { RootState } from '../../store';
import ContractTable from './ContractTable';

/** Pastille verte / orange / rouge du panneau de gauche. */
const couleurAvancement = (table: ContractTableSummary): 'success' | 'warning' | 'error' => {
  if (table.nb_a_corriger > 0 || table.nb_obsolete > 0) return 'error';
  if ((table.pct_valide ?? 0) >= 100) return 'success';
  return 'warning';
};

const InterfaceContractsPage: React.FC = () => {
  const { tableCible } = useParams<{ tableCible?: string }>();
  const navigate = useNavigate();
  const utilisateur = useSelector((state: RootState) => state.auth.user);

  const [meta, setMeta] = useState<ContractMeta | null>(null);
  const [tables, setTables] = useState<ContractTableSummary[]>([]);
  const [module, setModule] = useState('');
  const [selectionnee, setSelectionnee] = useState<ContractTableSummary | null>(null);
  const [couverture, setCouverture] = useState<ContractCoverage | null>(null);
  const [afficherCouverture, setAfficherCouverture] = useState(false);
  const [chargement, setChargement] = useState(true);
  const [message, setMessage] = useState<{ texte: string; type: 'success' | 'error' } | null>(null);
  const champFichier = useRef<HTMLInputElement>(null);

  const charger = useCallback(async () => {
    setChargement(true);
    try {
      const donnees = await interfaceContractService.listTables(module || undefined);
      setTables(donnees);
      return donnees;
    } catch {
      setMessage({ texte: 'Erreur lors du chargement des contrats', type: 'error' });
      return [];
    } finally {
      setChargement(false);
    }
  }, [module]);

  useEffect(() => {
    interfaceContractService
      .meta()
      .then(setMeta)
      .catch(() => setMessage({ texte: 'Erreur lors du chargement des métadonnées', type: 'error' }));
  }, []);

  useEffect(() => {
    charger().then((donnees) => {
      // Deep link : /interface-contracts/<table_cible> ouvre directement la
      // table a relire (lien envoyable par mail au metier).
      const cible = tableCible
        ? donnees.find((t) => t.table_cible === tableCible)
        : undefined;
      setSelectionnee((precedente) =>
        cible ?? donnees.find((t) => t.contract_table_id === precedente?.contract_table_id) ?? null,
      );
    });
  }, [charger, tableCible]);

  useEffect(() => {
    setCouverture(null);
    if (!selectionnee) return;
    interfaceContractService
      .getCoverage(selectionnee.contract_table_id)
      .then(setCouverture)
      .catch(() => setCouverture(null));
  }, [selectionnee?.contract_table_id]);

  const selectionner = (table: ContractTableSummary) => {
    setSelectionnee(table);
    navigate(`/interface-contracts/${table.table_cible}`, { replace: true });
  };

  const rafraichir = async () => {
    const donnees = await charger();
    setSelectionnee(
      (precedente) =>
        donnees.find((t) => t.contract_table_id === precedente?.contract_table_id) ?? precedente,
    );
    if (selectionnee) {
      interfaceContractService
        .getCoverage(selectionnee.contract_table_id)
        .then(setCouverture)
        .catch(() => undefined);
    }
  };

  const signer = async () => {
    if (!selectionnee) return;
    try {
      await interfaceContractService.sign(
        selectionnee.contract_table_id,
        !selectionnee.signe_le,
      );
      setMessage({
        texte: selectionnee.signe_le ? 'Signature retirée' : 'Table signée',
        type: 'success',
      });
      await rafraichir();
    } catch {
      setMessage({ texte: 'Erreur lors de la signature', type: 'error' });
    }
  };

  const exporter = async () => {
    try {
      await interfaceContractService.exportWorkbook(module || undefined);
    } catch {
      setMessage({ texte: "Erreur lors de la génération du classeur", type: 'error' });
    }
  };

  const importer = async (fichier: File) => {
    try {
      const resultat = await interfaceContractService.importWorkbook(
        fichier,
        module || meta?.modules[0] || 'supplier',
      );
      setMessage({
        texte: `${resultat.reprises} validation(s) reprises, ${resultat.ignorees} ligne(s) ignorée(s)`,
        type: 'success',
      });
      await rafraichir();
    } catch {
      setMessage({ texte: "Erreur lors de la reprise du classeur", type: 'error' });
    }
  };

  const global = useMemo(() => {
    const lignes = tables.reduce((total, t) => total + Number(t.nb_lignes), 0);
    const valides = tables.reduce(
      (total, t) => total + Number(t.nb_valide) + Number(t.nb_non_applicable),
      0,
    );
    const obsoletes = tables.reduce((total, t) => total + Number(t.nb_obsolete), 0);
    return { lignes, valides, obsoletes, pct: lignes ? (100 * valides) / lignes : 0 };
  }, [tables]);

  const peutValider = Boolean(meta?.can_validate);

  return (
    <Container maxWidth={false} sx={{ py: 2 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, flexWrap: 'wrap', mb: 2 }}>
        <Box>
          <Typography variant="h5">Contrats d'interface</Typography>
          <Typography variant="body2" color="text.secondary">
            Mapping SAP → IFS, sa règle de transformation et sa validation métier.
          </Typography>
        </Box>
        <Box sx={{ flexGrow: 1 }} />
        <FormControl size="small" sx={{ minWidth: 160 }}>
          <InputLabel>Module</InputLabel>
          <Select label="Module" value={module} onChange={(e) => setModule(e.target.value)}>
            <MenuItem value="">Tous</MenuItem>
            {meta?.modules.map((nom) => (
              <MenuItem key={nom} value={nom}>
                {nom}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        <Button startIcon={<RefreshIcon />} onClick={rafraichir}>
          Actualiser
        </Button>
        <Button startIcon={<ExportIcon />} variant="outlined" onClick={exporter}>
          Exporter en Excel
        </Button>
        {meta?.can_manage && (
          <>
            <input
              ref={champFichier}
              type="file"
              accept=".xlsx"
              hidden
              onChange={(e) => {
                const fichier = e.target.files?.[0];
                if (fichier) importer(fichier);
                e.target.value = '';
              }}
            />
            <Tooltip title="Reprendre un classeur rempli hors ligne par un relecteur sans compte">
              <Button
                startIcon={<ImportIcon />}
                variant="outlined"
                onClick={() => champFichier.current?.click()}
              >
                Importer un classeur
              </Button>
            </Tooltip>
          </>
        )}
      </Box>

      {/* Tableau de bord */}
      <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 1 }}>
          <Typography variant="subtitle1">
            Avancement global : {global.valides} / {global.lignes} lignes validées
          </Typography>
          {global.obsoletes > 0 && (
            <Chip
              size="small"
              color="warning"
              label={`${global.obsoletes} à revalider (règle modifiée)`}
            />
          )}
        </Box>
        <LinearProgress variant="determinate" value={Math.min(global.pct, 100)} sx={{ mb: 2 }} />
        <Box sx={{ display: 'flex', gap: 1.5, flexWrap: 'wrap' }}>
          {tables.map((table) => (
            <Card
              key={table.contract_table_id}
              variant="outlined"
              sx={{
                width: 250,
                borderColor:
                  selectionnee?.contract_table_id === table.contract_table_id
                    ? 'primary.main'
                    : undefined,
              }}
            >
              <CardActionArea onClick={() => selectionner(table)}>
                <CardContent sx={{ pb: 1.5 }}>
                  <Typography variant="subtitle2" noWrap title={table.libelle}>
                    {table.libelle}
                  </Typography>
                  <Typography variant="caption" color="text.secondary" noWrap>
                    {table.schema_cible}.{table.table_cible}
                  </Typography>
                  <LinearProgress
                    variant="determinate"
                    color={couleurAvancement(table)}
                    value={Number(table.pct_valide ?? 0)}
                    sx={{ my: 1 }}
                  />
                  <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
                    <Chip size="small" label={`${table.pct_valide ?? 0}%`} />
                    {table.nb_a_corriger > 0 && (
                      <Chip size="small" color="error" label={`${table.nb_a_corriger} à corriger`} />
                    )}
                    {table.nb_obsolete > 0 && (
                      <Chip size="small" color="warning" label={`${table.nb_obsolete} à revalider`} />
                    )}
                    {table.signe_le && (
                      <Chip size="small" color="success" icon={<SignIcon />} label="signée" />
                    )}
                  </Stack>
                  {(table.owner_metier || table.date_limite) && (
                    <Typography variant="caption" color="text.secondary" display="block" mt={0.5}>
                      {table.owner_metier}
                      {table.date_limite ? ` · échéance ${table.date_limite}` : ''}
                    </Typography>
                  )}
                </CardContent>
              </CardActionArea>
            </Card>
          ))}
        </Box>
        {chargement && <CircularProgress size={20} sx={{ mt: 2 }} />}
        {!chargement && tables.length === 0 && (
          <Alert severity="info" sx={{ mt: 2 }}>
            Aucun contrat chargé. Amorcer un module avec
            <code> scripts/seed_interface_contracts.py</code>.
          </Alert>
        )}
      </Paper>

      {/* Visionneuse : panneau des tables + détail */}
      <Box sx={{ display: 'flex', gap: 2, alignItems: 'flex-start', flexWrap: 'wrap' }}>
        <Paper variant="outlined" sx={{ width: 280, flexShrink: 0, maxHeight: '78vh', overflow: 'auto' }}>
          <List dense disablePadding>
            {tables.map((table) => (
              <ListItemButton
                key={table.contract_table_id}
                selected={selectionnee?.contract_table_id === table.contract_table_id}
                onClick={() => selectionner(table)}
              >
                <Box
                  sx={{
                    width: 10,
                    height: 10,
                    borderRadius: '50%',
                    mr: 1.2,
                    bgcolor: `${couleurAvancement(table)}.main`,
                  }}
                />
                <ListItemText
                  primary={table.libelle}
                  secondary={`${table.nb_valide + table.nb_non_applicable}/${table.nb_lignes} validées`}
                  primaryTypographyProps={{ variant: 'body2', noWrap: true }}
                />
              </ListItemButton>
            ))}
          </List>
        </Paper>

        <Box sx={{ flex: '1 1 700px', minWidth: 0 }}>
          {selectionnee ? (
            <>
              <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
                <Box sx={{ display: 'flex', gap: 2, alignItems: 'flex-start', flexWrap: 'wrap' }}>
                  <Box sx={{ flexGrow: 1, minWidth: 260 }}>
                    <Typography variant="h6">{selectionnee.libelle}</Typography>
                    <Typography variant="body2" color="text.secondary">
                      {selectionnee.description}
                    </Typography>
                    {selectionnee.source_procedure && (
                      <Chip
                        size="small"
                        sx={{ mt: 1, fontFamily: 'monospace' }}
                        label={selectionnee.source_procedure}
                      />
                    )}
                  </Box>
                  <Stack spacing={1} alignItems="flex-end">
                    {selectionnee.signe_le ? (
                      <Chip
                        color="success"
                        icon={<SignIcon />}
                        label={`Signée par ${selectionnee.signe_par} le ${new Date(
                          selectionnee.signe_le,
                        ).toLocaleDateString('fr-FR')}`}
                      />
                    ) : (
                      <Chip label="Non signée" />
                    )}
                    {peutValider && (
                      <Button size="small" variant="outlined" onClick={signer}>
                        {selectionnee.signe_le ? 'Retirer la signature' : 'Signer la table'}
                      </Button>
                    )}
                    {couverture && (
                      <Button
                        size="small"
                        color={couverture.non_documentees.length ? 'warning' : 'inherit'}
                        startIcon={<CoverageIcon />}
                        onClick={() => setAfficherCouverture((v) => !v)}
                      >
                        Couverture : {couverture.nb_colonnes_documentees}/
                        {couverture.nb_colonnes_reelles} colonnes
                      </Button>
                    )}
                  </Stack>
                </Box>
                <Collapse in={afficherCouverture && Boolean(couverture)}>
                  <Divider sx={{ my: 1.5 }} />
                  {!couverture?.table_existe && (
                    <Alert severity="warning">
                      La table cible n'existe pas encore en base : la couverture ne peut pas
                      être calculée.
                    </Alert>
                  )}
                  {Boolean(couverture?.non_documentees.length) && (
                    <Alert severity="warning" sx={{ mb: 1 }}>
                      Colonnes de la table absentes du contrat :{' '}
                      {couverture?.non_documentees.map((c) => c.column_name).join(', ')}
                    </Alert>
                  )}
                  {Boolean(couverture?.obsoletes.length) && (
                    <Alert severity="error">
                      Colonnes citées par le contrat mais absentes de la table :{' '}
                      {couverture?.obsoletes.join(', ')}
                    </Alert>
                  )}
                  {couverture?.table_existe &&
                    !couverture.non_documentees.length &&
                    !couverture.obsoletes.length && (
                      <Alert severity="success">
                        Toutes les colonnes de la table sont documentées.
                      </Alert>
                    )}
                </Collapse>
              </Paper>

              <ContractTable
                key={selectionnee.contract_table_id}
                table={selectionnee}
                readOnly={!peutValider}
                onChanged={rafraichir}
              />
            </>
          ) : (
            <Alert severity="info">Sélectionner une table à consulter ou à valider.</Alert>
          )}
        </Box>
      </Box>

      <Snackbar
        open={Boolean(message)}
        autoHideDuration={5000}
        onClose={() => setMessage(null)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert severity={message?.type ?? 'success'} onClose={() => setMessage(null)}>
          {message?.texte}
        </Alert>
      </Snackbar>
    </Container>
  );
};

export default InterfaceContractsPage;
