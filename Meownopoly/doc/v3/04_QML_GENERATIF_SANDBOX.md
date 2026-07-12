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

**Orientation D13, conditionnelle à R1 :** même moteur QML, contexte restreint et
JS borné/instrumenté. La machine locale est considérée de confiance et les pairs
réseau hostiles. Cette préférence ne devient viable que si le prototype sait
réellement interrompre une boucle, borner CPU/mémoire et masquer les singletons
globaux ; la stack V2 ne le fait pas (doc 10).

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
  autorisée — **pas** les singletons globaux directement. Attention : un contexte
  enfant ne constitue pas, à lui seul, une frontière de sécurité. Les singletons
  QML enregistrés et les fonctions globales/imports accessibles doivent être
  testés explicitement ; l'isolation forte peut exiger un moteur ou un **processus
  séparé**.
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
- Kill-switch : pouvoir **détruire** un artefact qui dérape. Limite fondamentale :
  `destroy()` ne peut pas interrompre une boucle JS qui bloque déjà le thread GUI.
  Un timeout préemptif crédible suppose de l'isolation hors du thread/processus
  principal, ou un langage/DSL borné. Le prototype R1 doit mesurer ce point avant
  de promettre un « sandbox » in-process.

### 3.5 Cycle de vie
- **Instanciation** : canal → validation → contexte restreint → rattachement.
- **Persistance** : l'artefact (source QML) peut vivre dans l'espace mémoire de la
  tuile (doc 05) pour être rechargé au chargement de la map — **à condition** de
  re-valider à chaque chargement (ne jamais faire confiance au JSON sur disque).
- **Destruction** : à la suppression de la tuile / fin de session / kill-switch.

## 4. Le nœud réseau : réplication du QML génératif

C'est **la** question de sécurité à trancher (doc 08). Trois postures :

1. **Exécution locale, arbitrage hôte** : la source est envoyée à l'hôte dans
   l'enveloppe de proposition pour que l'arbitre puisse la juger, mais elle n'est
   ni broadcastée ni exécutée chez les autres pairs. Les autres joueurs ne voient
   que les effets autoritatifs répliqués. C'est la posture initiale recommandée.
2. **Répliqué + re-validé** : l'artefact transite (via le pipeline collab) et est
   **re-passé au sandbox chez chaque pair**. Nécessite un sandbox de confiance
   égale partout ; RCE inter-joueurs si le sandbox a une faille.
3. **Répliqué + host-validé + signé** : seul le host instancie/valide, ou un
   registre signé de comportements approuvés circule. Plus lourd.

**Décision D16 : la politique est portée par l'artefact.** La source atteint
toujours l'hôte arbitre, sans broadcast systématique. L'artefact accepté déclare
ensuite soit « exécution hôte uniquement + réplication des effets », soit
« exécution chez chaque pair après revalidation ». La seconde politique ne peut
être activée qu'après réussite complète de R1.

## 5. Articulation avec l'espace mémoire (doc 05)

Deux registres complémentaires :

- **Espace mémoire = données** : `config` suit les ops d'édition/persistance ;
  `state` suit le futur bus autoritatif runtime (doc 05). Une donnée reste soumise
  à schéma, autorisation et quotas même si elle ne passe pas par le sandbox QML.
- **Artefact QML = comportement** (code) : la logique qui *utilise* ces données.
  Passe par le sandbox ; réplication à trancher (§4).

Beaucoup de personnalisations visées par le joueur (« loyer doublé », « bonus »)
sont **de la donnée** et ne demandent **pas** de code : elles vivent dans l'espace
mémoire + les capacités d'exécution des règles (doc 06). On garde donc la règle « donnée
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

## 6. Questions ouvertes (synthèse doc 08 ; questionnaire exhaustif doc 09)

- Périmètre exact de l'**API de jeu** exposée à l'artefact (la façade §3.3).
- Faisabilité réelle du **sandboxing QML/JS dans Qt** : jusqu'où peut-on
  verrouiller le `QQmlContext` et les imports ? (à prototyper — c'est le risque
  technique n°1 du pivot).
- Frontière d'isolation : même moteur QML, moteur séparé dans le même processus,
  processus auxiliaire, ou repli vers un DSL/capacités déclaratives ?
- Réplication : critères autorisant la propriété « exécution chez chaque pair ».
- Validation : parser maison, `qmllint`, ou analyse d'AST ? Que fait-on des faux
  négatifs ?
- ~~Faut-il un mode revue humaine ?~~ **Tranché D9/D13 : non.**
- Signature officielle : définir clés, rotation et révocation. Le SHA-256 actuel
  du launcher vérifie l'intégrité, pas l'identité de l'éditeur (doc 10).
