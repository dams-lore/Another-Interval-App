# AnotherInterval.App — app iPhone (repo `intrvl`, dossier `interval-app-v2`)

Timer et suivi d'entraînement structuré pour athlètes CrossFit / HYROX / fractionné.
Produit, design, roadmap, intégrations : voir `docs/` (index en bas de ce fichier).

Racine du projet : `C:\Users\DamienCOQUET\interval-app\interval-app-v2` (contient package.json et .git).
Toutes les commandes npm / npx / expo / git se lancent depuis ce dossier, jamais depuis le dossier parent.

## Stack (état réel du code)
- Expo SDK 57, React Native 0.86, React 19, TypeScript, expo-router (routes dans `app/`).
- État : Zustand + `persist` AsyncStorage (`store/workoutStore`, `sessionStore`, `recordsStore`, `heartRateStore`).
- Styles : `StyleSheet` inline. **Pas de NativeWind** (absent du code, ne pas le réintroduire).
- Polices : Manrope (titres/UI) + Inter (chiffres) + Bebas Neue — voir `docs/design-system.md`.
- Audio : `expo-audio` (`assets/sounds/beep.mp3`, `beep-final.wav`). Haptics : `expo-haptics`.
- Depuis le SDK 56 : aucun import `@react-navigation/*` dans le code de l'app → utiliser `expo-router/react-navigation`, `expo-router/js-tabs`, etc.
- Import de workout par photo : `app/(tabs)/activities/new.tsx`, appel direct à l'API Anthropic (Messages API).
  - Modèle : `claude-sonnet-5-5` (les modèles Claude 4 sont retirés de l'API).
  - Clé : `EXPO_PUBLIC_ANTHROPIC_KEY` dans `.env` (jamais en dur, jamais affichée dans le terminal, ne jamais lire `.env`).
  - ⚠️ Une variable `EXPO_PUBLIC_*` est embarquée dans le binaire : acceptable en dev uniquement. Voir ticket T-002.
- Builds natifs : `eas.json` + `codemagic.yaml` (Development Build iOS, déclenché à chaque push sur `master`).

## Lancer l'app
- `npx expo start --tunnel --clear --port 8082` (tunnel obligatoire : le réseau local ne passe pas ; 8081 est en conflit).
- Après toute modif de `.env` : relancer avec `--clear`.
- Expo Go ne charge pas les modules natifs (Garmin, BLE, HealthKit) → Development Build via Codemagic.

## Façon de travailler
- Dams est product owner, pas développeur : fais les modifications toi-même, ne lui demande jamais de copier-coller du code.
- Réponds en français, court, direct. Challenge ses idées quand c'est justifié.
- **Une tâche = un ticket** (`docs/tickets/`), avec un critère de fin vérifiable sur l'iPhone. Utilise `/ticket`.
- Travaille sur une branche `claude/<ticket>-<slug>`, jamais directement sur `master`.
- **Tout ajout passe par une Pull Request** vers `master` : jamais de commit ni de push direct sur `master`. La PR référence le ticket et n'est mergée qu'avec la CI au vert.
- **Tout code nouveau ou modifié a des tests unitaires** (Jest, preset `jest-expo`) : fichiers `__tests__/<nom>.test.ts(x)` à côté du code testé. Logique métier (stores, utils, calculs de timer/score) testée en priorité ; un bug corrigé = un test qui le reproduit.
- Après chaque modif : `npm test`, `npx tsc --noEmit`, relis `git diff`, puis commit avec un message clair (`feat:`, `fix:`, `docs:`, `chore:`, `test:`).
- **CI** (`.github/workflows/ci.yml`, GitHub Actions) : tourne à chaque commit poussé sur une PR → `jest --ci` (bloquant) + `tsc --noEmit` (non bloquant jusqu'à T-008). **CD** : Codemagic construit le Development Build iOS au merge sur `master`.
- Ne pousse pas sans qu'on te le demande. Dams pousse et merge via **GitHub Desktop** (l'auth git en terminal se bloque).
- Termine toujours par : ce qui a changé (1-3 lignes) + la commande exacte pour tester + ce qu'il faut vérifier sur l'iPhone.
- Tu ne peux pas valider sur l'iPhone toi-même : ne déclare jamais un ticket « terminé » avant le retour de Dams.
- En fin de session, `/handoff` met à jour `docs/` (roadmap, learnings, tickets).

## Règles critiques (détail et historique dans `docs/learnings.md`)
1. Après une sauvegarde de séance : `router.replace`, jamais `router.back()`.
2. Cercle SVG : condition sur le **format** de la séance + `initialBlockDuration !== null` (exclut reps/distance).
3. Timer compact : même `fontSize` minutes/secondes, seule la graisse change (alignement des `TSpan`).
4. Cache corrompu : supprimer `node_modules` et `.expo`, `npm install`, relancer avec `--clear`.
5. Titres d'onglets du type `workout/[id]` ou `(tabs)` = overlay de dev Expo, pas un bug.
6. Si une correction échoue deux fois : on change d'approche, on ne répète pas.
7. Shell de Dams = PowerShell : dans les commandes que tu lui donnes, pas de `&&` ni `rd /s /q` ; utiliser `;`, `Set-Location`, `Remove-Item -Recurse -Force`.

## Outils connectés (`.mcp.json`)
- **Figma** : fichier `akSiGekTw8lwC4Hr0UQJBp` (« Another Intrval App »). Travail design → agent `design-figma`.
- **Notion** : **lecture seule** (hub projet, cahier des charges, data model). Ne jamais écrire dans Notion. IDs dans `docs/integrations.md`.
- **Context7** : doc à jour d'Expo / React Native / Zustand avant toute réponse sur une API de librairie.

## Index docs/
- `docs/product.md` — vision, cible, freemium, différenciateurs, interval score
- `docs/design-system.md` — tokens Liquid Glass, polices, mode gym, règles Figma
- `docs/architecture.md` — spec technique de l'app native (Swift + Supabase), à valider
- `docs/roadmap.md` — phases, état réel, critères de fin
- `docs/learnings.md` — toutes les règles apprises (« ne pas re-débattre »)
- `docs/garmin.md` — app Connect IQ (Vivoactive 5), protocole iPhone ↔ montre
- `docs/integrations.md` — Anthropic API, Codemagic/EAS, Figma, Notion, Webflow
- `docs/besoins-internet.md` — besoins Internet (comptes, sync, IA, abonnement), contraintes Apple, architecture backend
- `docs/tickets/` — backlog, un fichier par ticket
