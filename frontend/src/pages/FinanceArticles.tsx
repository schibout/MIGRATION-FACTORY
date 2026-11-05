import {
    Add as AddIcon,
    Calculate as CalculIcon,
    Close as CloseIcon,
    FileDownload as ExcelIcon,
    FileUpload as ImportIcon,
    Inventory2 as ArticleIcon,
    Search as SearchIcon,
    Sync as SyncIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Chip,
    FormControl,
    IconButton,
    InputAdornment,
    InputLabel,
    LinearProgress,
    MenuItem,
    Paper,
    Select,
    Tab,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TablePagination,
    TableRow,
    TableSortLabel,
    Tabs,
    TextField,
    Tooltip,
    Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';

// Même logique que FinanceFournisseurs : date d'arrêté, Calculer / Synchroniser SAP, import du fichier validé.
// Source : clean_data.article_perimetre (sql/articleSap/article_perimetre.sql), colonnes de clean_data.v_article_sap
// (écran Données SAP > Articles).

type Row = Record<string, string | number | boolean | null>;

interface SyncStatus {
  status: 'never' | 'running' | 'completed' | 'failed';
  step?: string;
  progress?: number;
  error?: string | null;
  rows?: number | null;
  started_at?: string;
  finished_at?: string | null;
}

interface Colonne { key: string; label: string }

interface ListResponse {
  rows: Row[];
  total: number;
  stats: { total: number; fichier: number; sap_nouveau: number; date_arrete: string | null };
  colonnes: Colonne[];
  sync: SyncStatus | null;
}

const formatDate = (v?: string | null) => (v ? new Date(v).toLocaleDateString('fr-FR') : '');
const formatDateTime = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('fr-FR') : '');
const nb = (n: number) => n.toLocaleString('fr-FR');

// Destinations IFS : règles dans sql/articleSap/v_article_destination_ifs.sql, API /finance/articles/destinations.
interface Segment {
  type_sap: string;
  catalogue: boolean;
  inventory: boolean;
  sales: boolean | null;
  piece_detachee: 'RATTACHEE' | 'DECONNECTEE' | null;
  articles: number;
  stock: number;
}
interface Condition { champ: string; op: 'est' | 'nest'; valeur: string }
interface Vue { cle: string; libelle: string; conds: Condition[]; nb: number }
interface DestinationsResponse { segments: Segment[]; vues: Vue[]; fichiers: string[] }

const DESTS = [
  { k: 'catalogue', nom: 'Catalogue', table: 'part_catalog', couleur: '#37474f' },
  { k: 'inventory', nom: 'Inventory', table: 'inventory_part', couleur: '#00838f' },
  { k: 'sales', nom: 'Sales', table: 'sales_part', couleur: '#6a4c93' },
  { k: 'piece', nom: 'Pièce détachée', table: 'table IFS à confirmer', couleur: '#b45309' },
];
const dansDest = (s: Segment, k: string) => (k === 'piece' ? !!s.piece_detachee : s[k as 'catalogue' | 'inventory' | 'sales'] === true);
const somme = (l: Segment[]) => l.reduce((a, s) => a + s.articles, 0);

const TYPES_LIBELLES: Record<string, string> = {
  IBAU: 'Sous-ensemble de maintenance', ERSA: 'Pièces de rechange', HIBE: 'Matière consommable',
  NLAG: 'Non géré en stock', HALB: 'Produit semi-fini', ROH: 'Matière première', ABSENT: 'Absent de SAP',
};
const OUI_NON = [{ v: 'oui', l: 'Oui' }, { v: 'non', l: 'Non' }];
const VALEURS_DESTINATION = [
  { v: 'catalogue', l: 'Catalogue' }, { v: 'inventory', l: 'Inventory' }, { v: 'sales', l: 'Sales' },
  { v: 'piece', l: 'Pièce détachée' }, { v: 'deconnectee', l: 'Pièce déconnectée' }, { v: 'rattachee', l: 'Pièce rattachée' },
];
const CHAMPS = [
  { k: 'destination', l: 'Destination IFS' }, { k: 'type', l: 'Type SAP' }, { k: 'stock', l: 'Stock positif' },
  { k: 'magasin', l: 'Classe magasin' }, { k: 'nomenclature', l: 'Dans une nomenclature' }, { k: 'fichier', l: 'Fichier validé' },
];

