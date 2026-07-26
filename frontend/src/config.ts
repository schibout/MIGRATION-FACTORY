// Configuration de base - utilise l'IP de l'host
const SERVER_HOST = '10.190.100.58'; // IP de votre serveur
const SERVER_PORT = '5000'; // Port exposé par Docker
const API_PATH = '/api/v1';

// URL complète de l'API via l'IP de l'host
export const API_URL = `http://${SERVER_HOST}:${SERVER_PORT}${API_PATH}`;

// Configuration des logs (désactivée par défaut ; ne pas logger d'informations sensibles)
export const ENABLE_DETAILED_LOGS = false;