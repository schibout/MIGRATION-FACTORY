# 🔐 Résolution du problème d'authentification - Page Import Clients

## **Problème identifié**
La page `/import/clients` reçoit une erreur **401 (UNAUTHORIZED)** avec le message "Missing Authorization Header". Cela indique un problème d'authentification JWT.

## **Diagnostic**

### 1. **Vérifier l'état d'authentification**
```bash
# Dans la console du navigateur, vérifier :
localStorage.getItem('token')  // Doit retourner un token JWT
localStorage.getItem('user')   // Doit retourner les infos utilisateur
```

### 2. **Exécuter le script de diagnostic**
```bash
cd backend
python test_auth_api.py
```

Ce script va :
- Tester la connexion au serveur
- Vérifier les tables de base de données
- Tester l'API de connexion
- Tester l'API import-types avec authentification

## **Solutions implémentées**

### 1. **Amélioration de la gestion des erreurs 401**
- **Fichier modifié :** `frontend/src/services/api.ts`
- **Changement :** Redirection automatique vers `/login` en cas d'erreur 401
- **Nettoyage :** Suppression automatique du localStorage

### 2. **Vérification d'authentification dans les composants**
- **Fichier modifié :** `frontend/src/components/import/ClientFileTypeSelector.tsx`
- **Changement :** Vérification de l'authentification avant les appels API
- **Redirection :** Vers la page de login si non authentifié

### 3. **Amélioration de la page de login**
- **Fichier modifié :** `frontend/src/pages/Login.tsx`
- **Changement :** Gestion du retour vers la page d'origine après connexion
- **État :** Conservation de la page demandée dans l'URL

### 4. **Composant de débogage**
- **Fichier créé :** `frontend/src/components/debug/AuthDebugger.tsx`
- **Fonction :** Affichage de l'état d'authentification en mode développement
- **Utilisation :** Ajouté à la page ImportClientsSimple pour le diagnostic

## **Étapes de résolution**

### **Étape 1 : Vérifier la connexion au serveur**
```bash
# Tester si le serveur répond
curl http://10.190.100.58:8080/api/v1/auth/me
```

### **Étape 2 : Vérifier les credentials de test**
Le script de diagnostic teste automatiquement :
- `admin` / `admin123`
- `schibout` / `password`
- `test` / `test123`

### **Étape 3 : Vérifier les tables de base de données**
Le script vérifie :
- Table `users` ou `user` (pour l'authentification)
- Tables contenant "import" (pour la configuration)

### **Étape 4 : Tester l'API avec authentification**
```bash
# Après avoir obtenu un token valide
curl -H "Authorization: Bearer <TOKEN>" \
     "http://10.190.100.58:8080/api/v1/import-types?category=customer"
```

## **Vérifications à effectuer**

### **Frontend**
1. **Console du navigateur :** Vérifier les erreurs 401
2. **LocalStorage :** Vérifier la présence du token JWT
3. **Redirection :** Vérifier que la page de login s'affiche

### **Backend**
1. **Logs du serveur :** Vérifier les erreurs d'authentification
2. **Base de données :** Vérifier les tables et données utilisateurs
3. **Configuration JWT :** Vérifier `JWT_SECRET_KEY` dans `.env`

### **Réseau**
1. **CORS :** Vérifier que les requêtes cross-origin sont autorisées
2. **Headers :** Vérifier que l'header `Authorization` est bien envoyé
3. **Timeout :** Vérifier que les requêtes ne dépassent pas le timeout

## **Commandes de test**

### **Test de connexion simple**
```bash
curl -X POST http://10.190.100.58:8080/api/v1/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username": "admin", "password": "admin123"}'
```

### **Test de l'API protégée**
```bash
# Remplacer <TOKEN> par le token obtenu
curl -H "Authorization: Bearer <TOKEN>" \
     "http://10.190.100.58:8080/api/v1/import-types?category=customer"
```

## **Résolution des erreurs courantes**

### **Erreur "Missing Authorization Header"**
- **Cause :** Token JWT manquant dans la requête
- **Solution :** Vérifier que l'utilisateur est connecté et que le token est valide

### **Erreur "Token has expired"**
- **Cause :** Token JWT expiré
- **Solution :** Se reconnecter pour obtenir un nouveau token

### **Erreur "Invalid token"**
- **Cause :** Token JWT malformé ou invalide
- **Solution :** Nettoyer le localStorage et se reconnecter

### **Erreur "User not found"**
- **Cause :** Utilisateur supprimé ou désactivé
- **Solution :** Vérifier la base de données et recréer l'utilisateur

## **Monitoring et maintenance**

### **Logs à surveiller**
- Erreurs 401 dans les logs du serveur
- Tentatives de connexion échouées
- Tokens expirés ou invalides

### **Métriques à suivre**
- Taux de succès des authentifications
- Nombre d'erreurs 401 par utilisateur
- Temps de réponse des APIs d'authentification

## **Support et débogage**

### **Composant de débogage**
Le composant `AuthDebugger` affiche en mode développement :
- Statut de l'authentification
- Présence du token JWT
- Informations sur l'utilisateur connecté
- Détails du token (longueur, format)

### **Logs détaillés**
Les intercepteurs Axios loggent :
- Toutes les requêtes API
- Headers d'authentification
- Erreurs détaillées avec contexte

### **Script de diagnostic**
Le script `test_auth_api.py` permet de :
- Tester la connectivité
- Valider l'authentification
- Vérifier les APIs protégées
- Diagnostiquer les problèmes de base de données

---

**Note :** Ce guide doit être mis à jour à chaque modification de l'API d'authentification ou de la logique de gestion des tokens.