const MODE_EMPLOI: { titre: string; items: [string, string][] }[] = [
  {
    titre: 'Actions en haut de page',
    items: [
      ["Date d'arrêté", "Date de référence du périmètre : un article créé dans SAP à partir de cette date et absent des fichiers validés est ajouté en SAP_NOUVEAU. Elle est prise en compte au prochain Calculer ou Synchroniser SAP."],
      ['Calculer', "Relit les tables SAP déjà extraites (MARA, MAKT, MARC…), met à jour les colonnes SAP de chaque N° article, puis recalcule le périmètre. N'appelle pas SAP. Ne touche ni au fichier validé, ni au groupe comptable, ni au groupe d'achat. Ne recharge pas les tables IFS."],
      ['Synchroniser SAP', "Ré-extrait d'abord les tables articles de SAP, rejoue les modules de chargement articles (qui recalculent aussi part_catalog et les autres tables IFS articles), puis recalcule le périmètre. C'est l'action la plus longue : compter 15 à 40 minutes."],
      ['Importer le fichier validé', "Ouvre l'assistant d'import : choix du fichier, association des colonnes (N° article obligatoire), contrôle, puis import. Les articles du fichier passent en FICHIER et le périmètre est recalculé. Une option permet de vider d'abord les fichiers déjà importés."],
      ['Exporter Excel', 'Télécharge un classeur des articles affichés, avec tous les filtres et le tri en cours, et toutes les colonnes.'],
    ],
  },
  {
    titre: 'Pastilles de synthèse',
    items: [
      ['Articles · FICHIER · SAP_NOUVEAU', "Nombre total d'articles du périmètre, ceux venant des fichiers validés, et ceux ajoutés depuis SAP après la date d'arrêté."],
      ["Date d'arrêté du chargement", 'Date utilisée par le dernier calcul. Elle peut différer de la date saisie tant que le calcul n’est pas relancé.'],
    ],
  },
  {
    titre: 'Destinations IFS',
    items: [
      ['Cartes Catalogue, Inventory, Sales, Pièce détachée', 'Nombre d’articles qui iraient dans chaque table IFS. Un clic filtre la liste sur cette destination, un second clic retire le filtre.'],
      ['Tableau type SAP × destination', 'Répartition par type SAP. Un clic sur un chiffre filtre la liste sur ce type et cette destination, un second clic retire le filtre. Un même article peut compter dans plusieurs colonnes.'],
      ['Important', 'Ces destinations sont simulées : elles montrent où chaque article irait selon les règles ci-dessous, pas où il est déjà. Elles ne modifient aucune table IFS.'],
    ],
  },
  {
    titre: 'Règles de destination',
    items: [
      ['Catalogue', 'Tout article connu de SAP.'],
      ['Inventory', "Article de classe MAGASIN, c'est-à-dire avec une ligne magasin SAP (MARD) non supprimée sur son site."],
      ['Sales', 'À définir : aucun article du périmètre n’a de vue de vente SAP (MVKE).'],
      ['Pièce détachée', 'Types IBAU et ERSA. « Rattachée » si l’article est dans une nomenclature d’équipement (equipment_object_spare), « Déconnectée » sinon.'],
      ['Absent de SAP', 'Article du fichier introuvable dans SAP : à vérifier, aucune destination proposée.'],
    ],
  },
  {
    titre: 'Filtres',
    items: [
      ['Vues', 'Filtres prêts à l’emploi, avec leur nombre d’articles. Un clic remplace le filtre avancé par celui de la vue, un second clic le retire.'],
      ['Type SAP', 'Filtre sur un ou plusieurs types. Chaque clic ajoute ou retire un type.'],
      ['Filtre avancé', 'Combine des conditions du type « Stock positif est Oui ». « Toutes les conditions » correspond à ET, « Au moins une condition » à OU.'],
      ['Ajouter une condition', 'Ajoute une ligne de condition : choisir le champ, « est » ou « n’est pas », puis la valeur.'],
      ['Croix sur une condition', 'Retire cette condition.'],
      ['Tout effacer', 'Retire la vue, les types, la destination et les conditions. Ne retire ni la recherche ni le filtre Source.'],
      ['Recherche', 'Cherche dans le N° article, la description et l’ancien numéro. Valider avec la touche Entrée.'],
      ['Source', 'Limite la liste aux articles FICHIER ou SAP_NOUVEAU.'],
    ],
  },
  {
    titre: 'Liste des articles',
    items: [
      ['En-têtes de colonnes', 'Un clic trie sur la colonne, un second clic inverse le sens.'],
      ['Colonnes « Fichier · … »', 'Valeurs lues dans les fichiers importés, sans recalcul depuis SAP.'],
      ['Groupe comptable et groupe d’achat', 'Viennent toujours du fichier validé, jamais de SAP : vides si le fichier ne les renseigne pas.'],
      ['Lignes par page et flèches', 'Règlent le nombre de lignes affichées et changent de page.'],
    ],
  },
];

