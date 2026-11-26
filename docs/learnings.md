# Règles apprises — ne pas re-débattre

> Chaque règle a coûté au moins une session. `/handoff` ajoute les nouvelles ici.

## Navigation / logique
- Après une sauvegarde de séance : `router.replace`, pas `router.back()` (avec `back`, la sauvegarde n'était pas prise en compte).
- Cercle SVG : la condition d'affichage dépend du **format de séance**, pas du type d'étape, et exige `initialBlockDuration !== null` pour exclure les étapes reps/distance.
- SDK 56+ : aucun import `@react-navigation/*` dans le code de l'app → `expo-router/react-navigation`, `expo-router/js-tabs`.

## Expo / Metro
- Lancement : `npx expo start --tunnel --clear --port 8082`. Le port 8081 est en conflit ; le réseau local ne passe pas, d'où le tunnel.
- Cache corrompu : supprimer `node_modules` et `.expo`, `npm install`, relancer avec `--clear`.
- Titres d'onglets type `workout/[id]` ou `(tabs)` : overlay de dev Expo Go, disparaît en build de production.
- Expo Go ne suit que les SDK récents : si l'app ne se lance plus sur l'iPhone, monter de SDK avant toute autre chose.
- Expo Go ne charge aucun module natif → Garmin, BLE, HealthKit nécessitent un Development Build (Codemagic).
- NativeWind : abandonné après des erreurs Babel insolubles (v4 puis v2). Ne pas réintroduire.

## Windows / outillage
- Pas de Mac : tout build natif iOS passe par Codemagic (`mac_mini_m2`).
- Shell PowerShell : pas de `&&` ni `rd /s /q` → `;`, `Set-Location`, `Remove-Item -Recurse -Force`.
- Git : push uniquement via GitHub Desktop (l'auth en terminal se bloque).
- Ancien piège Claude Code CLI : il écrivait dans un worktree interne, pas à la racine du projet. Avec le desktop et les branches `claude/*`, on travaille dans le repo → vérifier en début de session que `git rev-parse --show-toplevel` pointe bien sur `interval-app-v2`.

## Méthode
- Une étape = un critère de fin vérifiable sur l'iPhone.
- Quand on tourne en rond (arrivé sur l'audio, les haptics, le cercle) : changer d'approche au lieu de répéter la même correction.

## Figma MCP
- Couleurs liées à une variable : `figma.variables.setBoundVariableForPaint()`.
- Rayons d'angle : `setBoundVariable()` quatre fois (un par coin), pas de raccourci.
- `layoutSizingHorizontal = 'FILL'` à définir explicitement **après** l'ajout dans un parent auto-layout.
- `itemSpacing` mixte : utiliser des frames vides comme espaceurs.
- Plan Starter : quota fini, et ce qui est créé avant la coupure reste.

## Connect IQ (Garmin)
- Retirer du manifest les attributs non supportés (`launchType`, `iq:language` avec `id`).
- Constructeurs Monkey C : annoter correctement le type de retour.
- Utiliser `WatchUi.InputDelegate` (`WatchUi.TouchScreen` n'existe pas).
- Gérer explicitement la nullabilité.

## Permissions Claude Code
- 21/11/2026 : la règle `"Bash(git push:*)"` de `permissions.deny` (`.claude/settings.json`) a été **retirée temporairement** à la demande de Dams, pour que Claude pousse sa branche `claude/*` pendant le dev natif. **À remettre plus tard au besoin** (`git push --force` et `git reset --hard` restent interdits). Toujours jamais de push direct sur `master` : tout passe par PR.

## App native (Tuist / Xcode)
- Erreurs Xcode « Couldn't load <Package> because it is already opened from another project or workspace » : quitter Xcode (`Cmd+Q`), `tuist generate --no-open`, ouvrir **uniquement** `apple/AnotherInterval.xcworkspace`. Jamais le `.xcodeproj` ni un dossier de package en parallèle.
- `mise` s'installe avec `curl https://mise.run | sh` (pas besoin de Homebrew) puis `mise activate zsh` dans `~/.zshrc`.
- Installer l'app native sur l'iPhone **sans compte payant** : Apple ID gratuit (« Personal Team »), iPhone branché en câble, Mode développeur activé, `DEVELOPMENT_TEAM` dans `Secrets.xcconfig` (le réglage fait dans l'interface Xcode est effacé à chaque `tuist generate`). Limites : app valable 7 jours, 3 apps max, pas de TestFlight (compte payant Apple Developer requis).
- Premier lancement sur l'iPhone : message « Développeur non approuvé » → Réglages > Général > VPN et gestion de l'appareil > App de développeur > Faire confiance (iPhone connecté à Internet).
- Windows → Mac : tout passe par **GitHub** (commit + push d'une branche depuis Windows, pull sur le Mac). Les secrets (`.env`, clé développeur Garmin `*.der` / `*.pem`) ne passent **jamais** par git : copie manuelle (clé USB ou stockage privé), seulement si nécessaire.
