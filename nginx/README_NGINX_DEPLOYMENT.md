# 🚀 Déploiement Nginx - Migration Factory

Ce guide explique comment déployer la configuration Nginx pour Migration Factory sur votre serveur interne.

## 📋 Prérequis

- Serveur Ubuntu/Debian avec accès root
- Nginx installé (`sudo apt install nginx`)
- Migration Factory backend fonctionnel sur le port 5000
- Accès SSH au serveur 10.190.100.58

## 📁 Fichiers à Transférer

```bash
# Depuis votre projet local, transférez ces fichiers:
migration-factory-8080.conf  # Configuration port 8080
main-80.conf                 # Configuration port 80
index.html                   # Page d'accueil
deploy-nginx.sh              # Script de déploiement
nginx.conf                   # Configuration principale (optionnel)
```

## 🚀 Étapes de Déploiement

### 1. Transfert des Fichiers

```bash
# Copier les fichiers sur le serveur
scp migration-factory-8080.conf main-80.conf index.html deploy-nginx.sh user@10.190.100.58:/tmp/
```

### 2. Exécution du Script de Déploiement

```bash
# Se connecter au serveur
ssh user@10.190.100.58

# Aller dans le répertoire
cd /tmp

# Rendre le script exécutable
chmod +x deploy-nginx.sh

# Exécuter le script en tant que root
sudo ./deploy-nginx.sh
```

### 3. Vérification

```bash
# Vérifier le statut de Nginx
sudo systemctl status nginx

# Tester la configuration
sudo nginx -t

# Vérifier les ports
sudo netstat -tuln | grep -E ":(80|8080)"
```

## 🌐 URLs d'Accès

- **Page d'accueil**: `http://10.190.100.58`
- **Migration Factory**: `http://10.190.100.58:8080`
- **API Backend**: `http://10.190.100.58:8080/api/`

### 🔄 Redirections Automatiques

