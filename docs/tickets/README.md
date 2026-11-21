# Backlog

> Un ticket = un fichier `T-xxx-slug.md` (modèle : `_template.md`). `/ticket` prend le premier « à faire » par priorité dont les dépendances sont faites.
> Statuts : à faire → en cours → à tester → fait (uniquement après test iPhone par Dams) | bloqué.

| ID | Titre | Priorité | Statut | Dépend de |
|---|---|---|---|---|
| T-006 | Revalidation complète sur l'iPhone (baseline) | P0 | à faire | — |
| T-001 | Rapatrier l'app Garmin dans le repo | P0 | à faire | — |
| T-002 | Sortir la clé Anthropic de l'app (proxy) | P0 avant distribution | à faire | choix hébergeur |
| T-004 | Nettoyer les restes du template et imports interdits | P1 | à faire | — |
| T-003 | Centraliser les tokens de design | P1 | à faire | choix des polices |
| T-005 | Section « Mes scores » dans Profile | P2 | à faire | T-003 |
| T-007 | Conventions PR + tests unitaires + CI | P1 | à tester | — |
| T-008 | Corriger les erreurs `tsc` existantes et rendre l'étape CI bloquante | P1 | à faire | T-007 |
| T-009 | Spec technique de l'app native (Swift + Supabase) | P0 | à tester | — |
| T-010 | Squelette de l'app native (Tuist + packages + CI) | P0 | à tester | T-009 |
| T-011 | Domain + TimerEngine (formats, pause, skip, tests) | P0 | à tester | T-010 |
| T-012 | Écran de séance compact + gym (Figma Run) | P0 | à tester | T-011 |
| T-013 | Bips et haptics pendant la séance | P0 | en cours | T-012 |
| T-014 | Import de séance par photo (killer feature) | P0 | à faire | T-011 |
| T-015 | WearableGarmin natif (Connect IQ) | P1 | à faire | T-013, T-001 |

## Idées non encore découpées
- Finir la refonte design Garmin (après T-001)
- Reprise Figma : Profile → Workout Detail → New Workout (après T-003)
- Interval score partageable
- Découper `app/workout/[id]/run.tsx` (1 127 lignes) en hooks/composants
- Codemagic : déclencher sur tag plutôt qu'à chaque push sur `master`
