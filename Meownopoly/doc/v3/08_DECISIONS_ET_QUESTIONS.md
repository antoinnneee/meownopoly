# 08 — Registre des décisions & questions ouvertes

> **Statut : document vivant.** Journal des décisions d'architecture (ADR léger)
> et des questions à trancher. Mettre à jour à chaque arbitrage.

## 1. Décisions prises

### D1 — Modèle d'exécution : **QML génératif complet**
- **Décision.** L'IA du joueur produit du **vrai code QML** chargé au runtime
  (`Qt.createQmlObject` / `Loader`), pas seulement des données ou une palette de
  briques figées.
- **Pourquoi.** Liberté maximale, cohérente avec « ajouter des éléments à la
  volée » et « une partie selon ses propres règles ». Exploite le fait que le QML
  est interprété.
- **Conséquence.** Le **sandbox** (doc 04) devient la pièce d'architecture la plus
  critique ; c'est la plus grande surface de sécurité du projet. Risque technique
  n°1 : la faisabilité réelle du sandboxing QML/JS dans Qt (à prototyper tôt).
- **Alternatives écartées.** « Palette + espace mémoire » (plus sûr, moins libre) ;
  « hybride validé » (compromis). Conservées comme **repli** si le sandbox complet
  s'avère infaisable.

### D2 — Canal d'interaction : **nouveau WebSocket dédié**
- **Décision.** Créer un canal WS **local dédié** IA↔jeu, distinct de
  l'`AutomationServer` (qui reste réservé au test/debug interne).
- **Pourquoi.** Séparer les responsabilités (debug bas niveau vs capacités
  gameplay de haut niveau), pouvoir **durcir la sécurité** du canal IA
  indépendamment (allow-list vs introspection totale), évoluer sans casser le
  harnais de dev.
- **Conséquence.** Réutiliser les **fondations** de l'automation (loopback strict,
  JSON corrélé, GUI thread) mais **pas** son catalogue permissif. Doc 02.
- **Alternatives écartées.** Étendre l'`AutomationServer` (couplage debug/prod
  indésirable) ; décider plus tard (le pivot a besoin du canal tôt).

### D3 — Moteur de règles : **cadrage différé**
- **Décision.** Reporter le cadrage (doc 06 = stub). Réserver l'emplacement.
- **Pourquoi.** Le format des règles dépend des docs 04 (sandbox) et 05 (espace
  mémoire), à stabiliser d'abord.

### D4 — Bibliothèque : **cadrage différé**
- **Décision.** Reporter le cadrage (doc 07 = stub). Réserver l'emplacement.
- **Pourquoi.** Le format d'une entrée de bibliothèque dépend de la représentation
  d'un comportement/donnée (docs 04/05).

### D5 — Dossier de cadrage
- **Décision.** Regrouper le cadrage V3 dans `Meownopoly/doc/v3/`, docs numérotés,
  en français, avec bandeaux de statut. Commit/push sur la branche **V3**.

## 2. Questions ouvertes (par thème)

### Sécurité (bloquant pour D1)
- Jusqu'où peut-on **verrouiller** un `QQmlContext` et l'allow-list d'imports dans
  Qt ? (prototype requis — risque technique n°1).
- **Réplication du QML génératif** en multi-joueurs : local-only / répliqué+
  re-validé / host-validé+signé ? (doc 04 §4). Reco de départ : **local-only**.
- Authentification du canal local : simple loopback (comme l'automation) ou token
  de session ? Reco : **token**, car le canal exécute à terme du QML.

### Canal WS (doc 02)
- Un canal multiplexé vs plusieurs canaux (éditeur / runtime / règles) ?
- Sur quel bus interne brancher les **événements poussés** (signaux `Game`,
  `EditorOpBus.remoteOpReceived`, `ItemSnapableEvents`) ?
- Exposer une échappatoire `automation.raw` pour le prototypage ?

### Capacités manquantes (chantiers identifiés)
- Réconcilier **hooks ↔ tools MCP** (des hooks existent sans tool MCP) — prérequis
  à la génération de la skill (doc 03).
- Ajouter l'**introspection d'état** (lister tuiles par uuid/type/pos, énumérer les
  enums) — requise par la boucle perception→action.
- Ajouter l'**édition ciblée par uuid** (`deleteTile`, `moveTile`, `resizeTile`,
  `selectTile`).
- Ajouter les capacités **runtime** (piloter joueur/NPC en jeu, lire les bodies) —
  absentes en V2, requises pour « modules NPC/joueur ».

### Espace mémoire (doc 05)
- Blob **global à la tuile** vs **par sous-paramètre** ? Reco : global.
- Op fine `SetItemMemory` : merge partiel vs remplacement ?
- Traiter proprement la **sérialisation string-manuelle** de `ItemSnapable::toJSON`
  (piège n°1). 
- Plafond de taille du blob.

### Skill client (doc 03)
- Quel agent client cible-t-on d'abord (format de skill natif) ?
- Emplacement d'installation standardisé multi-plateforme.
- Génération : script de build dédié ou étape d'installeur ?

## 3. Risques majeurs

| # | Risque | Impact | Atténuation |
|---|--------|--------|-------------|
| R1 | Sandbox QML infaisable/insuffisant dans Qt | Bloque D1 | Prototyper tôt ; repli « palette + mémoire » ; démarrer local-only |
| R2 | RCE inter-joueurs via QML répliqué | Critique | Local-only d'abord ; re-validation + host-authoritative ensuite |
| R3 | Canal local détourné par un autre process | Élevé | Token de session + loopback strict |
| R4 | Sérialisation cassée du blob mémoire | Moyen | Passer `toJSON` du blob par `QJsonDocument` (doc 05 §3) |
| R5 | Dérive skill ↔ capacités réelles | Moyen | Générer la skill depuis le MCP (source unique) après réconciliation hooks/MCP |
| R6 | Complexité multi-joueurs des règles custom | Moyen | Différé (D3) ; concevoir avec host-authoritative en tête |

## 4. Séquencement suggéré (non engageant)

1. **Prototype sandbox QML** (R1) — dé-risque D1 avant tout le reste.
2. **Espace mémoire, étapes A+B** (doc 05) — valeur immédiate, risque minimal.
3. **Canal WS minimal** (doc 02) : introspection d'état + `setMemory` + pose,
   réutilisant les hooks existants.
4. **Réconciliation hooks/MCP + génération de skill** (docs 03).
5. **Capacités runtime** (piloter joueur/NPC).
6. Rouvrir **règles** (D3) et **bibliothèque** (D4).
