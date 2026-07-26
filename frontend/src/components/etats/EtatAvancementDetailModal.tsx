import {
    Alert,
    Box,
    Chip,
    CircularProgress,
    Collapse,
    Dialog,
    DialogContent,
    DialogTitle,
    Divider,
    IconButton,
    Paper,
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableRow,
    Typography,
} from '@mui/material';
import CloseIcon from '@mui/icons-material/Close';
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp';
import React, { useEffect, useState } from 'react';
import api from '../../services/api';

interface EtatRaw {
    sharepoint_id: number;
    title: string;
    status_date: string | null;
    percent_completed: number | null;
    global_status: string | null;
    health: string | null;
    planning: string | null;
    cost: string | null;
    update_text: string | null;
    current_phase_id: number | null;
    end_project_mark: string | null;
    site_id: string;
    guid: string;
}

interface JalonRow {
    sharepoint_id: number;
    title: string;
    gate: string | null;
    mark: string | null;
    ranking: string | null;
    actual: string | null;
    baseline: string | null;
    forecast: string | null;
    milestone_id: number | null;
    jalon_label: string | null;
    raw_data: Record<string, any>;
}

interface ChildRow {
    sharepoint_id: number;
    title: string;
    raw_data: Record<string, any>;
}

interface HistRow {
    etat_id: number;
    status_date: string | null;
    mark: string | null;
    ranking: string | null;
    actual: string | null;
    baseline: string | null;
    forecast: string | null;
}

interface DetailData {
    etat: EtatRaw;
    phase_label: string | null;
    jalons: JalonRow[];
    cfv: ChildRow[];
    couts: ChildRow[];
}

interface Props {
    open: boolean;
    siteId: string;
    etatId: number | null;
    onClose: () => void;
}

const formatDate = (d?: string | null) => {
    if (!d) return '';
    const date = new Date(d);
    if (isNaN(date.getTime())) return d;
    return date.toLocaleDateString('fr-FR');
};

const formatNumber = (v: any) => {
    if (v === null || v === undefined || v === '') return '';
    const n = typeof v === 'string' ? parseFloat(v) : v;
    if (isNaN(n)) return String(v);
    return n.toLocaleString('fr-FR', { maximumFractionDigits: 2 });
};

const stripHtml = (html: string | null) => (html || '').replace(/<[^>]+>/g, '').trim();

const Field: React.FC<{ label: string; children?: React.ReactNode }> = ({ label, children }) => (
    <Box sx={{ display: 'flex', borderBottom: '1px solid #eee', py: 1 }}>
        <Box sx={{ width: 180, color: 'text.secondary', fontSize: 14, pr: 2 }}>{label}</Box>
        <Box sx={{ flex: 1, fontSize: 14 }}>{children || <Typography variant="body2" color="text.disabled">—</Typography>}</Box>
    </Box>
);

const DetailKV: React.FC<{ label: string; value?: React.ReactNode }> = ({ label, value }) => (
    <Box sx={{ minWidth: 140 }}>
        <Typography variant="caption" color="text.secondary" display="block">{label}</Typography>
        <Typography variant="body2">{value || '—'}</Typography>
    </Box>
);

