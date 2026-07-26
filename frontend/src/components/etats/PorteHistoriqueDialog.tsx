import {
    Alert,
    Box,
    CircularProgress,
    Dialog,
    DialogContent,
    DialogTitle,
    IconButton,
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableRow,
    Typography,
} from '@mui/material';
import CloseIcon from '@mui/icons-material/Close';
import React, { useEffect, useState } from 'react';
import api from '../../services/api';

interface HistRow {
    etat_id: number;
    status_date: string | null;
    milestone_id: number | null;
    jalon_label: string | null;
    mark: string | null;
    ranking: string | null;
    actual: string | null;
    baseline: string | null;
    forecast: string | null;
}

interface Props {
    open: boolean;
    siteId: string | number;
    gate: string | null;
    onClose: () => void;
}

const formatDate = (d?: string | null) => {
    if (!d) return '';
    const x = new Date(d);
    return isNaN(x.getTime()) ? d : x.toLocaleDateString('fr-FR');
};

const formatNumber = (v: any) => {
    if (v === null || v === undefined || v === '') return '';
    const n = typeof v === 'string' ? parseFloat(v) : v;
    return isNaN(n) ? String(v) : n.toLocaleString('fr-FR', { maximumFractionDigits: 2 });
};

/**
 * Historique d'une porte (Gate) à travers tous les états d'avancement du projet.
 * Ouvert au clic sur une carte de porte (onglet Jalons).
 */
const PorteHistoriqueDialog: React.FC<Props> = ({ open, siteId, gate, onClose }) => {
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [rows, setRows] = useState<HistRow[]>([]);

    useEffect(() => {
        if (open && gate) load();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [open, gate, siteId]);

    const load = async () => {
        setLoading(true);
        setError(null);
        setRows([]);
        try {
            const res = await api.get(`/data/projets/${siteId}/porte/${gate}/historique`);
            if (res.data?.success) setRows(res.data.data || []);
            else setError(res.data?.error || 'Erreur de chargement');
        } catch (e: any) {
            setError(e?.response?.data?.error || e?.message || 'Erreur réseau');
        } finally {
            setLoading(false);
        }
    };

    return (
        <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth scroll="paper">
            <DialogTitle sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', bgcolor: '#1976d2', color: 'white' }}>
                Porte {gate} — historique
                <IconButton onClick={onClose} sx={{ color: 'white' }} size="small">
                    <CloseIcon />
                </IconButton>
            </DialogTitle>
            <DialogContent dividers>
                {loading && (
                    <Box sx={{ display: 'flex', justifyContent: 'center', py: 3 }}>
                        <CircularProgress />
                    </Box>
                )}
                {error && <Alert severity="error" sx={{ my: 2 }}>{error}</Alert>}
                {!loading && !error && (
                    rows.length === 0 ? (
                        <Typography color="text.disabled" sx={{ py: 2 }}>
                            Aucun historique pour cette porte
                        </Typography>
                    ) : (
                        <Table size="small">
                            <TableHead sx={{ bgcolor: '#e3f2fd' }}>
                                <TableRow>
                                    <TableCell sx={{ fontWeight: 600 }}>Date état</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Jalon</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }} align="right">Note</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Classement</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Date réalisée</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {rows.map((h, i) => (
                                    <TableRow key={`${h.etat_id}-${h.milestone_id ?? 'x'}-${i}`}>
                                        <TableCell>{formatDate(h.status_date)}</TableCell>
                                        <TableCell>{h.jalon_label || gate}</TableCell>
                                        <TableCell align="right">{formatNumber(h.mark)}</TableCell>
                                        <TableCell>{h.ranking || ''}</TableCell>
                                        <TableCell>{formatDate(h.actual || h.forecast || h.baseline)}</TableCell>
                                    </TableRow>
                                ))}
                            </TableBody>
                        </Table>
                    )
                )}
            </DialogContent>
        </Dialog>
    );
};

export default PorteHistoriqueDialog;
