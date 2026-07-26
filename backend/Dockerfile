# Utiliser une image Python officielle comme base
FROM python:3.11-slim

# Définir le répertoire de travail
WORKDIR /app

# Réduire la taille de l'image en désactivant les fichiers .pyc
ENV PYTHONDONTWRITEBYTECODE=1
# Éviter la mise en buffer de stdout/stderr pour un affichage immédiat des logs
ENV PYTHONUNBUFFERED=1
# Mode production
ENV FLASK_ENV=production

# Installer les dépendances système requises
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gcc \
        libc6-dev \
        # Pour psycopg2
        libpq-dev \
        postgresql \
        postgresql-contrib \
        # Outils de diagnostic réseau
        curl \
        iputils-ping \
        net-tools \
        vim \
        nano \
        htop \
        git \
        # Outils système
        procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copier les fichiers de dépendances
COPY requirements.txt .

# Installer les dépendances
RUN pip install --no-cache-dir -r requirements.txt

# Fix pour l'erreur numpy.dtype size changed
RUN pip uninstall -y numpy pandas
RUN pip install --no-cache-dir numpy==1.26.2
RUN pip install --no-cache-dir pandas

# Installation explicite de psycopg2-binary (plus fiable que psycopg2)
RUN pip install --no-cache-dir psycopg2-binary

# Copier le script de vérification des dépendances avant le reste pour optimiser le cache
COPY check_dependencies.py .
RUN python check_dependencies.py

# Copier le reste de l'application
COPY . .

# Ajouter le script de démarrage alternatif (déjà copié avec le reste de l'application)
RUN chmod +x /app/start.sh

# Créer un utilisateur non-root pour exécuter l'application
RUN adduser --disabled-password --gecos "" appuser
# Donner les permissions nécessaires
RUN chown -R appuser:appuser /app
# Créer le dossier de logs et donner les permissions nécessaires
RUN mkdir -p /app/logs && chown -R appuser:appuser /app/logs && chmod 755 /app/logs

# Passer à l'utilisateur non-root
USER appuser

# Exposer le port sur lequel l'application écoutera
EXPOSE 5000

# Démarrer via start.sh -> gunicorn (serveur de production, DEBUG désactivé).
# Ne PAS utiliser `flask run` (serveur de développement Werkzeug) en production.
# On invoque `bash` explicitement : le bind mount ./backend:/app masque le `chmod +x`
# ci-dessus (le start.sh du host Windows n'a pas le bit exécutable), donc "/app/start.sh"
# seul échoue avec "permission denied".
CMD ["bash", "/app/start.sh"]