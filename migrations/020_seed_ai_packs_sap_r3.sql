-- =====================================================
-- Migration: Assistant IA — packs de connaissances SAP R/3 4.6C additionnels
-- Description:
--   Enrichit les prompts de l'Assistant IA (écran « Configuration IA ») en
--   ajoutant de NOUVEAUX domaines métier SAP non encore couverts par les
--   packs d'origine (clients, fournisseurs, factures, achats, articles_stock,
--   equipements). On peuple les deux tables éditables de la migration 019 :
--     - public.ai_packs           (1 ligne = 1 domaine, content JSONB)
--     - public.ai_domain_tables   (routage mot-clé -> tables)
--
--   Domaines ajoutés (standard SAP R/3 4.6C / ECC) :
--     1. comptabilite_generale  (FI/GL) : bkpf, bseg, ska1, skat, skb1
--     2. immobilisations        (FI-AA) : anla, anlz, anlc
--     3. centres_cout           (CO)    : csks, cskt
--     4. organisation           (Org.)  : t001, t001w, t001l, t001k
--     5. postes_techniques      (PM)    : iflot, iflotx
--
-- Anti-hallucination : chaque domaine n'est inséré QUE si TOUTES ses tables
--   existent réellement dans le schéma raw_data (sinon RAISE NOTICE + skip).
--   On ne référence jamais une table absente dans le prompt.
--
-- Date: 2026-06-15
-- Idempotent : ON CONFLICT (domain) DO UPDATE sur ai_packs +
--              DELETE/INSERT par domain_id sur ai_domain_tables.
--              Rejouable sans effet de bord. N'écrase aucun domaine existant.
-- Prérequis : migration 019_create_ai_config_editable.sql jouée.
-- =====================================================

-- ----------------------------------------------------
-- 1. Comptabilité générale / Grand livre (FI-GL)
-- ----------------------------------------------------
DO $blk$
DECLARE
    v_domaine  TEXT   := 'comptabilite_generale';
    v_tables   TEXT[] := ARRAY['bkpf','bseg','ska1','skat','skb1'];
    v_missing  TEXT;
BEGIN
    SELECT string_agg(t, ', ') INTO v_missing
    FROM unnest(v_tables) AS t
    WHERE NOT EXISTS (SELECT 1 FROM information_schema.tables
                      WHERE table_schema = 'raw_data' AND table_name = t);

    IF v_missing IS NOT NULL THEN
        RAISE NOTICE 'Domaine % ignoré (table(s) absente(s) dans raw_data : %).', v_domaine, v_missing;
    ELSE
        INSERT INTO public.ai_packs (domain, content) VALUES (v_domaine, $j$
{
  "domain": "comptabilite_generale",
  "keywords": ["comptabilite","compta","ecriture","ecritures","piece comptable","grand livre","compte general","balance","fi"],
  "synonyms": ["g/l","general ledger","journal comptable"],
  "docs": [
    "Piece comptable active = bkpf.stblg vide (non contre-passee)",
    "Montants stockes en varchar -> CAST ::numeric. Debit = shkzg='S', Credit = shkzg='H'."
  ],
  "tables": ["raw_data.bkpf","raw_data.bseg","raw_data.ska1","raw_data.skat","raw_data.skb1"],
  "joins": [
    "bkpf (entete piece) <-> bseg (postes) sur (mandt,bukrs,belnr,gjahr)",
    "bseg.hkont = ska1.saknr (compte general) ; libelle via skat (mandt,ktopl,saknr,spras='F')",
    "skb1 = donnees du compte general par societe sur (mandt,bukrs,saknr)"
  ],
  "enums": [
    "bkpf.blart=type de piece, budat=date compta, bldat=date piece (YYYYMMDD), waers=devise, stblg vide=NON contre-passee",
    "bseg.koart=type de compte (S=general,D=client,K=fournisseur,A=immo,M=article) ; shkzg=sens (S=debit,H=credit)",
    "bseg.dmbtr=montant en monnaie interne (::numeric), wrbtr=montant devise piece (::numeric), hkont=compte general, kostl=centre de cout"
  ],
  "rules": [
    "bkpf/bseg = comptabilite financiere (FI), a NE PAS confondre avec les factures logistiques (rbkp/rseg).",
    "Piece active = bkpf.stblg vide/NULL. Jointure bseg toujours sur (mandt,bukrs,belnr,gjahr). Montants varchar -> ::numeric."
  ],
  "patterns": [
    {
      "intent": "total des ecritures par compte general",
      "sql": "SELECT b.hkont, SUM(b.dmbtr::numeric) AS total FROM raw_data.bkpf k JOIN raw_data.bseg b ON b.mandt=k.mandt AND b.bukrs=k.bukrs AND b.belnr=k.belnr AND b.gjahr=k.gjahr WHERE k.mandt='700' AND (k.stblg IS NULL OR k.stblg='') GROUP BY b.hkont ORDER BY total DESC"
    }
  ]
}
$j$::jsonb)
        ON CONFLICT (domain) DO UPDATE
            SET content = EXCLUDED.content, date_maj = CURRENT_TIMESTAMP;

        DELETE FROM public.ai_domain_tables WHERE domain_id = v_domaine;
        INSERT INTO public.ai_domain_tables (domain_id, keywords, tables, position)
        VALUES (
            v_domaine,
            $j$["comptabilite","compta","ecriture","ecritures","piece comptable","grand livre","compte general","balance","fi"]$j$::jsonb,
            $j$["raw_data.bkpf","raw_data.bseg","raw_data.ska1","raw_data.skat","raw_data.skb1"]$j$::jsonb,
            (SELECT COALESCE(MAX(position), 0) + 1 FROM public.ai_domain_tables)
        );
        RAISE NOTICE 'Domaine % ajouté / mis à jour.', v_domaine;
    END IF;
