# Reprise des commandes d'achat SAP vers IFS – règles de gestion

Objet : alimentation de la table de reprise `clean_data.commande_achat_ifs` (module ETL « Commandes d'achat SAP (ouvertes) », export « Commandes d'achat »).

## 1. Périmètre

Sont reprises les **commandes d'achat SAP ouvertes de la société STJN**, c'est-à-dire :

- les commandes d'achat fermes (type de document `F`), non supprimées ;
- de la seule société **STJN** – l'ancienne société APSJ (arrêtée en 2014) est exclue ;
- et, pour chaque commande, les postes non supprimés relevant de l'un des cas suivants (règle du 23/10/2026) :
  1. **réception non facturée** (quantité réceptionnée supérieure à la quantité facturée, sans indicateur « facture finale ») : repris **quelle que soit l'ancienneté de la commande**, même si le poste est clôturé en livraison (« livraison finale » cochée) ; il n'a alors plus rien à livrer et son reste à facturer est la quantité réceptionnée moins la quantité facturée ;
  2. **poste ouvert déjà partiellement réceptionné** (pas de « livraison finale », reste à livrer strictement positif) : repris sans limite de date ;
  3. **poste ouvert sans aucune réception** : repris uniquement si la commande a été **créée à partir du 01/03/2026**. Cette date se modifie dans l'écran *Valeurs par défaut* (module commandeAchat, colonne `date_creation_min_sans_reception`) et s'applique au prochain chargement.

Conséquences à connaître :

- une commande n'apparaît que par ses postes repris ; un poste totalement livré et facturé n'est pas repris, même si d'autres postes de la même commande le sont ;
- un poste **partiellement livré puis clôturé** par l'acheteur, entièrement facturé, est considéré comme soldé et n'est pas repris ;
- un poste ancien **jamais réceptionné** et créé avant la date paramétrée n'est pas repris, même s'il n'a jamais été clôturé dans SAP.

La table est un **instantané** : elle est vidée et rechargée intégralement à chaque exécution, les reliquats reflètent donc l'état de SAP au moment du chargement.

## 2. Structure : une ligne par poste

La table est « à plat » : **une ligne par poste de commande** (numéro de commande + numéro de poste). Les informations d'en-tête (fournisseur, devise, conditions, acheteur, date de création) sont répétées sur chaque poste.

## 3. Type de ligne IFS : PART / NOPART

- **PART** : le poste SAP porte un numéro d'article → ligne IFS « article » ; le numéro d'article est repris **sans les zéros de tête SAP**. Depuis le 18/11/2026, la ligne est reprise **même si l'article est absent du catalogue article IFS** (`part_catalog`, limité au périmètre Finance > Articles) : le nombre de ces lignes est seulement signalé dans le journal du chargement.
- **NOPART** : le poste SAP n'a pas d'article (prestations, locations, études, travaux, achats non stockés) → ligne IFS « hors catalogue », décrite par sa désignation seule.

La désignation est le texte court du poste SAP, débarrassé des caractères de contrôle.

## 4. Fournisseur

- Le fournisseur de la commande et le fournisseur de facturation sont repris avec leur **numéro SAP** et leur **numéro de compte IFS**.
- Le numéro IFS est celui **arbitré par le métier dans le fichier de sélection des fournisseurs** (numéros 600001 et suivants). Un fournisseur absent de ce fichier a un numéro IFS **vide** : la ligne est reprise mais devra être complétée ou le fournisseur ajouté au fichier.
- Le fournisseur de facturation est le partenaire SAP « émetteur de facture » (rôle RS, à défaut PI) de la commande ; s'il n'y en a pas, c'est le fournisseur de la commande.

## 5. Site

Le site IFS est déduit de la **division SAP du poste** : divisions 9200 (et historique 2200) → **SJ** (Saint-Jean-de-Maurienne), divisions 9000 (et historique 2000) → **CS** (Castelsarrasin). La société n'est pas utilisée pour cela car STJN couvre les deux usines.

## 6. Quantités et montants

- **Quantité commandée** : quantité du poste SAP.
- **Quantité reçue** : somme des réceptions de marchandises de l'historique du poste (les annulations sont déduites).
- **Quantité facturée** : somme des factures et avoirs de l'historique du poste (les annulations sont déduites).
- **Restant à livrer** = commandé − reçu ; **restant à facturer** = commandé − facturé ; jamais négatifs.
- **Prix net unitaire** = prix net SAP ramené à l'unité (division par la base de prix, par ex. prix pour 100).
- **Montant restant à livrer / à facturer** = reliquat correspondant × prix net unitaire. Montants dans la **devise de la commande**, avec le taux de change SAP d'origine, arrondis à 4 décimales.

