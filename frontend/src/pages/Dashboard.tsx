import {
  ArrowDownward as BaisseIcon,
  ArrowUpward as HausseIcon,
  Cached as RecalculIcon,
  CheckCircleOutline as OkIcon,
  ErrorOutline as ErreurIcon,
  OpenInNew as OuvrirIcon,
} from '@mui/icons-material';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Grid,
  IconButton,
  List,
  ListItem,
  ListItemButton,
  ListItemText,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Tooltip as MuiTooltip,
  Typography,
  useTheme,
} from '@mui/material';
import {
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  Legend,
  LinearScale,
  LineElement,
  PointElement,
  Tooltip,
} from 'chart.js';
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Bar, Line } from 'react-chartjs-2';
import { Link as RouterLink } from 'react-router-dom';
import api from '../services/api';

// Tableau de bord branché sur /api/v1/dashboard (api/dashboard.py).
ChartJS.register(BarElement, CategoryScale, Legend, LinearScale, LineElement, PointElement, Tooltip);

interface Domaine {
  cle: string;
  label: string;
  url: string;
  avec_controles: boolean;
  tables: number;
  tables_remplies: number;
  lignes: number;
  dernier_chargement: { date: string; statut: string } | null;
  controles?: number;
  ko?: number;
  en_erreur?: number;
  anomalies?: number;
  delta_precedent?: number | null;
  delta_7j?: number | null;
  principale?: { label: string; n: number } | null;
}

interface Synthese {
  calcul: { en_cours: boolean; calcule_le: string | null; premier_jour: string | null };
  domaines: Domaine[];
  a_traiter: { ecran: string; code: string; label: string; n: number; delta: number | null; domaine: string; url: string }[];
  historique: { jour: string; ecran: string; ko: number; anomalies: number }[];
  extractions: {
    jobs_30j: number;
    statuts_30j: Record<string, number>;
    par_mois: ({ mois: string } & Record<string, number | string>)[];
    dernier_etat: Record<string, number>;
    echecs: { table: string; date: string | null; erreur: string }[];
  };
  maintenance: { statut: string; date: string | null; erreur: string | null } | null;
}

interface SerieControle { code: string; label: string; points: { jour: string; n: number | null }[] }
interface HistoriqueEcran { series: SerieControle[]; masques: number }
interface Courbe { label: string; data: (number | null)[]; color: string }

// Palette validée sur le fond des cartes (#2c3649) : la couleur suit le domaine, jamais son rang.
const CATEGORIES = ['#3987e5', '#d95926', '#199e70', '#c98500', '#d55181', '#0ca30c', '#9085e9', '#e66767'];
const COULEUR_DOMAINE: Record<string, string> = {
  fournisseurs: CATEGORIES[0],
  clients: CATEGORIES[1],
  articles: CATEGORIES[2],
  structure: CATEGORIES[3],
  projets: CATEGORIES[4],
  pm_actions: CATEGORIES[5],
  operations: CATEGORIES[6],
  ressources: CATEGORIES[7],
};
const STATUT_BON = '#0ca30c';
const STATUT_CRITIQUE = '#d03b3b';
const STATUTS_EXTRACTION: { cle: string; label: string; color: string }[] = [
  { cle: 'reussie', label: 'Réussies', color: STATUT_BON },
  { cle: 'avec_erreurs', label: 'Avec erreurs', color: '#fab219' },
  { cle: 'en_cours', label: 'En cours', color: '#3987e5' },
  { cle: 'annulee', label: 'Annulées', color: '#898781' },
  { cle: 'interrompue', label: 'Interrompues', color: '#ec835a' },
  { cle: 'echec', label: 'En échec', color: STATUT_CRITIQUE },
];
const GRILLE = 'rgba(255, 255, 255, 0.08)';

const nombre = (v: number) => v.toLocaleString('fr-FR');
const dateHeure = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' }) : '—');
const jourCourt = (jour: string) => `${jour.slice(8, 10)}/${jour.slice(5, 7)}`;
const moisCourt = (mois: string) =>
  new Date(`${mois}-15T12:00:00`).toLocaleDateString('fr-FR', { month: 'short', year: '2-digit' });

