# T-007 — Conventions PR + tests unitaires + CI

- **Statut** : à tester
- **Priorité** : P1
- **Type** : chore
- **Dépend de** : —

## Pourquoi
Rien n'empêchait un commit direct sur `master`, aucun test n'existait et rien ne vérifiait le code avant un merge.

## Fichiers concernés
- `CLAUDE.md`, `.claude/skills/ticket/SKILL.md`
- `package.json`, `package-lock.json`
- `.github/workflows/ci.yml`
- `utils/__tests__/*.test.ts`
- `components/__tests__/StyledText-test.js` (supprimé)

## À faire
- Conventions : tout ajout via PR, tests unitaires obligatoires, CI sur chaque commit de PR.
- Installer Jest (`jest-expo`) + script `npm test`.
- Premiers tests sur `utils/` (`isMovingActivity`, `generateId`).
- Workflow GitHub Actions : `jest --ci` (bloquant) + `tsc --noEmit` (non bloquant, voir T-008).
- Supprimer le test hérité du template, cassé (erreur de rendu, snapshot vide).

## Critère de fin
- [ ] Le check « CI / Tests unitaires + TypeScript » apparaît et passe au vert sur la PR GitHub.
- [ ] L'app démarre toujours sur l'iPhone (aucun code applicatif modifié).

## Hors périmètre
- Correction des erreurs `tsc` existantes → T-008.
- Protection de branche `master` dans les réglages GitHub (à activer par le propriétaire du repo).

## Rapport
- 2026-11-03 : CI en place, 24 tests unitaires verts en local. `tsc` a 6 erreurs préexistantes sur `master` → étape non bloquante, T-008 créé.
