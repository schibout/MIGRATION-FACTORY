import {
  DeleteOutline as DeleteIcon,
  HelpOutline as HelpIcon,
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
  DialogContentText,
  DialogTitle,
  FormControl,
  FormControlLabel,
  InputLabel,
  MenuItem,
  Paper,
  Radio,
  RadioGroup,
  Select,
  Snackbar,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Tabs,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import React, { useCallback, useEffect, useMemo, useState } from 'react';

import defaultValueService, { EtlDefaultValue } from '../services/defaultValueService';
import matrixService, {
  MatrixColumn,
  MatrixMeta,
  MatrixValue,
  PartTypeRule,
} from '../services/matrixService';

// Colonne / ligne "joker" de la grille : la valeur null cote API.
const JOKER = '__TOUS__';
const enJoker = (v: string): string | null => (v === JOKER ? null : v);

// Marque de repetition : la cellule vaut exactement la constante de la colonne
// "Constante". Repeter la valeur dans les 15 cellules noyait les rares regles
// reelles sous un mur de texte identique.
const DITTO = '·';

// Meme regle de priorite que public.get_default_value_ctx() cote base :
// (site + famille) > site seul > famille seule > joker.
// La grille doit montrer ce que l'ETL appliquera, pas une approximation.
function regleLaPlusSpecifique<T extends { contract: string | null; part_family: string | null; is_active: boolean }>(
  regles: T[],
  contract: string | null,
  famille: string | null
): T | undefined {
  return regles
    .filter(
      (r) =>
        r.is_active &&
        (r.contract === null || r.contract === contract) &&
        (r.part_family === null || r.part_family === famille)
    )
    .sort((a, b) => {
      const specA = (a.contract ? 1 : 0) + (a.part_family ? 1 : 0);
      const specB = (b.contract ? 1 : 0) + (b.part_family ? 1 : 0);
      if (specA !== specB) return specB - specA;
      return (b.contract ? 1 : 0) - (a.contract ? 1 : 0);
    })[0];
}

const libelleRegle = (r: { contract: string | null; part_family: string | null }): string => {
  if (r.contract && r.part_family) return `site ${r.contract} + famille ${r.part_family}`;
  if (r.contract) return `site ${r.contract} (toutes familles)`;
  if (r.part_family) return `famille ${r.part_family} (tous sites)`;
  return 'règle générale (tous sites, toutes familles)';
};

const messageErreur = (e: unknown, repli: string): string => {
  const detail = (e as { response?: { data?: { error?: string } } })?.response?.data?.error;
  return detail || repli;
};

const afficherValeur = (v: { type_valeur: string; valeur: string | null }): string =>
  v.type_valeur === 'NULL' ? 'NULL' : v.valeur || '(vide)';

// L'API des constantes est paginee (100 max) et une table peut depasser
// 100 lignes (cust_ord_customer : 101 colonnes, plusieurs variantes) :
// on rapatrie toutes les pages pour ne pas perdre la colonne "Constante".
async function chargerToutesConstantes(tableCible: string): Promise<EtlDefaultValue[]> {
  const resultat: EtlDefaultValue[] = [];
  let page = 1;
  let pages = 1;
  do {
    const rep = await defaultValueService.list({ table_cible: tableCible, per_page: 100, page });
    resultat.push(...rep.default_values);
    pages = rep.pages;
    page += 1;
  } while (page <= pages);
  return resultat;
}

const LARGEUR_COLONNE = 200;    // colonne gelee : nom technique de la colonne
const LARGEUR_LIBELLE = 230;    // colonne gelee : libelle metier (catalogue IFS)
const LARGEUR_CONSTANTE = 110;  // colonne gelee : valeur de repli
const DECALAGE_LIBELLE = LARGEUR_COLONNE;
const DECALAGE_CONSTANTE = LARGEUR_COLONNE + LARGEUR_LIBELLE;
const H_ENTETE_1 = 34;         // hauteur de la 1re ligne d'en-tete (groupes site)
const H_ENTETE_2 = 30;         // hauteur de la 2e ligne (familles)

type Cellule = { colonne: string; contract: string | null; part_family: string | null };

const MatriceSiteFamille: React.FC = () => {
  const theme = useTheme();

  // Les colonnes gelees passent AU-DESSUS des cellules de donnees pendant le
  // defilement horizontal : leur fond doit etre totalement opaque. Un fond
  // translucide (le zebrage du theme) laisserait lire le texte du dessous.
  // D'ou le motif fond opaque + teinte posee en background-image : l'element
  // reste opaque tout en portant une nuance derivee du theme.
  const teinteOpaque = useCallback(
    (couleur: string, opacite: number) => ({
      backgroundColor: theme.palette.background.default,
      backgroundImage: `linear-gradient(${alpha(couleur, opacite)}, ${alpha(couleur, opacite)})`,
    }),
    [theme]
  );

  const styleGelee = useMemo(
    () => ({
      position: 'sticky' as const,
      backgroundColor: theme.palette.background.default,
      whiteSpace: 'nowrap' as const,
      overflow: 'hidden',
      textOverflow: 'ellipsis',
    }),
    [theme]
  );

  const [onglet, setOnglet] = useState(0);
  const [meta, setMeta] = useState<MatrixMeta>({
    sites: [],
    familles: [],
    cibles: [],
    tables_cibles: [],
    part_type_tables: [],
  });
  const [message, setMessage] = useState<{ texte: string; type: 'success' | 'error' } | null>(null);

  // --- Onglet 1 : valeurs par défaut ---------------------------------------
  const [tableCible, setTableCible] = useState('');
  const [filtreColonne, setFiltreColonne] = useState('');
  const [seulementRegles, setSeulementRegles] = useState(false);
  const [regles, setRegles] = useState<MatrixValue[]>([]);
  const [constantes, setConstantes] = useState<Map<string, EtlDefaultValue>>(new Map());
  // Libelle metier des colonnes, lu dans le catalogue IFS (public.ifs_field_catalog).
  const [libelles, setLibelles] = useState<Map<string, MatrixColumn>>(new Map());
  const [cellule, setCellule] = useState<Cellule | null>(null);
  const [valeurEdit, setValeurEdit] = useState('');
  const [descriptionEdit, setDescriptionEdit] = useState('');
  const [typeEdit, setTypeEdit] = useState<'CONSTANTE' | 'NULL'>('CONSTANTE');

  // --- Onglet 2 : routage de création --------------------------------------
  const [routages, setRoutages] = useState<PartTypeRule[]>([]);

  useEffect(() => {
    matrixService
      .meta()
      .then(setMeta)
      .catch(() => setMessage({ texte: 'Erreur lors du chargement des métadonnées', type: 'error' }));
  }, []);

  // Axes horizontaux : (Tous les sites, SJ, CS...) x (Toutes les familles, 21, 22...).
  const axeSites = useMemo(() => [JOKER, ...meta.sites], [meta.sites]);
  const axeFamilles = useMemo(() => [JOKER, ...meta.familles.map((f) => f.code)], [meta.familles]);
  const familleParCode = useMemo(
    () => new Map(meta.familles.map((f) => [f.code, f])),
    [meta.familles]
  );
  const nbColonnesDonnees = axeSites.length * axeFamilles.length;

  const tablesCibles = meta.tables_cibles;
  const colonnesCibles = useMemo(
    () =>
      meta.cibles
        .filter((c) => c.table_cible === tableCible)
        .map((c) => c.colonne)
        .filter((v, i, t) => t.indexOf(v) === i)
        .sort(),
    [meta.cibles, tableCible]
  );

  const reglesParColonne = useMemo(() => {
    const m = new Map<string, MatrixValue[]>();
    regles.forEach((r) => {
      const liste = m.get(r.colonne) ?? [];
      liste.push(r);
      m.set(r.colonne, liste);
    });
    return m;
  }, [regles]);

  const colonnesAffichees = useMemo(() => {
    const motif = filtreColonne.trim().toLowerCase();
    return colonnesCibles.filter((c) => {
      const libelle = (libelles.get(c)?.libelle ?? '').toLowerCase();
      return (
        (!motif || c.toLowerCase().includes(motif) || libelle.includes(motif)) &&
        (!seulementRegles || (reglesParColonne.get(c)?.length ?? 0) > 0)
      );
    });
  }, [colonnesCibles, filtreColonne, seulementRegles, reglesParColonne, libelles]);

  const chargerRegles = useCallback(async () => {
    if (!tableCible) {
      setRegles([]);
      setConstantes(new Map());
      setLibelles(new Map());
      return;
    }
    try {
      const [valeurs, toutesConstantes, colonnesIfs] = await Promise.all([
        matrixService.listValues({ table_cible: tableCible }),
        // Le repli de la matrice : la constante de Configuration > Valeurs par défaut.
        chargerToutesConstantes(tableCible),
        // Libellés métier des colonnes (catalogue IFS). Simple confort :
        // un backend plus ancien ne connaît pas la route, l'écran doit
        // continuer d'afficher ses règles et ses constantes.
        matrixService.columns(tableCible).catch(() => [] as MatrixColumn[]),
      ]);
      setRegles(valeurs);
      setLibelles(new Map(colonnesIfs.map((c) => [c.colonne, c])));
      const m = new Map<string, EtlDefaultValue>();
      toutesConstantes
        .filter((c) => c.variante === 'STANDARD' && c.is_active)
        .forEach((c) => m.set(c.colonne, c));
      setConstantes(m);
    } catch (e) {
      setMessage({ texte: messageErreur(e, 'Erreur lors du chargement de la matrice'), type: 'error' });
    }
  }, [tableCible]);

  useEffect(() => {
    chargerRegles();
  }, [chargerRegles]);

  const chargerRoutages = useCallback(async () => {
    try {
      setRoutages(await matrixService.listPartTypes());
    } catch (e) {
      setMessage({ texte: messageErreur(e, 'Erreur lors du chargement du routage'), type: 'error' });
    }
  }, []);

  useEffect(() => {
    chargerRoutages();
  }, [chargerRoutages]);

  // ------------------------------------------------------------------ Valeurs
  const trouverPropre = (c: Cellule) =>
    reglesParColonne
      .get(c.colonne)
      ?.find((r) => r.contract === c.contract && r.part_family === c.part_family);

  const ouvrirCellule = (c: Cellule) => {
    const propre = trouverPropre(c);
    setCellule(c);
    setTypeEdit(propre?.type_valeur ?? 'CONSTANTE');
    setValeurEdit(propre?.valeur ?? '');
    setDescriptionEdit(propre?.description ?? '');
  };

  const enregistrerCellule = async () => {
    if (!cellule) return;
    try {
      await matrixService.saveValue({
        table_cible: tableCible,
        colonne: cellule.colonne,
        contract: cellule.contract,
        part_family: cellule.part_family,
        type_valeur: typeEdit,
        valeur: typeEdit === 'NULL' ? null : valeurEdit,
        description: descriptionEdit || null,
      });
      setMessage({ texte: 'Règle enregistrée', type: 'success' });
      setCellule(null);
      chargerRegles();
    } catch (e) {
      setMessage({ texte: messageErreur(e, "Erreur lors de l'enregistrement"), type: 'error' });
    }
  };

  const supprimerCellule = async () => {
    if (!cellule) return;
    const propre = trouverPropre(cellule);
    if (!propre) {
      setCellule(null);
      return;
    }
    try {
      await matrixService.deleteValue(propre.id);
      setMessage({ texte: 'Règle supprimée : la cellule hérite de nouveau', type: 'success' });
      setCellule(null);
      chargerRegles();
    } catch (e) {
      setMessage({ texte: messageErreur(e, 'Erreur lors de la suppression'), type: 'error' });
    }
  };

  // Trois etats, trois poids visuels : la regle posee ici ressort (pastille
  // pleine), la valeur heritee d'une regle plus generale reste lisible mais
  // discrete, et la cellule qui vaut simplement la constante s'efface.
  const rendreCelluleValeur = (colonne: string, contract: string | null, part_family: string | null) => {
    const reglesColonne = reglesParColonne.get(colonne) ?? [];
    const propre = reglesColonne.find((r) => r.contract === contract && r.part_family === part_family);
    const heritee = regleLaPlusSpecifique(reglesColonne, contract, part_family);
    const constante = constantes.get(colonne);

    if (propre) {
      return (
        <Tooltip title={propre.description || 'Règle définie sur cette cellule'}>
          <Chip
            size="small"
            color={propre.type_valeur === 'NULL' ? 'default' : 'primary'}
            label={afficherValeur(propre)}
            variant={propre.is_active ? 'filled' : 'outlined'}
            sx={{ maxWidth: '100%', height: 20, fontSize: 12 }}
          />
        </Tooltip>
      );
    }
    if (heritee) {
      return (
        <Tooltip title={`Hérité de la ${libelleRegle(heritee)}`}>
          <Typography variant="body2" noWrap sx={{ fontSize: 12, color: 'text.secondary' }}>
            {afficherValeur(heritee)}
          </Typography>
        </Tooltip>
      );
    }
    return (
      <Tooltip
        title={
          constante
            ? `Identique à la constante : ${afficherValeur(constante)}`
            : 'Aucune valeur : la colonne restera vide'
        }
      >
        <Typography component="span" sx={{ color: 'text.disabled', fontSize: 14, lineHeight: 1 }}>
          {constante ? DITTO : '—'}
        </Typography>
      </Tooltip>
    );
  };

  // ------------------------------------------------------------------ Routage
  // Clic = cycle hérité -> Créé -> Non créé -> hérité. La suppression de la
  // règle (retour à "hérité") est le seul moyen de revenir au repli général.
  const basculerRoutage = async (target_table: string, contract: string | null, part_family: string | null) => {
    const propre = routages.find(
      (r) => r.target_table === target_table && r.contract === contract && r.part_family === part_family
    );
    try {
      if (!propre) {
        await matrixService.savePartType({ target_table, contract, part_family, should_create: true });
      } else if (propre.should_create) {
        await matrixService.savePartType({ target_table, contract, part_family, should_create: false });
      } else {
        await matrixService.deletePartType(propre.id);
      }
      chargerRoutages();
    } catch (e) {
      setMessage({ texte: messageErreur(e, 'Erreur lors de la mise à jour du routage'), type: 'error' });
    }
  };

  const rendreCelluleRoutage = (target_table: string, contract: string | null, part_family: string | null) => {
    const reglesTable = routages.filter((r) => r.target_table === target_table);
    const propre = reglesTable.find((r) => r.contract === contract && r.part_family === part_family);
    const heritee = regleLaPlusSpecifique(reglesTable, contract, part_family);

    if (propre) {
      return (
        <Chip
          size="small"
          color={propre.should_create ? 'success' : 'error'}
          label={propre.should_create ? 'Créé' : 'Non créé'}
          sx={{ height: 20, fontSize: 12 }}
        />
      );
    }
    const libelle = heritee ? (heritee.should_create ? 'Créé' : 'Non créé') : 'Créé';
    const info = heritee
      ? `Hérité de la ${libelleRegle(heritee)}`
      : 'Aucune règle : la création est autorisée par défaut';
    return (
      <Tooltip title={info}>
        <Typography variant="body2" noWrap sx={{ fontSize: 12, color: 'text.disabled' }}>
          {libelle}
        </Typography>
      </Tooltip>
    );
  };

  // ----------------------------------------------------------- Tableau croisé
  // En-tête à deux niveaux : un groupe par site, une sous-colonne par famille.
  // Les axes viennent des données (meta) : un nouveau site ou une nouvelle
  // famille élargit le tableau sans changement de code.
  const enTete = (libelleLigne: string, avecColonnes: boolean) => (
    <TableHead>
      <TableRow>
        <TableCell
          rowSpan={2}
          sx={{
            ...styleGelee,
            left: 0,
            zIndex: 5,
            minWidth: LARGEUR_COLONNE,
            maxWidth: LARGEUR_COLONNE,
            borderRight: avecColonnes ? 0 : 2,
            borderRightColor: 'divider',
          }}
        >
          {libelleLigne}
        </TableCell>
        {avecColonnes && (
          <TableCell
            rowSpan={2}
            sx={{
              ...styleGelee,
              left: DECALAGE_LIBELLE,
              zIndex: 5,
              minWidth: LARGEUR_LIBELLE,
              maxWidth: LARGEUR_LIBELLE,
            }}
          >
            <Tooltip title="Libellé fonctionnel IFS, lu dans le catalogue des champs">
              <span>Libellé</span>
            </Tooltip>
          </TableCell>
        )}
        {avecColonnes && (
          <TableCell
            rowSpan={2}
            align="center"
            sx={{
              ...styleGelee,
              left: DECALAGE_CONSTANTE,
              zIndex: 5,
              minWidth: LARGEUR_CONSTANTE,
              borderRight: 2,
              borderRightColor: 'divider',
            }}
          >
            <Tooltip title="Valeur de Configuration > Valeurs par défaut, appliquée quand aucune règle ne correspond">
              <span>Constante</span>
            </Tooltip>
          </TableCell>
        )}
        {axeSites.map((site) => (
          <TableCell
            key={site}
            colSpan={axeFamilles.length}
            align="center"
            sx={{
              height: H_ENTETE_1,
              borderLeft: 2,
              borderLeftColor: 'divider',
              color: site === JOKER ? 'text.secondary' : 'primary.light',
              ...(site === JOKER ? {} : teinteOpaque(theme.palette.primary.main, 0.14)),
            }}
          >
            {site === JOKER ? 'Tous les sites' : site}
          </TableCell>
        ))}
      </TableRow>
      <TableRow>
        {axeSites.map((site) =>
          axeFamilles.map((fam, i) => {
            const famille = fam === JOKER ? undefined : familleParCode.get(fam);
            // Une famille livrée mais non déclarée dans le référentiel est
            // signalée : ses articles sont chargés sans documentation.
            const nonDeclaree = famille?.source === 'DONNEES';
            return (
              <TableCell
                key={`${site}-${fam}`}
                align="center"
                sx={{
                  top: H_ENTETE_1,
                  height: H_ENTETE_2,
                  borderLeft: i === 0 ? 2 : 0,
                  borderLeftColor: 'divider',
                  ...(fam === JOKER ? teinteOpaque(theme.palette.common.white, 0.05) : {}),
                }}
              >
                {fam === JOKER ? (
                  'Toutes'
                ) : (
                  <Tooltip
                    title={
                      nonDeclaree
                        ? `Famille ${fam} présente dans les données mais non déclarée. Documentez-la dans Configuration > Paramètres de la matrice.`
                        : famille?.description || famille?.libelle || `Famille ${fam}`
                    }
                  >
                    <Box>
                      <Box sx={{ color: nonDeclaree ? 'warning.main' : 'inherit' }}>
                        {fam}
                        {nonDeclaree ? ' *' : ''}
                      </Box>
                      {famille?.libelle && (
                        <Box
                          sx={{
                            fontSize: 10,
                            fontWeight: 400,
                            letterSpacing: 0,
                            textTransform: 'none',
                            color: 'text.disabled',
                            maxWidth: 130,
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                          }}
                        >
                          {famille.libelle}
                        </Box>
                      )}
                    </Box>
                  </Tooltip>
                )}
              </TableCell>
            );
          })
        )}
      </TableRow>
    </TableHead>
  );

  const cellulesLigne = (
    rendre: (contract: string | null, part_family: string | null) => React.ReactNode,
    onClick: (contract: string | null, part_family: string | null) => void
  ) =>
    axeSites.map((site) =>
      axeFamilles.map((fam, i) => (
        <TableCell
          key={`${site}-${fam}`}
          align="center"
          onClick={() => onClick(enJoker(site), enJoker(fam))}
          sx={{
            cursor: 'pointer',
            px: 1,
            minWidth: 92,
            maxWidth: 150,
            borderLeft: i === 0 ? 2 : 0,
            borderLeftColor: 'divider',
            bgcolor: fam === JOKER ? alpha(theme.palette.common.white, 0.03) : undefined,
            // Affordance d'édition : la cellule survolée se cerne d'un liseré.
            '&:hover': {
              outline: `1px solid ${theme.palette.primary.main}`,
              outlineOffset: -1,
            },
          }}
        >
          {rendre(enJoker(site), enJoker(fam))}
        </TableCell>
      ))
    );

  // Le fond des colonnes gelées suit le survol de la ligne, sinon la ligne
  // survolée paraît coupée en deux.
  const survolColonnesGelees = {
    '& .MuiTableRow-root:hover .col-gelee': teinteOpaque(theme.palette.primary.main, 0.1),
  };

  const regleCourante = cellule ? trouverPropre(cellule) : undefined;

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" gutterBottom>
        Matrice Site × Famille
      </Typography>
      <Alert severity="info" sx={{ mb: 2 }} icon={<HelpIcon />}>
        La cellule la plus précise gagne : <strong>site + famille</strong> &gt; site seul &gt; famille seule &gt;
        règle générale. Sans règle, c'est la valeur de la colonne <strong>Constante</strong> (issue de
        Configuration &gt; Valeurs par défaut) qui s'applique. Les modifications prennent effet au{' '}
        <strong>prochain chargement ETL</strong>.
      </Alert>

      <Tabs value={onglet} onChange={(_, v) => setOnglet(v)} sx={{ mb: 2 }}>
        <Tab label="Valeurs par défaut" />
        <Tab label="Routage de création" />
      </Tabs>

      {onglet === 0 && (
        <>
          <Paper sx={{ p: 2, display: 'flex', gap: 2, flexWrap: 'wrap', alignItems: 'center' }}>
            <FormControl size="small" sx={{ minWidth: 320 }}>
              <InputLabel>Table cible</InputLabel>
              <Select
                value={tableCible}
                label="Table cible"
                onChange={(e) => {
                  setTableCible(e.target.value);
                  setFiltreColonne('');
                }}
              >
                {tablesCibles.map((t) => (
                  <MenuItem key={t.table_cible} value={t.table_cible}>
                    {t.libelle ? `${t.libelle} — ${t.table_cible}` : t.table_cible}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
            <TextField
              size="small"
              label="Filtrer les colonnes"
              value={filtreColonne}
              onChange={(e) => setFiltreColonne(e.target.value)}
              disabled={!tableCible}
              sx={{ minWidth: 220 }}
            />
            <FormControlLabel
              control={
                <Checkbox
                  size="small"
                  checked={seulementRegles}
                  onChange={(e) => setSeulementRegles(e.target.checked)}
                  disabled={!tableCible}
                />
              }
              label="Seulement les colonnes ayant une règle"
            />
            {tableCible && (
              <Typography variant="body2" sx={{ color: 'text.secondary', ml: 'auto' }}>
                {colonnesAffichees.length} / {colonnesCibles.length} colonnes · {regles.length} règle(s)
              </Typography>
            )}
          </Paper>

          {!tableCible ? (
            <Alert severity="info" sx={{ mt: 2 }}>
              Choisissez une table cible pour afficher toutes ses colonnes en tableau croisé site × famille.
            </Alert>
          ) : (
            <>
              <TableContainer component={Paper} sx={{ mt: 2, maxHeight: 'calc(100vh - 360px)', minHeight: 240 }}>
                <Table size="small" stickyHeader sx={survolColonnesGelees}>
                  {enTete('Colonne', true)}
                  <TableBody>
                    {colonnesAffichees.map((col) => {
                      const constante = constantes.get(col);
                      const nbRegles = reglesParColonne.get(col)?.length ?? 0;
                      const champ = libelles.get(col);
                      // Infobulle du libellé : ce que le catalogue IFS dit du champ.
                      const infoChamp = [
                        champ?.libelle,
                        champ?.type_ifs ? `Type IFS : ${champ.type_ifs}` : null,
                        champ?.obligatoire ? 'Champ obligatoire' : null,
                        champ?.commentaire,
                      ]
                        .filter(Boolean)
                        .join(' — ');
                      return (
                        <TableRow key={col} hover>
                          <TableCell
                            className="col-gelee"
                            title={col}
                            sx={{
                              ...styleGelee,
                              left: 0,
                              zIndex: 2,
                              minWidth: LARGEUR_COLONNE,
                              maxWidth: LARGEUR_COLONNE,
                              fontSize: 13,
                              // Une colonne qui porte des règles est le point
                              // d'entrée : elle se signale dès la marge.
                              color: nbRegles ? 'text.primary' : 'text.secondary',
                              borderLeft: 2,
                              borderLeftColor: nbRegles ? 'primary.main' : 'transparent',
                            }}
                          >
                            {col}
                          </TableCell>
                          <TableCell
                            className="col-gelee"
                            sx={{
                              ...styleGelee,
                              left: DECALAGE_LIBELLE,
                              zIndex: 2,
                              minWidth: LARGEUR_LIBELLE,
                              maxWidth: LARGEUR_LIBELLE,
                              fontSize: 12,
                              color: champ?.libelle ? 'text.secondary' : 'text.disabled',
                            }}
                          >
                            <Tooltip title={infoChamp || 'Champ absent du catalogue IFS'}>
                              <span>{champ?.libelle || '—'}</span>
                            </Tooltip>
                          </TableCell>
                          <TableCell
                            className="col-gelee"
                            align="center"
                            sx={{
                              ...styleGelee,
                              left: DECALAGE_CONSTANTE,
                              zIndex: 2,
                              minWidth: LARGEUR_CONSTANTE,
                              borderRight: 2,
                              borderRightColor: 'divider',
                            }}
                          >
                            <Tooltip title={constante?.description || 'Constante de Configuration > Valeurs par défaut'}>
                              <Typography
                                variant="body2"
                                noWrap
                                sx={{ fontSize: 12, color: constante ? 'text.primary' : 'text.disabled' }}
                              >
                                {constante ? afficherValeur(constante) : '—'}
                              </Typography>
                            </Tooltip>
                          </TableCell>
                          {cellulesLigne(
                            (c, f) => rendreCelluleValeur(col, c, f),
                            (c, f) => ouvrirCellule({ colonne: col, contract: c, part_family: f })
                          )}
                        </TableRow>
                      );
                    })}
                    {colonnesAffichees.length === 0 && (
                      <TableRow>
                        <TableCell colSpan={3 + nbColonnesDonnees} align="center" sx={{ py: 4, color: 'text.secondary' }}>
                          Aucune colonne ne correspond au filtre.
                        </TableCell>
                      </TableRow>
                    )}
                  </TableBody>
                </Table>
              </TableContainer>
              <Box sx={{ display: 'flex', gap: 2.5, alignItems: 'center', flexWrap: 'wrap', mt: 1.5 }}>
                <Box sx={{ display: 'flex', gap: 0.75, alignItems: 'center' }}>
                  <Chip size="small" color="primary" label="valeur" sx={{ height: 20, fontSize: 12 }} />
                  <Typography variant="caption" color="text.secondary">
                    règle posée sur la cellule
                  </Typography>
                </Box>
                <Box sx={{ display: 'flex', gap: 0.75, alignItems: 'center' }}>
                  <Typography sx={{ fontSize: 12, color: 'text.secondary' }}>valeur</Typography>
                  <Typography variant="caption" color="text.secondary">
                    héritée d'une règle plus générale
                  </Typography>
                </Box>
                <Box sx={{ display: 'flex', gap: 0.75, alignItems: 'center' }}>
                  <Typography sx={{ color: 'text.disabled', fontSize: 14 }}>{DITTO}</Typography>
                  <Typography variant="caption" color="text.secondary">
                    identique à la constante
                  </Typography>
                </Box>
                <Typography variant="caption" color="text.secondary">
                  Cliquez sur une cellule pour définir, modifier ou supprimer sa règle.
                </Typography>
              </Box>
            </>
          )}
        </>
      )}

      {onglet === 1 && (
        <>
          <Alert severity="warning">
            Les trois tables sont indépendantes : un article peut être à la fois fabriqué, vendu et
            acheté. Passer une cellule à <strong>Non créé</strong> supprime aussi, au prochain
            chargement, les lignes déjà chargées pour ce site et cette famille.
          </Alert>
          <TableContainer component={Paper} sx={{ mt: 2 }}>
            <Table size="small" stickyHeader sx={survolColonnesGelees}>
              {enTete('Table à créer', false)}
              <TableBody>
                {meta.part_type_tables.map((t) => (
                  <TableRow key={t.target_table} hover>
                    <TableCell
                      className="col-gelee"
                      title={t.target_table}
                      sx={{
                        ...styleGelee,
                        left: 0,
                        zIndex: 2,
                        minWidth: LARGEUR_COLONNE,
                        maxWidth: LARGEUR_COLONNE,
                        borderRight: 2,
                        borderRightColor: 'divider',
                      }}
                    >
                      {t.libelle}
                    </TableCell>
                    {cellulesLigne(
                      (c, f) => rendreCelluleRoutage(t.target_table, c, f),
                      (c, f) => basculerRoutage(t.target_table, c, f)
                    )}
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
          <Typography variant="caption" sx={{ display: 'block', mt: 1.5, color: 'text.secondary' }}>
            Chaque clic fait défiler : hérité → Créé → Non créé → hérité.
          </Typography>
        </>
      )}

      <Dialog open={cellule !== null} onClose={() => setCellule(null)} maxWidth="sm" fullWidth>
        <DialogTitle>{cellule?.colonne}</DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 1 }}>
          <DialogContentText variant="body2">
            {cellule ? libelleRegle(cellule) : ''} — table <strong>{tableCible}</strong>
            {cellule && constantes.get(cellule.colonne) && (
              <>
                <br />
                Constante actuelle : <strong>{afficherValeur(constantes.get(cellule.colonne)!)}</strong>
              </>
            )}
          </DialogContentText>
          <RadioGroup row value={typeEdit} onChange={(e) => setTypeEdit(e.target.value as 'CONSTANTE' | 'NULL')}>
            <FormControlLabel value="CONSTANTE" control={<Radio />} label="Valeur" />
            <FormControlLabel value="NULL" control={<Radio />} label="NULL (colonne laissée vide)" />
          </RadioGroup>
          {typeEdit === 'CONSTANTE' && (
            <TextField
              label="Valeur"
              size="small"
              autoFocus
              value={valeurEdit}
              onChange={(e) => setValeurEdit(e.target.value)}
              helperText="La valeur doit être compatible avec le type de la colonne cible (contrôlé à l'enregistrement)."
            />
          )}
          <TextField
            label="Description"
            size="small"
            multiline
            minRows={2}
            value={descriptionEdit}
            onChange={(e) => setDescriptionEdit(e.target.value)}
          />
        </DialogContent>
        <DialogActions>
          {regleCourante && (
            <Button color="error" startIcon={<DeleteIcon />} onClick={supprimerCellule}>
              Supprimer la règle
            </Button>
          )}
          <Box sx={{ flex: 1 }} />
          <Button onClick={() => setCellule(null)}>Annuler</Button>
          <Button variant="contained" onClick={enregistrerCellule}>
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

export default MatriceSiteFamille;