const FinanceArticles: React.FC = () => {
  const navigate = useNavigate();
  const [data, setData] = useState<ListResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [source, setSource] = useState('');
  const [dateArrete, setDateArrete] = useState('');
  const [sync, setSync] = useState<SyncStatus | null>(null);
  const [exporting, setExporting] = useState(false);
  const [onglet, setOnglet] = useState(0);
  const [types, setTypes] = useState<string[]>([]);
  const [dest, setDest] = useState('');
  const [conds, setConds] = useState<Condition[]>([]);
  const [logique, setLogique] = useState<'ET' | 'OU'>('ET');
  const [vue, setVue] = useState('');
  const [sort, setSort] = useState('');
  const [dir, setDir] = useState<'asc' | 'desc'>('asc');
  const [destinations, setDestinations] = useState<DestinationsResponse | null>(null);

  const filtres = useMemo(() => {
    const p: Record<string, string> = {};
    if (search) p.search = search;
    if (source) p.source = source;
    if (types.length) p.types = types.join(',');
    if (dest) p.dest = dest;
    if (conds.length) {
      p.conds = JSON.stringify(conds);
      p.logique = logique;
    }
    return p;
  }, [search, source, types, dest, conds, logique]);

  useEffect(() => { setPage(0); }, [filtres]);

  const chargerDestinations = useCallback(async () => {
    try {
      const res = await api.get<DestinationsResponse>('/finance/articles/destinations', { params: filtres });
      setDestinations(res.data);
    } catch (err) {
      console.error('Erreur chargement destinations:', err);
      setError('Erreur lors du chargement des destinations IFS');
    }
  }, [filtres]);

  useEffect(() => {
    chargerDestinations();
  }, [chargerDestinations]);

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.get<ListResponse>('/finance/articles', {
        params: { ...filtres, sort: sort || undefined, dir, page: page + 1, page_size: pageSize },
      });
      setData(res.data);
      setSync(res.data.sync);
      setDateArrete((d) => d || res.data.stats.date_arrete || '');
    } catch (err) {
      console.error('Erreur chargement articles:', err);
      setError('Erreur lors du chargement des articles');
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, filtres, sort, dir]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (sync?.status !== 'running') return undefined;
    const timer = setInterval(async () => {
      try {
        const res = await api.get<SyncStatus>('/finance/articles/sync');
        setSync(res.data);
        if (res.data.status !== 'running') {
          load();
          chargerDestinations();
        }
      } catch (err) {
        console.error('Erreur statut synchronisation:', err);
      }
    }, 5000);
    return () => clearInterval(timer);
  }, [sync?.status, load, chargerDestinations]);

  const handleSync = async (src: 'sap' | 'mf') => {
    try {
      setError(null);
      const res = await api.post<SyncStatus>('/finance/articles/sync', { source: src, date_arrete: dateArrete || null });
      setSync(res.data);
    } catch (err: any) {
      if (err?.response?.status === 409) setSync(err.response.data);
      else setError(err?.response?.data?.error ?? 'Impossible de lancer le calcul');
    }
  };

  const handleExport = async () => {
    try {
      setExporting(true);
      setError(null);
      const res = await api.get('/finance/articles/export.xlsx', {
        params: { ...filtres, sort: sort || undefined, dir },
        responseType: 'blob',
      });
      const match = /filename="?([^";]+)"?/.exec(res.headers['content-disposition'] ?? '');
      const url = window.URL.createObjectURL(res.data);
      const link = document.createElement('a');
      link.href = url;
      link.download = match?.[1] ?? 'articles.xlsx';
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error('Erreur export Excel articles:', err);
      setError("Erreur lors de l'export Excel");
    } finally {
      setExporting(false);
    }
  };

  const running = sync?.status === 'running';
  const stats = data?.stats;
  const colonnes = data?.colonnes ?? [];
  const segments = destinations?.segments ?? [];
  const segmentsTypes = segments.filter((s) => !types.length || types.includes(s.type_sap));
  const typesListe = Array.from(new Set(segments.map((s) => s.type_sap)))
    .map((code) => ({ code, total: somme(segments.filter((s) => s.type_sap === code)) }))
    .sort((a, b) => b.total - a.total);
  const typesChoix = Array.from(new Set([...Object.keys(TYPES_LIBELLES), ...segments.map((s) => s.type_sap)]));

  const valeursDe = (champ: string): { v: string; l: string }[] => {
    if (champ === 'destination') return VALEURS_DESTINATION;
    if (champ === 'type') return typesChoix.map((v) => ({ v, l: v === 'ABSENT' ? TYPES_LIBELLES.ABSENT : v }));
    if (champ === 'fichier') return (destinations?.fichiers ?? []).map((v) => ({ v, l: v }));
    return OUI_NON;
  };
  const modifierCond = (i: number, patch: Partial<Condition>) => {
    setVue('');
    setConds((cur) => cur.map((c, j) => (j === i ? { ...c, ...patch } : c)));
  };
  const toutEffacer = () => {
    setVue('');
    setConds([]);
    setTypes([]);
    setDest('');
  };
  const trier = (cle: string) => {
    if (sort === cle) setDir(dir === 'asc' ? 'desc' : 'asc');
    else {
      setSort(cle);
      setDir('asc');
    }
    setPage(0);
  };

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2, gap: 2, flexWrap: 'wrap' }}>
        <ArticleIcon sx={{ fontSize: 32, color: '#00838f' }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Articles
        </Typography>
        <Box sx={{ ml: 'auto', display: 'flex', gap: 1, alignItems: 'center', flexWrap: 'wrap' }}>
          <Tooltip title="Les articles créés dans SAP à partir de cette date, absents des fichiers validés, sont ajoutés au périmètre (SAP_NOUVEAU)">
            <TextField
              size="small"
              type="date"
              label="Date d'arrêté"
              value={dateArrete}
              onChange={(e) => setDateArrete(e.target.value)}
              InputLabelProps={{ shrink: true }}
            />
          </Tooltip>
          <Tooltip title="Relit les tables SAP déjà extraites (MARA, MAKT, MARC…) et met à jour les colonnes SAP de chaque N° article, puis recalcule le périmètre avec la date d'arrêté saisie. Le groupe comptable et le groupe d'achat restent ceux du fichier. N'appelle pas SAP : pour des données fraîches, utiliser Synchroniser SAP">
            <span>
              <Button variant="outlined" startIcon={<CalculIcon />} onClick={() => handleSync('mf')} disabled={running}>
                Calculer
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Ré-extrait de SAP les tables articles (MARA, MAKT, MARC…), rejoue les modules ETL articles comme l'écran Données SAP > Articles, puis recalcule le périmètre">
            <span>
              <Button variant="contained" startIcon={<SyncIcon />} onClick={() => handleSync('sap')} disabled={running}>
                {running ? 'Synchronisation…' : 'Synchroniser SAP'}
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Assistant d'import (comme l'import générique) : mapping des colonnes du fichier validé, N° article obligatoire, autres colonnes conservées ; les articles du fichier passent en FICHIER puis le périmètre est recalculé avec la date de validation">
            <span>
              <Button variant="outlined" startIcon={<ImportIcon />} onClick={() => navigate('/finance/articles/import')} disabled={running}>
                Importer le fichier validé
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Classeur Excel des articles filtrés (recherche, source), toutes colonnes">
            <span>
              <Button variant="outlined" color="success" startIcon={<ExcelIcon />} onClick={handleExport} disabled={exporting || !data?.total}>
                {exporting ? 'Export…' : 'Exporter Excel'}
              </Button>
            </span>
          </Tooltip>
        </Box>
      </Box>

      <Tabs value={onglet} onChange={(_, v) => setOnglet(v)} sx={{ mb: 2, borderBottom: 1, borderColor: 'divider' }}>
        <Tab label="Articles" />
        <Tab label="Mode d'emploi" />
      </Tabs>

      {onglet === 1 && (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, maxWidth: 1000 }}>
          {MODE_EMPLOI.map((section) => (
            <Paper key={section.titre} variant="outlined" sx={{ p: 2 }}>
              <Typography variant="h6" component="h2" sx={{ mb: 1, fontSize: 17 }}>{section.titre}</Typography>
              <Table size="small">
                <TableBody>
                  {section.items.map(([nom, texte]) => (
                    <TableRow key={nom}>
                      <TableCell component="th" scope="row" sx={{ fontWeight: 600, width: { xs: '40%', md: 260 }, verticalAlign: 'top' }}>{nom}</TableCell>
                      <TableCell>{texte}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </Paper>
          ))}
        </Box>
      )}

      {onglet === 0 && (
      <>
      <Alert severity="info" sx={{ mb: 2 }}>
        FICHIER = article des fichiers validés par le métier (la référence, même absent de SAP : ses colonnes SAP restent
        vides) ; SAP_NOUVEAU = article de Données SAP &gt; Articles créé dans SAP (date de création MARA) à partir de la
        date d'arrêté et absent des fichiers validés. Les colonnes « Fichier · … » viennent des fichiers importés.
        Groupe comptable et groupe d'achat viennent toujours du fichier, jamais de SAP : vides si le fichier ne les renseigne pas.
      </Alert>

      {stats && (
        <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
          <Chip label={`${stats.total.toLocaleString('fr-FR')} articles`} color="primary" />
          <Chip label={`${stats.fichier.toLocaleString('fr-FR')} FICHIER`} />
          <Chip label={`${stats.sap_nouveau.toLocaleString('fr-FR')} SAP_NOUVEAU`} color="warning" />
          {stats.date_arrete && <Chip label={`Date d'arrêté du chargement : ${formatDate(stats.date_arrete)}`} variant="outlined" />}
        </Box>
      )}

      {running && (
        <Alert severity="info" sx={{ mb: 2 }}>
          {sync?.step} — démarrée le {formatDateTime(sync?.started_at)}
          <LinearProgress variant="determinate" value={sync?.progress ?? 0} sx={{ mt: 1 }} />
        </Alert>
      )}
      {sync?.status === 'completed' && (
        <Alert severity="success" sx={{ mb: 2 }}>
          Dernier calcul le {formatDateTime(sync.finished_at)} : {sync.rows?.toLocaleString('fr-FR')} articles chargés.
        </Alert>
      )}
      {sync?.status === 'failed' && (
        <Alert severity="error" sx={{ mb: 2 }}>
          Échec le {formatDateTime(sync.finished_at)} : {sync.error}
        </Alert>
      )}
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))', gap: 1.5, mb: 2 }}>
        {DESTS.map((d) => {
          const liste = segmentsTypes.filter((s) => dansDest(s, d.k));
          let detail = 'Articles connus de SAP';
          if (d.k === 'inventory') detail = 'Articles de classe MAGASIN';
          if (d.k === 'sales') detail = 'Règle à définir';
          if (d.k === 'piece') {
            const rattachees = somme(liste.filter((s) => s.piece_detachee === 'RATTACHEE'));
            detail = `${nb(rattachees)} rattachées · ${nb(somme(liste) - rattachees)} déconnectées`;
          }
          return (
            <Button key={d.k} variant="outlined" onClick={() => setDest(dest === d.k ? '' : d.k)} aria-pressed={dest === d.k}
              sx={{ display: 'block', textAlign: 'left', textTransform: 'none', color: 'text.primary', borderColor: 'divider', borderTop: `4px solid ${d.couleur}`, bgcolor: dest === d.k ? '#e6f4f6' : 'background.paper', p: 1.5 }}>
              <Typography sx={{ fontWeight: 600, fontSize: 14 }}>{d.nom}</Typography>
              <Typography variant="caption" sx={{ fontFamily: 'monospace', color: 'text.secondary' }}>{d.table}</Typography>
              <Typography sx={{ fontSize: 26, fontWeight: 600 }}>{nb(somme(liste))}</Typography>
              <Typography variant="caption" sx={{ color: 'text.secondary' }}>{detail}</Typography>
            </Button>
          );
        })}
      </Box>

      <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
        <Typography variant="h6" component="h2" sx={{ fontSize: 16 }}>Du type SAP vers IFS</Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
          Destinations simulées, aucune table IFS n'est modifiée. Cliquer un chiffre filtre la liste. Un article peut aller dans plusieurs tables.
        </Typography>
        <TableContainer>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell sx={{ fontWeight: 600 }}>Type SAP</TableCell>
                <TableCell align="right" sx={{ fontWeight: 600 }}>Articles</TableCell>
                {DESTS.map((d) => <TableCell key={d.k} align="center" sx={{ fontWeight: 600 }}>{d.nom}</TableCell>)}
              </TableRow>
            </TableHead>
            <TableBody>
              {typesListe.map((t) => (
                <TableRow key={t.code}>
                  <TableCell component="th" scope="row">
                    <strong>{t.code === 'ABSENT' ? 'Absent' : t.code}</strong>{TYPES_LIBELLES[t.code] ? ` · ${TYPES_LIBELLES[t.code]}` : ''}
                  </TableCell>
                  <TableCell align="right" sx={{ fontWeight: 600 }}>{nb(t.total)}</TableCell>
                  {DESTS.map((d) => {
                    const valeur = somme(segments.filter((s) => s.type_sap === t.code && dansDest(s, d.k)));
                    const actif = dest === d.k && types.length === 1 && types[0] === t.code;
                    return (
                      <TableCell key={d.k} align="center" sx={{ py: 0.5 }}>
                        {valeur === 0 ? '–' : (
                          <Button size="small" variant={actif ? 'contained' : 'text'} sx={{ minWidth: 80 }}
                            aria-label={`${t.code} vers ${d.nom} : ${nb(valeur)} articles`}
                            onClick={() => {
                              setTypes(actif ? [] : [t.code]);
                              setDest(actif ? '' : d.k);
                            }}>
                            {nb(valeur)}
                          </Button>
                        )}
                      </TableCell>
                    );
                  })}
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      <Paper variant="outlined" sx={{ p: 2, mb: 2, display: 'flex', flexDirection: 'column', gap: 1.5 }}>
        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, alignItems: 'center' }}>
          <Typography variant="body2" sx={{ fontWeight: 600, width: 100 }}>Vues</Typography>
          {(destinations?.vues ?? []).map((v) => (
            <Chip key={v.cle} clickable color={vue === v.cle ? 'primary' : 'default'} variant={vue === v.cle ? 'filled' : 'outlined'}
              label={`${v.libelle} · ${nb(v.nb)}`}
              onClick={() => {
                const actif = vue === v.cle;
                setVue(actif ? '' : v.cle);
                setConds(actif ? [] : v.conds);
                setLogique('ET');
              }} />
          ))}
        </Box>
        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, alignItems: 'center' }}>
          <Typography variant="body2" sx={{ fontWeight: 600, width: 100 }}>Type SAP</Typography>
          {typesListe.map((t) => {
            const actif = types.includes(t.code);
            return (
              <Chip key={t.code} clickable color={actif ? 'primary' : 'default'} variant={actif ? 'filled' : 'outlined'}
                label={`${t.code === 'ABSENT' ? 'Absent' : t.code} · ${nb(t.total)}`}
                onClick={() => setTypes(actif ? types.filter((c) => c !== t.code) : [...types, t.code])} />
            );
          })}
        </Box>
        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, alignItems: 'center' }}>
          <Typography variant="body2" sx={{ fontWeight: 600, width: 100 }}>Filtre avancé</Typography>
          <TextField select size="small" label="Garder les articles qui respectent" value={logique} sx={{ minWidth: 280 }}
            onChange={(e) => {
              setVue('');
              setLogique(e.target.value as 'ET' | 'OU');
            }}>
            <MenuItem value="ET">Toutes les conditions (ET)</MenuItem>
            <MenuItem value="OU">Au moins une condition (OU)</MenuItem>
          </TextField>
          <Button size="small" variant="outlined" startIcon={<AddIcon />}
            onClick={() => {
              setVue('');
              setConds([...conds, { champ: 'destination', op: 'est', valeur: 'deconnectee' }]);
            }}>
            Ajouter une condition
          </Button>
          <Button size="small" onClick={toutEffacer}>Tout effacer</Button>
        </Box>
        {conds.map((c, i) => (
          <Box key={i} sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, alignItems: 'center', pl: { md: '108px' } }}>
            <TextField select size="small" label="Champ" value={c.champ} sx={{ minWidth: 200 }}
              onChange={(e) => modifierCond(i, { champ: e.target.value, valeur: valeursDe(e.target.value)[0]?.v ?? '' })}>
              {CHAMPS.map((x) => <MenuItem key={x.k} value={x.k}>{x.l}</MenuItem>)}
            </TextField>
            <TextField select size="small" label="Opérateur" value={c.op} sx={{ minWidth: 120 }}
              onChange={(e) => modifierCond(i, { op: e.target.value as 'est' | 'nest' })}>
              <MenuItem value="est">est</MenuItem>
              <MenuItem value="nest">n'est pas</MenuItem>
            </TextField>
            <TextField select size="small" label="Valeur" value={c.valeur} sx={{ minWidth: 220 }}
              onChange={(e) => modifierCond(i, { valeur: e.target.value })}>
              {valeursDe(c.champ).map((x) => <MenuItem key={x.v} value={x.v}>{x.l}</MenuItem>)}
            </TextField>
            <IconButton size="small" aria-label="Retirer cette condition"
              onClick={() => {
                setVue('');
                setConds(conds.filter((_, j) => j !== i));
              }}>
              <CloseIcon fontSize="small" />
            </IconButton>
          </Box>
        ))}
      </Paper>

      <Box sx={{ display: 'flex', gap: 2, mb: 2, flexWrap: 'wrap', alignItems: 'center' }}>
        <TextField
          size="small"
          placeholder="N° article, description, ancien numéro…"
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              setPage(0);
              setSearch(searchInput);
            }
          }}
          sx={{ minWidth: 380 }}
          InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment> }}
        />
        <FormControl size="small" sx={{ minWidth: 170 }}>
          <InputLabel>Source</InputLabel>
          <Select label="Source" value={source} onChange={(e) => { setPage(0); setSource(e.target.value); }}>
            <MenuItem value="">Toutes</MenuItem>
            <MenuItem value="FICHIER">FICHIER</MenuItem>
            <MenuItem value="SAP_NOUVEAU">SAP_NOUVEAU</MenuItem>
          </Select>
        </FormControl>
      </Box>

      <Paper>
        {loading && <LinearProgress />}
        <TableContainer sx={{ maxHeight: '70vh', minHeight: 300 }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                {colonnes.map((c) => (
                  <TableCell key={c.key} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>
                    <TableSortLabel active={sort === c.key} direction={sort === c.key ? dir : 'asc'} onClick={() => trier(c.key)}>
                      {c.label}
                    </TableSortLabel>
                  </TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {data?.rows.map((r, i) => (
                <TableRow key={i} hover>
                  {colonnes.map((c) => (
                    <TableCell key={c.key} sx={{ whiteSpace: 'nowrap', maxWidth: 400, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {c.key === 'source' && r.source
                        ? <Chip size="small" label={String(r.source)} color={r.source === 'SAP_NOUVEAU' ? 'warning' : 'default'} />
                        : String(r[c.key] ?? '')}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
              {data?.rows.length === 0 && (
                <TableRow>
                  <TableCell colSpan={colonnes.length || 1} align="center">
                    Aucune ligne : lancer « Calculer » (ou « Synchroniser SAP » si les articles SAP n'ont jamais été chargés)
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
        <TablePagination
          component="div"
          count={data?.total ?? 0}
          page={page}
          rowsPerPage={pageSize}
          rowsPerPageOptions={[25, 50, 100, 250]}
          onPageChange={(_, p) => setPage(p)}
          onRowsPerPageChange={(e) => { setPageSize(parseInt(e.target.value, 10)); setPage(0); }}
          labelRowsPerPage="Lignes par page"
        />
      </Paper>
      </>
      )}
    </Box>
  );
};

export default FinanceArticles;
