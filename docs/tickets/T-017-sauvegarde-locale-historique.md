# T-017 — Sauvegarde locale et historique (app opérationnelle)

- **Statut** : à tester (sauvegarde et suppression validées sur l'iPhone le 26/11/2026 ; reste la réouverture du récap)
- **Priorité** : P0
- **Type** : feat
- **Dépend de** : T-016

## Pourquoi
Pour tester l'app en vrai sur l'iPhone, les séances importées et les résultats doivent survivre à la fermeture de l'app.

## Fait
- `Domain` : `SessionRecord` (séance effectuée, avec copie figée de la séance et les `SetResult`), protocoles `WorkoutRepository` / `SessionRepository`.
- `DataLayer` : stockage local en fichiers JSON (`workouts.json`, `sessions.json` dans Application Support), écriture atomique, fichier illisible mis de côté (`.corrupt`), suppression logique des séances.
- `FeatureWorkoutRun` : le résultat est remis à l'app **une seule fois** à la fin d'une séance (pas si rien n'a été fait) ; sets écoulés pendant que l'app était en arrière-plan marqués « non finis ».
- App : onglets **Séances** (démo ajoutées une fois, importées, suppression par balayage) et **Historique** (récap set par set rouvrable) ; import photo : « Enregistrer sans lancer ».

## Écart avec la spec
- Stockage en JSON plutôt que GRDB (SQLite) : plus simple à valider sans Mac sous la main ; migration vers GRDB prévue derrière les mêmes protocoles (spec § 8), avec l'outbox de synchronisation.

## Hors périmètre
- Éditeur de séance, records (PR), courbe de FC, synchronisation Supabase, export.

## Critère de fin (sur le Mac / iPhone)
- [x] `swift test` vert (Domain, DataLayer, FeatureWorkoutRun) et tests de l'app.
- [x] Une séance importée ou lancée reste dans la liste après fermeture complète de l'app.
- [ ] Une séance terminée apparaît dans l'historique ; son récap set par set se rouvre.
- [x] Suppression d'une séance et d'une ligne d'historique.
