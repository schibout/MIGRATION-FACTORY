**Objet :** Nouvel écran Migration Factory : périmètre des fournisseurs à reprendre dans IFS

Bonjour,

Un nouvel écran est disponible dans Migration Factory : **Finance > Fournisseurs**. Il donne la liste des fournisseurs à reprendre dans IFS, avec leurs adresses et leurs moyens de communication, tels qu'ils sont aujourd'hui dans SAP.

Lien : http://10.190.100.58:8081/finance/fournisseurs

## Quels fournisseurs sont repris

La liste réunit deux origines, indiquées dans la colonne **Source** :

| Source | Règle | Aujourd'hui |
|---|---|---|
| **FICHIER** | Fournisseur présent dans le fichier de sélection que vous avez validé. | 1 841 |
| **SAP_NOUVEAU** | Fournisseur absent du fichier, créé dans SAP depuis la date d'arrêté du fichier (le 2 septembre 2026). | 42 |

Pourquoi ce complément : le fichier de sélection a été figé à une date donnée. Les fournisseurs créés dans SAP depuis n'y figurent pas, l'écran les ajoute automatiquement.

Parmi ces nouveaux fournisseurs SAP, deux catégories sont écartées :

- les fournisseurs **marqués pour suppression** dans SAP ;
- les **employés gérés en fournisseur** (groupes de comptes ZPER, ZPE1 et P001), par exemple pour les notes de frais.

La date d'arrêté se modifie en haut de l'écran. Il suffit ensuite de cliquer sur **Calculer** pour voir la liste à une autre date.

## D'où viennent les informations

Du fichier de sélection, l'écran ne reprend que ce que vous y avez arbitré :

- le **numéro IFS** du fournisseur (600001 et suivants) ;
- les **codes TVA** SAP et IFS.

**Toutes les autres informations viennent directement de SAP** : nom, adresse, SIRET, n° de TVA intracommunautaire, conditions et mode de paiement, incoterms, téléphones, e-mail, coordonnées bancaires. Les textes du fichier étaient mal encodés (accents abîmés, par exemple « FranÃ§ais » au lieu de « Français »), alors que les données SAP sont propres.

Trois informations sont converties en codes IFS par les tables de transcodification : le **pays**, les **conditions de paiement** et la **langue**.

### Conditions de paiement : trois colonnes

Dans SAP, un fournisseur porte une condition de paiement côté comptabilité et une autre côté achats, qui ne sont pas toujours les mêmes. L'écran affiche donc trois colonnes :

| Colonne | Origine SAP | Contenu |
|---|---|---|
| **Condition de paiement SAP** | Données comptables du fournisseur (LFB1), société STJN en priorité | Le code SAP brut, par exemple C030. Il permet de contrôler la conversion. |
| **Conditions de paiement compta** | Même code comptable (LFB1) | Le code IFS obtenu par la table de transcodification, par exemple 30FM15. |
| **Conditions de paiement achats** | Données d'achat du fournisseur (LFM1), organisation d'achats principale | Le code IFS obtenu par la même table de transcodification. |

Aujourd'hui, la condition comptable est renseignée pour 1 881 fournisseurs et la condition d'achat pour 1 830. Les 53 autres n'ont pas de données d'achat dans SAP. Pour **290 fournisseurs, les conditions compta et achats sont différentes** : merci de nous dire laquelle doit être reprise dans IFS.

Un code SAP absent de la table de transcodification donne une case vide en compta ou en achats. Le code SAP d'origine reste visible dans la colonne Condition de paiement SAP.

## Les quatre onglets

- **Fournisseurs** : une ligne par fournisseur.
- **Adresses** : une ligne par adresse. Chaque fournisseur a son adresse propre, et parfois celles de ses partenaires dans SAP : auteur de la facture, adresse de commande, transporteur. Aujourd'hui : 2 502 adresses.
- **Méthodes de communication** : une ligne par téléphone, e-mail, fax, télex ou télétex de ces adresses, avec le numéro principal signalé « Par défaut ». Aujourd'hui : 9 787 lignes.
- **Mode d'emploi** : l'aide complète, avec l'origine SAP de chaque colonne.

## Filtres, export et mise à jour

- **Recherche** : par n° SAP, n° IFS, nom, localité, SIRET ou TVA. Validez avec la touche Entrée.
- **Source** : tous les fournisseurs, ceux du fichier, ou seulement les nouveaux fournisseurs SAP.
- **Exporter Excel** : produit un classeur à trois feuilles, Fournisseurs, Adresses et Méthodes de communication, limité aux fournisseurs filtrés.
- **Calculer** : recharge l'écran en une minute environ, à partir des données déjà présentes dans Migration Factory et de la date d'arrêté saisie, sans appeler SAP.
- **Synchroniser SAP** : relit les données dans SAP, puis recharge l'écran. Comptez quelques minutes.

## Ce que nous attendons de vous

1. **Les 42 nouveaux fournisseurs SAP** n'ont ni numéro IFS ni codes TVA, puisqu'ils ne sont pas dans le fichier. Merci de les passer en revue (filtre Source = SAP_NOUVEAU) et de nous indiquer ceux à reprendre, avec leur numéro IFS et leurs codes TVA.
2. **Deux conditions de paiement** n'ont pas la même correspondance dans la table de transcodification et dans le fichier. En attendant votre confirmation, c'est la table de transcodification qui s'applique :

| Code SAP | Transcodification (appliquée) | Fichier |
|---|---|---|
| C030 | 30FM15 | 30NETS |
| F005 | 30NETS | 30FM15 |

3. **Compta ou achats** : pour les 290 fournisseurs dont les deux conditions de paiement diffèrent, laquelle reprendre dans IFS ?

## Limites à connaître

- **Personnes de contact non reprises** : seuls les numéros et e-mails attachés à l'adresse du fournisseur figurent dans l'écran.
- **Portables non distingués** : SAP ne signale pas les numéros de portable, ils apparaissent comme des téléphones.
- **Télex** : beaucoup de numéros saisis en télex dans SAP sont en fait des numéros de téléphone. Ils sont repris tels quels.

N'hésitez pas à me faire part de vos remarques, en particulier sur la liste des nouveaux fournisseurs SAP.

Cordialement,

Samir
