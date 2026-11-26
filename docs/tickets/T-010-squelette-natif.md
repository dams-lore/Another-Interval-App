# T-010 — Squelette de l'app native (étape 1 de `docs/architecture.md` § 15)

- **Statut** : à tester (app installée sur l'iPhone par câble le 26/11/2026 ; restent la CI sur la PR et TestFlight)
- **Priorité** : P0
- **Type** : chore
- **Dépend de** : T-009 (spec, PR #4)

## Pourquoi
Démarrer l'app iOS native (Swift 6, SwiftUI, iOS 18) : monorepo SPM + projet Xcode généré par Tuist + CI.

## Fichiers concernés
- `apple/` (Tuist, `Apps/iOSApp`, `Packages/*`)
- `.github/workflows/ios.yml`, `.gitignore`, `CLAUDE.md`

## À faire
- Manifestes Tuist (version figée dans `apple/.mise.toml`), helpers Swift 6 strict, iOS 18.
- Packages : Domain, TimerEngine, TestSupport, DesignSystem, Platform, Backend, DataLayer (chacun testé).
- App iOS minimale qui démarre. Workflow GitHub Actions (runner macOS).

## Écarts assumés avec la spec
- `Clock` → `AppClock` (évite le conflit avec `Swift.Clock`).
- `Data` → `DataLayer` (évite le conflit avec `Foundation.Data`).
- Features, Widgets, WatchApp, WearableKit : tickets suivants.

## Critère de fin (vérifiable sur le Mac)
- [x] `tuist install` puis `tuist generate` sans erreur (Tuist 4.31.0). Erreurs « already opened from another project » levées en rouvrant uniquement le `.xcworkspace`.
- [x] `Cmd+B` compile, `Cmd+U` : tous les tests verts.
- [x] L'app affiche « Another Interval » dans le simulateur iPhone.
- [ ] CI GitHub verte sur la PR.
- [ ] (Plus tard, avec compte Apple) l'app vide s'installe sur l'iPhone via TestFlight.

## Hors périmètre
- Signature, TestFlight, Codemagic (déclenchement sur tag), Supabase.