## 7. Unité d'achat

L'unité SAP du poste est **transcodée** vers l'unité IFS via la table de transcodification du projet (catégorie UOM). Une unité SAP sans correspondance est remplacée par l'unité générique IFS « * ».

## 8. Dates

Toutes les dates sont au format JJ/MM/AAAA.

- **Date de création** : date de création de la commande SAP.
- **Date de livraison planifiée** et **date de livraison promise** : la prochaine échéance de livraison à venir du poste ; s'il n'y en a plus, la dernière échéance connue.
- **Date de réception souhaitée** : date de la dernière réception de marchandises du poste (vide si rien n'a encore été reçu).

## 9. Conditions et acheteur

- **Condition de paiement** : code SAP repris tel quel.
- **Condition de livraison** : Incoterm SAP suivi de son lieu (par ex. « DAP Saint-Jean »).
- **Mode d'expédition** : valeur fixe « 10 ».
- **Acheteur** : groupe d'acheteurs SAP repris **tel quel** – aucune table de correspondance vers les acheteurs IFS n'existe à ce jour (à fournir par le métier si nécessaire).

## 10. Adresse de livraison

Adresse du poste SAP si elle est renseignée, sinon adresse de la division : nom, rue et numéro, code postal, ville, pays.

## 11. Pré-imputation

L'imputation comptable principale du poste est reprise sous une forme lisible, par priorité : **PROJET=** (élément d'OTP), sinon **CENTRE_COUT=**, sinon **ORDRE=**, sinon **COMPTE=**. Vide pour un poste sans imputation (article stocké).

## 12. Volumes au 12/09/2026

3 325 postes ouverts, 1 204 commandes, société STJN ; 2 961 postes sur le site SJ et 364 sur CS ; 1 521 lignes PART et 1 804 lignes NOPART ; 2 993 postes avec un fournisseur IFS résolu, 332 sans (fournisseur absent du fichier de sélection).

## 13. Points d'attention / limites

- Le numéro d'acheteur n'est pas transcodé (pas de référentiel).
- Les fournisseurs absents du fichier de sélection ont un numéro IFS vide.
- Les postes anciens non clôturés dans SAP sont repris tant qu'ils ne sont pas soldés ou qu'aucune borne de date n'est paramétrée (§ 14).
- Le champ « À transférer = OUI » demandé par le métier n'existe ni dans SAP ni dans le modèle IFS : c'est un arbitrage manuel (liste de commandes) qui doit être transmis sous forme de fichier ; tant qu'il n'est pas fourni, toutes les commandes ouvertes STJN sont reprises (§ 15).
- Si l'extraction SAP des postes de commande (table EKPO) venait à être vide, le module charge un repli « en-tête seule » (une ligne par commande, sans article ni quantité) et le signale par un avertissement dans le journal du chargement ; il suffit de relancer le chargement après ré-extraction.

## 14. Date de bascule et bornes de date

### Date de bascule (valeur par défaut, depuis le 18/11/2026)

La date de bascule se règle dans l'écran **Valeurs par défaut** (module `commandeAchat`, table `clean_data.purchase_order`, colonne **`date_bascule`**, format AAAA-MM-JJ), comme la largeur de la fenêtre d'envoi (`mois_anteriorite`). Valeur actuelle : **2026-09-01**. Elle sert à trois choses :

1. **ORDER_DATE** de toutes les commandes chargées dans IFS ;
2. **borne de création** : seules les commandes SAP créées **strictement avant** la date de bascule sont reprises ;
3. **début de la fenêtre d'envoi** : une commande sans réception n'est envoyée à IFS que si elle a été créée dans les `mois_anteriorite` mois (6) précédant la date de bascule.

Une modification s'applique au prochain « Recalculer ».

### Suppression de l'ancienne borne fixe du 31/08/2026 (18/11/2026)

Jusqu'au 18/11/2026, la date de bascule était portée par deux paramètres distincts :

- la valeur par défaut `purchase_order.order_date` (2026-09-01), qui ne servait qu'à ORDER_DATE et à la fenêtre d'envoi ;
- une borne **`date_fin` = 2026-08-31** inscrite **en base** dans `module_params` du module (`public.etl_target_tables`), sans écran pour la voir ni la modifier.

