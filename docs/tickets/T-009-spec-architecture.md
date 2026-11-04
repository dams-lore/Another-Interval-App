# T-009 — Spec technique de l'app native (Swift + Supabase)

- **Statut** : à tester
- **Priorité** : P0
- **Type** : docs
- **Dépend de** : —

## Pourquoi
Décision du 04/11/2026 : réécriture native Swift et backend Supabase. Il faut une spec technique finale qui couvre le vrai domaine (timer d'intervalles) et les exigences de `docs/besoins-internet.md`.

## Fichiers concernés
- `docs/architecture.md` (nouveau)
- `CLAUDE.md` (index docs)

## À faire
- Consolider l'ébauche d'Antoine : packages SPM, Domain timer, TimerEngine, sync local-first GRDB + Supabase, WearableKit (Garmin piloté par l'iPhone), navigation, CI/CD, ordre de construction.

## Critère de fin
- [ ] Antoine et Dams valident la spec dans la PR (relecture + points du § 16 tranchés ou reportés).

## Hors périmètre
- Mise à jour de la stack dans `CLAUDE.md` : à la bascule (§ 13).
- Création du squelette : ticket séparé (étape 1 du § 15).