END $blk$;

-- ----------------------------------------------------
-- 2. Immobilisations (FI-AA)
-- ----------------------------------------------------
DO $blk$
DECLARE
    v_domaine  TEXT   := 'immobilisations';
    v_tables   TEXT[] := ARRAY['anla','anlz','anlc'];
    v_missing  TEXT;
BEGIN
    SELECT string_agg(t, ', ') INTO v_missing
    FROM unnest(v_tables) AS t
    WHERE NOT EXISTS (SELECT 1 FROM information_schema.tables
                      WHERE table_schema = 'raw_data' AND table_name = t);

    IF v_missing IS NOT NULL THEN
        RAISE NOTICE 'Domaine % ignoré (table(s) absente(s) dans raw_data : %).', v_domaine, v_missing;
    ELSE
        INSERT INTO public.ai_packs (domain, content) VALUES (v_domaine, $j$
{
  "domain": "immobilisations",
  "keywords": ["immobilisation","immobilisations","immo","actif immobilise","asset","amortissement"],
  "synonyms": ["fixed asset","bien immobilise"],
  "docs": [
    "Immobilisation active = anla.lvorm vide ET deakt vide/0 (non desactivee, non marquee suppression)",
    "Cle immo = (bukrs, anln1 [numero principal], anln2 [sous-numero])"
  ],
  "tables": ["raw_data.anla","raw_data.anlz","raw_data.anlc"],
  "joins": [
    "anla (fiche immo) <-> anlz (affectation temporelle: kostl, werks) sur (mandt,bukrs,anln1,anln2)",
    "anla <-> anlc (valeurs cumulees par exercice gjahr) sur (mandt,bukrs,anln1,anln2)"
  ],
  "enums": [
    "anla.anlkl=classe d'immobilisation, txt50=libelle, aktiv=date mise en service (YYYYMMDD), deakt=date desactivation, lvorm='X'=marquee suppression",
    "anlz.kostl=centre de cout d'affectation, werks=division ; anlc.gjahr=exercice, kansw=valeur d'acquisition (::numeric)"
  ],
  "rules": [
    "Cle immo = (bukrs, anln1, anln2). Active = anla.lvorm vide/NULL ET (deakt vide OU deakt='00000000').",
    "Valeurs/montants en varchar -> CAST ::numeric. Affectation centre de cout / division via anlz."
  ],
  "patterns": [
    {
      "intent": "nombre d'immobilisations actives par classe",
      "sql": "SELECT a.anlkl, COUNT(*) AS nb FROM raw_data.anla a WHERE a.mandt='700' AND (a.lvorm IS NULL OR a.lvorm='') GROUP BY a.anlkl ORDER BY nb DESC"
    }
  ]
}
$j$::jsonb)
        ON CONFLICT (domain) DO UPDATE
            SET content = EXCLUDED.content, date_maj = CURRENT_TIMESTAMP;

        DELETE FROM public.ai_domain_tables WHERE domain_id = v_domaine;
        INSERT INTO public.ai_domain_tables (domain_id, keywords, tables, position)
        VALUES (
            v_domaine,
            $j$["immobilisation","immobilisations","immo","actif immobilise","asset","amortissement"]$j$::jsonb,
            $j$["raw_data.anla","raw_data.anlz","raw_data.anlc"]$j$::jsonb,
            (SELECT COALESCE(MAX(position), 0) + 1 FROM public.ai_domain_tables)
        );
        RAISE NOTICE 'Domaine % ajouté / mis à jour.', v_domaine;
    END IF;
