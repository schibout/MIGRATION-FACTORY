**Objet :** Nouvel écran Migration Factory : historique des coûts par projet

Bonjour,

Un nouvel écran est disponible dans Migration Factory : **Finance > Historique des coûts par projet**. Il donne, pour chaque projet SAP de la société STJN, le réel, le plan, le budget et les engagements, mois par mois. Il indique aussi quels projets seront repris dans IFS.

Lien : http://10.190.100.58:8081/finance/historique-couts

## Ce que contient l'écran

Les chiffres sont reconstitués à partir de la base d'informations projet de SAP, la table RPSCO, comme l'état ZCOA. Aujourd'hui l'écran couvre **951 projets**, de l'exercice 2013 à 2029.

L'écran propose trois onglets :

- **Par projet** : une ligne par projet, exercice et période, tous les éléments d'OTP du projet additionnés.
- **Par élément d'OTP** : le même détail au niveau de chaque élément d'OTP.
- **Mode d'emploi** : l'aide complète, avec la signification de chaque colonne et un exemple chiffré.

## Attention : l'exercice va de juillet à juin

Les colonnes Année et Période suivent l'exercice SAP de STJN, et non l'année civile. L'exercice 2027 a commencé le 1er juillet 2026 et se termine le 30 juin 2027.

| Période | Mois | Période | Mois |
|---|---|---|---|
| 1 | juillet N-1 | 7 | janvier N |
| 2 | août N-1 | 8 | février N |
| 3 | septembre N-1 | 9 | mars N |
| 4 | octobre N-1 | 10 | avril N |
| 5 | novembre N-1 | 11 | mai N |
| 6 | décembre N-1 | 12 | juin N |

La période 0 porte les montants annuels, sans mois. Par exemple, la ligne « 2027, période 4 » correspond à octobre 2026.

## Les colonnes de montants

Tous les montants sont en euros, avec le signe SAP : un montant négatif est une annulation ou un avoir.

| Colonne | Ce qu'elle représente | Total STJN |
|---|---|---|
| **Réel** | Les coûts comptabilisés sur le projet dans le mois : factures, réceptions valorisées, prestations. | 270,76 M€ |
| **Réel cumulé** | Le total du réel depuis la première dépense du projet jusqu'au mois de la ligne. | non additionnable |
| **Plan** | Les coûts prévus, saisis par le chef de projet. C'est une estimation. | 234,21 M€ |
| **Budget annuel** | L'enveloppe autorisée pour l'exercice, portée par la période 0. | 246,30 M€ |
| **Commandes non réceptionnées** | Les commandes d'achat imputées au projet qui ne sont pas encore reçues. | 4,74 M€ |
| **Demandes d'achat** | Les demandes d'achat imputées au projet qui ne sont pas encore commandées. | 2,82 M€ |

Quelques points pour bien lire ces colonnes :

- **Le réel exclut les répartitions.** Une répartition transfère des coûts du projet vers un autre objet, par exemple une immobilisation à la mise en service. La compter ferait baisser le réel alors que la dépense a bien eu lieu. Une seule écriture est concernée aujourd'hui, pour −4 187 €.
- **Le réel cumulé est un solde à date.** Il ne faut pas l'additionner. Il part toujours du début du projet, même si vous filtrez sur quelques exercices.
- **Le budget global n'est pas repris.** SAP tient aussi un budget pour toute la durée du projet, sans exercice ni période. Seul le budget annuel apparaît.
- **Les engagements sont datés à la livraison prévue.** Une commande passée en 2026 peut donc apparaître en 2027 ou 2028. Ce sont les engagements en cours aujourd'hui : on ne peut pas retrouver ce qui était engagé à une date passée.

## N° projet et projets à migrer

- **N° projet** : le numéro du projet dans la liste SharePoint, qui est aussi son identifiant dans IFS, par exemple 21.009 pour le projet SAP SN21009. On le retrouve en comparant les codes sans les points ni les lettres finales. 846 projets ont un n° projet.
- **À migrer** : Oui si le n° projet fait partie des projets préparés pour la reprise IFS, Non sinon. **159 projets** sont à migrer aujourd'hui.

Un filtre « Migration » permet d'afficher seulement les projets à migrer, ou seulement les autres.

## Filtres, export et mise à jour

- **Recherche** : par code projet, n° projet, désignation, responsable ou élément d'OTP. Validez avec la touche Entrée.
- **Année de / Année à** : limite l'affichage à une plage d'exercices.
- **Exporter Excel** : produit un classeur avec les lignes filtrées de l'onglet affiché, toutes les pages comprises.
- **Recalculer** : recharge l'écran en quelques secondes à partir des données déjà présentes dans Migration Factory, sans appeler SAP.
- **Synchroniser SAP** : relit les données dans SAP et la liste des projets dans SharePoint, puis recharge l'écran. Comptez quelques minutes.

## Limites à connaître

- **Ordres d'investissement non couverts.** Les ordres d'investissement de type IM01 ne figurent pas dans l'écran. Les données SAP nécessaires ne sont pas extraites aujourd'hui.
- **Projets sans n° projet.** Une centaine de projets SAP, souvent anciens, n'ont pas de projet SharePoint correspondant. Ils restent sans n° projet et ne sont pas marqués à migrer.

Contrôle effectué : le total du réel de l'écran est identique, au centime, à la somme des écritures réelles de SAP sur les mêmes projets.

N'hésitez pas à me faire part de vos remarques, en particulier sur la liste des projets à migrer.

Cordialement,

Samir
