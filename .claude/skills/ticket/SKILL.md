---
name: ticket
description: Prend un ticket du backlog docs/tickets/ (le prochain « à faire » par priorité, ou celui passé en argument, ex. /ticket T-003), le réalise sur une branche claude/, et rend un rapport de test iPhone. À utiliser pour tout travail de dev ou de design sur l'app.
---

# /ticket — réaliser un ticket

## 1. Choisir le ticket
- Argument fourni (`T-003`) → ce ticket.
- Sinon → lis `docs/tickets/README.md`, prends le premier ticket `à faire` de plus haute priorité dont les dépendances sont `fait`.
- Si le ticket n'a pas de critère de fin vérifiable sur l'iPhone, **arrête-toi** et propose-en un à Dams avant de coder.

## 2. Préparer
- `git status` doit être propre. Sinon, arrête-toi et dis-le.
- Vérifie que `git rev-parse --show-toplevel` est bien le dossier `interval-app-v2`.
- Crée la branche : `git switch -c claude/<id-en-minuscules>-<slug>` (ex. `claude/t-003-design-tokens`).
- Passe le ticket à `en cours` dans le fichier du ticket et dans `docs/tickets/README.md`.
- Lis uniquement les fichiers listés dans le ticket, plus ceux qu'ils importent directement.
- Pour toute API de librairie (Expo, expo-audio, expo-router, Zustand, Reanimated) : vérifie avec Context7, pas de mémoire.

## 3. Réaliser
- Changement minimal qui satisfait le critère de fin. Pas de refacto opportuniste hors périmètre : note-la comme nouveau ticket à la place.
- Respecte les règles critiques de `CLAUDE.md` et `docs/learnings.md`.
- Écris les tests unitaires en même temps que le code (`__tests__/<nom>.test.ts(x)`). Un fix = un test qui reproduit le bug avant correction.
- Travail Figma → délègue à l'agent `design-figma`.

## 4. Vérifier
- `npm test` doit passer (tous les tests, y compris les nouveaux).
- `npx tsc --noEmit` doit passer (aucune nouvelle erreur).
- Relis `git diff` en entier.
- Délègue une relecture à l'agent `reviewer` avec : l'ID du ticket et la sortie de `git diff master...HEAD`. Corrige ce qu'il remonte de bloquant.

## 5. Committer (sans pousser)
- `git add` des seuls fichiers concernés, puis commit : `<type>(<id>): <résumé>` (ex. `feat(T-003): tokens de design centralisés`).
- Ajoute dans le fichier du ticket une section `## Rapport` (date, fichiers modifiés, ce qui reste à tester). Statut → `à tester`.

## 6. Rapport à Dams (format fixe, en français)
```
✅ T-xxx — <titre>   (branche claude/…)
Changé : <1 à 3 lignes>
À faire de ton côté :
  1. GitHub Desktop → Current branch : claude/… → Push origin
  2. Set-Location C:\Users\DamienCOQUET\interval-app\interval-app-v2 ; npx expo start --tunnel --clear --port 8082
  3. Sur l'iPhone, vérifie : <critère de fin, en étapes concrètes>
Si OK : GitHub Desktop → Create Pull Request, attends la CI au vert sur GitHub, puis Merge et dis-moi « T-xxx ok ».
Jamais de push direct sur master.
```
Ne déclare jamais le ticket `fait` toi-même : seulement quand Dams confirme le test iPhone.
