# 06 — Règles de partie (gouvernées par l'arbitre)

> **Statut : partiellement tranché.** **D8 décide l'autorité de politique** : les
> règles sont **gouvernées par l'IA arbitre** (pas de moteur générique séparé
> décidé à ce stade) ; il n'y a pas de
> tour imposé, il s'introduit par prompt ou proposition acceptée. Les **détails**
> (format d'une règle, mémorisation, réplication) restent différés — à reprendre
> après stabilisation des docs 02/04/05.

## 1. Intention & décision cadre (D8)

Chaque joueur, via son IA, doit pouvoir **construire une partie selon ses propres
règles**. **Décision (D8) : les règles sont gouvernées par l'IA arbitre**
(doc 00 §4, D6) — c'est l'arbitre qui accepte ou refuse les propositions et
maintient la politique courante. Cela ne signifie pas que le LLM exécute chaque
événement du runtime : une règle acceptée doit être **matérialisée** sous une forme
exécutable par le jeu (configuration, module, primitive ou artefact QML/JS validé).
Aucun moteur de règles générique séparé n'est décidé à ce stade.

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
  tenues par le **sandbox** (doc 04), pas par le jugement souple du MJ (doc 00 §9).

## 2. Périmètre (recadré par D8)

- **Règlement souple = politique de l'arbitre.** L'ensemble des règles de partie
  (déclencheurs → effets, phases/tour éventuels, conditions de victoire,
  économie/loyers) n'est **pas** un DSL figé côté cœur : c'est ce que l'arbitre
  **connaît** et fait évoluer via des propositions acceptées. Le prompt seul ne
  suffit toutefois ni à la reprise, ni à la migration d'hôte, ni à l'exécution
  déterministe : le règlement accepté doit avoir un état matérialisé à définir.
  L'arbitre choisit la vue du règlement exposée aux joueurs et peut la modifier
  en cours de partie ; l'état autoritatif complet reste néanmoins versionné pour
  migration et audit.
- **Exécution = capacités du jeu.** Les effets runtime sont appliqués par des
  primitives/modules existants ou par du QML/JS validé. L'arbitre juge et produit
  un plan/verdict ; il ne devient pas implicitement une boucle temps réel.
- **Représentation hiérarchique (D12).** Le jeu choisit la forme la moins libre
  suffisante : plan de capacités, configuration de module, DSL/machine à états,
  puis QML/JS sandboxé. Le règlement autoritatif est un document structuré
  versionné ; le prompt n'en est qu'une vue/configuration.
- **Invariants durs = sandbox + garde-fous** (doc 04) : intégrité de partie,
  anti-triche, limites de ressources, sécurité — **non-négociables**, hors du
  jugement de l'arbitre. L'arbitre affine ; il ne peut jamais lever ces invariants.

> **Question partiellement tranchée (D8).** L'arbitre est l'**autorité de
> politique**, pas nécessairement le moteur d'exécution. Restent à instruire le
> format d'une règle proposée et acceptée, sa matérialisation exécutable, sa
> mémorisation et sa réplication — voir §4.

## 3. Ancrages avec le reste du cadrage

- **Consomme l'espace mémoire** (doc 05) : les règles lisent **et écrivent** la
  configuration et l'état des tuiles (`config`, `state`, `tags`) pour décider des
  effets (« si `tags` contient `water-adjacent`, loyer
  ×`config.rentMultiplier` »). Surtout, elles
  **réagissent** aux changements via le signal `userMemoryChanged` (doc 05 §1
  usage 3) — un changement de variable, local ou reçu par broadcast, réveille la
  règle. L'espace mémoire est donc le **bus de variables** des comportements, pas
  un simple stockage passif.
- **Peut déléguer au QML génératif** (doc 04) pour les effets non exprimables en
  données.
- **Doit rester compatible host-authoritative** : les effets s'appliquent-ils
  chez l'hôte uniquement puis se répliquent, ou chez chaque pair à partir d'un
  artefact déterministe, avec quelle autorité ? (lien avec le
  déterminisme réseau host-authoritative existant : `EditorSession` /
  `PhysicsSession`).
- Existant V2 à cartographier avant de concevoir : `GameplayModuleManager`
  (modules activables : vie, inventaire, monnaie, stats/XP) et les mécaniques de
  plateau présentes. **⚠️ Il n'existe pas de système de tour en V2** : le socle de
  règles devra donc l'**introduire** (déclencheurs, phases, conditions de
  victoire), pas seulement surcharger un existant.

## 4. Questions à instruire (questionnaire exhaustif doc 09)

- **Mémorisation du règlement en cours** : où vit l'état des règles que l'arbitre
  fait respecter — dans son seul contexte (prompt + historique), ou aussi
  matérialisé (espace mémoire d'une entité « partie », doc 05) pour survivre à un
  redémarrage / une migration d'hôte ?
- **Format d'une règle proposée** par une IA cliente : texte libre pour l'arbitre,
  données structurées, ou artefact QML/JS (doc 04) ? Comment l'arbitre l'« accepte »
  concrètement (verdict D6) et la rend effective.
- **Forme exécutable d'une règle acceptée** : plan de capacités, configuration de
  module, machine à états/DSL borné, ou QML/JS ? Qui compile/valide cette forme ?
- **Déclenchement runtime** : quels événements sont autoritatifs, comment une
  règle s'y abonne-t-elle et comment empêche-t-on boucles/réentrance ?
- **Réplication** : après acceptation, comment le nouveau règlement se propage aux
  autres joueurs (host-authoritative) et à leurs IA clientes ?
- **Rapport avec `GameplayModuleManager` existant** : les règles s'appuient-elles
  sur les modules activables ou sont-elles au-dessus ? **Tranché D12 : les deux** ;
  les modules sont des primitives sous la couche de règles.
- **Bootstrap du tour** : **tranché D12** — artefact généré et/ou orchestration
  directe de l'arbitre, sans primitive native exigée.
- **Amendement** : D11 autorise l'arbitre à modifier et appliquer immédiatement
  une proposition. La proposition originale et la forme appliquée doivent toutes
  deux être persistées.

## 5. Prochaine action

Rouvrir ce document une fois les docs 04 (sandbox) et 05 (espace mémoire) stables,
et après une cartographie dédiée du gameplay V2 existant. Poser à ce moment une
décision **D-règles** dans le doc 08.
