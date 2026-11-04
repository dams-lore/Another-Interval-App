# Architecture technique — app native iOS / watchOS

> Statut : **proposition à valider** (PR T-009). Remplace, une fois validée, la stack Expo décrite dans `CLAUDE.md`.
> Décisions du 04/11/2026 : **réécriture Swift native** ; **backend Supabase** (comparatif Supabase / Cloudflare : voir § 14) ; **projet Xcode généré par Tuist** (§ 2 bis).
> Exigences fonctionnelles et contraintes Apple : `docs/besoins-internet.md`. Produit : `docs/product.md`.

## 1. Contexte et contraintes

- App iPhone de **timer et suivi d'entraînement structuré** (CrossFit, HYROX, fractionné) : créer une séance (à la main ou par photo), l'exécuter guidée (iPhone, montre), comparer réel vs cible, suivre ses PR.
- Stack : **Swift 6** (strict concurrency partout), **SwiftUI**, **iOS 17+ / watchOS 10+**, monorepo **Swift Package Manager**.
- **Garmin** n'exécute pas de Swift : l'app montre reste en Monkey C (`watch-garmin/`, déjà fonctionnelle). L'iPhone **pilote** la montre (état du bloc en cours) et la montre renvoie les actions de l'athlète.
- **Apple Watch** arrive plus tard : elle doit réutiliser Domain, Data et le moteur de timer sans modification.
- **Local-first** : tout fonctionne hors ligne (salle de sport = réseau faible), le cloud synchronise.
- **Un Mac est obligatoire** pour builder et tester (Xcode). Dams (Windows) passe par les builds Codemagic / TestFlight.
- Objectif : architecture modulaire, testable, dépendances à sens unique, chaque module testé (convention « tout code a des tests unitaires »).

## 2. Arborescence

```
apple/                         (tout le natif ; l'app Expo reste à la racine jusqu'à la bascule, § 13)
  Tuist.swift                  configuration Tuist
  Workspace.swift              workspace : apps + packages
  Tuist/
    Package.swift              dépendances externes (supabase-swift, GRDB, RevenueCat…)
    ProjectDescriptionHelpers/ fonctions partagées (créer un module, ses tests, ses réglages)
  Apps/
    iOSApp/                    cible app iOS (composition root)
    iOSWidgets/                Live Activity + widgets (ActivityKit / WidgetKit)
    WatchApp/                  cible watchOS (plus tard)
  Packages/
    Domain/                    Swift pur : entités, règles, protocoles, use cases
    TimerEngine/               moteur d'exécution de séance (Swift pur, partagé iOS/watchOS)
    Data/                      repositories : GRDB (local) + Supabase (sync), outbox
    Backend/                   client Supabase (auth, tables, Edge Functions), DTO
    Platform/                  audio, haptics, notifications, HealthKit, Live Activity, StoreKit/RevenueCat
    WearableKit/
      WearableGarmin/          Connect IQ Mobile SDK
      WearableAppleWatch/      WatchConnectivity / WorkoutKit (plus tard)
    DesignSystem/              tokens Liquid Glass, composants, mode gym
    Features/
      FeatureHome/
      FeatureWorkoutEditor/    création / édition manuelle
      FeaturePhotoImport/      import par photo (consentement IA inclus)
      FeatureWorkoutRun/       exécution guidée + mode gym
      FeatureSessionSummary/   résumé, réel vs cible, interval score, partage
      FeatureHistory/          historique, analytics, courbe FC
      FeatureRecords/          PR / benchmarks
      FeatureAccount/          auth, abonnement, suppression de compte, export RGPD
      FeatureDeviceSync/       appairage montres
      FeatureSettings/
    TestSupport/               fakes, fixtures, horloge contrôlable
supabase/                      migrations SQL, politiques RLS, Edge Functions, seed
watch-garmin/                  app Connect IQ (inchangée)
```

## 2 bis. Projet Xcode généré par Tuist

