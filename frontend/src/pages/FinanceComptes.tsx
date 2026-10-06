import {
    AccountTree as ComptesIcon,
    Add as AddIcon,
    Cached as RecalculIcon,
    Check as SaveIcon,
    Close as CancelIcon,
    Edit as EditIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Chip,
    IconButton,
    LinearProgress,
    Paper,
    Switch,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TextField,
    Tooltip,
    Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useState } from 'react';
import api from '../services/api';
import transcodificationService from '../services/transcodificationService';
import { euros, SyncAlerts, SyncStatus } from './FinanceImmobilisations';

// Onglets « Conversion cpte général » et « TRansco comptes generaux » du classeur
// métier, réunis : la conversion est la transcodification FA_ACCOUNT (SAP -> IFS),
// les comptes des fiches viennent de clean_data.immobilisation.

interface Conversion {
  id: number;
  compte_sap: string;
  pcg_fr: string | null;
  compte_ifs: string;
  libelle: string;
  is_active: boolean;
}

interface CompteFiche {
  role: 'immobilisation' | 'amortissement';
  compte_sap: string;
  compte_ifs: string | null;
  nb_fiches: number;
  nb_reprises: number;
  acquisition: number | null;
  amortissements: number | null;
  vnc: number | null;
}

interface ComptesResponse {
  conversion: Conversion[];
  fiches: CompteFiche[];
  sync: SyncStatus | null;
}

type Brouillon = { compte_sap: string; pcg_fr: string; compte_ifs: string; libelle: string };

const vide: Brouillon = { compte_sap: '', pcg_fr: '', compte_ifs: '', libelle: '' };

// Description stockée dans TranscodificationTable : « LIBELLE (PCG FR nnn) »
const description = (b: Brouillon) =>
  `${b.libelle.trim()}${b.pcg_fr.trim() ? ` (PCG FR ${b.pcg_fr.trim()})` : ''}`;