END $blk$;

-- ----------------------------------------------------
-- 3. Centres de coût (CO)
-- ----------------------------------------------------
DO $blk$
DECLARE
    v_domaine  TEXT   := 'centres_cout';
    v_tables   TEXT[] := ARRAY['csks','cskt'];
    v_missing  TEXT;
BEGIN
    SELECT string_agg(t, ', ') INTO v_missing
    FROM unnest(v_tables) AS t
    WHERE NOT EXISTS (SELECT 1 FROM information_schema.tables
                      WHERE table_schema = 'raw_data' AND table_name = t);

    IF v_missing IS NOT NULL THEN
        RAISE NOTICE 'Domaine % ignoré (table(s) absente(s) dans raw_data : %).', v_domaine, v_missing;
    ELSE
        INSERT INTO public.ai_packs (domain, content) VALUES (v_domaine, $j$
{
  "domain": "centres_cout",
  "keywords": ["centre de cout","centres de cout","cost center","kostl","controlling","centre analytique"],
  "synonyms": ["co","centre de frais"],
  "docs": [
    "Version courante d'un centre de cout = datbi='99991231' (date de fin de validite maximale)",
    "Libelle via cskt (spras='F')"
  ],
  "tables": ["raw_data.csks","raw_data.cskt"],
  "joins": [
    "csks (donnees de base) <-> cskt (libelles, spras='F') sur (mandt,kokrs,kostl,datbi)"
  ],
  "enums": [
    "csks.kokrs=perimetre analytique, kostl=centre de cout, datbi=date fin de validite (souvent 99991231), bukrs=societe, werks=division, verak=responsable",
    "cskt.ktext=libelle court, ltext=libelle long (spras='F')"
  ],
  "rules": [
    "Cle temporelle datbi : pour la version courante filtrer datbi='99991231' (ou MAX(datbi) par kostl) afin d'eviter les doublons d'historique.",
    "Libelle toujours via cskt avec spras='F'. Jointure sur (mandt,kokrs,kostl,datbi)."
  ],
  "patterns": [
    {
      "intent": "liste des centres de cout actifs avec libelle",
      "sql": "SELECT c.kostl, t.ktext FROM raw_data.csks c JOIN raw_data.cskt t ON t.mandt=c.mandt AND t.kokrs=c.kokrs AND t.kostl=c.kostl AND t.datbi=c.datbi AND t.spras='F' WHERE c.mandt='700' AND c.datbi='99991231' ORDER BY c.kostl"
    }
  ]
}
$j$::jsonb)
        ON CONFLICT (domain) DO UPDATE
            SET content = EXCLUDED.content, date_maj = CURRENT_TIMESTAMP;

        DELETE FROM public.ai_domain_tables WHERE domain_id = v_domaine;
        INSERT INTO public.ai_domain_tables (domain_id, keywords, tables, position)
        VALUES (
            v_domaine,
            $j$["centre de cout","centres de cout","cost center","kostl","controlling","centre analytique"]$j$::jsonb,
            $j$["raw_data.csks","raw_data.cskt"]$j$::jsonb,
            (SELECT COALESCE(MAX(position), 0) + 1 FROM public.ai_domain_tables)
        );
        RAISE NOTICE 'Domaine % ajouté / mis à jour.', v_domaine;
    END IF;
