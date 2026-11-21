# T-014 — Import de séance par photo (killer feature)

- **Statut** : à faire (cadrage)
- **Priorité** : P0
- **Type** : feat
- **Dépend de** : T-011 ; clé IA côté serveur (spec § 7, `import-workout`)

## Pourquoi
Différenciateur n°1 du produit : photographier le tableau / la feuille du coach et obtenir une séance prête à lancer.

## Points à trancher avant de coder
- Où tourne l'appel à l'IA : **proxy serveur** (spec : Edge Function Supabase) plutôt que la clé dans l'app (T-002). Pour une première version de test : appel direct avec clé de dev (jamais commitée).
- Format de sortie : JSON validé → `Workout` (blocs, rounds, cap, format).
- Consentement IA, quota gratuit (3 imports), photo non conservée.

## Critère de fin
- [ ] Photo d'une séance → `Workout` valide → lancée dans l'écran de séance.