const age = (iso: string | null) => {
  if (!iso) return 'jamais calculés';
  const minutes = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
  if (minutes < 1) return "calculés à l'instant";
  if (minutes < 60) return `calculés il y a ${minutes} min`;
  return `calculés le ${dateHeure(iso)}`;
};

// Tous les jours entre deux dates : un jour sans mesure reste un trou et garde sa place sur l'axe.
const joursEntre = (debut: string, fin: string) => {
  const jours: string[] = [];
  const courant = new Date(`${debut}T00:00:00Z`);
  const dernier = new Date(`${fin}T00:00:00Z`);
  while (courant <= dernier) {
    jours.push(courant.toISOString().slice(0, 10));
    courant.setUTCDate(courant.getUTCDate() + 1);
  }
  return jours;
};

const Ecart: React.FC<{ valeur?: number | null }> = ({ valeur }) => {
  if (valeur == null) return <Typography component="span" variant="body2" color="text.secondary">—</Typography>;
  if (valeur === 0) return <Typography component="span" variant="body2" color="text.secondary">=</Typography>;
  const hausse = valeur > 0;
  const Icone = hausse ? HausseIcon : BaisseIcon;
  return (
    <Box component="span" sx={{ display: 'inline-flex', alignItems: 'center', gap: 0.25, color: hausse ? 'error.light' : 'secondary.main', whiteSpace: 'nowrap' }}>
      <Icone sx={{ fontSize: 14 }} aria-label={hausse ? 'en hausse' : 'en baisse'} />
      <Typography component="span" variant="body2" sx={{ fontVariantNumeric: 'tabular-nums' }}>{nombre(Math.abs(valeur))}</Typography>
    </Box>
  );
};

const Tuile: React.FC<{ titre: string; valeur: React.ReactNode; detail: React.ReactNode }> = ({ titre, valeur, detail }) => (
  <Card sx={{ height: '100%' }}>
    <CardContent>
      <Typography variant="body2" color="text.secondary" gutterBottom>{titre}</Typography>
      <Typography variant="h4" component="div" sx={{ mb: 0.5, textTransform: 'none' }}>{valeur}</Typography>
      <Typography variant="body2" color="text.secondary" component="div">{detail}</Typography>
    </CardContent>
  </Card>
);

