# 04 — QML génératif « à la volée » & sandbox d'exécution

> **Statut : cadrage (draft).** Découle de la décision **D1 : QML génératif
> complet**. **Document le plus critique du pivot** — la liberté maximale y
> rencontre la surface de sécurité maximale.

## 1. L'atout : QML interprété

Le QML est **chargé et interprété au runtime**, pas compilé. Qt fournit deux voies
d'instanciation dynamique :

- `Qt.createQmlObject(qmlString, parent, url)` — instancie du QML depuis une
  **chaîne** produite à la volée.
- `Qt.createComponent(url)` + `Loader` — instancie depuis un fichier/URL.

C'est ce qui rend crédible le cœur de la vision : l'IA peut **produire un
comportement ou un élément qui n'existe pas encore** et le jeu l'exécute dans la
session courante, sans recompiler ni redéployer. Là où V2 exigeait un nouveau
`TileType` C++ + recompilation, V3 laisse l'IA écrire du code.

**Forme concrète visée : du JS embarqué dans les éléments, adossé aux briques
préexistantes.** Le but V3 (doc 00 §2) est de **créer du gameplay**, pas seulement
du décor. Le mécanisme courant n'est donc pas « générer une scène entière de
zéro » mais **composer les briques graphiques et gameplay déjà fournies** (éléments
posables, modules activables) **et y injecter du code JS** qui porte le
comportement nouveau (réactions, événements, règles locales). Le JS embarqué est
un premier-classe du pivot — c'est *le* levier d'écriture de gameplay — d'où
l'importance du sandbox ci-dessous.

## 2. Le risque : exécuter du code non fait-maison

`Qt.createQmlObject` exécute du **JavaScript arbitraire** dans le contexte du
moteur QML du jeu. Sans précaution, un artefact QML peut :

- accéder à **tous les objets exposés au contexte** (singletons `Game`, `Catway`,
  `EditorOpBus`, `MapFileManager`, `PhysicsSession`…),
- appeler `Qt.` (dont potentiellement des accès système selon les imports),
- importer des modules non désirés,
- boucler/allouer sans fin (déni de service local),
- en réseau : si l'artefact est **répliqué aux autres joueurs** (collab), un
  joueur peut pousser du code chez les autres → **RCE inter-joueurs**.

**Posture de cadrage : tout artefact QML est hostile par défaut.** Le sandbox
n'est pas une option de confort, c'est la condition de viabilité de D1.

## 3. Le sandbox — principes de conception

Le sandbox est le **point de passage obligatoire** de tout QML génératif entre le
canal (doc 02) et la scène.

### 3.1 Validation avant instanciation
- **Allow-list d'imports** : seuls des modules explicitement autorisés
  (`QtQuick` de base, un module « API de jeu » restreint — cf. §3.3). Rejet de
  tout import hors liste.
- **Interdits statiques** : pas d'accès fichier/réseau/process (`XMLHttpRequest`,
  `Qt.openUrlExternally`, composants `FileDialog`, `Process`…), pas de
  `Qt.createQmlObject` imbriqué non contrôlé, pas d'`import "…js"` arbitraire.
- **Analyse syntaxique** avant chargement (parser QML/JS) plutôt que confiance
  aveugle à `createQmlObject`.

### 3.2 Contexte d'exécution restreint
- Instancier dans un **`QQmlContext` dédié** qui n'expose **que** l'API de jeu
  autorisée — **pas** les singletons globaux directement. L'artefact voit une
  façade, pas `Game`/`Catway`/`EditorOpBus` en direct.
- **Parent maîtrisé** : rattaché à un porteur (la tuile / un conteneur de
  quarantaine), jamais à la racine de la scène sans contrôle.

### 3.3 Une « API de jeu » exposée à l'artefact (façade)
Définir le **vocabulaire minimal** qu'un comportement généré a le droit
d'utiliser : **lire et écrire les variables de l'espace mémoire** de sa tuile et
**s'abonner à leur signal de changement** (`userMemoryChanged`, doc 05) — c'est le
canal de communication normal entre le JS embarqué et l'état synchronisé —,
demander une animation, émettre un événement de jeu, réagir à un trigger physique.
Cette façade est l'équivalent, pour le QML génératif, de l'allow-list de commandes
du canal.