- **Aucun `.xcodeproj` ni `.xcworkspace` n'est commité** (ajoutés au `.gitignore`). Ils sont générés par `tuist generate`, sur chaque Mac et en CI, à partir de manifestes Swift versionnés.
- Pourquoi : supprimer les conflits de merge sur `project.pbxproj` (une PR par ticket, branches parallèles), rendre les changements de projet lisibles en PR, garantir des réglages identiques partout.
- Chaque cible (`Apps/iOSApp`, `Apps/iOSWidgets`, `Apps/WatchApp`) a son `Project.swift`. Les modules sont déclarés via des **fonctions de `ProjectDescriptionHelpers`** (ex. `.feature("WorkoutRun")` crée la cible et sa cible de tests, avec Swift 6 strict) : tous les modules sont configurés de façon identique.
- Les packages de `Packages/` restent des **packages SPM classiques** (`Package.swift`), testables seuls avec `swift test`, sans Tuist. Tuist sert à assembler les apps.
- Dépendances externes déclarées dans `Tuist/Package.swift`, installées par `tuist install`.
- **Version de Tuist figée** (`mise`, fichier `.mise.toml`) : même version sur tous les Mac et en CI.
- `tuist graph` sert à vérifier visuellement la règle de dépendances (§ 3).
- Uniquement les fonctions gratuites et locales de Tuist (pas de cache distant payant).
- Commandes : `tuist install` puis `tuist generate` (ouvre Xcode) ; `tuist test` en CI.

## 3. Règle de dépendances

```
Features ──► Domain, DesignSystem
TimerEngine ──► Domain
Data ──► Domain, Backend
Backend ──► (SDK supabase-swift uniquement)
Platform ──► Domain
WearableGarmin / WearableAppleWatch ──► Domain
Apps ──► tout (assemblage)
```

- **Domain ne dépend de rien** : ni SwiftUI, ni GRDB, ni Supabase, ni SDK tiers.
- Les Features ne voient que des **protocoles** du Domain : jamais Data, Backend, Platform ni un SDK.
- Le schéma Supabase ne fuit jamais hors de Backend/Data (mapping DTO ↔ entité dans Data).
- Vérifié en CI : chaque package compile seul (`swift build` par package) ; un import interdit casse le build.

## 4. Domain (Swift pur)

Toutes les entités sont des `struct` `Sendable`, `Codable`, `Equatable`, avec un `id: UUID` **généré côté client** (requis par la sync).

### Entités (alignées sur `types/workout.ts`, `types/session.ts` et le modèle de données de Dams)
- `Workout` : modèle de séance — `id`, `name`, `format`, `sport?`, `steps: [Step]`, `capTime?`, `rounds?`, `source` (`manual` | `photoImport`), `createdAt`, `updatedAt`, `deletedAt?`.
- `WorkoutFormat` : `forTime`, `amrap`, `emom`, `intervals` (EMOM : nouveau, absent de l'app actuelle).
- `Step` : `id`, `type` (`reps` | `distance` | `time`), `movement`, `value`, `unit?`, `weight?`, `height?`, **cibles** (`targetPace?`, `targetHR?`), `notes?`.
- `Session` : exécution d'un workout — `id`, `workoutId`, `workoutSnapshot` (copie figée du workout au lancement : l'historique ne change pas si le modèle est modifié), `startedAt`, `endedAt`, `roundsCompleted`, `blockResults: [BlockResult]`, `hrSamples: [HRSample]`, `intervalScore?`.
- `BlockResult` : `stepId`, `roundIndex`, `startedAt`, `endedAt`, `duration`, mesures réelles (`distance?`, `avgPace?`, `avgHR?`).
- `HRSample` (`t`, `bpm`, `source`), `GPSSample` (`t`, `speed`, `coordinate?`).
- `PersonalRecord` : `movement`, `metric` (temps, charge, allure…), `value`, `sessionId`, `achievedAt`.
- `UserProfile` : `id`, `displayName?`, unités, FC max/repos (zones), `isAnonymous`.
- `Entitlement` : `isPremium`, `expiresAt?`, `source`. **Lecture seule** côté app : la vérité est serveur.
- `Device` : `id`, `name`, `brand` (`garmin` | `appleWatch` | `bleHRM`), `connectionState`.
- `AIImport` : `id`, `status`, `createdAt` (affichage du quota restant).

### Règles métier pures
- Allure, vitesse, conversions d'unités.
- Zones cardiaques (à partir de FC max/repos du profil).
- **Réel vs cible** par bloc, **interval score** (respect des consignes du coach), détection de PR.
- Agrégats hebdo / mensuels.
- Limites freemium (nombre de séances sauvegardées) : règle pure, alimentée par l'`Entitlement`.

