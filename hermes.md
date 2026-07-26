CONTEXTE
--------
Je travaille sur "Migration Factory" (migration SAP → IFS).
Stack (à vérifier dans le code avant de commencer) :
- Frontend : React + TypeScript + Vite, Redux Toolkit (src/store/slices/*),
  Material UI (thème sombre), src/services/api.ts, src/pages/*, layout dans
  src/components/layout/Layout.tsx.
- Backend : Python (Flask + Flask-RESTX, voir app.py, api/*, services/,
  config/settings.py).

Une agent IA "Hermes" (Nous Research) tourne déjà sur le même serveur
(10.190.100.58), dans Docker, en network_mode: host. Hermes expose une API
HTTP compatible OpenAI (le "serveur API" de Hermes).

OBJECTIF
--------
Ajouter dans Migration Factory une page de chat "Assistant Hermes" qui :
1. permet de discuter avec l'agent Hermes (envoi de messages, réponses affichées
   en streaming) ;
2. permet à l'utilisateur de DONNER DES INSTRUCTIONS à Hermes (un champ
   "Instructions système" / consigne persistante qui oriente le comportement de
   l'agent sur toute la conversation).

INTÉGRATION HERMES (faits établis — à ne pas réinventer)
-------------------------------------------------------
- API de Hermes : OpenAI-compatible.
  Endpoint : POST http://10.190.100.58:8642/v1/chat/completions
  Auth     : header "Authorization: Bearer <API_SERVER_KEY>"
  Modèle   : {"model": "hermes-agent", ...} (le champ model est cosmétique)
  Body     : {"model":"hermes-agent","messages":[...],"stream":true|false}
- Le champ "instructions utilisateur" = un message {"role":"system","content":...}
  en tête du tableau messages. Hermes le superpose à son prompt interne.
- Streaming : SSE. Chunks standard "chat.completion.chunk" + un event custom
  "hermes.tool.progress" (début d'appel d'outil) qu'on peut afficher comme
  indicateur "Hermes utilise un outil…".
- Multi-tour : API stateless — renvoyer tout l'historique messages à chaque
  requête (le plus simple), OU passer un header "X-Hermes-Session-Id" stable.

PRÉREQUIS CÔTÉ SERVEUR (à documenter, pas à exécuter par toi)
------------------------------------------------------------
Le serveur API de Hermes doit être activé. Génère un court README/section
expliquant qu'il faut, sur le serveur, ajouter dans ~/.hermes/.env :
    API_SERVER_ENABLED=true
    API_SERVER_KEY=<clé secrète forte>
    API_SERVER_HOST=0.0.0.0      # pour que le conteneur backend MF puisse joindre Hermes
puis redémarrer le gateway :
    docker compose -f ~/hermes/hermes-agent/docker-compose.yml restart gateway
(Note : API_SERVER_KEY est OBLIGATOIRE ; l'API donne accès au toolset complet de
Hermes, terminal inclus.)

EXIGENCES TECHNIQUES
--------------------
Backend (proxy — la clé ne doit JAMAIS atteindre le navigateur) :
- Nouveau blueprint/namespace, ex. api/hermes.py, route POST /api/hermes/chat.
- Lit HERMES_API_URL et HERMES_API_KEY depuis config/settings.py (variables
  d'environnement ; valeurs par défaut : http://10.190.100.58:8642/v1 et vide).
- Reçoit {messages, instructions?, stream?} du front, construit le tableau
  messages (préfixe le message system = instructions si fourni), appelle Hermes
  et RELAIE le flux SSE au frontend (streaming de bout en bout).
- Gère : Hermes indisponible (502), clé manquante (500 explicite), timeouts.
- Respecte l'auth existante de Migration Factory (mêmes décorateurs/login que les
  autres routes protégées).

Frontend :
- Nouvelle page src/pages/HermesChat.tsx (+ entrée de menu dans Layout.tsx,
  route dans le routeur, style cohérent avec le thème sombre MUI existant).
- Slice Redux src/store/slices/hermesChatSlice.ts : state {messages, instructions,
  isStreaming, error}, actions pour envoyer un message et accumuler les deltas.
- Service src/services/hermesService.ts : appelle /api/hermes/chat et consomme le
  flux SSE (fetch + ReadableStream), reconstruit le texte token par token.
- UI : historique de conversation (bulles user/assistant), zone de saisie, bouton
  "Effacer la conversation", un champ repliable "Instructions à Hermes"
  (textarea) appliqué à toute la session, indicateur de streaming, et affichage
  discret des events "Hermes utilise un outil…".

CONTRAINTES
-----------
- Suis les conventions existantes du repo (nommage, structure des slices, style
  des appels API dans services/api.ts, gestion d'erreurs, i18n si présent).
- Ne mets aucune clé API dans le frontend ni dans le bundle.
- N'expose pas de nouvelle faille : la route /api/hermes/chat doit exiger la même
  authentification que le reste de l'app.
- TypeScript strict, pas de "any" superflu.

LIVRABLES
---------
1. Commence par explorer le code pour confirmer la stack et les conventions
   (routeur, auth, structure des slices/services) — ne code qu'après.
2. Propose un plan court (fichiers créés/modifiés) puis implémente.
3. Termine par : comment tester en local (variables d'env à définir, commande de
   lancement, et un exemple curl vers /api/hermes/chat).