const FinanceComptes: React.FC = () => {
  const [data, setData] = useState<ComptesResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [sync, setSync] = useState<SyncStatus | null>(null);
  const [edition, setEdition] = useState<number | 'nouveau' | null>(null);
  const [brouillon, setBrouillon] = useState<Brouillon>(vide);

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.get<ComptesResponse>('/finance/comptes');
      setData(res.data);
      setSync(res.data.sync);
    } catch (err) {
      console.error('Erreur chargement comptes:', err);
      setError('Erreur lors du chargement des comptes');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (sync?.status !== 'running') return undefined;
    const timer = setInterval(async () => {
      try {
        const res = await api.get<SyncStatus>('/finance/immobilisations/sync');
        setSync(res.data);
        if (res.data.status !== 'running') load();
      } catch (err) {
        console.error('Erreur statut rechargement:', err);
      }
    }, 5000);
    return () => clearInterval(timer);
  }, [sync?.status, load]);

  const commencer = (c?: Conversion, compteSap?: string) => {
    setEdition(c ? c.id : 'nouveau');
    setBrouillon(c
      ? { compte_sap: c.compte_sap, pcg_fr: c.pcg_fr ?? '', compte_ifs: c.compte_ifs, libelle: c.libelle }
      : { ...vide, compte_sap: compteSap ?? '' });
    setInfo(null);
  };

  const enregistrer = async () => {
    if (!brouillon.compte_sap.trim() || !brouillon.compte_ifs.trim()) {
      setError('Le compte SAP et le compte IFS sont obligatoires');
      return;
    }
    try {
      setError(null);
      const payload = {
        category: 'FA_ACCOUNT',
        source_system: 'SAP',
        target_system: 'IFS',
        source_value: brouillon.compte_sap.trim(),
        target_value: brouillon.compte_ifs.trim(),
        description: description(brouillon),
        is_active: true,
      };
      if (edition === 'nouveau') {
        await transcodificationService.createTranscodification(payload);
      } else if (edition !== null) {
        await transcodificationService.updateTranscodification(edition, payload);
      }
      setEdition(null);
      setInfo('Conversion enregistrée. Cliquez « Recalculer » pour l\'appliquer aux fiches (vue Travail, export).');
      await load();
    } catch (err: any) {
      console.error('Erreur enregistrement conversion:', err);
      setError(err?.response?.status === 409 ? 'Ce compte SAP a déjà une conversion' : "Erreur lors de l'enregistrement");
    }
  };

  const basculerActif = async (c: Conversion) => {
    try {
      await transcodificationService.updateTranscodification(c.id, { is_active: !c.is_active });
      await load();
    } catch (err) {
      console.error('Erreur activation conversion:', err);
      setError("Erreur lors de l'activation");
    }
  };

  const recalculer = async () => {
    try {
      setError(null);
      const res = await api.post<SyncStatus>('/finance/immobilisations/sync', { source: 'mf' });
      setSync(res.data);
    } catch (err: any) {
      if (err?.response?.status === 409) setSync(err.response.data);
      else setError('Impossible de lancer le rechargement');
    }
  };

  const running = sync?.status === 'running';
  const manquants = data?.fiches.filter((f) => !f.compte_ifs) ?? [];
  const champ = (k: keyof Brouillon, largeur: number, placeholder?: string) => (
    <TextField
      size="small"
      value={brouillon[k]}
      placeholder={placeholder}
      onChange={(e) => setBrouillon({ ...brouillon, [k]: e.target.value })}
      sx={{ width: largeur }}
    />
  );
  const ligneEdition = (
    <TableRow key="edition" sx={{ bgcolor: 'action.hover' }}>
      <TableCell>{champ('compte_sap', 120, 'PCG US SAP')}</TableCell>
      <TableCell>{champ('pcg_fr', 120, 'PCG FR SAP')}</TableCell>
      <TableCell>{champ('compte_ifs', 110, 'PCG IFS')}</TableCell>
      <TableCell>{champ('libelle', 360, 'Libellé')}</TableCell>
      <TableCell />
      <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
        <IconButton color="primary" onClick={enregistrer} title="Enregistrer"><SaveIcon /></IconButton>
        <IconButton onClick={() => setEdition(null)} title="Annuler"><CancelIcon /></IconButton>
      </TableCell>
    </TableRow>
  );

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2, gap: 2, flexWrap: 'wrap' }}>
        <ComptesIcon sx={{ fontSize: 32, color: '#5d4037' }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Comptes des immobilisations
        </Typography>
        <Box sx={{ ml: 'auto', display: 'flex', gap: 1 }}>
          <Tooltip title="Recharge clean_data.immobilisation depuis les tables SAP déjà extraites, avec les conversions ci-dessous (sans appeler SAP)">
            <span>
              <Button variant="contained" startIcon={<RecalculIcon />} onClick={recalculer} disabled={running}>
                {running ? 'Rechargement…' : 'Recalculer les immobilisations'}
              </Button>
            </span>
          </Tooltip>
        </Box>
      </Box>

      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Conversion des comptes généraux PCG SAP vers IFS (transcodification FA_ACCOUNT, aussi visible dans Configuration &gt; Transcodification)
        et comptes réellement portés par les fiches immobilisations. Un compte de fiche sans conversion sort à vide dans la reprise IFS.
      </Typography>

      <SyncAlerts sync={sync} />
      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}
      {info && <Alert severity="success" sx={{ mb: 2 }} onClose={() => setInfo(null)}>{info}</Alert>}
      {manquants.length > 0 && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          {manquants.length} compte(s) de fiches sans conversion IFS : {manquants.map((m) => m.compte_sap).join(', ')}.
        </Alert>
      )}
      {loading && <LinearProgress sx={{ mb: 2 }} />}

      <Typography variant="h6" sx={{ mb: 1 }}>Conversion cpte général</Typography>
      <TableContainer component={Paper} sx={{ mb: 3 }}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell sx={{ fontWeight: 600 }}>PCG US SAP</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>PCG FR SAP</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>PCG IFS</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Libellé</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Actif</TableCell>
              <TableCell align="right">
                <Button size="small" startIcon={<AddIcon />} onClick={() => commencer()} disabled={edition !== null}>
                  Ajouter
                </Button>
              </TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {edition === 'nouveau' && ligneEdition}
            {data?.conversion.map((c) => (edition === c.id ? ligneEdition : (
              <TableRow key={c.id} hover sx={c.is_active ? undefined : { '& td': { color: 'text.disabled' } }}>
                <TableCell>{c.compte_sap}</TableCell>
                <TableCell>{c.pcg_fr ?? ''}</TableCell>
                <TableCell>{c.compte_ifs}</TableCell>
                <TableCell>{c.libelle}</TableCell>
                <TableCell><Switch size="small" checked={c.is_active} onChange={() => basculerActif(c)} /></TableCell>
                <TableCell align="right">
                  <IconButton size="small" onClick={() => commencer(c)} disabled={edition !== null} title="Modifier"><EditIcon fontSize="small" /></IconButton>
                </TableCell>
              </TableRow>
            )))}
          </TableBody>
        </Table>
      </TableContainer>

      <Typography variant="h6" sx={{ mb: 1 }}>TRansco comptes généraux des fiches</Typography>
      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell sx={{ fontWeight: 600 }}>Rôle</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Cpt fiche (SAP)</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Nv cpte fiche (IFS)</TableCell>
              <TableCell align="right" sx={{ fontWeight: 600 }}>Fiches</TableCell>
              <TableCell align="right" sx={{ fontWeight: 600 }}>À reprendre</TableCell>
              <TableCell align="right" sx={{ fontWeight: 600 }}>Acquisition</TableCell>
              <TableCell align="right" sx={{ fontWeight: 600 }}>Amortissements cumulés</TableCell>
              <TableCell align="right" sx={{ fontWeight: 600 }}>VNC</TableCell>
              <TableCell />
            </TableRow>
          </TableHead>
          <TableBody>
            {data?.fiches.map((f) => (
              <TableRow key={`${f.role}-${f.compte_sap}`} hover>
                <TableCell>{f.role === 'immobilisation' ? 'Compte immobilisation' : 'Compte amortissement cumulé'}</TableCell>
                <TableCell>{f.compte_sap}</TableCell>
                <TableCell>
                  {f.compte_ifs ?? <Chip size="small" color="warning" label="sans conversion" />}
                </TableCell>
                <TableCell align="right">{f.nb_fiches.toLocaleString('fr-FR')}</TableCell>
                <TableCell align="right">{f.nb_reprises.toLocaleString('fr-FR')}</TableCell>
                <TableCell align="right">{euros(f.acquisition)}</TableCell>
                <TableCell align="right">{euros(f.amortissements)}</TableCell>
                <TableCell align="right">{euros(f.vnc)}</TableCell>
                <TableCell align="right">
                  {!f.compte_ifs && (
                    <Button size="small" startIcon={<AddIcon />} onClick={() => commencer(undefined, f.compte_sap)} disabled={edition !== null}>
                      Convertir
                    </Button>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
};

export default FinanceComptes;