**TOUS les accès redirigent automatiquement vers la page de login** :
- **`http://10.190.100.58/`** → **`http://10.190.100.58:8080/login`** (redirection depuis la homepage)
- **`http://10.190.100.58:8080/`** → **`http://10.190.100.58:8080/login`** (redirection depuis la racine de l'application)
- **`http://10.190.100.58/dashboard`** → **`http://10.190.100.58:8080/login`** (redirection via login)
- **`http://10.190.100.58/export`** → **`http://10.190.100.58:8080/login`** (redirection via login)
- **`http://10.190.100.58/mf`** → **`http://10.190.100.58:8080/login`** (redirection via login)

> **🔒 Sécurité**: Cette configuration garantit que tous les accès passent obligatoirement par la page de connexion, renforçant la sécurité de l'application.

### 🔗 Raccourcis Directs (Port 80) - Tous via Login

- **Login**: `http://10.190.100.58/login` → `http://10.190.100.58:8080/login`
- **Dashboard**: `http://10.190.100.58/dashboard` → `http://10.190.100.58:8080/login`
- **Export**: `http://10.190.100.58/export` → `http://10.190.100.58:8080/login`
- **Migration Factory**: `http://10.190.100.58/mf` → `http://10.190.100.58:8080/login`
- **Migration Factory**: `http://10.190.100.58/migration-factory` → `http://10.190.100.58:8080/login`

> **🔒 Sécurité**: Tous les raccourcis redirigent vers la page de login pour garantir l'authentification obligatoire.

## 📂 Structure des Répertoires

```
/var/www/
├── html/                    # Page d'accueil (port 80)
│   └── index.html
├── migration-factory/       # Frontend Migration Factory
│   └── (fichiers React build)
└── logs/
    └── nginx/               # Logs nginx
```

## 🔧 Configuration Manuelle (Alternative)

Si vous préférez configurer manuellement :

### 1. Copier les Configurations

```bash
# Copier les fichiers de configuration
sudo cp migration-factory-8080.conf /etc/nginx/sites-available/
sudo cp main-80.conf /etc/nginx/sites-available/
```

### 2. Activer les Sites

```bash
# Désactiver le site default
sudo rm /etc/nginx/sites-enabled/default

# Activer nos configurations
sudo ln -s /etc/nginx/sites-available/main-80.conf /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/migration-factory-8080.conf /etc/nginx/sites-enabled/
```

### 3. Créer les Répertoires

```bash
# Créer les répertoires web
sudo mkdir -p /var/www/html
sudo mkdir -p /var/www/migration-factory

# Copier la page d'accueil
sudo cp index.html /var/www/html/

# Configurer les permissions
sudo chown -R www-data:www-data /var/www/html
sudo chown -R www-data:www-data /var/www/migration-factory
```

### 4. Tester et Recharger

```bash
# Tester la configuration
sudo nginx -t

# Recharger nginx
sudo systemctl reload nginx
```

## 🏗️ Déploiement du Frontend

Pour déployer les fichiers React de Migration Factory :

```bash
# Depuis votre projet local (dans le dossier frontend/)
npm run build

# Transférer les fichiers build vers le serveur
scp -r dist/* user@10.190.100.58:/tmp/frontend-build/

# Sur le serveur
sudo cp -r /tmp/frontend-build/* /var/www/migration-factory/
sudo chown -R www-data:www-data /var/www/migration-factory
```

## 🔒 Sécurisation (Étapes Suivantes)

### 1. Certificats SSL

```bash
# Générer un certificat auto-signé
sudo openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/private/migration-factory.key -out /etc/ssl/certs/migration-factory.crt -days 365 -nodes
```

### 2. Firewall

```bash
# Configurer ufw
sudo ufw allow 80/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 443/tcp
sudo ufw allow ssh
sudo ufw enable
```

### 3. Fail2Ban

```bash
# Installer fail2ban
sudo apt install fail2ban

# Créer une configuration personnalisée
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

## 🐛 Dépannage

### Problèmes Courants

1. **Nginx ne démarre pas**
   ```bash
   sudo systemctl status nginx
   sudo journalctl -u nginx
   ```

2. **Erreur 502 Bad Gateway**
   - Vérifier que le backend est actif sur le port 5000
   - Vérifier les logs nginx

3. **Permission denied**
   ```bash
   sudo chown -R www-data:www-data /var/www/
   sudo chmod -R 755 /var/www/
   ```

4. **Erreur "unknown log format 'main'"**
   - ✅ **Corrigé** : Les fichiers utilisent maintenant le format `combined` (standard nginx)
   - Si le problème persiste, vérifiez que nginx est bien installé avec les modules par défaut

5. **Erreur "zero size shared memory zone 'global'"**
   - ✅ **Corrigé** : Le script ajoute automatiquement les définitions de rate limiting au nginx.conf principal
   - Les zones sont maintenant définies dynamiquement lors du déploiement

### Logs Utiles

```bash
# Logs nginx généraux
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log

# Logs spécifiques Migration Factory
sudo tail -f /var/log/nginx/migration-factory-8080.error.log
sudo tail -f /var/log/nginx/migration-factory-8080.access.log
```

## 📊 Monitoring

### Vérification des Services

```bash
# Statut nginx
sudo systemctl status nginx

# Processus en cours
sudo ps aux | grep nginx

# Ports ouverts
sudo netstat -tuln | grep -E ":(80|8080|5000)"
```

### Health Checks

- **Nginx**: `http://10.190.100.58/health`
- **Backend**: `http://10.190.100.58:8080/health`

## 🚨 Sauvegarde

```bash
# Sauvegarder les configurations
sudo cp -r /etc/nginx/sites-available/ /backup/nginx-configs/
sudo cp -r /var/www/ /backup/www-data/
```

## 📞 Support

En cas de problème, vérifiez :
1. Les logs nginx
2. Le statut du backend Migration Factory
3. Les permissions des fichiers
4. La configuration du firewall

Pour assistance : contactez l'équipe IT 