### Protocoles
- Repositories (`async throws`) : `WorkoutRepository`, `SessionRepository`, `RecordRepository`, `ProfileRepository` — chacun expose aussi un flux `AsyncStream` pour l'observation.
- `AuthService` (session anonyme, Sign in with Apple, magic link, déconnexion, suppression de compte), `EntitlementService`, `WorkoutImportService` (photo → `Workout`), `ConsentService`, `SyncService`.
- `WearableLink` (§ 8), `Clock` (horloge injectable), `GuidanceOutput` (audio/haptics, § 6).

### Use cases
`CreateWorkout`, `ImportWorkoutFromPhoto`, `StartSession`, `FinishSession` (persiste, calcule PR et interval score), `FetchHistory`, `ComputeStats`, `DeleteAccount`, `ExportUserData`.

### Erreurs
`DomainError` typé : `notAuthenticated`, `quotaExceeded`, `consentRequired`, `premiumRequired`, `offline`, `notFound`, `validation(…)`.

## 5. TimerEngine (le cœur du produit)

Package séparé, **Swift pur**, partagé iOS / watchOS.

- Machine à états : `idle → countdown → running(block, round) ⇄ paused → finished`. Gère For Time, AMRAP (arrêt au cap), EMOM (top chaque minute), Intervals (passage auto au bloc suivant, `skip`).
- Un `actor TimerEngine` publie un `AsyncStream<RunState>` (bloc, round, temps écoulé/restant, cible, alertes).
- **Le temps est calculé à partir d'horodatages** (`startedAt` + pauses cumulées), jamais en additionnant des ticks : l'état reste juste après verrouillage de l'écran, mise en arrière-plan ou ralentissement.
- `Clock` injectée : les tests avancent le temps instantanément (`TestClock` dans TestSupport).
- Émet des **événements** (`blockStarted`, `tenSecondsLeft`, `roundCompleted`, `finished`) consommés par l'audio, les haptics, la Live Activity et les montres.
- Couverture de tests attendue : tous les formats, pause/reprise, skip, cap AMRAP, non-régressions de `docs/roadmap.md`.

## 6. Platform (services système)

- **Audio** (`AVAudioSession`, catégorie `.playback` + `.mixWithOthers` / `.duckOthers`) : bips sans couper la musique (différenciateur produit).
- **Haptics** (Core Haptics / `UIFeedbackGenerator`).
- **Arrière-plan** : Live Activity (ActivityKit, chrono système `Text(timerInterval:)`) sur l'écran verrouillé et la Dynamic Island + notifications locales planifiées pour les fins de bloc.
- **Location** (vitesse GPS pour les blocs de course), **HealthKit** (écriture des séances et de la FC, lecture FC), **StoreKit 2 via RevenueCat**, **App Attest**.
- Chaque service implémente un protocole du Domain ; un fake existe dans TestSupport.

## 7. Backend Supabase et package Backend

### Projets
Trois projets Supabase en **région UE (Francfort)** : `dev` et `staging` (gratuits), `prod` (Pro). Le schéma vit dans `supabase/migrations/`, appliqué par la CI.

