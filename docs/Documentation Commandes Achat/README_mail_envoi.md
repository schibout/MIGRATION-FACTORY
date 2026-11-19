# Mail d'envoi – reprise des commandes d'achat SAP vers IFS

Texte à joindre à l'envoi du guide et de l'export des commandes d'achat.
Chiffres estimés le 19/11/2026 sur la base du serveur, avec le circuit de signature et l'exclusion des commandes à 0. Ils sont à confirmer après installation et « Recalculer ».

**Pièces jointes**

- `Guide_Commandes_Achat_SAP_IFS_Consultants_IFS.docx` : guide à l'attention des consultants IFS et du métier ;
- `commandes_achat_<date>.zip` : export « Exporter tout (ZIP) » de l'écran Finance > Commandes d'achat.

---

**Objet :** Reprise des commandes d'achat SAP → IFS – fichiers de chargement et guide (19/11/2026)

Bonjour à tous,

Vous trouverez ci-joint les fichiers de chargement IFS des commandes d'achat, ainsi que le guide qui décrit le vocabulaire SAP / IFS, le périmètre de reprise et les règles de gestion.

**Contenu du ZIP**

| Fichier | Lignes |
|---|---:|
| PURCHASE_ORDER.csv (en-têtes de commande) | 779 |
| PURCHASE_ORDER_LINE_PART.csv (lignes avec article) | 889 |
| PURCHASE_ORDER_LINE_NOPART.csv (lignes sans article) | 1 054 |
| commandes_achat_<date>.xlsx | 4 onglets de contrôle, toutes colonnes |

Les 779 commandes se répartissent en 735 pour le site SJ et 44 pour le site CS.

**Récapitulatif du périmètre**

- Commandes SAP STJN créées avant la date de bascule du 01/09/2026, autorisées via le circuit de signature, avec au moins un poste encore à livrer ou à facturer : 1 868 commandes, 3 611 postes (1 385 avec article).
- Reste à livrer : 60,4 M€ ; reste à facturer : 82,3 M€ (montants en EUR uniquement).
- Commandes envoyées à IFS : 779. Les 1 089 autres sont écartées :
  - 816 commandes à 0, qui n'ont plus rien à livrer (postes réceptionnés en attente de facture uniquement) ;
  - 260 commandes sans fournisseur IFS (124 fournisseurs SAP absents du fichier de sélection) ;
  - 13 commandes sans fournisseur de facturation ou sans condition de paiement IFS.

**Points à noter**

- Circuit de signature : seules les commandes entièrement libérées dans SAP (stratégie de libération terminée) sont reprises. Sont exclues 14 commandes en attente de signature et 1 162 commandes hors circuit (petits montants sous le seuil de signature) ; ces dernières peuvent être réintégrées par un paramètre si besoin.
- Commandes et lignes à 0 : seules les lignes encore à livrer sont envoyées. Une commande sans aucune ligne à livrer est écartée (816 commandes) ; dans les autres commandes, 135 lignes à quantité 0 sont retirées. Les postes reçus mais pas encore facturés sont donc à traiter hors de la reprise.
- Activité projet : la colonne ABREVIATION_ACTIVITE est en dernière position des fichiers de lignes. Elle est renseignée sur 141 lignes sans article et 1 ligne avec article ; les autres lignes ne sont pas imputées sur un projet (achats de stock, centres de coûts).
- Colonnes retirées des CSV, à cause de la limite du job de chargement : STATE, OBJTYPE, OBJVERSION, OBJID, CODE_A à CODE_J. Elles restent visibles dans le classeur Excel.
- Date de bascule : elle est désormais paramétrable dans l'écran Valeurs par défaut (01/09/2026). Elle sert de date de commande IFS et de limite de création ; l'ancienne limite fixe du 31/08/2026 a été supprimée, sans effet sur les volumes.
- À décider : 2 788 commandes STJN ont été créées dans SAP depuis le 01/09/2026. Elles ne sont pas reprises : faut-il les recréer dans IFS ou décaler la date de bascule ?

Je reste disponible pour toute question.

Cordialement,
