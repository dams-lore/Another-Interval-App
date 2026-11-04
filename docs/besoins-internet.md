# Besoins liés à Internet — app iOS « full prod »

> Benchmark du 03/11/2026 : App Review Guidelines Apple (révision du 8 juin 2026), exigences privacy manifest, apps concurrentes (Hevy, Strava, Whoop, Hyro, The Line, HyTrack, Roxfit, Centr), RevenueCat *State of Subscription Apps 2026*.
> Décision du 03/11/2026 : on construit dès maintenant la base prod (backend, comptes, sync), pas un V1 minimal local-first.

## 1. Contraintes Apple non négociables

| Règle | Conséquence pour l'app |
|---|---|
| 5.1.2(i) : divulguer et obtenir une permission explicite avant tout partage de données perso avec une IA tierce | Écran de consentement avant l'import photo (fournisseur Anthropic nommé, type de données envoyées) |
| 5.1.1(v) : suppression de compte dans l'app dès qu'un compte peut être créé | Parcours « Supprimer mon compte » (base + RevenueCat + intégrations) |
| 4.8 : login social ⇒ option équivalente limitant la collecte | Sign in with Apple proposé avec tout autre login |
| Privacy manifest (`PrivacyInfo.xcprivacy`) obligatoire | Déclarer les API « required reason » et les SDK ; upload refusé par App Store Connect sinon |
| Privacy labels + politique de confidentialité cohérentes avec le comportement réel | Auditer SDK, analytics, appels réseau avant chaque soumission |

## 2. Tableau besoins / fonctions Internet

> Liste exhaustive, volontairement non priorisée : l'arbitrage viendra ensuite.

| Domaine | Besoin → fonction | Standard marché / contrainte |
|---|---|---|
| Identité | Session anonyme au 1er lancement, convertible en compte | Zéro friction, identifiant pour quotas IA |
| | Sign in with Apple + email (magic link) | Exigence 4.8 |
| | Suppression de compte in-app | Guideline 5.1.1(v) |
| | Export / suppression des données (RGPD) | Politique de confidentialité + lien support |
| Données | Fonctionnement hors-ligne complet + resync | Salle de sport = réseau faible |
| | Sauvegarde cloud (séances, PR, historique) | Standard Hevy/Strava ; protège le moteur de rétention |
| | Restauration des achats | Exigé par Apple |
| IA | Import photo via Claude Vision **par proxy serveur** | Jamais de clé API dans l'app (T-002) |
| | Consentement IA tracé (version, date) | Guideline 5.1.2(i) |
| | Quotas / anti-abus par utilisateur et appareil (App Attest) | Le coût par appel = la marge |
| | Coach / génération de WOD / debrief IA | « Standard 2026 » ; risque de diluer le différenciateur (import photo) |
| Monétisation | Abonnement StoreKit 2 via RevenueCat | Annuel dominant en fitness |
| | Entitlements côté serveur (webhook RevenueCat) | L'IA est protégée côté serveur |
| | Paywall testable à distance (A/B) | Levier n°1 de conversion |
| | Web checkout hors app | 41 % des apps du top tier ; à cadrer juridiquement |
| Intégrations | Apple Health (écriture séances, FC) | Attention aux doublons Watch/Strava ; Development Build requis |
| | Export FIT + copie texte du résultat | Déjà proposé par Hyro |
| | Upload Strava (OAuth via serveur) | Hevy : sens unique app → Strava |
| | Apple Watch / Garmin | Bluetooth via app compagnon, pas Internet |
| Viralité | Partage de séance et d'« interval score » (carte image + lien universel + page web) | Levier d'acquisition organique |
| | Classements / communauté | Backend + signalement/blocage (contenu utilisateur) |
| Infra | Crash reporting (Sentry) + analytics UE (PostHog / TelemetryDeck) | À déclarer dans le manifeste |
| | Mises à jour OTA (EAS Update) | Corriger sans repasser en review |
| | Notifications push (rappels, streak) | Permission demandée en contexte |
| | Remote config / feature flags | Couper une feature IA coûteuse |
| | Privacy manifest, labels, CGU, page support | Rejet à l'upload sinon |
| | HTTPS/ATS, jetons en Keychain | Base sécurité |

## 3. Architecture de base

| Couche | Choix recommandé | Pourquoi |
|---|---|---|
| Backend | Supabase, région UE (Francfort) | Postgres, auth, stockage, fonctions serveur, RLS ; RGPD ; utilisable depuis RN, Swift et Garmin |
| Auth | Sign in with Apple + email (magic link) + session anonyme convertible | Zéro friction, quotas IA dès le départ |
| Sync | Local-first : cache local (SQLite recommandé), file d'envoi (outbox), UUID client, `updated_at` + suppression logique | Marche en salle, conflits simples (dernier écrit gagne) |
| IA | Edge Function `import-workout` : vérifie utilisateur, quota, consentement ; appelle Claude Vision ; renvoie un JSON validé | La clé Anthropic reste côté serveur (remplace l'appel direct de `activities/new.tsx`) |
| Abonnement | RevenueCat + StoreKit 2, webhook → table `entitlements` | Le serveur sait qui est premium |
| Intégrations | Apple Health (dev build), Strava OAuth via Edge Function, export FIT | Secrets OAuth jamais dans l'app |
| Observabilité | Sentry, PostHog UE, logs des Edge Functions | Déclarés dans le privacy manifest |
| Livraison | EAS Update / Codemagic ; environnements `dev` / `staging` / `prod` (3 projets Supabase) | Ne pas casser la prod avec un test |
| Légal | Privacy manifest, politique de confidentialité, CGU, suppression de compte, export | Obligatoire avant soumission |

### Modèle de données minimal
`profiles`, `workouts` (modèles), `sessions` (exécutions), `blocks_results` (splits par bloc), `personal_records`, `entitlements`, `ai_imports` (quota, statut, coût), `consents` (version, date, type), `integrations` (jetons chiffrés).

## 4. Ordre de construction (un critère de fin vérifiable chacun)

1. **Environnements + schéma + RLS** — un utilisateur ne voit que ses lignes (test par requête croisée).
2. **Auth** — session anonyme au lancement, conversion Apple sans perte de données.
3. **Sync** — créer une séance hors-ligne, la retrouver après réinstallation.
4. **Proxy IA + consentement + quota** — une photo donne un JSON ; le 4ᵉ appel gratuit est refusé côté serveur (couvre T-002).
5. **RevenueCat + entitlements** — achat sandbox débloque l'import ; la restauration fonctionne.
6. **Suppression de compte + export RGPD** — tout disparaît côté base et côté RevenueCat.
7. **Sentry / PostHog + privacy manifest** — build TestFlight sans rejet automatique.

## 5. Points à trancher

- **Supabase ou autre** (recommandation : Supabase, indépendant d'Apple, utilisable par l'app native, Garmin et le web).
- **Cache local** : SQLite dès maintenant (migrer plus tard coûte cher) ou AsyncStorage/Zustand persist actuel.
- **Premium** : le gating serveur impose de figer la définition du premium (voir `docs/product.md`).

## 6. Prérequis techniques

- Sign in with Apple, HealthKit, RevenueCat et App Attest **ne tournent pas dans Expo Go** : Development Build obligatoire (Codemagic, bloqué jusqu'ici par l'activation du compte Apple Developer).
- Le proxy IA (étape 4) est requis avant toute distribution externe, TestFlight compris (T-002).
