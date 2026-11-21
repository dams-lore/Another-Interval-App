# T-011 — Domain + TimerEngine (étape 2 de `docs/architecture.md` § 15)

- **Statut** : à tester (swift test vert sur Mac le 21/11/2026 : Domain 13 tests, TimerEngine 19 tests)
- **Priorité** : P0
- **Type** : feat
- **Dépend de** : T-010

## Pourquoi
Le cœur du produit : le moteur de timer, testable sans UI ni iPhone.

## Fichiers concernés
- `apple/Packages/Domain` : `Workout`, `Step`, `DomainError`, `Pace`, validation d'une séance.
- `apple/Packages/TimerEngine` : `TimerEngine` (struct, temps par horodatages), `RunConfiguration`, `RunState`.
- `apple/Packages/TestSupport` : `TestClock`.

## À faire
- Formats For Time (avec cap), AMRAP, EMOM, fractionné ; pause/reprise, skip, compte de tours, fin manuelle.
- Tests de tous les formats.

## Écarts assumés avec la spec
- Moteur en `struct` pure (l'`actor` + `AsyncStream` et les événements sonores viendront avec l'étape 3, quand l'UI en a besoin).
- `Session`, `BlockResult`, `PersonalRecord`, interval score, zones cardiaques : étapes suivantes (la formule du score reste à spécifier).

## Critère de fin (vérifiable sur le Mac)
- [x] `swift test` vert dans `Domain` (13) et `TimerEngine` (19). `TestSupport` testé via TimerEngine.
- [ ] `Cmd+U` vert dans Xcode.
