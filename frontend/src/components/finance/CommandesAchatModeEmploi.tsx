import { Box, Button, Chip, Paper, Table, TableBody, TableCell, TableHead, TableRow, Typography } from '@mui/material';
import React from 'react';
import { useNavigate } from 'react-router-dom';

// Onglet « Mode d'emploi » de l'écran Finance > Commandes d'achat.
// Source des règles : sql/commandeAchat/02_alimenter_commande_achat_ifs.sql (table à plat)
// et 04_alimenter_purchase_order.sql (dispatch IFS). À mettre à jour avec ces procédures.

const Section: React.FC<{ titre: string; children: React.ReactNode }> = ({ titre, children }) => (
  <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
    <Typography variant="h6" sx={{ mb: 1 }}>{titre}</Typography>
    {children}
  </Paper>
);

const Liste: React.FC<{ items: React.ReactNode[] }> = ({ items }) => (
  <Box component="ul" sx={{ m: 0, pl: 3, '& li': { mb: 0.5 } }}>
    {items.map((it, i) => <li key={i}><Typography variant="body2">{it}</Typography></li>)}
  </Box>
);

const Tableau: React.FC<{ entetes: string[]; lignes: React.ReactNode[][] }> = ({ entetes, lignes }) => (
  <Table size="small" sx={{ mb: 1 }}>
    <TableHead>
      <TableRow>{entetes.map((e) => <TableCell key={e} sx={{ fontWeight: 600 }}>{e}</TableCell>)}</TableRow>
    </TableHead>
    <TableBody>
      {lignes.map((l, i) => (
        <TableRow key={i}>{l.map((c, j) => <TableCell key={j} sx={{ verticalAlign: 'top' }}>{c}</TableCell>)}</TableRow>
      ))}
    </TableBody>
  </Table>
);

const Code: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <Box component="code" sx={{ bgcolor: 'action.hover', px: 0.5, borderRadius: 0.5 }}>{children}</Box>
);