Changer la date de bascule obligeait donc à modifier deux endroits, dont un par requête SQL, avec un risque d'incohérence (par exemple une bascule repoussée sans repousser la borne : les commandes créées entre-temps n'auraient pas été reprises). La migration 136 :

- crée la valeur par défaut `purchase_order.date_bascule` avec la valeur de `order_date` ;
- supprime la valeur par défaut `purchase_order.order_date`, remplacée par `date_bascule` ;
- retire `date_fin` de `module_params`.

Le résultat est inchangé à date égale : « créée avant le 01/09/2026 » équivaut à « créée au plus tard le 31/08/2026 ». Il n'y a plus qu'une date à changer si la bascule est déplacée.

Restent à aligner à la main si la bascule change : la date `date_creation_min_sans_reception` des postes jamais réceptionnés (01/03/2026, § 1), qui est une règle métier distincte.

### Bornes techniques facultatives (`module_params`)

Le module accepte toujours `date_debut` et `date_fin` (AAAA-MM-JJ) sur la date de création SAP, dans `module_params` de `public.etl_target_tables`, sans écran. Elles s'ajoutent à la date de bascule et ne sont plus utilisées à ce jour (`module_params` vide).

```sql
-- Exemple : ne reprendre que les commandes créées depuis le 01/01/2024
UPDATE public.etl_target_tables
   SET module_params = '{"date_debut": "2024-01-01"}'::jsonb, last_modified = CURRENT_TIMESTAMP
 WHERE python_module = 'etl_commande_achat.py';
```

## 15. Points en attente du métier

Pour livrer l'extraction demandée (commandes créées avant la date de bascule, « À transférer = OUI », colonnes du modèle IFS), il manque :

1. **La liste des commandes « À transférer »** : ce champ n'existe pas dans SAP ; il faut le fichier d'arbitrage (numéro de commande SAP + OUI/NON). Il sera importé dans une table de sélection et appliqué comme filtre, sur le même principe que le fichier de sélection des fournisseurs.
2. **Les réponses sur les champs structurants IFS** du modèle (`Lot11_AchatAppro_CommandeAchat_V3.0`), dont les colonnes de mappage SAP sont vides : code acheteur IFS par groupe d'acheteurs SAP, transcodification des conditions de paiement (`PAY_TERM_ID`), identifiants d'adresse (`ADDR_NO`, `DELIVERY_ADDRESS`), mode d'expédition (`SHIP_VIA_CODE`), type de demande (`DEMAND_CODE`), pré-imputation (`PRE_ACCOUNTING_ID`).
3. **Le format de livraison** : le modèle IFS attend trois objets (en-tête `PURCHASE_ORDER`, lignes `PURCHASE_ORDER_LINE_PART` et `PURCHASE_ORDER_LINE_NOPART`) ; la table actuelle est un intermédiaire à plat, à décliner en trois vues une fois les points 1 et 2 arbitrés.
4. Confirmer l'exclusion des commandes dont la stratégie de libération SAP n'est pas aboutie (3 commandes au 12/09/2026), conformément à la note du modèle « commandes déjà autorisées sur SAP ».
## ###########################
## 16. Synthèse du chargement du 16/09/2026 et actions à mener

**Résultat** : 3 325 postes ouverts sur 1 204 commandes d'achat STJN (2 961 postes SJ, 364 postes CS ; 1 521 lignes article PART, 1 804 lignes hors catalogue NOPART). Devises : 1 184 commandes en EUR, 18 en USD, 1 en CHF, 1 en GBP. Reste à livrer : environ 153 M€ en EUR, dont 59 M€ portés par des commandes antérieures à 2024 (fluorure d'aluminium, alumine, transport ferroviaire au forfait : contrats-cadres à gros volumes).

**Ce qui est complet** : 100 % des postes ont un article reconnu au catalogue IFS (PART), une désignation, un prix net, une date de livraison planifiée, une adresse de livraison et, pour les NOPART, une imputation comptable (2 068 centres de coût, 709 ordres, 198 projets).

**Actions à mener avant chargement dans IFS, par ordre d'importance :**

1. **178 commandes (332 postes, 91 fournisseurs SAP) sans numéro de fournisseur IFS** : ces fournisseurs sont absents du fichier de sélection des fournisseurs. Sans numéro IFS la commande ne peut pas être créée. → Le métier doit soit ajouter ces 91 fournisseurs au fichier de sélection (puis relancer le module fournisseurs et le module commandes), soit confirmer que ces commandes ne sont pas à reprendre. Même sujet pour 79 fournisseurs de facturation (291 postes).

