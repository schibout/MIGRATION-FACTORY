Contexte :
Le site ASAP (SharePoint 2013 on-premise, http://asap.stjn.local) contient une liste « États d'avancement » par projet. Le numéro de projet est le sous-site dans l'URL (ex. /976).

Tâche :
Récupère les états d'avancement du projet {NUMERO_PROJET} via l'API REST SharePoint, depuis l'onglet ouvert sur asap.stjn.local (session Windows déjà authentifiée, lecture seule, requêtes GET uniquement).

Appel à exécuter (fetch dans la page, en-tête Accept: application/json;odata=verbose) :
/{NUMERO_PROJET}/_api/web/lists/getbytitle('États d''avancement')/items?$select=ID,Title,Status_x0020_Date,Global_x0020_Status,Health,Cost,Planning,OData__x0025__x0020_Completed,EndProjectMark,Update,Current_x0020_Phase/Title&$expand=Current_x0020_Phase&$orderby=Status_x0020_Date desc&$top=500

Correspondance des champs :
- Title → Titre
- Status_x0020_Date → Date de l'état (UTC : convertir en heure de Paris, format JJ/MM/AAAA)
- Current_x0020_Phase/Title → Phase courante
- OData__x0025__x0020_Completed → % Complété (valeur 0–1, afficher en %)
- Global_x0020_Status → Statut global
- Health → Santé
- Cost → Coût
- Planning → Planning
- EndProjectMark → Note de fin de projet
- Update → Mise à jour (HTML : extraire le texte brut)

Restitution :
1. Un tableau trié du plus récent au plus ancien avec les colonnes ci-dessus.
2. Une synthèse en 3 à 5 lignes : dernier état, évolution du % complété, indicateurs Santé/Coût/Planning qui ne sont pas « Ok », changements de phase.
3. Si l'appel échoue, afficher le code HTTP et le message d'erreur SharePoint, sans essayer d'autre méthode.

Filtre optionnel (si une période est demandée) :
&$filter=Status_x0020_Date ge datetime'{AAAA-MM-JJ}T00:00:00Z'