END $blk$;

-- ----------------------------------------------------
-- 4. Structure organisationnelle (sociétés / divisions / magasins)
-- ----------------------------------------------------
DO $blk$
DECLARE
    v_domaine  TEXT   := 'organisation';
    v_tables   TEXT[] := ARRAY['t001','t001w','t001l','t001k'];
    v_missing  TEXT;
BEGIN
    SELECT string_agg(t, ', ') INTO v_missing
    FROM unnest(v_tables) AS t
    WHERE NOT EXISTS (SELECT 1 FROM information_schema.tables
                      WHERE table_schema = 'raw_data' AND table_name = t);

    IF v_missing IS NOT NULL THEN
        RAISE NOTICE 'Domaine % ignoré (table(s) absente(s) dans raw_data : %).', v_domaine, v_missing;
    ELSE
        INSERT INTO public.ai_packs (domain, content) VALUES (v_domaine, $j$
{
  "domain": "organisation",
  "keywords": ["societe","societes","division","divisions","magasin","magasins","usine","plant","werks","organisation","structure","bukrs"],
  "synonyms": ["entite juridique","etablissement","depot"],
  "docs": [
    "Tables de personnalisation (Customizing) : servent a traduire un code (bukrs/werks/lgort) en libelle lisible",
    "Domaine de valorisation (bwkey) lie a la societe via t001k"
  ],
  "tables": ["raw_data.t001","raw_data.t001w","raw_data.t001l","raw_data.t001k"],
  "joins": [
    "t001 (societes) sur (mandt,bukrs) ; t001k.bukrs = t001.bukrs [domaine de valorisation bwkey]",
    "t001w (divisions/usines) sur (mandt,werks) ; t001l (magasins) <-> t001w sur (mandt,werks) [lgort par division]"
  ],
  "enums": [
    "t001.butxt=nom societe, land1=pays, waers=devise, ktopl=plan comptable",
    "t001w.name1=nom division, ort01=ville, land1=pays ; t001l.lgort=magasin, lgobe=libelle magasin ; t001k.bwkey=domaine de valorisation"
  ],
  "rules": [
    "Filtrer toujours sur mandt. Pas de marqueur de suppression standard sur ces tables de Customizing.",
    "Utiliser ces tables pour enrichir un resultat avec un libelle lisible (ex: werks -> t001w.name1, bukrs -> t001.butxt)."
  ],
  "patterns": [
    {
      "intent": "liste des divisions avec ville",
      "sql": "SELECT w.werks, w.name1, w.ort01 FROM raw_data.t001w w WHERE w.mandt='700' ORDER BY w.werks"
    }
  ]
}
$j$::jsonb)
        ON CONFLICT (domain) DO UPDATE
            SET content = EXCLUDED.content, date_maj = CURRENT_TIMESTAMP;

        DELETE FROM public.ai_domain_tables WHERE domain_id = v_domaine;
        INSERT INTO public.ai_domain_tables (domain_id, keywords, tables, position)
        VALUES (
            v_domaine,
            $j$["societe","societes","division","divisions","magasin","magasins","usine","plant","werks","organisation","structure","bukrs"]$j$::jsonb,
            $j$["raw_data.t001","raw_data.t001w","raw_data.t001l","raw_data.t001k"]$j$::jsonb,
            (SELECT COALESCE(MAX(position), 0) + 1 FROM public.ai_domain_tables)
        );
        RAISE NOTICE 'Domaine % ajouté / mis à jour.', v_domaine;
    END IF;
