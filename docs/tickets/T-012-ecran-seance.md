# T-012 — Écran de séance (compact + gym) — début de l'étape 3

- **Statut** : fait (validé sur l'iPhone par Dams le 26/11/2026)
- **Priorité** : P0
- **Type** : feat
- **Dépend de** : T-011

## Pourquoi
Premier écran que Dams peut toucher dans le simulateur : exécuter une séance guidée.

## Fichiers concernés
- `apple/Packages/Features/FeatureWorkoutRun` : `RunViewModel`, `RunFormat`, `RunView`.
- `apple/Packages/DesignSystem` : tokens Figma (`DS.Colors`, `DS.Radius`).
- `apple/Apps/iOSApp` : séance de démo « Breakfast Club » lancée au démarrage.

## Source de design
Figma « Another Intrval App » : `Run — Compact (Intervals)` (19:2) et `Run — Gym Mode` (20:2).

## À faire
- Compte à rebours, chrono du bloc, anneau de progression, barre de progression, Stop / Skip / Pause, bascule compact ↔ gym.
- Tests du ViewModel et du formatage.

## Hors périmètre (tickets suivants)
- Bips et haptics (package Platform), Live Activity, écran verrouillé.
- Polices Manrope / Inter (non embarquées : police système en attendant).
- Splash : le quota Figma Starter était atteint (à relire plus tard, nœuds `55:2` « Splash » et `56:9` « Splash — logo »).
- Stockage local, éditeur de séance, navigation.

## Critère de fin (vérifiable sur le Mac)
- [x] `swift test` vert dans `FeatureWorkoutRun` et `DesignSystem`.
- [x] Le simulateur affiche l'écran Run : Démarrer → compte à rebours 10 s → blocs 400m Run / Rest qui s'enchaînent.
- [x] Pause, reprise et Skip fonctionnent ; la bascule compact ↔ gym aussi.
- [x] Rendu proche des maquettes Figma.
