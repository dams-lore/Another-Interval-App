# Design system — Liquid Glass

> ⚠️ Il n'existe **pas encore de fichier de tokens** : les couleurs sont redéfinies dans chaque écran (`GRAD`, `DARK`, `FORMAT_COLOR`…) et `constants/Colors.ts` est encore celui du template Expo. Voir ticket T-003.
> Ce document décrit l'état **réel du code** au 28/10/2026. L'ancien design (fond beige `#F0EFEB`, accent `#A793AC`) est abandonné ; il ne subsiste que dans `app.json` (splash, icône Android).

## Couleurs (relevées dans le code)
| Token proposé | Valeur | Usage |
|---|---|---|
| `gradient` | `#f0c4a0` → `#e8b8c8` → `#d4b8e0` → `#c8c0e8`, locations `[0, 0.33, 0.66, 1]` | Fond des écrans (`expo-linear-gradient`) |
| `textDark` | `#2a1a24` | Texte principal |
| `accent` | `#7050a0` | Liens, « voir tout », For Time |
| `format.for_time` | `#7050a0` | Badges format |
| `format.amrap` | `#5a9e57` | Badges format |
| `format.intervals` | `#3a6a94` | Badges format |

Badges : couleur du format + alpha `30` en fond, `50` en bordure.
Cartes : effet verre (fond blanc semi-transparent + bordure claire).

## Typographie
- **Manrope** (400, 500, 600, 700, 800) : UI, titres, libellés.
- **Inter** (300, 400, 700) : chiffres et timers — encore très utilisé (`Inter_700Bold` ≈ 60 occurrences).
- **Bebas Neue** : gros chiffres d'affichage.
- ⚠️ Trois familles, c'est une de trop. Décision à prendre (ticket T-003).

## Écran de séance (`app/workout/[id]/run.tsx`)
- Deux modes : **compact** et **gym**. Clé AsyncStorage : `intrvl-display-mode`.
- Mode gym : timer géant (fontSize 120, weight 900), boutons inversés, bascule via un composant « pill ».
- Timer central = temps du **bloc en cours** ; timer du haut = temps total.
- Timer SVG compact : même `fontSize` minutes/secondes, minutes en 700, secondes en 300 (alignement des `TSpan`).

## Parcours « Every X × N »
- Référence unique : `docs/design/every-x-run.md` (maquettes dans `docs/design/reference/every-x/`) : récap avant départ, set en cours, repos, récap de fin.

## Figma
- Fichier : `akSiGekTw8lwC4Hr0UQJBp` — « Another Intrval App ».
- Le code est la source de vérité : Figma reproduit l'app, pas l'inverse (sauf écran nouveau conçu d'abord dans Figma).
- Avancement : Home et Activities complets ; Profile partiel (titre, carte avatar, deux cartes stats — manquent menus et tab bar). Suite prévue : Profile → Workout Detail → New Workout, puis passe d'amélioration design.
- Règles techniques Figma MCP : voir `docs/learnings.md` § Figma.
- Plan Figma Starter : quota limité. Les nœuds créés persistent si le quota coupe en cours de route → reprendre là où ça s'est arrêté, ne pas tout refaire.
