# Migration Factory ? Claude Code

@AGENTS.md

Les instructions communes sont dans AGENTS.md, importe ci-dessus.
Les details metier de l'ancien CLAUDE.md sont conserves dans
`docs/ai/project-reference.md` : rechercher le module concerne avant lecture.

Skills projet : `/migration-factory` et `/verify-change`.
Reviewers : `reviewer-sap-ifs` et `reviewer-fullstack`, en lecture seule.
Modifier les skills dans `.agents/skills/`, puis executer
`python scripts/ai/sync_skills.py` ; ne pas editer leurs copies Claude.