2. **993 commandes sur 1 204 sans condition de livraison (Incoterm)** : SAP n'en porte que sur 211 commandes, avec des libellés hétérogènes (« DDP Saint Jean de Maurienne », « DDP St Jean de Maurienne », « DDP Frais de port : 36x2350 EUR »…). → Décider d'une règle de reprise : Incoterm par défaut du fournisseur dans IFS quand la commande n'en a pas, et normalisation des 23 libellés existants vers la liste des conditions de livraison IFS (DDP, DAP, CPT, FCA, EXW, CIF, CIP).

3. **Conditions de paiement** : seules 3 commandes en sont dépourvues (elles hériteront de la condition du fournisseur), mais les 18 codes SAP présents (M045 sur 707 commandes, F030 sur 155, C045 sur 138, M100, M110…) doivent être **transcodés vers les conditions de paiement IFS** (`PAY_TERM_ID`). → Table de correspondance à fournir par le métier ; à défaut, la condition du fournisseur IFS sera appliquée.

4. **22 groupes d'acheteurs SAP non transcodés** (92E sur 241 commandes, 92R sur 170, 92T sur 147, MX1 sur 120…) : IFS exige un code acheteur (`BUYER_CODE`). → Table de correspondance groupe d'acheteurs SAP → acheteur IFS à fournir par le métier.

5. **2 115 postes avec l'unité générique « * »** : 1 970 sont volontaires (unité SAP `UN` transcodée en « * » par choix projet) ; **145 postes portent une unité SAP sans correspondance IFS** (TRI = 52, PRT = 42, TAG = 26, H = 12, TH = 4, ML = 3, FLL = 2, J = 2, STD, LE). → Compléter la table de transcodification des unités pour ces 10 codes, ou valider « * ».

6. **1 167 postes PART dont l'article n'est pas déclaré en stock sur le site de la commande** (article au catalogue IFS mais absent de la fiche article du site SJ ou CS). → Vérifier avec le métier articles : soit l'article doit être ouvert sur le site, soit la ligne doit être reprise en NOPART.

7. **557 commandes créées avant 2024 (46 %)**, toujours ouvertes dans SAP faute de clôture par les acheteurs : 2 653 postes ont une date de livraison planifiée déjà dépassée. → Revue par les acheteurs : clôturer dans SAP ce qui est soldé (ou fournir la liste « À transférer »), sinon borner le chargement sur la date de création (§ 14).

8. **3 commandes dont la stratégie de libération SAP n'est pas aboutie** : à exclure si l'on s'en tient aux « commandes déjà autorisées » (§ 15).

9. Points de vigilance sans action immédiate : 1 760 postes partiellement reçus (le reliquat est repris, pas l'historique des réceptions) ; 745 postes déjà facturés au-delà du reçu (acomptes ou factures anticipées, le restant à facturer est plus faible que le restant à livrer) ; 37 commandes avec un fournisseur de facturation différent du fournisseur ; 20 commandes en devise étrangère avec le taux SAP d'origine.

## 17. Fichiers de chargement IFS (export ZIP) – règles au 18/11/2026

- **Lignes article** (`PURCHASE_ORDER_LINE_PART.csv`) : `PART_NO` = numéro d'article SAP sans les zéros de tête, sans contrôle de présence dans `part_catalog`. Avant ce changement, 1 293 lignes (581 articles hors périmètre Finance > Articles) étaient écartées : 780 lignes au lieu d'environ 2 073.
- **Activité projet** : la colonne `ABREVIATION_ACTIVITE` (`<projet>.20.REP` CAPEX, `<projet>.30.REP` OPEX) est ajoutée en **dernière colonne** des fichiers de lignes `PURCHASE_ORDER_LINE_PART.csv` et `PURCHASE_ORDER_LINE_NOPART.csv`. Elle n'est renseignée que pour les postes imputés sur un élément d'OTP : en pratique les lignes sans article (374 au 18/11/2026) ; les lignes article sont des achats de stock sans imputation projet (1 poste article sur 2 287 porte un OTP).
- **Colonnes retirées des CSV** (limite du nombre de colonnes du job de chargement IFS) : `STATE`, `OBJTYPE`, `OBJVERSION`, `OBJID`, `CODE_A` à `CODE_J`, ainsi que `SUB_PROJECT_ID` et `ACTIVITY_NO`. Elles restent visibles dans le classeur Excel du ZIP.