### Schéma (tables, toutes avec `user_id`, `created_at`, `updated_at`, `deleted_at`)
`profiles`, `workouts`, `sessions`, `block_results`, `personal_records`, `entitlements` (écrite seulement par le webhook RevenueCat), `ai_imports` (quota, statut, coût), `consents` (type, version, date), `integrations` (jetons chiffrés, jamais lisibles par l'app).

### Sécurité
- **RLS activée sur toutes les tables** : `user_id = auth.uid()`. Tests SQL de requêtes croisées en CI (un utilisateur ne lit jamais les lignes d'un autre).
- Aucune clé secrète dans l'app : seulement l'URL et la clé `anon` publique. Jetons de session en **Keychain**.
- Session anonyme protégée par CAPTCHA invisible et limite par IP (recommandation Supabase).

### Auth
Session anonyme au premier lancement → conversion par **Sign in with Apple** ou **magic link** (`linkIdentity`) sans perte de données.

### Edge Functions
- `import-workout` : vérifie utilisateur, consentement, quota, App Attest → appelle Claude Vision (clé Anthropic côté serveur) → renvoie un JSON **validé** par schéma. Remplace l'appel direct actuel (T-002).
- `revenuecat-webhook` → met à jour `entitlements`.
- `delete-account` : supprime les données, l'utilisateur auth, le client RevenueCat et les intégrations.
- `export-data` : archive JSON RGPD.
- `strava-oauth` (plus tard).

### Package Backend
Fin wrapper autour de **`supabase-swift`** : DTO `Codable` du schéma, appels des Edge Functions. Pas de client OpenAPI généré (inutile avec Supabase). Seul Data dépend de Backend.

## 8. Sync local-first (package Data)

- **Stockage local : GRDB (SQLite)**, pas SwiftData : contrôle fin du schéma, migrations explicites, observation de requêtes, compatible Swift 6, et adapté à une sync maison.
- Les repositories lisent et écrivent **toujours en local** ; l'UI ne dépend jamais du réseau.
- **Outbox** : chaque écriture locale ajoute une ligne dans `outbox` (table, id, opération) dans la même transaction.
- `SyncService` (`actor`) : pousse l'outbox (upsert par UUID client), puis tire les changements serveur depuis `last_pulled_at` (`updated_at > curseur`). Déclenché au lancement, au retour au premier plan, après une écriture et au retour du réseau.
- Conflits : **dernier écrit gagne** (`updated_at`) ; suppression logique (`deleted_at`) pour propager les suppressions.
- Les sessions sont quasi immuables (une fois terminées) : conflits rares en pratique.
- Accès base encapsulé dans des `actor` ; DTO et lignes GRDB mappés vers les entités Domain.

## 9. WearableKit

### Protocole commun
```swift
protocol WearableLink: Sendable {
  var connectionState: AsyncStream<ConnectionState> { get }
  func connect() async throws
  func disconnect() async
  func send(_ state: RunState) async          // iPhone → montre, à chaque changement d'état
  var actions: AsyncStream<WearableAction> { get }   // montre → iPhone : pause, nextBlock
  var heartRate: AsyncStream<HRSample> { get }       // montre → iPhone, si disponible
}
```

### WearableGarmin
- `actor` qui confine le **Connect IQ Mobile SDK** (non-Sendable), communication via l'app Garmin Connect.
- **Protocole JSON existant conservé** (`watch-garmin/README.md`) : `workout_state` (phone → montre) et `user_action` (montre → phone). L'app Monkey C n'a pas à changer.
- Évolution prévue : message `hr_sample` montre → phone pour enregistrer la FC dans la session.

### WearableAppleWatch (plus tard)
- **WatchConnectivity** pour le pilotage live (même `RunState`), `HKWorkoutSession` sur la montre pour la FC, **WorkoutKit** pour envoyer une séance à l'app Exercice en autonomie.
- L'app watchOS embarque `TimerEngine` et `Domain` tels quels.

### Tests
`FakeWearableLink` dans TestSupport : développer et tester sans montre.

## 10. Features et navigation

- **MVVM** : un ViewModel `@Observable @MainActor` par écran, qui ne parle qu'aux use cases et protocoles du Domain.
- Dépendances injectées par initialiseur ; aucun singleton.
- Les Features ne se connaissent pas : elles exposent leurs **intentions de sortie** en closures (`onStartWorkout(Workout.ID)`, `onSessionFinished(Session.ID)`).
- Dans l'app : `AppRouter` `@Observable @MainActor`, `enum Route: Hashable` (`workoutDetail(id)`, `workoutEditor(id?)`, `photoImport`, `run(workoutID)`, `sessionSummary(id)`, `paywall`, `account`, `deviceSync`, `settings`), `NavigationStack(path:)` + `navigationDestination(for: Route.self)`.
- Un routeur par onglet (`TabView`). Deep links / liens universels (partage de score) et restauration d'état via le routeur.
- **Paywall** : une seule route, déclenchée par `DomainError.premiumRequired`.
- watchOS : même `Route`, routeur simplifié.

## 11. DesignSystem

- Tokens repris de `docs/design-system.md` (Liquid Glass, Manrope / Inter / Bebas Neue).
- Composants : cartes de séance, chrono (minutes/secondes même taille, seule la graisse change — règle critique n° 3), cercle de progression (seulement pour les blocs temporels — règle n° 2), badges de zones, graphiques Swift Charts.
- **Mode gym** : alertes plein écran lisibles de loin.
- Partagé iOS / watchOS quand c'est pertinent.

## 12. Qualité, CI/CD, observabilité

- **Tests** : Swift Testing dans chaque package (`swift test`). Priorité : TimerEngine, Domain, sync, mapping DTO. Tests UI XCTest seulement sur les parcours critiques (lancer une séance, terminer, retrouver dans l'historique).
- **CI GitHub Actions** (runner macOS) à chaque commit de PR : `swift test` par package, build de l'app, lint (SwiftLint / swift-format), tests RLS Supabase. Bloquante avant merge.
- **CD** : Codemagic → TestFlight au merge sur `master` (ou sur tag, pour économiser les minutes) ; migrations Supabase appliquées sur `staging` puis `prod`.
- **Environnements** : `dev` / `staging` / `prod` via des configurations Xcode (`.xcconfig`, déclarées dans les manifestes Tuist) pointant chacune vers son projet Supabase.
- **Génération en CI** : `tuist install` puis `tuist generate --no-open` avant tout build ou test, sur GitHub Actions comme sur Codemagic.
- **Observabilité** : Sentry (crashs), PostHog UE ou TelemetryDeck (analytics), déclarés dans le **privacy manifest**.
- **Feature flags** : table `remote_config` Supabase (couper une feature IA coûteuse).
- Pas de mise à jour OTA (EAS Update) en natif : chaque correctif repasse par la review Apple.

## 13. Migration depuis l'app Expo

- L'app Expo reste en place et utilisable jusqu'à la **parité fonctionnelle** du natif ; le natif vit dans `apple/` (pas dans `ios/`, réservé au prebuild Expo).
- Aucun utilisateur externe aujourd'hui : **pas de migration de données** à prévoir (les données de test de Dams peuvent être réimportées ou abandonnées, à décider).
- À la bascule : suppression de l'app Expo, mise à jour de `CLAUDE.md` (stack, commandes), de la CI et de `codemagic.yaml`.

## 14. Pourquoi Supabase (rappel du comparatif du 04/11/2026)

À notre échelle, l'hébergement coûte peu dans les deux cas (~25 $/mois Supabase Pro contre ~5 $/mois Cloudflare Workers) ; le coût dominant est l'IA. Supabase fournit d'emblée l'auth (anonyme convertible + Apple), **Postgres avec RLS** (sécurité par défaut au lieu de vérifications à la main dans chaque endpoint), les Edge Functions, la console et les sauvegardes, la région UE et un SDK Swift officiel. La dépendance reste confinée aux packages Backend/Data : passer un jour sur un backend maison ne toucherait ni le Domain ni les Features.

## 15. Ordre de construction (un critère de fin vérifiable chacun)

1. **Squelette** : monorepo, manifestes Tuist + helpers, packages vides, Swift 6 strict, app iOS qui démarre, CI verte. → *L'app vide s'installe sur l'iPhone via TestFlight.*
2. **Domain + TimerEngine + TestSupport**, tests complets. → *Tous les formats passent en test, sans UI.*
3. **Data local (GRDB)** + FeatureWorkoutEditor + FeatureWorkoutRun (audio, haptics, mode gym, Live Activity). → *Créer une séance, l'exécuter écran verrouillé avec la musique, la retrouver dans l'historique — hors ligne.*
4. **Supabase** : projets, schéma, RLS, auth anonyme + Apple, sync. → *Une séance créée hors ligne est retrouvée après réinstallation.*
5. **Import photo** : Edge Function `import-workout`, consentement, quota. → *Une photo donne une séance ; le 4ᵉ import gratuit est refusé côté serveur.*
6. **Abonnement** : RevenueCat, webhook, paywall. → *Un achat sandbox débloque l'import ; la restauration fonctionne.*
7. **Compte** : suppression + export RGPD. → *Tout disparaît côté base et RevenueCat.*
8. **Historique, analytics, PR, interval score, partage** (parité avec l'app Expo).
9. **WearableGarmin.** → *La Vivoactive 5 affiche le bloc en cours et pause la séance.*
10. **Observabilité + privacy manifest + soumission TestFlight externe.**
11. **Apple Watch** (après acquisition d'une montre de test).

## 16. Points à trancher

- **Version minimale** : iOS 17 (base de cette spec) ou iOS 18 (API SwiftUI plus récentes, parc un peu réduit).
- **Données de test de l'app Expo** : réimport ou abandon.
- **Définition du premium** (tension rétention / limite de séances, `docs/product.md`) : nécessaire avant l'étape 6.
- **EMOM** : confirmé pour la V1 native ?
- **Déclenchement Codemagic** : à chaque merge ou sur tag.