const CommandesAchatModeEmploi: React.FC = () => {
  const navigate = useNavigate();

  return (
    <Box sx={{ maxWidth: 1200 }}>
      <Section titre="1. Le circuit en deux étapes">
        <Liste items={[
          <>
            <b>Étape 1 : extraction SAP → table à plat</b> (onglet « Commandes d'achat SAP ») : une ligne par poste de
            commande SAP ouvert, avec les identifiants SAP <i>et</i> IFS côte à côte, pour contrôle.
          </>,
          <>
            <b>Étape 2 : dispatch → objets de reprise IFS</b> (onglets « Purchase order », « Order line part »,
            « Order line no part ») : la table à plat est éclatée au format exact des fichiers de chargement IFS
            (Lot 11), avec les transcodifications et les valeurs par défaut appliquées.
          </>,
          <>Les deux étapes s'enchaînent automatiquement à chaque « Recalculer » ou « Synchroniser SAP ».</>,
        ]} />
      </Section>

      <Section titre="2. Utiliser l'écran">
        <Tableau
          entetes={['Action', 'Effet', 'Quand l\'utiliser']}
          lignes={[
            [<b>Recalculer</b>, 'Recharge la table à plat depuis les tables SAP déjà extraites, puis relance le dispatch IFS. N\'appelle pas SAP (1 à 2 min).',
              'Après avoir modifié une transcodification ou une valeur par défaut.'],
            [<b>Synchroniser SAP</b>, 'Ré-extrait de SAP EKKO, EKPO, EKBE, EKET, EKPA, EKKN, LFA1, T001W, ADRC, PRPS, puis fait un « Recalculer ».',
              'Pour prendre en compte les dernières commandes, réceptions et factures SAP.'],
            [<b>Exporter Excel</b>, 'Classeur de l\'onglet affiché, toutes les colonnes, toutes les pages.', 'Contrôle d\'un onglet.'],
            [<b>Exporter tout (ZIP)</b>, 'Classeur des 4 onglets + PURCHASE_ORDER.csv, PURCHASE_ORDER_LINE_PART.csv, PURCHASE_ORDER_LINE_NOPART.csv (format IFS : « ; », UTF-8, dates JJ/MM/AAAA, virgule décimale).',
              'Livraison des fichiers de chargement IFS.'],
            [<b>Recherche / Site</b>, 'Filtrent la liste et les exports (y compris le ZIP).', 'Sans filtre, les exports contiennent tout.'],
            [<b>Toutes les colonnes</b>, 'Affiche toutes les colonnes au lieu des colonnes principales.', '—'],
          ]}
        />
        <Typography variant="body2" color="text.secondary">
          Un rechargement est en cours ? Le bandeau bleu affiche sa progression ; la liste se met à jour à la fin.
          Un seul rechargement à la fois.
        </Typography>
      </Section>

      <Section titre="3. Règles de gestion – étape 1 (commandes d'achat SAP)">
        <Liste items={[
          <><b>Périmètre</b> : commandes fermes (type F) de la société <b>STJN</b>, non supprimées ; postes non supprimés, <b>non clos</b> (pas d'indicateur « livraison finale ») et avec une quantité restant à livrer &gt; 0.</>,
          <><b>Site</b> : déduit de la division du poste – 9200 / 2200 → <b>SJ</b>, 9000 / 2000 → <b>CS</b>.</>,
          <><b>Quantités</b> : reçu = réceptions (EKBE), facturé = factures et avoirs, annulations déduites ; restant = commandé − reçu / facturé, jamais négatif.</>,
          <><b>Prix net unitaire</b> = prix net SAP ÷ base de prix ; montants = reliquat × prix, dans la devise de la commande.</>,
          <><b>Dates</b> : livraison planifiée / promise = prochaine échéance à venir (sinon la dernière) ; réception souhaitée = dernière réception.</>,
          <><b>Fournisseur IFS</b> : numéro de compte du fichier de sélection des fournisseurs (600001…) ; vide si le fournisseur n'y figure pas. Fournisseur de facturation = partenaire SAP RS (sinon PI), à défaut le fournisseur de la commande.</>,
          <><b>Pré-imputation</b> (lisible) : PROJET= &gt; CENTRE_COUT= &gt; ORDRE= &gt; COMPTE=, d'après l'imputation EKKN du poste.</>,
          <><b>Élément OTP</b> : PRPS de l'imputation ; <b>N° projet</b> : projet SharePoint de cet OTP (rapprochement sans les points ni le suffixe IM / EX / EP : <Code>SN26052IM</Code> ↔ <Code>SN.26052</Code>).</>,
          <><b>Centre de coûts SAP</b> (colonne technique) : celui de l'imputation, ou pour un poste imputé sur un ordre, le centre responsable de l'ordre.</>,
        ]} />
      </Section>

      <Section titre="4. Règles de gestion – étape 2 (objets IFS)">
        <Liste items={[
          <><b>Commandes reprises</b> : celles qui ont déjà une réception, ou créées dans les <b>6 mois</b> précédant la <b>date de bascule</b> (01/09/2026). Les deux se paramètrent dans Valeurs par défaut (<Code>purchase_order.order_date</Code>, <Code>purchase_order.mois_anteriorite</Code>).</>,
          <><b>N° de commande IFS</b> = « S » + n° SAP ; <b>LINE_NO</b> = n° de poste SAP sans zéros (00010 → 10) ; ORDER_DATE = date de bascule.</>,
          <><b>Lignes PART</b> : postes avec un article présent dans le catalogue IFS (<Code>part_catalog</Code>) ; <b>NOPART</b> : postes sans article.</>,
          <><b>Adresse de livraison</b> : adresse du site de la commande (Saint-Jean ou Castelsarrasin), paramétrée dans Valeurs par défaut.</>,
          <><b>Exclusions</b> (journal du chargement) : commande sans fournisseur IFS, sans fournisseur de facturation IFS ou sans condition de paiement IFS (en-tête et lignes exclus) ; poste avec un article absent du catalogue IFS.</>,
        ]} />
      </Section>

      <Section titre="5. Identifiants IFS et transcodifications appliqués">
        <Tableau
          entetes={['Colonne IFS', 'Règle (dans l\'ordre de priorité)', 'Où corriger']}
          lignes={[
            [<Code>VENDOR_NO</Code>, 'ID fournisseur IFS de la fiche fournisseur (rapproché sur le n° SAP).', 'Module fournisseurs / fichier de sélection'],
            [<Code>INVOICING_SUPPLIER</Code>, 'ID IFS du fournisseur de facturation ; s\'il est identique au fournisseur commandé, VENDOR_NO.', 'Idem'],
            [<Code>ADDR_NO</Code>, 'Adresse IFS du fournisseur ; à défaut valeur par défaut « 1 ».', 'Valeurs par défaut'],
            [<Code>PART_NO</Code>, 'Article du catalogue IFS (n° SAP sans zéros de tête).', 'Modules articles'],
            [<Code>PAY_TERM_ID</Code>, <>Transco <Chip size="small" label="PAY_TERM" /> du code SAP ; sinon condition de la fiche fournisseur IFS ; sinon commande exclue.</>, 'Transcodification'],
            [<Code>DELIVERY_TERMS</Code>, 'Incoterm SAP (3 lettres reconnues : DDP, DAP, CPT, FCA, EXW…) ; sinon Incoterm du fournisseur IFS ; sinon valeur par défaut (DDP).', 'Valeurs par défaut'],
            [<Code>DEL_TERMS_LOCATION</Code>, 'Suite du libellé SAP après l\'Incoterm (« DDP Saint Jean » → « Saint Jean »), seulement si l\'Incoterm vient de SAP.', '—'],
            [<Code>SHIP_VIA_CODE</Code>, 'Mode d\'expédition SAP ; sinon celui du fournisseur IFS ; sinon valeur par défaut (10).', 'Valeurs par défaut'],
            [<Code>PRE_ACCOUNTING_ID</Code>, <>Transco <Chip size="small" label="COST_CENTER" /> du centre de coûts SAP (imputation, ou centre responsable de l'ordre) ; vide si non transcodé ou poste imputé sur OTP.</>, 'Transcodification'],
            [<Code>PROJECT_ID</Code>, 'N° projet SharePoint de l\'élément OTP.', 'SharePoint projets'],
            [<Code>BUY_UNIT_MEAS</Code>, <>Transco <Chip size="small" label="UOM" /> de l'unité SAP ; « * » (unité générique IFS) si non transcodée.</>, 'Transcodification'],
            ['Autres colonnes', 'Constantes du modèle IFS Lot 11 (module « commandeAchat »).', 'Valeurs par défaut'],
          ]}
        />
        <Tableau
          entetes={['Transcodification', 'Contenu', 'Origine']}
          lignes={[
            [<Chip size="small" label="PAY_TERM" />, 'Condition de paiement SAP → IFS (12 codes).', 'Déduite du fichier Lot 11 V2, à valider ; F045, M015, M100 non transcodés (plusieurs codes IFS selon le fournisseur).'],
            [<Chip size="small" label="COST_CENTER" />, 'Centre de coûts SAP → IFS (202 centres).', 'Fichier métier centredecouts.csv ; 92E210900 et 92E310900 réduits à un seul code IFS.'],
            [<Chip size="small" label="UOM" />, 'Unité SAP → IFS.', 'Commune à tous les modules.'],
          ]}
        />
        <Box sx={{ display: 'flex', gap: 1, mt: 1 }}>
          <Button variant="outlined" size="small" onClick={() => navigate('/transcodification')}>Ouvrir Transcodification</Button>
          <Button variant="outlined" size="small" onClick={() => navigate('/configuration/valeurs-defaut')}>Ouvrir Valeurs par défaut</Button>
        </Box>
        <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
          Une transcodification ou une valeur par défaut modifiée ne s'applique qu'au prochain « Recalculer ».
        </Typography>
      </Section>
    </Box>
  );
};

export default CommandesAchatModeEmploi;
