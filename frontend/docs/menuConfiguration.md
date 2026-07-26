# Menu Configuration

Le menu **Configuration** est une page centrale de l'application qui permet d'accéder rapidement à différentes fonctionnalités de paramétrage. Il est conçu pour être moderne, responsive et facilement extensible.

## Structure et fonctionnement

- **Affichage** : Le menu s'affiche sous forme de grille de cartes (1, 2 ou 3 par ligne selon la taille de l'écran).
- **Navigation** : Chaque carte est cliquable et redirige vers la page de gestion correspondante.
- **Composants** : Utilise Material-UI (`Grid`, `Card`, `Box`, `Typography`, icônes).
- **Effet UX** : Survoler une carte la fait remonter légèrement et ajoute une ombre portée.

## Éléments du menu

Les éléments sont définis dans un tableau et chaque entrée contient :
- Un titre
- Un chemin de navigation (`path`)
- Une icône
- Une description

**Exemples d'éléments actuels et futurs :**

| Titre                | Chemin                                 | Description                                         |
|----------------------|----------------------------------------|-----------------------------------------------------|
| Mappings de champs   | `/configuration/field-mappings`        | Gérez les mappings entre les champs sources/cibles  |
| Transcodifications   | `/configuration/transcodifications`    | Configurez les règles de transcodification des données |
| Système (exemple)    | `/configuration/system`                | Paramètres système et configuration générale        |
| Sécurité (exemple)   | `/configuration/security`              | Gestion des accès et permissions utilisateurs       |
| Connecteurs API      | `/configuration/api`                   | Configuration des connexions aux APIs externes      |
| Règles métier        | `/configuration/rules`                 | Définition des règles métier et validations         |

> **Remarque :** Seuls les deux premiers éléments sont réellement implémentés dans le routeur principal. Les autres sont des exemples pour des évolutions futures.

## Extensibilité

Pour ajouter un nouvel élément au menu, il suffit d'ajouter un objet dans le tableau de configuration de la page `Configuration.tsx`.

---

**Résumé :**
Le menu Configuration centralise l'accès aux fonctions de paramétrage de l'application, avec une interface claire, moderne et évolutive. 