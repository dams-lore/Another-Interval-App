# T-008 — Corriger les erreurs `tsc` existantes et rendre l'étape CI bloquante

- **Statut** : à faire
- **Priorité** : P1
- **Type** : fix
- **Dépend de** : T-007

## Pourquoi
`npx tsc --noEmit` échoue déjà sur `master` (6 erreurs). L'étape TypeScript de la CI est donc non bloquante pour l'instant.

## Fichiers concernés
- `app/(tabs)/activities/[id].tsx` (`workout` possiblement `undefined`, l. 76 et 80)
- `app/_layout.tsx` (type `NativeTheme` / `Theme`, l. 48)
- `components/ExternalLink.tsx` (`@ts-expect-error` inutile, l. 13)
- `components/Themed.tsx` (index `ColorSchemeName`, l. 24 et 29)
- `.github/workflows/ci.yml` (retirer `continue-on-error`)

## À faire
- Corriger les 6 erreurs, avec des tests unitaires sur ce qui est testable.
- Retirer `continue-on-error: true` de l'étape TypeScript.

## Critère de fin (vérifiable sur l'iPhone)
- [ ] CI entièrement verte et bloquante sur la PR.
- [ ] Écran détail d'une activité et thème clair/sombre inchangés sur l'iPhone.

## Hors périmètre
- Nettoyage plus large du template → T-004.
