# T-014 — Import de séance par photo (killer feature)

- **Statut** : en cours (option A écrite, non compilée)
- **Priorité** : P0
- **Type** : feat
- **Dépend de** : T-011

## Pourquoi
Différenciateur n°1 du produit : photographier le tableau / la feuille du coach et obtenir une séance prête à lancer.

## Décision (21/11/2026, Dams)
- **Option A pour les tests** : appel direct à l'API Anthropic depuis l'app **Debug**, avec une clé de développement lue dans `apple/Apps/iOSApp/Config/Secrets.xcconfig` (ignoré par git, jamais en dur, jamais dans la version Release).
- **Option B avant toute distribution** : Edge Function Supabase `import-workout` (spec § 7) ; la clé ne doit jamais être dans l'app publiée. Voir T-002.

## Fichiers concernés
- `Backend` : `AnthropicImportClient`, `WorkoutImportDTO`. `DataLayer` : `WorkoutImportMapper`, `PhotoWorkoutImportService`.
- `Domain/WorkoutImportService`, `TestSupport/FakeWorkoutImportService`.
- `Features/FeaturePhotoImport` : `PhotoImportViewModel`, `PhotoImportView` (PhotosPicker, UI simple ; finition d'après Figma « Import 1/2/3 » plus tard).
- `apple/Apps/iOSApp` : bouton « Importer une séance par photo », config xcconfig.

## Retour du premier test (21/11/2026)
- Photo « EMF RX - DARK ZONE » (« Every 5:00 x 6 sets », 4 tâches : rameur en calories, burpees) refusée : « un fractionné demande au moins un bloc chronométré ».
- Corrigé : (1) format **Every X × N / EMOM** avec durée d'intervalle (`Workout.intervalSeconds`) et liste des tâches de l'intervalle ; (2) fractionné avec **blocs manuels** (reps, distance : bouton « Bloc terminé », chrono qui compte le temps du bloc) ; (3) prompt IA enrichi (calories, H/F 20/16, niveau RX, « Every X »).
- La séance est aussi dans la liste de démo (sans IA).

## Critère de fin
- [ ] `swift test` vert (Backend, DataLayer, FeaturePhotoImport).
- [ ] Dans le simulateur (photo glissée dans l'app Photos) : photo → séance affichée → « Lancer la séance » ouvre l'écran de séance avec les bons blocs.
- [ ] Cas d'erreur lisibles : sans clé, photo illisible, hors ligne.

## Hors périmètre
- Caméra directe, consentement IA, quota gratuit, stockage de la séance (étapes suivantes).
