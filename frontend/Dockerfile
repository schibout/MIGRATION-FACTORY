# Dockerfile pour le développement - Mode Vite dev server
FROM node:18-bullseye

# Installer des outils utiles pour le développement
RUN apt-get update && apt-get install -y \
    git \
    bash \
    curl \
    vim \
    nano \
    htop \
    build-essential \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Définir le répertoire de travail
WORKDIR /workspace

# Créer les dossiers nécessaires et définir les permissions
RUN mkdir -p /workspace/frontend && \
    chown -R node:node /workspace

# Définir le répertoire de travail pour le frontend
WORKDIR /workspace/frontend

# Copier les fichiers de dépendances
COPY --chown=node:node package*.json ./

# Installer les dépendances
RUN npm install

# Copier tout le code source
COPY --chown=node:node . .

# Corriger les permissions après la copie
RUN chown -R node:node /workspace/frontend && \
    chmod -R 755 /workspace/frontend

# Passer à l'utilisateur node
USER node

# Variables d'environnement pour le développement
ENV NODE_ENV=development
ENV CHOKIDAR_USEPOLLING=true
ENV WATCHPACK_POLLING=true

# Exposer le port pour Vite dev server
EXPOSE 3000

# Commande par défaut - Vite dev server sur port 3000
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "3000"]