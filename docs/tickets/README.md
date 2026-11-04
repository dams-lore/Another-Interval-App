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

## Idées non encore découpées
- Finir la refonte design Garmin (après T-001)
- Reprise Figma : Profile → Workout Detail → New Workout (après T-003)
- Interval score partageable
- Découper `app/workout/[id]/run.tsx` (1 127 lignes) en hooks/composants
- Codemagic : déclencher sur tag plutôt qu'à chaque push sur `master`
