# T-016 — Parcours « Every X × N » (récap, set par set, repos, récap de fin)

- **Statut** : à tester (set « non fini » validé sur l'iPhone le 26/11/2026 ; restent les 4 écrans et le récap de fin)
- **Priorité** : P0
- **Type** : feat
- **Dépend de** : T-014

## Pourquoi
Les séances « Every 5:00 × 6 sets » sont le cas d'usage réel de Dams. La simulation HTML (voir `docs/design/every-x-run.md`) est la cible : l'app doit afficher les tâches par set, laisser valider au tap, montrer l'avancement et donner un récap des temps par étape et par set.

## À faire
1. Récap avant départ : étapes par type et répétitions, réglages Départ dans (10/20/30 s) et Validation (4 taps / 1 tap).
2. Pendant la séance : set X / N, étape Y / Z, chrono avant le prochain set, tap n'importe où pour valider, annulation du set, pastilles de sets.
3. Avancement dans les blocs (segments) et écran de repos.
4. Récap de fin : sets finis, moyenne, meilleur / pire / écart, barres par set avec splits et repos, copie du résultat.

## Hors périmètre
- Sélecteur de niveau « Calories 15 / 20 » (variantes RX), format « Failure », courbe de FC et zones (écran 5), sauvegarde de l'historique, montre Garmin.

## Critère de fin (sur le Mac / iPhone)
- [x] `swift test` vert (Domain, FeatureWorkoutRun, Platform).
- [ ] La séance DARK ZONE de la liste de démo suit les 4 écrans de la simulation.
- [x] Un set non fini à 5:00 est noté « non fini » et le set suivant démarre.