// Graphique et son équivalent en tableau : aucune valeur n'est lisible seulement au survol.
const Graphique: React.FC<{
  titre: string;
  sousTitre?: React.ReactNode;
  action?: React.ReactNode;
  type: 'bar' | 'line';
  labels: string[];
  courbes: Courbe[];
  libelleLigne: string;
}> = ({ titre, sousTitre, action, type, labels, courbes, libelleLigne }) => {
  const theme = useTheme();
  const [enTableau, setEnTableau] = useState(false);
  const surface = theme.palette.background.paper;
  const texte = theme.palette.text.secondary;

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    interaction: { mode: 'index' as const, intersect: false },
    plugins: {
      legend: { position: 'bottom' as const, labels: { color: texte, usePointStyle: true, boxHeight: 8, padding: 14 } },
    },
    scales: {
      x: { stacked: type === 'bar', grid: { display: false }, ticks: { color: texte, maxRotation: 0, autoSkipPadding: 16 } },
      y: { stacked: type === 'bar', beginAtZero: true, grid: { color: GRILLE }, border: { display: false }, ticks: { color: texte, precision: 0 } },
    },
  };

  return (
    <Card sx={{ height: '100%' }}>
      <CardContent>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 1, mb: 1 }}>
          <Box>
            <Typography variant="h6">{titre}</Typography>
            {sousTitre && <Typography variant="body2" color="text.secondary">{sousTitre}</Typography>}
          </Box>
          <Box sx={{ display: 'flex', gap: 1, flexShrink: 0 }}>
            {action}
            <Button size="small" onClick={() => setEnTableau((v) => !v)}>{enTableau ? 'Graphique' : 'Tableau'}</Button>
          </Box>
        </Box>
        {enTableau ? (
          <TableContainer sx={{ maxHeight: 300 }}>
            <Table size="small" stickyHeader>
              <TableHead>
                <TableRow>
                  <TableCell>{libelleLigne}</TableCell>
                  {courbes.map((c) => <TableCell key={c.label} align="right">{c.label}</TableCell>)}
                </TableRow>
              </TableHead>
              <TableBody>
                {labels.map((l, i) => (
                  <TableRow key={l}>
                    <TableCell>{l}</TableCell>
                    {courbes.map((c) => (
                      <TableCell key={c.label} align="right" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                        {c.data[i] == null ? '—' : nombre(c.data[i] as number)}
                      </TableCell>
                    ))}
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        ) : (
          <Box sx={{ height: 300 }} role="img" aria-label={titre}>
            {type === 'bar' ? (
              <Bar
                options={options}
                data={{
                  labels,
                  datasets: courbes.map((c) => ({
                    label: c.label, data: c.data, backgroundColor: c.color, borderColor: surface, borderWidth: 1, borderRadius: 4, maxBarThickness: 28,
                  })),
                }}
              />
            ) : (
              <Line
                options={options}
                data={{
                  labels,
                  datasets: courbes.map((c) => ({
                    label: c.label, data: c.data, borderColor: c.color, backgroundColor: c.color, borderWidth: 2, spanGaps: true,
                    pointRadius: 4, pointHoverRadius: 6, pointHitRadius: 12, pointBorderColor: surface, pointBorderWidth: 2,
                  })),
                }}
              />
            )}
          </Box>
        )}
      </CardContent>
    </Card>
  );
};

const Dashboard: React.FC = () => {
  const theme = useTheme();
  const [data, setData] = useState<Synthese | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [selection, setSelection] = useState<string | null>(null);
  const [detail, setDetail] = useState<HistoriqueEcran | null>(null);

  const load = useCallback(async () => {
    try {
      const res = await api.get<Synthese>('/dashboard');
      setData(res.data);
      setError(null);
    } catch (e) {
      setError((e as { response?: { status?: number } }).response?.status === 403
        ? "Votre compte n'a pas accès au tableau de bord."
        : 'Impossible de charger le tableau de bord.');
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const enCours = data?.calcul.en_cours ?? false;
  const calculeLe = data?.calcul.calcule_le ?? null;
  useEffect(() => {
    if (!enCours) return undefined;
    const minuteur = setTimeout(load, 3000);
    return () => clearTimeout(minuteur);
  }, [enCours, calculeLe, load, data]);

  const majDetail = useCallback(async (cle: string | null) => {
    if (!cle) {
      setDetail(null);
      return;
    }
    try {
      const res = await api.get<HistoriqueEcran>(`/dashboard/historique/${cle}`);
      setDetail(res.data);
    } catch {
      setError("Impossible de charger le détail du domaine.");
    }
  }, []);

  useEffect(() => { majDetail(selection); }, [selection, calculeLe, majDetail]);

  const recalculer = async () => {
    try {
      await api.post('/dashboard/recalculer');
    } catch {
      // 409 : un calcul tourne déjà, le rechargement l'indiquera
    }
    await load();
  };

  const avecControles = useMemo(() => (data?.domaines ?? []).filter((d) => d.avec_controles && d.controles), [data]);
  const totalControles = avecControles.reduce((s, d) => s + (d.controles ?? 0), 0);
  const totalKo = avecControles.reduce((s, d) => s + (d.ko ?? 0), 0);
  const totalErreurs = avecControles.reduce((s, d) => s + (d.en_erreur ?? 0), 0);
  const totalTables = (data?.domaines ?? []).reduce((s, d) => s + d.tables, 0);
  const totalRemplies = (data?.domaines ?? []).reduce((s, d) => s + d.tables_remplies, 0);

  const parKo = useMemo(() => [...avecControles].sort((a, b) => (b.ko ?? 0) - (a.ko ?? 0)), [avecControles]);

  // Évolution : tous les domaines (contrôles KO, échelle comparable) ou un domaine (lignes par contrôle)
  const evolution = useMemo(() => {
    const historique = data?.historique ?? [];
    const toutesDates = selection && detail
      ? detail.series.flatMap((s) => s.points.map((p) => p.jour))
      : historique.map((h) => h.jour);
    if (toutesDates.length === 0) return { labels: [] as string[], jours: [] as string[], courbes: [] as Courbe[] };
    const tri = [...toutesDates].sort();
    const jours = joursEntre(tri[0], tri[tri.length - 1]);
    const courbes: Courbe[] = selection && detail
      ? detail.series.map((s, i) => {
          const valeurs = new Map(s.points.map((p) => [p.jour, p.n]));
          return { label: s.label, color: CATEGORIES[i % CATEGORIES.length], data: jours.map((j) => valeurs.get(j) ?? null) };
        })
      : avecControles.map((d) => {
          const valeurs = new Map(historique.filter((h) => h.ecran === d.cle).map((h) => [h.jour, h.ko]));
          return { label: d.label, color: COULEUR_DOMAINE[d.cle] ?? CATEGORIES[0], data: jours.map((j) => valeurs.get(j) ?? null) };
        });
    return { labels: jours.map(jourCourt), jours, courbes };
  }, [data, detail, selection, avecControles]);

  if (!data) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', p: 6 }}>
        {error ? <Alert severity="error">{error}</Alert> : <CircularProgress />}
      </Box>
    );
  }

  const domaineChoisi = data.domaines.find((d) => d.cle === selection);
  const mesureUnique = evolution.jours.length === 1;
  const courbesExtraction: Courbe[] = STATUTS_EXTRACTION
    .filter((s) => data.extractions.par_mois.some((m) => m[s.cle]))
    .map((s) => ({ label: s.label, color: s.color, data: data.extractions.par_mois.map((m) => Number(m[s.cle] ?? 0)) }));
  const etatTables = STATUTS_EXTRACTION.filter((s) => data.extractions.dernier_etat[s.cle]);
  const maintenanceOk = data.maintenance?.statut === 'DONE';

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 2, mb: 3 }}>
        <Typography variant="h4" component="h1">TABLEAU DE BORD</Typography>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          <Typography variant="body2" color="text.secondary">
            Contrôles {enCours ? 'en cours de calcul…' : age(data.calcul.calcule_le)}
          </Typography>
          <Button
            variant="outlined"
            size="small"
            disabled={enCours}
            startIcon={enCours ? <CircularProgress size={14} /> : <RecalculIcon />}
            onClick={recalculer}
          >
            Recalculer
          </Button>
        </Box>
      </Box>

      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
      {avecControles.length === 0 && enCours && (
        <Alert severity="info" sx={{ mb: 2 }}>Premier calcul des contrôles en cours : compter une vingtaine de secondes.</Alert>
      )}
      {avecControles.length === 0 && !enCours && (
        <Alert severity="warning" sx={{ mb: 2 }}>Aucune mesure disponible : le calcul des contrôles n'a pas abouti. Relancez-le avec Recalculer.</Alert>
      )}

      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} lg={3}>
          <Tuile
            titre="Contrôles en anomalie"
            valeur={totalControles ? `${totalKo} / ${totalControles}` : '—'}
            detail={totalErreurs ? `dont ${totalErreurs} non calculable(s)` : 'sur les 8 écrans Données IFS'}
          />
        </Grid>
        <Grid item xs={12} sm={6} lg={3}>
          <Tuile titre="Tables d'export remplies" valeur={`${totalRemplies} / ${totalTables}`} detail="tables d'export actives" />
        </Grid>
        <Grid item xs={12} sm={6} lg={3}>
          <Tuile
            titre="Extractions SAP sur 30 jours"
            valeur={nombre(data.extractions.jobs_30j)}
            detail={STATUTS_EXTRACTION.filter((s) => data.extractions.statuts_30j[s.cle])
              .map((s) => `${data.extractions.statuts_30j[s.cle]} ${s.label.toLowerCase()}`).join(' · ') || 'Aucune extraction'}
          />
        </Grid>
        <Grid item xs={12} sm={6} lg={3}>
          <Tuile
            titre="Dernier rechargement maintenance"
            valeur={data.maintenance ? (
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                {maintenanceOk ? <OkIcon sx={{ color: STATUT_BON }} /> : <ErreurIcon sx={{ color: STATUT_CRITIQUE }} />}
                {maintenanceOk ? 'Réussi' : data.maintenance.statut === 'ERROR' ? 'En échec' : 'En cours'}
              </Box>
            ) : '—'}
            detail={data.maintenance ? dateHeure(data.maintenance.date) : 'Aucun rechargement'}
          />
        </Grid>
      </Grid>

      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} lg={5}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="h6">Contrôles par domaine</Typography>
              <Typography variant="body2" color="text.secondary">Nombre de contrôles, détail dans le tableau ci-dessous</Typography>
              <Box sx={{ height: 300, mt: 1 }} role="img" aria-label="Contrôles sans anomalie et en anomalie par domaine">
                <Bar
                  options={{
                    indexAxis: 'y',
                    responsive: true,
                    maintainAspectRatio: false,
                    interaction: { mode: 'index', axis: 'y', intersect: false },
                    plugins: { legend: { position: 'bottom', labels: { color: theme.palette.text.secondary, usePointStyle: true, boxHeight: 8, padding: 14 } } },
                    scales: {
                      x: { stacked: true, beginAtZero: true, grid: { color: GRILLE }, border: { display: false }, ticks: { color: theme.palette.text.secondary, precision: 0 } },
                      y: { stacked: true, grid: { display: false }, ticks: { color: theme.palette.text.secondary } },
                    },
                  }}
                  data={{
                    labels: parKo.map((d) => d.label),
                    datasets: [
                      { label: 'En anomalie', data: parKo.map((d) => d.ko ?? 0), backgroundColor: STATUT_CRITIQUE, borderColor: theme.palette.background.paper, borderWidth: 1, borderRadius: 4, maxBarThickness: 18 },
                      { label: 'Sans anomalie', data: parKo.map((d) => (d.controles ?? 0) - (d.ko ?? 0) - (d.en_erreur ?? 0)), backgroundColor: STATUT_BON, borderColor: theme.palette.background.paper, borderWidth: 1, borderRadius: 4, maxBarThickness: 18 },
                    ],
                  }}
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} lg={7}>
          <Graphique
            titre={domaineChoisi ? `Évolution : ${domaineChoisi.label}` : 'Évolution des anomalies'}
            sousTitre={
              mesureUnique && data.calcul.premier_jour
                ? `Suivi démarré le ${new Date(`${data.calcul.premier_jour}T12:00:00`).toLocaleDateString('fr-FR')} : la courbe se construit jour après jour`
                : domaineChoisi
                  ? `Lignes en anomalie par contrôle${detail?.masques ? ` (${detail.masques} autre(s) contrôle(s) dans le tableau de l'écran)` : ''}`
                  : 'Nombre de contrôles en anomalie par domaine, 90 derniers jours'
            }
            action={domaineChoisi && <Button size="small" onClick={() => setSelection(null)}>Tous les domaines</Button>}
            type="line"
            labels={evolution.labels}
            courbes={evolution.courbes}
            libelleLigne="Jour"
          />
        </Grid>
      </Grid>

      <Card sx={{ mb: 3 }}>
        <CardContent sx={{ pb: 0 }}>
          <Typography variant="h6">État par domaine</Typography>
          <Typography variant="body2" color="text.secondary">Cliquez sur un domaine pour suivre ses contrôles sur la courbe</Typography>
        </CardContent>
        <TableContainer>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Domaine</TableCell>
                <TableCell align="right">Lignes</TableCell>
                <TableCell align="right">Tables</TableCell>
                <TableCell align="right">Contrôles KO</TableCell>
                <TableCell align="right">Anomalies</TableCell>
                <TableCell align="right">
                  <MuiTooltip title="Variation des lignes en anomalie depuis la mesure précédente"><span>Écart</span></MuiTooltip>
                </TableCell>
                <TableCell align="right">
                  <MuiTooltip title="Variation des lignes en anomalie depuis la mesure d'il y a au moins 7 jours"><span>Écart 7 j</span></MuiTooltip>
                </TableCell>
                <TableCell>Principale anomalie</TableCell>
                <TableCell>Dernier chargement</TableCell>
                <TableCell padding="none" />
              </TableRow>
            </TableHead>
            <TableBody>
              {data.domaines.map((d) => (
                <TableRow key={d.cle} selected={d.cle === selection} hover>
                  <TableCell>
                    {d.avec_controles ? (
                      <Button
                        size="small"
                        onClick={() => setSelection(d.cle === selection ? null : d.cle)}
                        sx={{ textTransform: 'none', p: 0, minWidth: 0, color: 'text.primary', justifyContent: 'flex-start' }}
                      >
                        {d.label}
                      </Button>
                    ) : d.label}
                  </TableCell>
                  <TableCell align="right" sx={{ fontVariantNumeric: 'tabular-nums' }}>{nombre(d.lignes)}</TableCell>
                  <TableCell align="right" sx={{ fontVariantNumeric: 'tabular-nums' }}>{d.tables_remplies} / {d.tables}</TableCell>
                  {d.controles ? (
                    <>
                      <TableCell align="right" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                        {d.ko} / {d.controles}{d.en_erreur ? ` (${d.en_erreur} non calculé)` : ''}
                      </TableCell>
                      <TableCell align="right" sx={{ fontVariantNumeric: 'tabular-nums' }}>{nombre(d.anomalies ?? 0)}</TableCell>
                      <TableCell align="right"><Ecart valeur={d.delta_precedent} /></TableCell>
                      <TableCell align="right"><Ecart valeur={d.delta_7j} /></TableCell>
                      <TableCell>{d.principale ? `${d.principale.label} : ${nombre(d.principale.n)}` : 'Aucune'}</TableCell>
                    </>
                  ) : (
                    <TableCell colSpan={5} sx={{ color: 'text.secondary' }}>
                      {d.avec_controles ? 'Mesure en attente' : 'Pas de contrôle défini'}
                    </TableCell>
                  )}
                  <TableCell sx={{ whiteSpace: 'nowrap' }}>
                    {d.dernier_chargement ? (
                      <>
                        {dateHeure(d.dernier_chargement.date)}
                        {d.dernier_chargement.statut === 'ERROR' && <Typography component="span" variant="body2" color="error.light"> (échec)</Typography>}
                      </>
                    ) : (
                      <MuiTooltip title="Aucun chargement journalisé depuis la mise en place du suivi, ou écran rechargé par une autre voie">
                        <Typography component="span" variant="body2" color="text.secondary">Non tracé</Typography>
                      </MuiTooltip>
                    )}
                  </TableCell>
                  <TableCell padding="none">
                    <MuiTooltip title={d.avec_controles ? 'Ouvrir les contrôles' : "Ouvrir l'écran"}>
                      <IconButton component={RouterLink} to={d.url} size="small" aria-label={`Ouvrir ${d.label}`}>
                        <OuvrirIcon fontSize="small" />
                      </IconButton>
                    </MuiTooltip>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </Card>

      <Grid container spacing={3}>
        <Grid item xs={12} lg={5}>
          <Card sx={{ height: '100%' }}>
            <CardContent sx={{ pb: 0 }}>
              <Typography variant="h6">À traiter</Typography>
              <Typography variant="body2" color="text.secondary">Hausses d'abord, puis les plus gros volumes</Typography>
            </CardContent>
            <List dense>
              {data.a_traiter.length === 0 && (
                <ListItem><ListItemText primary="Aucune anomalie mesurée" /></ListItem>
              )}
              {data.a_traiter.map((a) => (
                <ListItem key={`${a.ecran}-${a.code}`} disablePadding secondaryAction={<Ecart valeur={a.delta} />}>
                  <ListItemButton component={RouterLink} to={a.url} sx={{ pr: 8 }}>
                    <ListItemText primary={`${a.domaine} : ${a.label}`} secondary={`${nombre(a.n)} ligne(s)`} />
                  </ListItemButton>
                </ListItem>
              ))}
            </List>
          </Card>
        </Grid>
        <Grid item xs={12} lg={7}>
          <Graphique
            titre="Extractions SAP par mois"
            sousTitre={`Dernier état par table : ${etatTables.map((s) => `${data.extractions.dernier_etat[s.cle]} ${s.label.toLowerCase()}`).join(' · ') || 'aucun'}`}
            type="bar"
            labels={data.extractions.par_mois.map((m) => moisCourt(m.mois))}
            courbes={courbesExtraction}
            libelleLigne="Mois"
          />
          {data.extractions.echecs.length > 0 && (
            <Alert severity="error" sx={{ mt: 2 }}>
              {data.extractions.echecs.map((e) => (
                <Box key={e.table}>
                  <strong>{e.table}</strong>{e.date ? ` (${dateHeure(e.date)})` : ''} : {e.erreur || 'erreur non renseignée'}
                </Box>
              ))}
            </Alert>
          )}
        </Grid>
      </Grid>
    </Box>
  );
};

export default Dashboard;