const EtatAvancementDetailModal: React.FC<Props> = ({ open, siteId, etatId, onClose }) => {
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [data, setData] = useState<DetailData | null>(null);
    // Porte dépliée (sharepoint_id du jalon) + cache/chargement de l'historique par milestone
    const [expandedJalon, setExpandedJalon] = useState<number | null>(null);
    const [histByMilestone, setHistByMilestone] = useState<Record<number, HistRow[]>>({});
    const [histLoading, setHistLoading] = useState<number | null>(null);

    const toggleJalon = async (jalon: JalonRow) => {
        // Referme si on reclique la même porte
        if (expandedJalon === jalon.sharepoint_id) {
            setExpandedJalon(null);
            return;
        }
        setExpandedJalon(jalon.sharepoint_id);
        // Charge l'historique (par milestone) si pas déjà en cache
        const mid = jalon.milestone_id;
        if (mid != null && histByMilestone[mid] === undefined) {
            setHistLoading(mid);
            try {
                const res = await api.get(`/data/etats-avancement/${siteId}/jalon/${mid}/historique`);
                setHistByMilestone((prev) => ({ ...prev, [mid]: res.data?.data || [] }));
            } catch {
                setHistByMilestone((prev) => ({ ...prev, [mid]: [] }));
            } finally {
                setHistLoading(null);
            }
        }
    };

    useEffect(() => {
        if (open && etatId !== null) {
            load();
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [open, etatId, siteId]);

    const load = async () => {
        setLoading(true);
        setError(null);
        setData(null);
        setExpandedJalon(null);
        try {
            const res = await api.get(`/data/etats-avancement/${siteId}/${etatId}/detail`);
            if (res.data?.success) setData(res.data.data);
            else setError(res.data?.error || 'Erreur de chargement');
        } catch (e: any) {
            setError(e?.response?.data?.error || e?.message || 'Erreur réseau');
        } finally {
            setLoading(false);
        }
    };

    const totalBudgetSap = data?.etat.raw_data?.['Total_x0020_Budget_x0020_SAP']
        ?? data?.etat.raw_data?.['TotalBudgetSAP']
        ?? null;

    return (
        <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth scroll="paper">
            <DialogTitle sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', bgcolor: '#1976d2', color: 'white' }}>
                État d'avancement
                <IconButton onClick={onClose} sx={{ color: 'white' }} size="small">
                    <CloseIcon />
                </IconButton>
            </DialogTitle>
            <DialogContent dividers>
                {loading && (
                    <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
                        <CircularProgress />
                    </Box>
                )}
                {error && <Alert severity="error" sx={{ my: 2 }}>{error}</Alert>}
                {data && (
                    <Box>
                        {/* Bloc principal */}
                        <Field label="Date de l'état">{formatDate(data.etat.status_date)}</Field>
                        <Field label="% Complété">
                            {data.etat.percent_completed != null
                                ? `${Math.round(data.etat.percent_completed * 100)}%`
                                : null}
                        </Field>
                        <Field label="Mise à jour">
                            {data.etat.update_text
                                ? <Box sx={{ whiteSpace: 'pre-wrap' }}>{stripHtml(data.etat.update_text)}</Box>
                                : null}
                        </Field>
                        <Field label="Statut santé projet">
                            {data.etat.health && <Chip label={data.etat.health} size="small" />}
                        </Field>
                        <Field label="Phase courante">{data.phase_label || (data.etat.current_phase_id ? `#${data.etat.current_phase_id}` : null)}</Field>

                        {/* Jalons */}
                        <Box sx={{ display: 'flex', borderBottom: '1px solid #eee', py: 1 }}>
                            <Box sx={{ width: 180, color: 'text.secondary', fontSize: 14, pr: 2 }}>Jalons</Box>
                            <Box sx={{ flex: 1 }}>
                                <Table size="small">
                                    <TableHead sx={{ bgcolor: '#e3f2fd' }}>
                                        <TableRow>
                                            <TableCell sx={{ width: 40 }} />
                                            <TableCell sx={{ fontWeight: 600 }}>Jalon</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }}>Porte</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }} align="right">Note</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }}>Classement</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }}>Date de début</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }}>Fin / Échéance</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {data.jalons.length === 0 ? (
                                            <TableRow><TableCell colSpan={7} align="center" sx={{ color: 'text.disabled' }}>Aucun jalon</TableCell></TableRow>
                                        ) : data.jalons.map((j) => {
                                            const isOpen = expandedJalon === j.sharepoint_id;
                                            const hist = j.milestone_id != null ? histByMilestone[j.milestone_id] : undefined;
                                            return (
                                            <React.Fragment key={j.sharepoint_id}>
                                                <TableRow hover onClick={() => toggleJalon(j)} sx={{ cursor: 'pointer', '& > td': { borderBottom: isOpen ? 'unset' : undefined } }}>
                                                    <TableCell>
                                                        <IconButton size="small">
                                                            {isOpen ? <KeyboardArrowUpIcon fontSize="small" /> : <KeyboardArrowDownIcon fontSize="small" />}
                                                        </IconButton>
                                                    </TableCell>
                                                    <TableCell>{j.gate || j.jalon_label || '—'}</TableCell>
                                                    <TableCell>{j.jalon_label || ''}</TableCell>
                                                    <TableCell align="right">{formatNumber(j.mark)}</TableCell>
                                                    <TableCell>{j.ranking || ''}</TableCell>
                                                    <TableCell>{formatDate(j.actual || j.baseline)}</TableCell>
                                                    <TableCell>{formatDate(j.forecast || j.baseline)}</TableCell>
                                                </TableRow>
                                                <TableRow>
                                                    <TableCell colSpan={7} sx={{ py: 0, borderBottom: isOpen ? undefined : 'none' }}>
                                                        <Collapse in={isOpen} timeout="auto" unmountOnExit>
                                                            <Box sx={{ m: 1, p: 2, bgcolor: '#fafafa', borderRadius: 1 }}>
                                                                <Typography variant="subtitle2" gutterBottom>
                                                                    Détail de la porte {j.jalon_label || j.gate}
                                                                </Typography>
                                                                <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 2, mb: 2 }}>
                                                                    <DetailKV label="Porte (référentiel)" value={j.jalon_label} />
                                                                    <DetailKV label="Gate" value={j.gate} />
                                                                    <DetailKV label="Note" value={formatNumber(j.mark)} />
                                                                    <DetailKV label="Classement" value={j.ranking} />
                                                                    <DetailKV label="Date réalisée" value={formatDate(j.actual)} />
                                                                    <DetailKV label="Baseline" value={formatDate(j.baseline)} />
                                                                    <DetailKV label="Prévue" value={formatDate(j.forecast)} />
                                                                    <DetailKV label="Milestone" value={j.milestone_id != null ? String(j.milestone_id) : null} />
                                                                </Box>
                                                                <Typography variant="caption" color="text.secondary">Historique à travers les états</Typography>
                                                                {histLoading === j.milestone_id ? (
                                                                    <Box sx={{ py: 1 }}><CircularProgress size={18} /></Box>
                                                                ) : (hist && hist.length > 0) ? (
                                                                    <Table size="small" sx={{ mt: 0.5 }}>
                                                                        <TableHead>
                                                                            <TableRow>
                                                                                <TableCell sx={{ fontWeight: 600 }}>Date état</TableCell>
                                                                                <TableCell sx={{ fontWeight: 600 }} align="right">Note</TableCell>
                                                                                <TableCell sx={{ fontWeight: 600 }}>Classement</TableCell>
                                                                                <TableCell sx={{ fontWeight: 600 }}>Date réalisée</TableCell>
                                                                            </TableRow>
                                                                        </TableHead>
                                                                        <TableBody>
                                                                            {hist.map((h) => (
                                                                                <TableRow key={h.etat_id}>
                                                                                    <TableCell>{formatDate(h.status_date)}</TableCell>
                                                                                    <TableCell align="right">{formatNumber(h.mark)}</TableCell>
                                                                                    <TableCell>{h.ranking || ''}</TableCell>
                                                                                    <TableCell>{formatDate(h.actual || h.forecast || h.baseline)}</TableCell>
                                                                                </TableRow>
                                                                            ))}
                                                                        </TableBody>
                                                                    </Table>
                                                                ) : (
                                                                    <Typography variant="body2" color="text.disabled" sx={{ py: 1 }}>
                                                                        {j.milestone_id == null ? 'Pas de milestone lié' : 'Aucun historique'}
                                                                    </Typography>
                                                                )}
                                                            </Box>
                                                        </Collapse>
                                                    </TableCell>
                                                </TableRow>
                                            </React.Fragment>
                                            );
                                        })}
                                    </TableBody>
                                </Table>
                            </Box>
                        </Box>

                        {/* Commissions Feu Vert */}
                        <Box sx={{ display: 'flex', borderBottom: '1px solid #eee', py: 1 }}>
                            <Box sx={{ width: 180, color: 'text.secondary', fontSize: 14, pr: 2 }}>Commissions Feu Vert</Box>
                            <Box sx={{ flex: 1 }}>
                                <Table size="small">
                                    <TableHead sx={{ bgcolor: '#e3f2fd' }}>
                                        <TableRow>
                                            <TableCell sx={{ fontWeight: 600 }}>Phase</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }}>État</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }}>Date</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {data.cfv.length === 0 ? (
                                            <TableRow><TableCell colSpan={3} align="center" sx={{ color: 'text.disabled' }}>Aucune commission</TableCell></TableRow>
                                        ) : data.cfv.map((c) => {
                                            const r = c.raw_data || {};
                                            const phase = r.Phase || r.Title || c.title;
                                            const etat = r.Status || r.Etat || r.State;
                                            const date = r.Date || r.Actual || r.Forecast;
                                            return (
                                                <TableRow key={c.sharepoint_id}>
                                                    <TableCell>{phase}</TableCell>
                                                    <TableCell>{etat}</TableCell>
                                                    <TableCell>{formatDate(date)}</TableCell>
                                                </TableRow>
                                            );
                                        })}
                                    </TableBody>
                                </Table>
                            </Box>
                        </Box>

                        <Field label="Note de fin de projet">{data.etat.end_project_mark}</Field>
                        <Field label="Statut planning projet">
                            {data.etat.planning && <Chip label={data.etat.planning} size="small" />}
                        </Field>

                        {/* Coûts */}
                        <Box sx={{ display: 'flex', borderBottom: '1px solid #eee', py: 1 }}>
                            <Box sx={{ width: 180, color: 'text.secondary', fontSize: 14, pr: 2 }}>Coûts</Box>
                            <Box sx={{ flex: 1 }}>
                                {totalBudgetSap != null && (
                                    <Typography variant="body2" sx={{ mb: 1 }}>
                                        Budget total SAP du projet : <strong>{formatNumber(totalBudgetSap)} €</strong>
                                    </Typography>
                                )}
                                <Table size="small">
                                    <TableHead sx={{ bgcolor: '#e3f2fd' }}>
                                        <TableRow>
                                            <TableCell sx={{ fontWeight: 600 }}>WBS</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }} align="right">Budget</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }} align="right">Engagé</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }} align="right">Réceptionné</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }} align="right">Reste à engager</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {data.couts.length === 0 ? (
                                            <TableRow><TableCell colSpan={5} align="center" sx={{ color: 'text.disabled' }}>Aucun coût</TableCell></TableRow>
                                        ) : data.couts.map((c) => {
                                            const r = c.raw_data || {};
                                            const wbs = r.WBS || r.WBSCode || r.Code || c.title;
                                            const budget = r.Budget || r.Budgeted;
                                            const engaged = r.Engaged || r.Engage || r.Engagé;
                                            const received = r.Received || r.Receptionne || r.Réceptionné;
                                            const remaining = r.Remaining || r.RemainingToCommit || r.ResteAEngager;
                                            return (
                                                <TableRow key={c.sharepoint_id}>
                                                    <TableCell>{wbs}</TableCell>
                                                    <TableCell align="right">{formatNumber(budget)}</TableCell>
                                                    <TableCell align="right">{formatNumber(engaged)}</TableCell>
                                                    <TableCell align="right">{formatNumber(received)}</TableCell>
                                                    <TableCell align="right">{formatNumber(remaining)}</TableCell>
                                                </TableRow>
                                            );
                                        })}
                                    </TableBody>
                                </Table>
                            </Box>
                        </Box>

                        <Field label="État des coûts projet">
                            {data.etat.cost && <Chip label={data.etat.cost} size="small" />}
                        </Field>
                        <Field label="Statut Global">
                            {data.etat.global_status && <Chip label={data.etat.global_status} size="small" color="primary" />}
                        </Field>

                        <Divider sx={{ my: 2 }} />
                        <Typography variant="caption" color="text.disabled">
                            Site {data.etat.site_id} · État #{data.etat.sharepoint_id} · GUID {data.etat.guid}
                        </Typography>
                    </Box>
                )}
            </DialogContent>
        </Dialog>
    );
};

export default EtatAvancementDetailModal;
