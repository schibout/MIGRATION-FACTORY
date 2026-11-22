# Documentation des commandes d’achat SAP vers IFS

## Guide métier

[Guide des commandes d’achat SAP vers IFS](Guide_Commandes_Achat_SAP_IFS.docx), version du 18 novembre 2026, 13 pages.

Le guide présente le circuit SAP vers Migration Factory puis IFS, les tables sources, les écrans de contrôle, un exemple de commande et les fichiers de chargement. Le document Word était déjà présent dans ce dossier lors de son référencement. Il contient des captures Migration Factory et des emplacements à compléter pour SAP.

## Analyse du 18 novembre 2026

Lecture du guide transmis sous le nom `Guide_Commandes_Achat_SAP_IFS(2).docx` et rapprochement ciblé avec les scripts SQL locaux. Les volumes et les données de la commande d’exemple sont ceux annoncés par le guide ; ils n’ont pas été revérifiés dans une base ou une session SAP pour cette analyse.

### Éléments confirmés dans les sources locales

- La sélection porte sur `EKKO-BUKRS = STJN` et `EKKO-BSTYP = F`.
- Les postes réceptionnés non entièrement facturés peuvent être repris quelle que soit leur ancienneté, y compris lorsqu’ils sont clôturés en livraison.
- Les postes ouverts sans réception sont soumis à une date minimale paramétrée.
- Les articles absents de `clean_data.part_catalog` sont signalés et restent repris dans les lignes PART.

### Corrections à apporter au guide Word

| Passage | Correction ou complément |
| --- | --- |
| Société / organisation d’achats STJN | STJN est confirmé comme société par le filtre BUKRS. L’organisation d’achats EKORG doit être vérifiée indépendamment ; ne pas reprendre automatiquement STJN dans ce champ. |
| Type de commande F | F est la catégorie de document BSTYP. Le type de document BSART est un champ distinct ; ne pas saisir F dans le champ Type de document de ME2N. |
| Reste à facturer toujours égal à commandé moins facturé | Préciser l’exception du poste clôturé en livraison : le reliquat repris est reçu moins facturé, borné à zéro. |
| Volumes au 18 novembre 2026 | Conserver la date de mesure et distinguer commandes distinctes, postes SAP et lignes IFS. Ces chiffres ne constituent pas un inventaire SAP actualisé. |
| Cadres rouges de captures SAP | Remplacer par des captures réelles et lisibles ; les écrans SAP du guide ne sont pas encore illustrés. |

### Complément demandé sur toutes les commandes ouvertes

Le guide doit distinguer l’inventaire des commandes ouvertes SAP du périmètre effectivement repris dans IFS, qui applique des règles supplémentaires de date et de correspondance fournisseur.

Procédure à illustrer et à valider dans la session SAP :

1. Ouvrir ME2N, sans numéro de commande, fournisseur ou date pour un inventaire complet du périmètre autorisé.
2. Filtrer la société STJN dans le champ approprié, éventuellement via les délimitations libres. Choisir les divisions 9200 et 9000 ; documenter séparément l’inclusion éventuelle des divisions historiques 2200 et 2000.
3. Vérifier dans l’aide SAP locale les paramètres de sélection proposés pour les restes à livrer et les restes à facturer. Le guide cite WE101 et RECHNG ; leur définition et leur couverture doivent être contrôlées avant de les présenter comme une extraction exhaustive.
4. Exécuter et exporter séparément les deux listes, en conservant les critères, la date d’extraction et les nombres de lignes. Ne pas exclure les commandes anciennes pour cette collecte.
5. Utiliser la fonction Tableur ou Fichier local disponible dans le résultat SAP. Illustrer le chemin exact et le format réellement proposés par cette installation.
6. Conserver au minimum commande, poste, société, division, fournisseur, date, article, désignation, unité, devise, quantités et reliquats disponibles. Préserver les identifiants comme texte.
7. Réunir les deux exports sur la clé commande et poste, avec le mandant si plusieurs mandants sont réunis. Éviter de sommer deux fois un poste présent dans les deux listes ; garder la provenance de chaque sélection. Les détails d’échéance ou d’imputation peuvent nécessiter une consolidation préalable.
8. Contrôler notamment un poste partiellement livré et un poste livré mais non entièrement facturé. Rapprocher ensuite cet inventaire avec les exclusions et transcodifications de Migration Factory.

Aucune liste exhaustive de commandes ouvertes n’est jointe à ce dossier à ce stade. Aucune extraction complète ni export SAP n’a été validé pendant cette analyse.

## Sources techniques

- [Règles de gestion](../../sql/commandeAchat/REGLES_DE_GESTION.md)
- [Documentation du module](../../sql/commandeAchat/README.md)
- [Sélection des postes SAP](../../sql/commandeAchat/02_alimenter_commande_achat_ifs.sql)
- [Alimentation des objets IFS](../../sql/commandeAchat/04_alimenter_purchase_order.sql)

Le code et les migrations actuels restent la référence pour le comportement applicatif ; les paramètres SAP doivent être vérifiés dans le système utilisé.
