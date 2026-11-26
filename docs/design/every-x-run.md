# Séance « Every X × N » (EMOM long) — parcours cible

> Source : simulation HTML faite avec Claude par Dams (maquettes dans `docs/design/reference/every-x/`).
> **Cette page est la référence unique** pour ce parcours : app native, Figma, montre Garmin et docs doivent y revenir.
> Séance d'exemple : « EMF RX – DARK ZONE – Burpees and Row » (`00-photo-seance-source.jpg`) : Every 5:00 × 6 sets : 20/16 cal row, 15 burpees over row, 20/16 cal row, 15 burpees over row.

## Vocabulaire
- **Set** = un intervalle (ici 5:00). Un set part toutes les 5:00, quel que soit l'état du précédent.
- **Étape** = une tâche du set (row, burpees…). **Split** = temps passé sur une étape.
- **Repos** = temps gagné : 5:00 − temps du set. Si le set n'est pas fini à 5:00, le suivant part quand même et le set est noté « non fini ».

## Écran 1 — Récap avant validation (`01-recap-avant-depart.jpg`)
- En-tête : « EMF RX · DARK ZONE · MARDI 10 », titre de la séance.
- Carte « EVERY 5:00 × 6 SETS » : liste numérotée des étapes par type et répétitions, phrase d'explication (durée totale 30:00, repos = temps gagné, set non fini).
- Réglages (décision de Dams, 21/11/2026, après test) : **Départ dans** 5 s ou 10 s ; **intervalle, nombre de sets et valeurs de chaque étape modifiables** (+ / −) avant le départ ; **un seul mode de validation** : un tap par étape, la dernière étape affiche « Fin du set » et mène au repos. Le sélecteur « Calories 15 / 20 » et le choix « 4 taps / 1 tap » de la simulation sont remplacés par ces réglages.

## Écran 2 — Pendant le set (`02-run-set-en-cours.webp`)
- Fond vert (mode gym). En haut : Stop · mode (Gym) · temps total.
- « SET 1 / 6 · ÉTAPE 1 / 4 », nom de l'étape en cours, **gros chrono = temps restant avant le prochain set** (4:13), « Set en cours 0:47 », **4 segments d'avancement des étapes**.
- Bas : pastilles des 6 sets (courant en noir), gros bouton « Row fini » (nom de l'étape + « fini »), Pause.
- **Taper n'importe où sur l'écran valide l'étape** (ou le set en mode « 1 tap »).

## Écran 3 — Repos (`03-run-repos.webp`)
- Fond sombre, texte vert. « SET 1 / 6 TENU », « Repos », gros chrono = temps avant le prochain set (1:36), « Set en 3:15 · prochain : 15 cal row », 4 segments pleins.
- Bouton « Annuler, set pas fini » (corrige un tap fait trop tôt).

## Écran 4 — Récap de fin (`04-recap-fin-de-seance.jpg`)
- « DARK ZONE TERMINÉE », « 6/6 sets finis, moyenne 3:27 », trois cartes : meilleur set, pire set, écart.
- « SET PAR SET » : légende Row / Burpees / Repos, une barre par set (largeur = durée sur l'intervalle) avec temps du set, repos, et temps de chaque étape (« row 0:53 · burpees 0:40 · … »).
- Boutons « Copier le résultat » et « Nouvelle séance ».

## Écran 5 — Variante « Failure » + fréquence cardiaque (`05-recap-failure-et-frequence-cardiaque.jpg`)
- « FAILURE ATTEINTE — 5 sets tenus, dernier à 2:20 » : variante où le temps alloué diminue à chaque set (3:00, 2:50, 2:40…) jusqu'à l'échec. Totaux (temps, calories, burpees), courbe de FC, zones 1 à 5, partage.
- **Hors périmètre du ticket T-016** : à cadrer séparément (format « Failure » + FC via montre).

## Où ce parcours doit exister (checklist de cohérence)
| Endroit | État |
|---|---|
| App native (`FeatureWorkoutRun`) | écrans 1 à 4 : T-016 |
| Figma « Another Intrval App » | à reproduire depuis ces maquettes (page « App Screens ») — quota Figma Starter à surveiller |
| `docs/design-system.md` | pointeur vers cette page (fait) |
| Import photo (prompt IA) | « Every X × N » reconnu (T-014, fait) |
| Montre Garmin (T-015) | afficher set / étape / repos et recevoir le tap « étape finie » |
| Écran 5 (failure, FC) | à cadrer |
