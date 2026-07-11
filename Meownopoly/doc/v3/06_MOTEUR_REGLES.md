# 06 — Règles de partie (gérées par l'arbitre)

> **Statut : partiellement tranché.** **D8 décide l'ownership** : les règles sont
> **gérées par l'IA arbitre** (pas de moteur déterministe séparé) ; il n'y a pas de
> tour imposé, il s'introduit par prompt ou proposition acceptée. Les **détails**
> (format d'une règle, mémorisation, réplication) restent différés — à reprendre
> après stabilisation des docs 02/04/05.

## 1. Intention & décision cadre (D8)

Chaque joueur, via son IA, doit pouvoir **construire une partie selon ses propres
règles**. **Décision (D8) : les règles sont gérées par l'IA arbitre** (doc 00 §4,
D6) — c'est l'arbitre qui **valide ou non les actions des IA clientes**. Il n'y a
donc **pas** de moteur de règles déterministe séparé comme pièce première : les
règles **vivent dans le mandat de l'arbitre**.

Conséquences directes :

- **Pas de notion de tour imposée.** Aucune règle de tour n'est câblée par défaut
  (V2 n'en a **pas** — cf. §3).
- **Les règles (dont le tour) sont introduites de deux façons :**
  1. par le **prompt donné à l'arbitre** (le joueur hôte configure son MJ : « joue
     au tour par tour », « loyer doublé au bord de l'eau »…) ;
  2. par une **modification proposée par une IA cliente**, **si l'arbitre
     l'accepte** — le règlement est donc **négociable et évolutif en cours de
     partie**, sous l'autorité de l'arbitre.
- **Les invariants durs restent hors de l'arbitre** : intégrité/sécurité sont
  tenues par le **sandbox** (doc 04), pas par le jugement souple du MJ (doc 00 §8).

## 2. Périmètre (recadré par D8)

- **Règlement souple = politique de l'arbitre.** L'ensemble des règles de partie
  (déclencheurs → effets, phases/tour éventuels, conditions de victoire,
  économie/loyers) n'est **pas** un DSL figé côté cœur : c'est ce que l'arbitre
  **connaît** (par son prompt) et **fait respecter** en validant les actions ; il
  peut **évoluer en cours de partie** via des propositions acceptées.
- **Invariants durs = sandbox + garde-fous** (doc 04) : intégrité de partie,
  anti-triche, limites de ressources, sécurité — **non-négociables**, hors du
  jugement de l'arbitre. L'arbitre affine ; il ne peut jamais lever ces invariants.

> **Question tranchée (D8).** « L'arbitre est-il le moteur de règles, un
> consommateur, ou une couche distincte ? » → **l'arbitre gère les règles** : il en
> est l'autorité. Ce qui reste à instruire, ce sont les **détails** (format d'une
> règle proposée, mémorisation du règlement en cours, réplication) — voir §4.

## 3. Ancrages avec le reste du cadrage

- **Consomme l'espace mémoire** (doc 05) : les règles lisent **et écrivent** les
  variables typées des tuiles (`data`, `tags`) pour décider des effets (« si `tags`
  contient `water-adjacent`, loyer ×`data.rentMultiplier` »). Surtout, elles
  **réagissent** aux changements via le signal `userMemoryChanged` (doc 05 §1
  usage 3) — un changement de variable, local ou reçu par broadcast, réveille la
  règle. L'espace mémoire est donc le **bus de variables** du moteur de règles, pas
  un simple stockage passif.
- **Peut déléguer au QML génératif** (doc 04) pour les effets non exprimables en
  données.
- **Doit rester compatible host-authoritative** : les règles s'appliquent-elles
  chez le host, chez chaque pair, avec quelle autorité ? (lien avec le
  déterminisme réseau host-authoritative existant : `EditorSession` /
  `PhysicsSession`).
- Existant V2 à cartographier avant de concevoir : `GameplayModuleManager`
  (modules activables : vie, inventaire, monnaie, stats/XP) et les mécaniques de
  plateau présentes. **⚠️ Il n'existe pas de système de tour en V2** : le socle de
  règles devra donc l'**introduire** (déclencheurs, phases, conditions de
  victoire), pas seulement surcharger un existant.

## 4. Questions à instruire (avant de sortir du stub)

- **Mémorisation du règlement en cours** : où vit l'état des règles que l'arbitre
  fait respecter — dans son seul contexte (prompt + historique), ou aussi
  matérialisé (espace mémoire d'une entité « partie », doc 05) pour survivre à un
  redémarrage / une migration d'hôte ?
- **Format d'une règle proposée** par une IA cliente : texte libre pour l'arbitre,
  données structurées, ou artefact QML/JS (doc 04) ? Comment l'arbitre l'« accepte »
  concrètement (verdict D6) et la rend effective.
- **Réplication** : après acceptation, comment le nouveau règlement se propage aux
  autres joueurs (host-authoritative) et à leurs IA clientes ?
- **Rapport avec `GameplayModuleManager` existant** : les règles s'appuient-elles
  sur les modules activables (vie, inventaire, monnaie, stats/XP), ou sont-elles une
  couche au-dessus ?
- **Bootstrap du tour** : si le hôte veut un tour par tour, l'arbitre l'orchestre
  seul (séquençage des IA clientes) ou s'appuie-t-il sur une primitive côté jeu ?

## 5. Prochaine action

Rouvrir ce document une fois les docs 04 (sandbox) et 05 (espace mémoire) stables,
et après une cartographie dédiée du gameplay V2 existant. Poser à ce moment une
décision **D-règles** dans le doc 08.
