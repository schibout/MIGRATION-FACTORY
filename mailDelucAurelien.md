Monsieur LAROCHE,
L’équipe a testé ce mardi. Ci-dessous les remarques :
•	Il faut la séparation des articles en deux listes :
o	Liste avec seulement les IBAU : pas de MAJ depuis SAP mais modifiable par mes équipes (ajout, suppression, modification). La liste existe mais il semble qu’il y ait également des articles non IBAU mais rattachés à un IBAU. A vérifier. Pour la mise à jour, voir bas du mail. 
o	Liste avec les autres types d’articles : avec MAJ depuis SAP régulière ; mes équipes ne la modifieront pas. Pour la mise à jour, cf bas du mail. En lisant ton mode opératoire, je comprends que la mise à jour (via le bouton) effectue la mise à jour de l’ensemble des tables (Structure/articles IBAU/articles maintenance). Est-ce bien cela ? Si oui, cela ne correspond pas à mon besoin car j’ai besoin de liste figée pour les IBAU.
•	Temps de chargement des listes d’article très long : plus de 65000 articles vu qu’il y a tous les types d’articles.
•	Pour la structure technique :
o	Toujours pas la fonction d’ajout d’articles dans la structure. Faire sur le même modèle que l’ajout d’équipement (liste déroulante lorsque l’on tape le code article). La fonction d’ajout d’article ne fonctionne pas correctement. Elle est intégrée dans la fonction Ajout équipement alors qu’il faut deux fonctions différentes.
 
o	Certains champs ne sont pas modifiables en masse mais le sont en individuel ; exemple sur Identifiant Structuré (STRNO) ; est-il possible de modifier en masse seulement une partie du champ ? Non réalisé.
o	Certaines lignes ne sont ni sélectionnables, ni déplaçables, ni supprimables, voir ci-dessous : Il faut que l’on puisse, dans la structure technique, sélectionner, déplacer et supprimer un article. Je ne peux toujours pas supprimer les articles dans la structure technique.
  

Nous avons déjà commencé à travailler dessus.

De plus, puis-je avoir un mode opératoire pour les injections et extractions des listes ? Afin d’être autonome et pouvoir réaliser des sauvegardes.
Pour les différentes mises à jour depuis SAP, il me faut un bouton pour : la liste des articles non IBAU, la liste des équipements.
Il faut un bouton d’enregistrement de la liste des IBAU et de la structure technique afin d’assurer le suivi des modifications (possibilité de revenir à une précédente version).
Un mode opératoire devra être rédigé et transmis.

Merci,

---

# Projet de réponse

Monsieur DELUC,

Merci à vous et à vos équipes pour ces retours de test détaillés. Voici notre réponse point par point ; l'ensemble des développements décrits ci-dessous est finalisé et sera disponible lors de la prochaine mise à jour de la plateforme.

**1. Liste avec seulement les IBAU (figée, modifiable par vos équipes)**

C'est réalisé. Une nouvelle page « Liste IBAU (référentiel équipe) » a été créée, accessible depuis le menu Maintenance. Elle est alimentée une seule fois depuis SAP (8 446 IBAU du périmètre de la structure technique), puis totalement découplée : le bouton de mise à jour SAP ne la touche plus jamais. Vos équipes peuvent y ajouter, modifier et supprimer des articles librement, chaque modification étant tracée (qui / quand).

Concernant votre doute sur les articles non IBAU rattachés à un IBAU : nous l'avons vérifié, il est fondé. Environ 9 200 articles d'autres types (pièces de rechange ERSA, consommables HIBE, non stockés NLAG) sont rattachés comme composants sous des IBAU dans les nomenclatures. Conformément à votre demande, la liste ne contient que les IBAU ; ces composants restent visibles dans la structure technique et dans la liste des autres types. Si vous souhaitez finalement les inclure dans la liste figée, c'est une évolution simple : dites-le-nous.

**2. Liste des autres types d'articles (mise à jour SAP régulière, non modifiée par vos équipes)**

C'est le fonctionnement en place : ces listes lisent directement les données SAP et reflètent donc chaque mise à jour.

Sur votre question : oui, votre lecture du mode opératoire était exacte — le bouton de mise à jour rafraîchissait jusqu'ici l'ensemble (structure, articles IBAU, articles maintenance). C'est précisément pour répondre à votre besoin que la liste IBAU a été sortie de ce circuit : elle est désormais figée quelle que soit l'utilisation du bouton.

**3. Temps de chargement des listes d'articles**

Corrigé. L'origine n'était pas le volume lui-même mais un défaut d'optimisation des requêtes (les listes déroulantes de filtres recalculaient inutilement sur les 65 000 articles). Le chargement passe d'environ 25 secondes à 1 à 2 secondes, et les affichages suivants sont quasi instantanés.

**4. Structure technique — ajout d'articles**

C'est réalisé, avec deux fonctions bien distinctes comme demandé :
- « Ajouter un équipement » (inchangée) ;
- « Ajouter un article », nouveau bouton dédié sur chaque poste technique, sur le même modèle que l'ajout d'équipement : liste déroulante dès la saisie du code ou de la désignation, puis quantité et unité. L'article est ajouté à la nomenclature du poste, et cet ajout est préservé lors des mises à jour SAP.

**5. Modification en masse partielle (exemple STRNO)**

C'est réalisé. La modification en masse propose désormais, pour l'Identifiant Structuré (STRNO), un mode « remplacer une partie du champ » : vous indiquez le texte à remplacer et le texte de remplacement (par exemple remplacer « T130 » par « T140 »), et seul ce fragment est modifié sur l'ensemble du sous-arbre. Un contrôle empêche l'opération si elle créait deux identifiants identiques au même niveau.

**6. Sélectionner, déplacer, supprimer un article dans la structure**

C'est réalisé. La suppression d'un article est désormais possible directement depuis l'arbre (icône sur chaque ligne) ou depuis le panneau de détail, avec confirmation : seule l'occurrence est retirée, la fiche article et ses autres utilisations ne sont pas touchées. La sélection et le déplacement (glisser-déposer vers un poste ou un autre article) sont également fonctionnels ; le blocage que vous avez constaté venait de la version en ligne, antérieure à ces développements. Après un déplacement, l'écran se rafraîchit automatiquement et se positionne sur l'élément de destination.

**7. Mode opératoire injections / extractions des listes**

Entendu. Un mode opératoire couvrant l'extraction (export CSV des listes), l'injection et les sauvegardes vous sera rédigé et transmis avec la prochaine mise à jour.

**8. Boutons de mise à jour SAP séparés (articles non IBAU / équipements)**

Demande bien notée. Aujourd'hui le bouton de mise à jour est global ; nous allons le décliner en actions distinctes pour la liste des articles non IBAU et pour la liste des équipements. Nous revenons vers vous avec un délai.

**9. Enregistrement / versions de la liste IBAU et de la structure technique**

Pour la structure technique, c'est déjà en place : le module « Sauvegardes & restauration » permet d'enregistrer un état nommé à tout moment et d'y revenir (un état de sécurité est par ailleurs créé automatiquement avant chaque mise à jour SAP ou restauration). Nous allons étendre ce mécanisme à la liste IBAU afin que vous disposiez du même suivi des modifications et retour arrière sur cette liste.

**10. Mode opératoire général**

Il sera rédigé et transmis en même temps que la mise à jour, intégrant l'ensemble des nouveautés ci-dessus (liste IBAU, ajout/suppression d'articles dans la structure, modification en masse partielle, sauvegardes).

Nous restons à votre disposition pour une démonstration de ces évolutions avec vos équipes dès la mise en ligne.

Cordialement,
