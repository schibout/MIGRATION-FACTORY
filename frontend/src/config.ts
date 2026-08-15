// Configuration de base — URL relative : l'application est servie derrière le
// nginx de l'hôte, qui route <base>/api/ vers le backend. Aucune URL absolue
// avec port : le port 5000 n'est pas exposé au réseau. Le préfixe de
// déploiement (/app4 derrière le point d'entrée unique) vient de basePath.ts.
import { API_V1 } from './basePath';

const API_PATH = API_V1;

// URL de l'API, relative à l'origine courante (même valeur que api.ts)
export const API_URL = API_PATH;

// Configuration des logs (désactivée par défaut ; ne pas logger d'informations sensibles)
export const ENABLE_DETAILED_LOGS = false;
