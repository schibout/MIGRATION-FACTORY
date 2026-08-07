// Configuration de base — URL relative : l'application est servie derrière le
// nginx de l'hôte (http://10.190.100.58/), qui route /api/ vers le backend.
// Aucune URL absolue avec port : le port 5000 n'est plus exposé au réseau.
const API_PATH = '/api/v1';

// URL de l'API, relative à l'origine courante (même valeur que api.ts)
export const API_URL = API_PATH;

// Configuration des logs (désactivée par défaut ; ne pas logger d'informations sensibles)
export const ENABLE_DETAILED_LOGS = false;
