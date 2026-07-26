import {
    Alert,
    Box,
    Chip,
    CircularProgress,
    Collapse,
    IconButton,
    Paper,
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableRow,
    Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import AccountTreeIcon from '@mui/icons-material/AccountTree';
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import KeyboardArrowRightIcon from '@mui/icons-material/KeyboardArrowRight';
import LayersIcon from '@mui/icons-material/Layers';
import React, { useEffect, useState } from 'react';
import api from '../services/api';

interface ModelRow {
    id: number;
    project_id: string;
    project_name: string | null;
    node_type: 'SUB_PROJECT' | 'ACTIVITY' | 'ACTIVITY_CLASS';
    sub_project_id: string | null;
    sub_project_desc: string | null;
    activity_no: string | null;
    activity_desc: string | null;
    activity_class_id: string | null;
    activity_class_desc: string | null;
    value: string | null;
    validity: string | null;
    sort_order: number | null;
}

// Couleurs : les TEXTES utilisent les tokens du thème MUI (text.primary / text.secondary)
// pour rester lisibles en thème sombre comme en clair. Les accents sont des couleurs
// vives qui ressortent sur les deux fonds :
const BLUE = '#42a5f5';    // accent principal (bleu clair, lisible sur sombre)
const BLUE_DEEP = '#0d47a1';
const AMBER = '#ffb300';   // badge id sous-projet (contraste chaud)

const bySort = (a: ModelRow, b: ModelRow) => (a.sort_order ?? 0) - (b.sort_order ?? 0);

const ModelProjectPage: React.FC = () => {
    const [rows, setRows] = useState<ModelRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [expanded, setExpanded] = useState<Record<string, boolean>>({});

    useEffect(() => {
        (async () => {
            try {
                setLoading(true);
                setError(null);
                const res = await api.get('/data/ifs-model-project');
                if (res.data?.success) setRows(res.data.data || []);
                else setError(res.data?.error || 'Erreur de chargement');
            } catch (e: any) {
                setError(e?.response?.data?.error || e?.message || 'Erreur réseau');
            } finally {
                setLoading(false);
            }
        })();
    }, []);

    const toggle = (key: string) => setExpanded((p) => ({ ...p, [key]: !p[key] }));

    const subProjects = rows.filter((r) => r.node_type === 'SUB_PROJECT').sort(bySort);
    const activitiesOf = (sub: string) =>
        rows.filter((r) => r.node_type === 'ACTIVITY' && r.sub_project_id === sub).sort(bySort);
    const classesOf = (sub: string, act: string) =>
        rows.filter(
            (r) => r.node_type === 'ACTIVITY_CLASS' && r.sub_project_id === sub && r.activity_no === act
        ).sort(bySort);

    const projectId = rows[0]?.project_id;
    const projectName = rows[0]?.project_name;
    const nbActivities = rows.filter((r) => r.node_type === 'ACTIVITY').length;
    const nbClasses = rows.filter((r) => r.node_type === 'ACTIVITY_CLASS').length;

    return (
        <Box sx={{ p: { xs: 2, md: 4 }, maxWidth: 1100, mx: 'auto' }}>
            {/* En-tête */}
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 1 }}>
                <Box
                    sx={{
                        width: 52, height: 52, borderRadius: 2, flexShrink: 0,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        color: '#fff',
                        background: `linear-gradient(135deg, ${BLUE} 0%, ${BLUE_DEEP} 100%)`,
                        boxShadow: `0 6px 18px ${alpha(BLUE, 0.4)}`,
                    }}
                >
                    <AccountTreeIcon />
                </Box>
                <Box>
                    <Typography variant="h4" sx={{ fontWeight: 800, color: 'text.primary', letterSpacing: '-0.02em' }}>
                        Projet Modèle IFS
                    </Typography>
                    <Typography variant="body2" sx={{ color: BLUE, letterSpacing: '0.05em', textTransform: 'uppercase', fontSize: 12, fontWeight: 700 }}>
                        Référence IFS Cloud{projectId ? ` · ${projectId}` : ''}
                    </Typography>
                </Box>
            </Box>

            {projectName && (
                <Typography variant="body1" sx={{ color: 'text.secondary', mb: 2, fontStyle: 'italic' }}>
                    {projectName}
                </Typography>
            )}

            {/* Résumé */}
            {!loading && !error && rows.length > 0 && (
                <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', mb: 3 }}>
                    {[
                        { label: 'sous-projets', n: subProjects.length, c: BLUE },
                        { label: 'activités', n: nbActivities, c: AMBER },
                        { label: 'activity classes', n: nbClasses, c: '#66bb6a' },
                    ].map((s) => (
                        <Box key={s.label} sx={{
                            display: 'flex', alignItems: 'baseline', gap: 0.75,
                            px: 1.5, py: 0.75, borderRadius: 2,
                            bgcolor: alpha(s.c, 0.12), border: `1px solid ${alpha(s.c, 0.4)}`,
                        }}>
                            <Typography sx={{ fontWeight: 800, color: s.c, fontSize: 18, lineHeight: 1 }}>{s.n}</Typography>
                            <Typography sx={{ color: 'text.primary', fontSize: 13 }}>{s.label}</Typography>
                        </Box>
                    ))}
                </Box>
            )}

            {loading && (
                <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}><CircularProgress /></Box>
            )}
            {error && <Alert severity="error" sx={{ my: 2 }}>{error}</Alert>}
            {!loading && !error && rows.length === 0 && (
                <Alert severity="info">Aucune donnée. Déploie d'abord la table (create_ifs_model_project.sql).</Alert>
            )}

            {/* Arbre */}
            {!loading && !error && subProjects.map((sub) => (
                <Paper
                    key={sub.id}
                    elevation={0}
                    sx={{
                        mb: 2.5, overflow: 'hidden', borderRadius: 2,
                        border: '1px solid', borderColor: 'divider',
                    }}
                >
                    {/* Bandeau sous-projet : dégradé bleu, texte blanc, badge ambre */}
                    <Box sx={{
                        display: 'flex', alignItems: 'center', gap: 1.5, px: 2, py: 1.25,
                        background: `linear-gradient(90deg, ${BLUE_DEEP} 0%, #1565c0 55%, #1e88e5 100%)`,
                    }}>
                        <LayersIcon sx={{ color: alpha('#fff', 0.85), fontSize: 20 }} />
                        <Box
                            component="span"
                            sx={{
                                fontWeight: 800, fontSize: 13, color: '#3e2723', bgcolor: AMBER,
                                px: 1, py: 0.25, borderRadius: 1, fontFamily: 'monospace', letterSpacing: '0.05em',
                            }}
                        >
                            {sub.sub_project_id}
                        </Box>
                        <Typography variant="subtitle1" sx={{ fontWeight: 700, color: '#fff' }}>
                            {sub.sub_project_desc}
                        </Typography>
                    </Box>

                    {/* Activités */}
                    <Box sx={{ p: 1 }}>
                        {activitiesOf(sub.sub_project_id!).map((act) => {
                            const classes = classesOf(sub.sub_project_id!, act.activity_no!);
                            const hasClasses = classes.length > 0;
                            const key = `${sub.sub_project_id}-${act.activity_no}`;
                            const open = !!expanded[key];
                            return (
                                <Box key={act.id}>
                                    <Box
                                        onClick={() => hasClasses && toggle(key)}
                                        sx={{
                                            display: 'flex', alignItems: 'center', gap: 1, pl: 1.5, pr: 1, py: 1,
                                            borderRadius: 1.5,
                                            cursor: hasClasses ? 'pointer' : 'default',
                                            transition: 'background-color 0.15s',
                                            '&:hover': hasClasses ? { bgcolor: 'action.hover' } : undefined,
                                        }}
                                    >
                                        {hasClasses ? (
                                            <IconButton size="small" sx={{ p: 0.25, color: BLUE }}>
                                                {open ? <KeyboardArrowDownIcon fontSize="small" /> : <KeyboardArrowRightIcon fontSize="small" />}
                                            </IconButton>
                                        ) : (
                                            <Box sx={{ width: 28 }} />
                                        )}
                                        <Box
                                            component="span"
                                            sx={{
                                                fontFamily: 'monospace', fontSize: 12.5, fontWeight: 700, color: BLUE,
                                                bgcolor: alpha(BLUE, 0.12), border: `1px solid ${alpha(BLUE, 0.35)}`,
                                                px: 0.9, py: 0.3, borderRadius: 0.75,
                                                whiteSpace: 'nowrap',
                                            }}
                                        >
                                            {act.activity_no}
                                        </Box>
                                        <Typography variant="body2" sx={{ color: 'text.primary', fontWeight: 500 }}>
                                            {act.activity_desc}
                                        </Typography>
                                        {hasClasses && (
                                            <Chip
                                                label={`${classes.length} classes`}
                                                size="small"
                                                sx={{
                                                    ml: 'auto', height: 22, fontSize: 11, fontWeight: 700,
                                                    color: AMBER, bgcolor: alpha(AMBER, 0.12),
                                                    border: `1px solid ${alpha(AMBER, 0.4)}`,
                                                }}
                                            />
                                        )}
                                    </Box>

                                    {hasClasses && (
                                        <Collapse in={open} timeout="auto" unmountOnExit>
                                            <Box sx={{ pl: 6, pr: 1.5, pb: 1.5, pt: 0.5 }}>
                                                <Table size="small">
                                                    <TableHead>
                                                        <TableRow>
                                                            {['Activity Class', 'Validity', 'Value'].map((h) => (
                                                                <TableCell key={h} sx={{
                                                                    fontWeight: 700, color: BLUE, fontSize: 11,
                                                                    textTransform: 'uppercase', letterSpacing: '0.06em',
                                                                    borderBottomColor: 'divider',
                                                                }}>{h}</TableCell>
                                                            ))}
                                                        </TableRow>
                                                    </TableHead>
                                                    <TableBody>
                                                        {classes.map((c) => (
                                                            <TableRow key={c.id}>
                                                                <TableCell sx={{ borderBottomColor: 'divider' }}>
                                                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                                                        <Box sx={{ width: 8, height: 8, borderRadius: '50%', bgcolor: AMBER, flexShrink: 0 }} />
                                                                        <Box>
                                                                            <Typography component="span" sx={{ fontWeight: 700, color: 'text.primary', fontSize: 13 }}>
                                                                                {c.activity_class_id}
                                                                            </Typography>
                                                                            {c.activity_class_desc && (
                                                                                <Typography component="span" sx={{ color: 'text.secondary', fontSize: 13 }}>
                                                                                    {' '}— {c.activity_class_desc}
                                                                                </Typography>
                                                                            )}
                                                                        </Box>
                                                                    </Box>
                                                                </TableCell>
                                                                <TableCell sx={{ borderBottomColor: 'divider' }}>
                                                                    <Chip label={c.validity || 'GLOBAL'} size="small" variant="outlined"
                                                                        sx={{ height: 20, fontSize: 11, color: 'text.secondary', borderColor: 'divider' }} />
                                                                </TableCell>
                                                                <TableCell sx={{ borderBottomColor: 'divider' }}>
                                                                    <Box component="span" sx={{
                                                                        fontFamily: 'monospace', fontSize: 12.5, fontWeight: 600, color: BLUE,
                                                                        bgcolor: alpha(BLUE, 0.10), px: 0.9, py: 0.3, borderRadius: 0.75,
                                                                        border: `1px solid ${alpha(BLUE, 0.3)}`,
                                                                    }}>
                                                                        {c.value || '—'}
                                                                    </Box>
                                                                </TableCell>
                                                            </TableRow>
                                                        ))}
                                                    </TableBody>
                                                </Table>
                                            </Box>
                                        </Collapse>
                                    )}
                                </Box>
                            );
                        })}
                    </Box>
                </Paper>
            ))}
        </Box>
    );
};

export default ModelProjectPage;