END $blk$;

-- ----------------------------------------------------
-- 5. Postes techniques (PM)
-- ----------------------------------------------------
DO $blk$
DECLARE
    v_domaine  TEXT   := 'postes_techniques';
    v_tables   TEXT[] := ARRAY['iflot','iflotx'];
    v_missing  TEXT;
BEGIN
    SELECT string_agg(t, ', ') INTO v_missing
    FROM unnest(v_tables) AS t
    WHERE NOT EXISTS (SELECT 1 FROM information_schema.tables
                      WHERE table_schema = 'raw_data' AND table_name = t);

    IF v_missing IS NOT NULL THEN
        RAISE NOTICE 'Domaine % ignoré (table(s) absente(s) dans raw_data : %).', v_domaine, v_missing;
    ELSE
        INSERT INTO public.ai_packs (domain, content) VALUES (v_domaine, $j$
{
  "domain": "postes_techniques",
  "keywords": ["poste technique","postes techniques","functional location","tplnr","localisation technique","emplacement technique"],
  "synonyms": ["pm","maintenance technique"],
  "docs": [
    "Libelle d'un poste technique via iflotx (spras='F')",
    "Hierarchie des postes via iflot.tplma (poste technique superieur)"
  ],
  "tables": ["raw_data.iflot","raw_data.iflotx"],
  "joins": [
    "iflot (poste technique) <-> iflotx (libelles, spras='F') sur (mandt,tplnr)",
    "iflot.tplma = poste technique superieur (hierarchie) -> iflot.tplnr"
  ],
  "enums": [
    "iflot.tplnr=identifiant poste technique, fltyp=categorie, tplma=poste superieur (hierarchie), tplkz=indicatif de structure",
    "iflotx.pltxt=libelle du poste (spras='F')"
  ],
  "rules": [
    "Libelle via iflotx avec spras='F'. Hierarchie via iflot.tplma (poste pere).",
    "Ne PAS supposer de lien direct equi -> iflot sans verifier les colonnes reelles de equi (cf. domaine equipements)."
  ],
  "patterns": [
    {
      "intent": "liste des postes techniques avec libelle",
      "sql": "SELECT f.tplnr, x.pltxt FROM raw_data.iflot f JOIN raw_data.iflotx x ON x.mandt=f.mandt AND x.tplnr=f.tplnr AND x.spras='F' WHERE f.mandt='700' ORDER BY f.tplnr"
    }
  ]
}
$j$::jsonb)
        ON CONFLICT (domain) DO UPDATE
            SET content = EXCLUDED.content, date_maj = CURRENT_TIMESTAMP;

        DELETE FROM public.ai_domain_tables WHERE domain_id = v_domaine;
        INSERT INTO public.ai_domain_tables (domain_id, keywords, tables, position)
        VALUES (
            v_domaine,
            $j$["poste technique","postes techniques","functional location","tplnr","localisation technique","emplacement technique"]$j$::jsonb,
            $j$["raw_data.iflot","raw_data.iflotx"]$j$::jsonb,
            (SELECT COALESCE(MAX(position), 0) + 1 FROM public.ai_domain_tables)
        );
        RAISE NOTICE 'Domaine % ajouté / mis à jour.', v_domaine;
    END IF;
END $blk$;

-- ----------------------------------------------------
-- 6. Confirmation
-- ----------------------------------------------------
DO $blk$
DECLARE v_dom INTEGER; v_pck INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_dom FROM public.ai_domain_tables;
    SELECT COUNT(*) INTO v_pck FROM public.ai_packs;
    RAISE NOTICE '----------------------------------------------------';
    RAISE NOTICE 'ai_domain_tables : % ligne(s) au total ; ai_packs : % ligne(s) au total.', v_dom, v_pck;
    RAISE NOTICE 'Les nouveaux packs sont editables depuis l''ecran « Configuration IA ».';
    RAISE NOTICE 'Si la recherche semantique est active, re-indexer : python backend/build_ai_index.py';
    RAISE NOTICE '----------------------------------------------------';
END $blk$;
