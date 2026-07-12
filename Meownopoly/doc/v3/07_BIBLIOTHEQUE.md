# 07 — Bibliothèque

> **Statut : intention produit actée, format de package tranché (D29/D38).** Les
> primitives et la capitalisation de créations servent la vision ; une
> bibliothèque d'assets 3D est prévue. Le format du manifeste et les budgets de
> départ sont fixés (D38) ; la **sécurisation (confiance/signature) est
> explicitement différée** (D38, R16 assumé au MVP).

> **Arbitrage D18.** Le premier jalon est une bibliothèque **locale, officielle
> et unifiée**, alimentée par les développeurs. Le partage communautaire n'entre
> pas dans ce jalon.

## 1. Intention (telle qu'exprimée)

Le brief mentionne *« l'ajout d'une bibliothèque »* sans en préciser le contenu.
Trois facettes complémentaires sont envisagées :

- **Bibliothèque de primitives** : un catalogue de briques fournies par le jeu
  (composants QML de base, actions, templates de comportement/règles) dans lequel
  l'IA **pioche** pour construire. C'est le **vocabulaire de base** offert aux IA —
  et, pour le QML génératif (doc 04), la source de blocs **déjà validés** que
  l'IA assemble plutôt que de tout générer de zéro (réduit la surface du sandbox).
- **Bibliothèque de créations partagées** : un dépôt d'éléments/comportements
  **produits par les IA/joueurs**, sauvegardables et échangeables entre parties et
  entre joueurs (capitalisation du contenu custom).
- **Bibliothèque d'assets 3D** (précision 2026-07-12) : catalogue d'**objets et
  modèles 3D** fournis, piochables et composables par l'IA pour matérialiser des
  éléments visuels. C'est une **sous-catégorie concrète des primitives** — le
  versant **graphique** du vocabulaire — dont le but explicite est d'offrir un
  **large éventail de possibilités** de construction sans générer chaque forme de
  zéro. **Prévue au développement.** S'appuie sur le rendu 3D existant (World3D /
  Pattounx v2, doc 01) et, pour la distribution, sur l'`asset_server/` (§2).

> **Le but affiné de la V3 (doc 00 §2) rend ces deux lectures porteuses**, sans
> pour autant lever le report (D4). (a) « Composer les briques préexistantes
> plutôt que générer de zéro » place les **primitives** au cœur du mécanisme : ce
> sont le vocabulaire graphique/gameplay que l'IA assemble. (b) « Le jeu se
> construit au fur et à mesure grâce aux utilisateurs » est exactement la
> **capitalisation des créations partagées**. Le cadrage reste différé, mais ces
> deux facettes ne sont plus « optionnelles » : elles servent directement le but.
> La **bibliothèque d'assets 3D** (ci-dessus) en est la **première concrétisation
> prévue**, côté primitives graphiques.

## 2. Ancrages avec le reste du cadrage

- **Primitives ↔ sandbox (doc 04)** : plus la bibliothèque de primitives est
  riche, moins l'IA a besoin de générer du QML libre → surface de risque réduite.
  Une primitive de la bibliothèque est un artefact **pré-validé/signé**.
- **Créations partagées ↔ espace mémoire (doc 05)** : une « création » = un blob
  mémoire (données + réf. comportement) + éventuellement un artefact QML. Le format
  d'échange s'appuie sur la sérialisation existante (`toJSON`, map JSON).
- **Assets 3D ↔ rendu (World3D / Pattounx v2)** : la bibliothèque d'assets 3D
  alimente directement le rendu 3D existant (doc 01 §3, `qml/world3d/`). Une
  entrée « asset 3D » = un modèle importable + ses métadonnées (pose, échelle,
  point d'ancrage) ; format et pipeline d'import **à instruire** (§3).
- **Distribution** : le projet a déjà un `asset_server/` (serveur HTTP de
  distribution d'assets, launcher avec queue/retry/checksum). D18 décide de le
  **réutiliser après audit**. L'audit confirme file, reprise, retry, SHA-256 et
  manifestes, mais pas de signature d'éditeur ni adressage par hash (doc 10).
- **Sécurité** : toute création téléchargée depuis un dépôt est **non fiable** →
  re-validation obligatoire par le sandbox (doc 04) avant exécution.

## 3. Questions à instruire (questions ouvertes : doc 09)

- ~~Local ou communautaire au premier jalon ?~~ **Tranché D18 : local officiel.**
- Périmètre exact de la bibliothèque unifiée : primitives gameplay livrées avec
  le premier pack, en plus des assets 3D.
- ~~Modèle de confiance ?~~ **Différé explicitement (D38)** : « on verra plus
  tard la sécurisation de la bibliothèque ». Les champs `signature`/
  `publisherKeyId` sont **réservés** dans le manifeste dès la v1 ; R16 reste
  ouvert et doit être réglé **avant** toute ouverture au contenu communautaire.
- ~~Réutilisation d'`asset_server/` + launcher ?~~ **Tranché D18 : oui, après audit.**
- ~~Format de packaging d'une « entrée » de bibliothèque ?~~ **Tranché
  D29/D38** : même format que l'`AssetManager`/asset_server, **étendu** —
  identité (`id`, `version` semver, `contentHash` SHA-256 par fichier + hash
  racine, `kind` = `asset3d|primitive|module|skin`), métadonnées (`name`,
  `description`, `author`, `tags`, `preview`), contenu (GLB/QML/JSON +
  `entryPoint` pour les primitives), dépendances `{id, versionRange}`,
  champs de confiance réservés, compat (`minGameVersion`, `channelVersion`).
- **Budgets assets (D38, provisoires)** : ≤ 50 k triangles/asset (≤ 10 k
  recommandé posable en nombre), textures ≤ 2048² et ≤ 4/matériau PBR,
  ≤ 20 Mo/package, animations squelettales OK, pas de shader custom au MVP —
  **à confirmer à l'implémentation avec un premier package d'asset de test**.
- **Assets 3D** : **GLB est retenu** et déjà supporté par `RuntimeLoader` ; imports
  réservés aux développeurs au premier jalon. La référence IA étend les clés
  existantes `(category,type,id)`/`modelName` avec version et hash.

## 4. Prochaine action

Rouvrir après les docs 04 (sandbox) et 05 (espace mémoire) : le format d'une
entrée de bibliothèque dépend directement de la façon dont un comportement/donnée
est représenté et validé. Poser alors une décision **D-bibliothèque** dans le
doc 08.

Cas particulier : le **versant assets 3D** (purement graphique) dépend surtout du
rendu (World3D) et de la distribution, **moins du sandbox** — il peut être
**instruit plus tôt**, en parallèle des docs 04/05.