### 3.4 Budget de ressources
- Timeouts/quotas CPU, plafond mémoire, limite du nombre d'objets instanciés,
  taille max de l'artefact (cf. seuils réseau existants 20–30 KB).
- Kill-switch : pouvoir **détruire** un artefact qui dérape (`destroy()` + retrait
  du contexte).

### 3.5 Cycle de vie
- **Instanciation** : canal → validation → contexte restreint → rattachement.
- **Persistance** : l'artefact (source QML) peut vivre dans l'espace mémoire de la
  tuile (doc 05) pour être rechargé au chargement de la map — **à condition** de
  re-valider à chaque chargement (ne jamais faire confiance au JSON sur disque).
- **Destruction** : à la suppression de la tuile / fin de session / kill-switch.

## 4. Le nœud réseau : réplication du QML génératif

C'est **la** question de sécurité à trancher (doc 08). Trois postures :

1. **Local-only** : le QML généré ne quitte jamais la machine. Les autres joueurs
   voient l'**effet** (via l'état synchronisé : espace mémoire, tuiles) mais
   n'exécutent pas le code. Le plus sûr ; limite les comportements « visibles
   partout ».
2. **Répliqué + re-validé** : l'artefact transite (via le pipeline collab) et est
   **re-passé au sandbox chez chaque pair**. Nécessite un sandbox de confiance
   égale partout ; RCE inter-joueurs si le sandbox a une faille.
3. **Répliqué + host-validé + signé** : seul le host instancie/valide, ou un
   registre signé de comportements approuvés circule. Plus lourd.

**Recommandation de cadrage : démarrer en local-only (posture 1)** pour dé-risquer,
et n'ouvrir la réplication qu'une fois le sandbox éprouvé. Le modèle
host-authoritative existant (`EditorSession`, `PhysicsSession`) donne le point
d'insertion naturel pour une future validation centralisée.

## 5. Articulation avec l'espace mémoire (doc 05)

Deux registres complémentaires :

- **Espace mémoire = données** (blob JSON) : « cette case rapporte ×2 », état,
  paramètres. Se réplique sans danger par `ApplyState` (c'est de la donnée).
- **Artefact QML = comportement** (code) : la logique qui *utilise* ces données.
  Passe par le sandbox ; réplication à trancher (§4).

Beaucoup de personnalisations visées par le joueur (« loyer doublé », « bonus »)
sont **de la donnée** et ne demandent **pas** de code : elles vivent dans l'espace
mémoire + le futur moteur de règles (doc 06). On garde donc la règle « donnée
d'abord » : si l'effet s'exprime en données, pas de JS.

Mais **créer du gameplay nouveau passe, lui, par du code JS** (doc 00 §2) : ce
chemin n'est **pas** marginal, c'est le levier central du pivot. La stratégie de
réduction de risque n'est donc **pas** « éviter le code » mais **composer sur des
briques pré-validées** plutôt que générer du QML libre de zéro :

- le comportement s'écrit en **JS embarqué dans un élément** qui réutilise les
  briques graphiques/gameplay existantes (surface réduite au JS de glue, pas à une
  scène entière) ;
- une **bibliothèque de primitives pré-validées** (doc 07) fournit les blocs que
  l'IA assemble, réduisant d'autant ce que le sandbox doit valider à la volée ;
- l'IA **arbitre** (doc 00 §4, obligatoire) juge la viabilité contextuelle par
  dessus le sandbox.

Le QML totalement libre (scène de zéro) reste possible mais devient le cas
**extrême**, pas le cas courant — ce qui concentre le risque sur une fraction des
usages.

## 6. Questions ouvertes (→ doc 08)

- Périmètre exact de l'**API de jeu** exposée à l'artefact (la façade §3.3).
- Faisabilité réelle du **sandboxing QML/JS dans Qt** : jusqu'où peut-on
  verrouiller le `QQmlContext` et les imports ? (à prototyper — c'est le risque
  technique n°1 du pivot).
- Réplication : quelle posture (§4) et à quelle échéance ?
- Validation : parser maison, `qmllint`, ou analyse d'AST ? Que fait-on des faux
  négatifs ?
- Faut-il un **mode revue** (le joueur/host approuve un artefact avant exécution)
  au moins pour les comportements répliqués ?
