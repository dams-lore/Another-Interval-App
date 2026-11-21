# T-013 — Bips et haptics pendant la séance

- **Statut** : en cours (code écrit, non compilé)
- **Priorité** : P0
- **Type** : feat
- **Dépend de** : T-012

## Pourquoi
L'athlète s'entraîne sans regarder l'écran : le son et les vibrations guident la séance, sans couper sa musique.

## Règles (reprises de l'app Expo, `app/workout/[id]/run.tsx`)
- Compte à rebours 3-2-1 : vibration moyenne à chaque seconde ; « GO » : bip court + vibration succès.
- 10 s avant la fin d'un bloc / du cap / de l'AMRAP : bip court + alerte forte (1 vibration erreur + 8 impacts lourds). Pas d'alerte si le bloc dure 10 s ou moins.
- Fin de bloc (ou Skip) et fin de séance : bip long + vibration succès.
- Le son se mélange à la musique (`AVAudioSession .playback + .mixWithOthers`).

## Fichiers concernés
- `Domain/Guidance.swift` (`GuidanceCue`, protocole `GuidanceOutput`), `TimerEngine/RunEvent.swift` (détecteur, testé), `Platform/SystemGuidanceOutput.swift` + `SineWAV.swift`, `TestSupport/RecordingGuidanceOutput.swift`, `RunViewModel`.

## Critère de fin (sur l'iPhone, pas le simulateur)
- [ ] `swift test` vert (Domain, TimerEngine, Platform, FeatureWorkoutRun).
- [ ] Bip audible à 10 s de la fin d'un bloc, avec de la musique qui continue.
- [ ] Vibrations perceptibles (compte à rebours, alerte 10 s, fin de bloc).

## Hors périmètre
- Alertes écran verrouillé / Live Activity et notifications locales (ticket suivant).
