// =====================================================================
// Prefixe de deploiement de l'application — source UNIQUE.
//
// L'application est servie derriere le nginx de l'hote, qui expose un point
// d'entree unique sur le port 80 et distingue les applications par un
// sous-chemin (/app1 ProspectAI, /app2 Hermes, ... /app4 Migration Factory).
// Servir Migration Factory sous /app4/ impose que TOUT chemin absolu construit
// par le code — appels API, redirections, routes — porte ce prefixe : sinon la
// requete part a la racine et atterrit sur le portail.
//
// La valeur vient de Vite (`base` dans vite.config.ts, pilote par APP_BASE) :
//   APP_BASE=/app4/  -> BASE_PATH = '/app4'
//   APP_BASE absent  -> BASE_PATH = ''  (comportement historique, app a la racine)
// Aucun chemin en dur ici : changer de prefixe ne demande qu'une variable
// d'environnement et un redemarrage du conteneur frontend.
// =====================================================================

const RAW_BASE = import.meta.env.BASE_URL || '/';

/** Prefixe sans slash final : '' a la racine, '/app4' en sous-chemin. */
export const BASE_PATH = RAW_BASE.replace(/\/+$/, '');

/** Valeur attendue par `basename` de react-router (slash final tolere). */
export const ROUTER_BASENAME = RAW_BASE;

/** Prefixe un chemin absolu de l'application : withBase('/login') -> '/app4/login'. */
export const withBase = (path: string): string =>
  `${BASE_PATH}${path.startsWith('/') ? path : `/${path}`}`;

/** Racine de l'API REST, prefixe compris : '/app4/api/v1'. */
export const API_V1 = withBase('/api/v1');
