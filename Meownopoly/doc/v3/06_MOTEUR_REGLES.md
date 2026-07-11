# 06 — Moteur de règles de partie

> **Statut : STUB — cadrage différé (décision D3).** Ce document réserve
> l'emplacement de la brique et fixe le périmètre pressenti + les questions à
> instruire. **Il ne tranche rien.** À reprendre après stabilisation des docs
> 02/04/05.

## 1. Intention (telle qu'exprimée)

Le point de départ : *« la définition de règles de base définissant… »* (phrase
laissée volontairement incomplète dans le brief). L'ambition associée est que
chaque joueur, via son IA, puisse **construire une partie selon ses propres
règles** — donc au minimum un socle de règles par défaut que l'IA peut
**composer, étendre ou surcharger**.

## 2. Périmètre pressenti (à confirmer)

Deux facettes possibles, non exclusives :

- **Socle de règles de partie** : cadre déclaratif (déclencheurs → effets, phases
  de tour, conditions de victoire, économie/loyers) définissant ce qu'est « une
  partie » par défaut, que les IA peuvent modifier.
- **Contrat / garde-fous** : les invariants **non-négociables** que les règles
  custom ne peuvent jamais franchir (intégrité de partie, anti-triche, limites de
  ressources, sécurité). Miroir « règles » du sandbox QML (doc 04).

## 3. Ancrages avec le reste du cadrage

- **Consomme l'espace mémoire** (doc 05) : les règles lisent le blob des tuiles
  (`data`, `tags`) pour décider des effets (« si `tags` contient `water-adjacent`,
  loyer ×`data.rentMultiplier` »).
- **Peut déléguer au QML génératif** (doc 04) pour les effets non exprimables en
  données.
- **Doit rester compatible host-authoritative** : les règles s'appliquent-elles
  chez le host, chez chaque pair, avec quelle autorité ? (lien avec le
  déterminisme réseau du système de tour V2).
- Existant V2 à cartographier avant de concevoir : système de tour 4 phases,
  loyers/copropriété, enchères anonymes, `GameplayModuleManager` (modules
  activables : vie, inventaire, monnaie, stats/XP).

## 4. Questions à instruire (avant de sortir du stub)

- « Règles de base » = **moteur de règles**, **contrat de garde-fous**, ou **les
  deux** ? (question posée, réponse différée).
- Format des règles : DSL déclaratif ? données + QML génératif ? table
  d'événements ?
- Autorité et réplication des règles en multi-joueurs.
- Rapport avec `GameplayModuleManager` existant : les règles custom sont-elles des
  modules, ou une couche au-dessus ?
- Comment l'IA **négocie** un changement de règles accepté par les autres joueurs ?

## 5. Prochaine action

Rouvrir ce document une fois les docs 04 (sandbox) et 05 (espace mémoire) stables,
et après une cartographie dédiée du gameplay/tour V2. Poser à ce moment une
décision **D-règles** dans le doc 08.
