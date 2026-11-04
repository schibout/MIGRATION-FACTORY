---
name: verify-change
description: Choisir et executer les controles locaux pertinents pour un changement Migration Factory, puis rapporter les preuves et les verifications restantes.
---

# Verifier un changement

Depuis la racine du depot :

```bash
python scripts/ai/verify_change.py --plan
python scripts/ai/verify_change.py
```

Pour les fichiers indexes avant commit, utiliser `--staged` ; pour le socle
complet hors ligne, utiliser `--all`. Le script n'installe pas de dependances
et ne lance pas de migration SQL ni la suite backend complete.

- Examiner le plan pour comprendre les controles selectionnes.
- Executer les controles pertinents et lire codes de retour et diagnostics.
- Les tests automatiques backend utilisent une liste de tests hors ligne
  auditee. Ne jamais remplacer cela par `pytest backend/` sans examiner les
  connexions et effets des autres tests.
- Un changement SQL appelle une revue SAP/IFS et, si necessaire, un essai
  manuel dans une base de test isolee. Ne pas annoncer « SQL valide » sur la
  seule base d'une analyse de fichiers.
- Pour une regression UI, ajouter une reproduction Playwright sur une instance
  de developpement et des donnees de test ; ne pas declencher d'import ou de
  rechargement sur l'instance en service.
- Ne pas executer de generation Ollama par reflexe pendant une chauffe.

Restituer ce qui a ete execute, le resultat et les controles non realises,
avec leur raison. Un outil ou une dependance absent est une limite a corriger,
pas un succes. Eviter les changements de code metier sans rapport avec la
verification demandee.
