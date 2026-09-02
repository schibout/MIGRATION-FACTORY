import {
    Edit as EditIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Checkbox,
    Chip,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    FormControl,
    FormControlLabel,
    InputLabel,
    MenuItem,
    Paper,
    Select,
    Snackbar,
    Switch,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TablePagination,
    TableRow,
    TextField,
    Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useState } from 'react';

import defaultValueService, {
    DefaultValueMeta,
    EtlDefaultValue,
} from '../services/defaultValueService';

const DefaultValuesManagement: React.FC = () => {
  const [rows, setRows] = useState<EtlDefaultValue[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [perPage, setPerPage] = useState(25);
  const [meta, setMeta] = useState<DefaultValueMeta>({ modules: [], tables: [] });
  const [filtreModule, setFiltreModule] = useState('');
  const [filtreTable, setFiltreTable] = useState('');
  const [filtreColonne, setFiltreColonne] = useState('');
  const [filtreActif, setFiltreActif] = useState('');
  const [edition, setEdition] = useState<EtlDefaultValue | null>(null);
  const [valeurEdit, setValeurEdit] = useState('');
  const [descriptionEdit, setDescriptionEdit] = useState('');
  const [estNull, setEstNull] = useState(false);
  const [message, setMessage] = useState<{ texte: string; type: 'success' | 'error' } | null>(null);

  const charger = useCallback(async () => {
    try {
      const data = await defaultValueService.list({
        page: page + 1,
        per_page: perPage,
        module: filtreModule,
        table_cible: filtreTable,
        colonne: filtreColonne,
        is_active: filtreActif,
      });
      setRows(data.default_values);
      setTotal(data.total);
    } catch {
      setMessage({ texte: 'Erreur lors du chargement des valeurs par défaut', type: 'error' });
    }
  }, [page, perPage, filtreModule, filtreTable, filtreColonne, filtreActif]);

  useEffect(() => {
    charger();
  }, [charger]);

  useEffect(() => {
    defaultValueService.meta().then(setMeta).catch(() => undefined);
  }, []);

  const ouvrirEdition = (row: EtlDefaultValue) => {
    setEdition(row);
    setValeurEdit(row.valeur ?? '');
    setDescriptionEdit(row.description ?? '');
    setEstNull(row.type_valeur === 'NULL');
  };

  const messageErreur = (e: unknown, repli: string): string => {
    const detail = (e as { response?: { data?: { error?: string } } })?.response?.data?.error;
    return detail || repli;
  };

  const enregistrer = async () => {
    if (!edition) return;
    try {
      await defaultValueService.update(edition.id, {
        type_valeur: estNull ? 'NULL' : 'CONSTANTE',
        valeur: estNull ? null : valeurEdit,
        description: descriptionEdit,
      });
      setMessage({ texte: 'Valeur mise à jour', type: 'success' });
      setEdition(null);
      charger();
    } catch (e) {
      setMessage({ texte: messageErreur(e, 'Erreur lors de la mise à jour'), type: 'error' });
    }
  };

  const basculerActif = async (row: EtlDefaultValue) => {
    try {
      await defaultValueService.update(row.id, { is_active: !row.is_active });
      charger();
    } catch (e) {
      setMessage({ texte: messageErreur(e, "Erreur lors du changement d'état"), type: 'error' });
    }
  };

  const estBooleenDb =
    !!edition &&
    edition.colonne.endsWith('_db') &&
    ['TRUE', 'FALSE'].includes((edition.valeur ?? '').toUpperCase());

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" gutterBottom>
        Valeurs par défaut ETL
      </Typography>
      <Alert severity="info" sx={{ mb: 2 }}>
        Les modifications s'appliquent au <strong>prochain chargement ETL</strong> du module :
        les données déjà chargées ne sont pas modifiées, il faut relancer le chargement.
      </Alert>

      <Paper sx={{ p: 2, mb: 2, display: 'flex', gap: 2, flexWrap: 'wrap' }}>
        <FormControl size="small" sx={{ minWidth: 160 }}>
          <InputLabel>Module</InputLabel>
          <Select
            value={filtreModule}
            label="Module"
            onChange={(e) => {
              setFiltreModule(e.target.value);
              setFiltreTable('');
              setPage(0);
            }}
          >
            <MenuItem value="">Tous</MenuItem>
            {meta.modules.map((m) => (
              <MenuItem key={m} value={m}>
                {m}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        <FormControl size="small" sx={{ minWidth: 280 }}>
          <InputLabel>Table cible</InputLabel>
          <Select
            value={filtreTable}
            label="Table cible"
            onChange={(e) => {
              setFiltreTable(e.target.value);
              setPage(0);
            }}
          >
            <MenuItem value="">Toutes</MenuItem>
            {meta.tables
              .filter((t) => !filtreModule || t.module === filtreModule)
              .map((t) => (
                <MenuItem key={t.table_cible} value={t.table_cible}>
                  {t.table_cible}
                </MenuItem>
              ))}
          </Select>
        </FormControl>
        <TextField
          size="small"
          label="Colonne"
          value={filtreColonne}
          onChange={(e) => {
            setFiltreColonne(e.target.value);
            setPage(0);
          }}
        />
        <FormControl size="small" sx={{ minWidth: 140 }}>
          <InputLabel>Statut</InputLabel>
          <Select
            value={filtreActif}
            label="Statut"
            onChange={(e) => {
              setFiltreActif(e.target.value);
              setPage(0);
            }}
          >
            <MenuItem value="">Tous</MenuItem>
            <MenuItem value="true">Actif</MenuItem>
            <MenuItem value="false">Inactif</MenuItem>
          </Select>
        </FormControl>
      </Paper>

      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Table</TableCell>
              <TableCell>Colonne</TableCell>
              <TableCell>Variante</TableCell>
              <TableCell>Type</TableCell>
              <TableCell>Valeur</TableCell>
              <TableCell>Description</TableCell>
              <TableCell>Actif</TableCell>
              <TableCell>Modifié</TableCell>
              <TableCell />
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((row) => (
              <TableRow key={row.id} hover>
                <TableCell>{row.table_cible}</TableCell>
                <TableCell>{row.colonne}</TableCell>
                <TableCell>{row.variante !== 'STANDARD' ? row.variante : ''}</TableCell>
                <TableCell>
                  <Chip
                    size="small"
                    label={row.type_valeur}
                    color={row.type_valeur === 'NULL' ? 'default' : 'primary'}
                    variant="outlined"
                  />
                </TableCell>
                <TableCell>{row.type_valeur === 'NULL' ? <em>NULL</em> : row.valeur}</TableCell>
                <TableCell
                  sx={{ maxWidth: 280, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                >
                  {row.description}
                </TableCell>
                <TableCell>
                  <Switch size="small" checked={row.is_active} onChange={() => basculerActif(row)} />
                </TableCell>
                <TableCell>
                  {row.updated_by ? `${row.updated_by} — ${row.updated_at?.slice(0, 16).replace('T', ' ')}` : ''}
                </TableCell>
                <TableCell>
                  <Button size="small" startIcon={<EditIcon />} onClick={() => ouvrirEdition(row)}>
                    Éditer
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
        <TablePagination
          component="div"
          count={total}
          page={page}
          rowsPerPage={perPage}
          rowsPerPageOptions={[25, 50, 100]}
          onPageChange={(_, p) => setPage(p)}
          onRowsPerPageChange={(e) => {
            setPerPage(parseInt(e.target.value, 10));
            setPage(0);
          }}
        />
      </TableContainer>

      <Dialog open={edition !== null} onClose={() => setEdition(null)} maxWidth="sm" fullWidth>
        <DialogTitle>Modifier la valeur par défaut</DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 1 }}>
          <TextField label="Table" value={edition?.table_cible ?? ''} disabled size="small" />
          <TextField label="Colonne" value={edition?.colonne ?? ''} disabled size="small" />
          <TextField label="Variante" value={edition?.variante ?? ''} disabled size="small" />
          <FormControlLabel
            control={<Checkbox checked={estNull} onChange={(e) => setEstNull(e.target.checked)} />}
            label="NULL explicite (aucune valeur insérée)"
          />
          {!estNull &&
            (estBooleenDb ? (
              <FormControl size="small">
                <InputLabel>Valeur</InputLabel>
                <Select value={valeurEdit} label="Valeur" onChange={(e) => setValeurEdit(e.target.value)}>
                  <MenuItem value="TRUE">TRUE</MenuItem>
                  <MenuItem value="FALSE">FALSE</MenuItem>
                </Select>
              </FormControl>
            ) : (
              <TextField
                label="Valeur"
                value={valeurEdit}
                size="small"
                onChange={(e) => setValeurEdit(e.target.value)}
              />
            ))}
          <TextField
            label="Description"
            value={descriptionEdit}
            multiline
            minRows={2}
            size="small"
            onChange={(e) => setDescriptionEdit(e.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEdition(null)}>Annuler</Button>
          <Button variant="contained" onClick={enregistrer}>
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

export default DefaultValuesManagement;
