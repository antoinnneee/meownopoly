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
- **Précision du but (2026-07-11).** Le mécanisme visé n'est pas « générer des
  scènes entières de zéro » mais **créer du gameplay** en **composant les briques
  graphiques et gameplay préexistantes** de l'éditeur (éléments posables, modules
  activables) **et en y embarquant du code JS** pour le comportement nouveau. D1
  reste « vrai code au runtime » (le JS embarqué en est), mais **adossé à un
  vocabulaire de briques validées** — ce qui rapproche l'usage courant de
  l'« hybride validé » et **réduit d'autant la surface du sandbox** (cf. doc 04 §5,
  doc 07 primitives).

### D2 — Canal d'interaction : **canal local dédié** *(transport révisé par D20)*
- **Décision.** Créer un canal **local dédié** IA↔jeu, distinct de
  l'`AutomationServer` (qui reste réservé au test/debug interne). La forme
  initialement envisagée (WebSocket maison) est **remplacée par un serveur MCP
  local** — voir **D20**. L'essence de D2 (canal dédié, curé, ≠ automation)
  demeure.
- **Pourquoi.** Séparer les responsabilités (debug bas niveau vs capacités
  gameplay de haut niveau), pouvoir **durcir la sécurité** du canal IA
  indépendamment (allow-list vs introspection totale), évoluer sans casser le
  harnais de dev.
- **Conséquence.** Réutiliser les **fondations** de l'automation (loopback strict,
  JSON corrélé, GUI thread) mais **pas** son catalogue permissif. Doc 02.
- **Frontière d'accès (non-négociable).** L'IA cliente n'a **aucun accès** au
  harnais d'automation (`AutomationServer` port 7700, `automation_mcp/`), réservé
  au test/debug. Le canal ré-expose un **sous-ensemble curé** (certaines features
  **portées** + durcies), orienté **création de briques de gameplay** — pas
  l'introspection/injection bas niveau. Réutilisation = **de code**, pas d'accès.
- **Alternatives écartées.** Étendre l'`AutomationServer` (couplage debug/prod
  indésirable) ; **exposer l'automation à l'IA** (surface de test dangereuse comme
  contrat d'IA) ; décider plus tard (le pivot a besoin du canal tôt).

### D3 — Moteur de règles : **cadrage différé** (partiellement levé par D8)
- **Décision.** Reporter le cadrage des **détails** (doc 06). L'**ownership** est,
  lui, tranché par **D8** : les règles sont **gouvernées par l'arbitre** et leur
  forme acceptée est exécutée par le jeu ; pas de moteur générique séparé acté.
- **Pourquoi.** Le format d'une règle proposée / sa mémorisation / sa réplication
  dépend encore des docs 04 (sandbox) et 05 (espace mémoire), à stabiliser d'abord.

### D4 — Bibliothèque : **cadrage différé**
- **Décision.** Reporter le cadrage (doc 07 = stub). Réserver l'emplacement.
- **Pourquoi.** Le format d'une entrée de bibliothèque dépend de la représentation
  d'un comportement/donnée (docs 04/05).
- **Précision du contenu (2026-07-12).** Une première brique de contenu est actée
  au niveau **intention** : une **bibliothèque d'assets 3D**, prévue au
  développement, pour **élargir le vocabulaire graphique** composable par l'IA
  (« large éventail de possibilités », doc 00 §2, doc 07 §1). Cela **précise** la
  lecture « primitives » (son versant graphique) **sans lever** le report : format
  d'entrée, pipeline d'import 3D, distribution et modèle de confiance restent à
  cadrer (doc 07 §3).

### D5 — Dossier de cadrage
- **Décision.** Regrouper le cadrage V3 dans `Meownopoly/doc/v3/`, docs numérotés,
  en français, avec bandeaux de statut. Commit/push sur la branche **V3**.

### D6 — Deux rôles d'IA : cliente (proposante) + arbitre (MJ) chez l'hôte
- **Décision (niveau vision).** Le modèle d'acteurs distingue **deux rôles** :
  une **IA cliente** proposante présente chez chaque joueur (hôte compris), et une
  **IA arbitre / MJ** présente **uniquement chez l'hôte**, qui vérifie la
  viabilité d'une proposition avant son introduction dans la partie. Topologie :
  **2 modèles chez l'hôte** (cliente + arbitre), **1 chez le client** (cliente).
  Cf. doc 00 §4.
- **Pourquoi.** Séparer une posture *créative/permissive* (proposer) d'une posture
  *conservatrice/responsable* (arbitrer) ; ajouter un jugement **contextuel**
  au-dessus des garde-fous **mécaniques** (sandbox doc 04, validateurs de
  capacités) ; garder un **point d'autorité unique** aligné sur le host-authoritative
  (`EditorSession`) pour éviter le split-brain.
- **Arbitre obligatoire.** Le mécanisme central ouvre la construction d'une
  partie partagée à plusieurs proposants : l'arbitrage de gouvernance n'est
  **pas** optionnel. Héberger une partie
  pilotée par IA **exige** un modèle arbitre branché ; sans lui, le mode IA est
  indisponible (repli sur le jeu classique). Pas de « host sans arbitre ». Cette
  obligation ne fournit aucune garantie de sécurité mécanique.
- **Conséquence.** L'arbitre se greffe sur le domaine d'autorité de l'édition.
  `EditorSession` fournit aujourd'hui rate-limit, séquencement et rebroadcast,
  mais pas une validation sémantique générique : la passerelle de proposition et
  ses validateurs sont une responsabilité V3 nouvelle. L'arbitre **ne porte pas**
  de garantie de sécurité dure.
- **Différé (sous-cadrage).** La **nature** de l'arbitre (LLM / règles
  déterministes / hybride), son **grain** (par action / par lot / par artefact
  QML), le **format de verdict** rendu au proposant, et son **articulation** avec
  l'exécution des règles (doc 06) restent à instruire — voir §2 « IA arbitre ».
- **Alternatives écartées.** IA unique par joueur mêlant proposition et validation
  (dilue la garantie d'intégrité) ; validation purement mécanique sans arbitre
  (perd le jugement contextuel « cohérence/équilibre »).

### D7 — Espace mémoire : configuration durable distincte de l'état runtime
- **Décision corrigée.** La **configuration durable** suit le pipeline
  `ApplyState`/`EditDelta` et peut participer à l'undo/persistance. L'**état
  runtime** suit une autorité hôte inspirée de `PhysicsSession` et n'est pas
  undoable au grain de l'écriture. Une écriture cliente est une intention.
- **Pourquoi.** Confondre les deux ferait soit saturer les piles undo, soit
  persister/annuler des états éphémères sans rapport. Un snapshot mémoire global
  lors d'un undo est dangereux en collaboration car il écrase des mutations
  concurrentes postérieures.
- **Conséquence.** `toJSON`/`applyJson` portent la configuration durable et,
  seulement si le produit le décide, un état de reprise distinct. L'undo d'un
  artefact repose sur son write-set durable ciblé, pas sur toute la mémoire.
- **À trancher (§2).** Noms/schéma des deux espaces ; protocole runtime dédié ou
  extension physique ; delta/snapshot, coalescence, fiabilité, cadence ; conflits
  d'undo/redo ciblé.
- **Alternative écartée pour le runtime.** « Voyage gratuit via `EditDelta`/`ApplyState` »
  (thèse initiale de doc 05) : simple mais **inadapté à la fréquence runtime** et
  polluerait l'undo d'édition. Conservé pour la configuration durable et sa
  persistance/transaction d'undo.

### D8 — L'arbitre gouverne les règles ; le jeu exécute leur forme acceptée
- **Décision.** L'IA arbitre est l'**autorité de politique** : elle valide ou non
  les propositions et maintient le règlement courant. Aucun moteur de règles
  générique séparé n'est acté. Une règle acceptée doit néanmoins être matérialisée
  sous une forme exécutable par les capacités du jeu (configuration, module,
  primitive ou QML/JS validé). **Aucune notion de tour imposée** — elle
  s'**introduit** (a) par le **prompt** donné à l'arbitre, ou (b) par une
  **modification proposée par une IA cliente que l'arbitre accepte** (règlement
  négociable/évolutif en cours de partie).
- **Pourquoi.** Cohérent avec « une partie selon ses propres règles » et avec le
  rôle de l'arbitre (D6). Évite de figer un DSL de règles côté cœur ; laisse la
  liberté maximale, l'autorité restant unique (hôte).
- **Conséquence.** Répond à la question d'autorité : l'arbitre gouverne, mais ne
  devient pas implicitement une boucle d'exécution temps réel. Les **invariants
  durs** (sécurité,
  intégrité) restent au **sandbox** (doc 04), pas à l'arbitre (jugement souple).
  Détails différés (format proposé/accepté, exécution, mémorisation, réplication)
  — doc 06 §4.
- **Alternatives écartées.** Moteur de règles déclaratif figé côté C++ (rigide,
  contraire à la liberté du pivot) ; règles hardcodées type « système de tour V2 »
  (**inexistant** de toute façon, cf. §Capacités).

### D9 — Périmètre produit V3 et extinction du mode classique
- **Décision.** La cible V3 couvre les trois contextes : éditeur solo assisté,
  éditeur collaboratif et partie runtime co-construite. Tous exigent les deux
  rôles IA, y compris le solo. Une création validée entre automatiquement dans
  la partie, sans revue humaine obligatoire, et peut modifier une partie déjà
  commencée. Le mode classique est conservé pendant la transition mais n'est pas
  une cible maintenue à terme.
- **Plateformes.** Windows et Linux sont visés. L'audit confirme un cœur largement
  portable mais aucun packaging/CI/test Linux actuel (doc 10).
- **Encore ouvert.** Les trois modes ont été cochés comme « premier mode » : leur
  ordre réel de livraison reste à décider.

### D10 — Agents externes isolés et supervisés par l'application
- **Décision.** Les rôles proposant/arbitre utilisent des processus ou contextes
  réellement isolés ; un même fournisseur reste permis si les sessions sont
  séparées. Les premières cibles sont `claude -p` et un mode non interactif
  équivalent de Codex. Le launcher/jeu démarre et supervise ces agents via un
  adaptateur. L'hôte configure un budget et les joueurs configurent ensemble le
  prompt/personnalité initiale de l'arbitre. L'arbitre décide quelles règles il
  affiche et cette visibilité peut évoluer en cours de partie.
- **Migration.** Un changement d'arbitre avec transfert d'état/version est requis.
- **Gap V2.** `LauncherManager` ne lance actuellement aucun processus ; la
  supervision et le transfert de contexte sont de nouveaux chantiers (doc 10).
- **Précision interaction (2026-07-12).** Les IA clientes sont **invoquées
  directement depuis l'application, via un tchat ingame** — le joueur n'exécute
  **pas** les features depuis un CLI à part. `claude -p`/Codex non interactif
  restent le **mécanisme d'exécution sous-jacent** piloté par l'app, invisible
  pour le joueur. Bénéfice clé : l'app **pré-prompte** chaque modèle à
  l'invocation pour qu'il suive les **workflows des skills internes** (doc 03) —
  pas de dépendance à une configuration d'agent côté joueur.

### D11 — Proposition auditable, amendement immédiat et application automatique
- **Décision.** Une proposition porte auteur, intention, opérations, artefacts,
  write-set et version. Le flux est préfiltre mécanique → arbitre → validation
  complète → exécution. L'arbitre peut amender et appliquer immédiatement ; le
  journal conserve proposition originale, raisons, verdict et version appliquée.
- **Conséquence.** L'amendement ne repasse pas obligatoirement par le proposant,
  mais ne peut être silencieux dans l'audit. L'application partagée reste
  autoritative côté hôte.
- **Encore ouvert.** L'unité déclenchant un appel arbitre (commande, proposition
  complète, code seulement ou politique hybride) doit être choisie dans Q-C01.

### D12 — Représentation hiérarchique des règles
- **Décision d'orientation.** Une règle acceptée peut se matérialiser par plan de
  capacités, configuration de modules, DSL/machine à états ou QML/JS sandboxé ;
  la sélection est hiérarchique selon le besoin. Le règlement autoritatif vit
  dans un document structuré versionné. Les modules existants sont des primitives
  privilégiées sous une couche de règles.
- **Tour par tour.** S'il est demandé, il est généré comme artefact et/ou
  orchestré par l'arbitre ; aucune primitive native de tour n'est exigée.
- **Protection.** Profondeur maximale, file transactionnelle et détection de
  cycles/write-set sont toutes requises.

### D13 — Cible de sandbox in-process, conditionnée par R1
- **Intention validée.** Le chemin préféré est le même moteur QML avec contexte
  restreint et JS borné/instrumenté, sans accès disque/réseau/process et avec
  limites préemptives. Aucune revue humaine n'est requise ; la machine locale est
  considérée de confiance et les pairs réseau hostiles.
- **Condition bloquante.** La stack actuelle n'offre aucune de ces garanties et
  expose de nombreux singletons au moteur QML. D13 reste **conditionnelle** à la
  réussite de R1, notamment l'arrêt réel d'une boucle infinie. En cas d'échec,
  l'isolation en processus séparé redevient nécessaire.
- **Signature.** Les artefacts officiels pourront faire confiance à une signature,
  mais la stack ne possède aujourd'hui qu'un checksum SHA-256 non signé (doc 10).

### D14 — Un canal unique multiplexé et versionné *(transport révisé par D20)*
- **Décision.** Un seul canal local multiplexe rôles et namespaces, avec une
  version globale du protocole. Les événements passent par un adaptateur unifié
  alimenté par les signaux internes et un nouveau journal métier. Les lots visent
  une sémantique tout-ou-rien. `automation.raw` n'existe qu'en build de dev et
  reste absent du manifeste livré. *(« WebSocket » remplacé par « serveur MCP
  local » — D20 ; le reste de la décision demeure.)*
- **Gaps.** Les transactions V2 sont groupées, pas rollback-atomiques ;
  `reliable.io` n'assure pas la retransmission (doc 10). ~~Authentification et
  découverte du secret~~ résolues par construction avec D20 (config/token
  injectés au spawn de l'agent).

### D15 — Modèle mémoire V3
- **Décision.** Un même objet `memory` contient deux namespaces `config` et
  `state`. La mémoire existe sur tuiles, session et joueurs. Le transport cible
  est un bus d'état générique partagé, avec séquencement hôte/LWW, write-set par
  tuile + clé + ressource/capacité, et signaux global et ciblé.
- **Gaps.** Ce bus n'existe pas en V2. Format de sauvegarde runtime, stratégie
  delta/snapshot, garanties de transport et conflit d'undo restent ouverts.

### D16 — Artefacts : autorité hôte et politique d'exécution déclarée
- **Décision.** La source voyage de l'auteur vers l'hôte arbitre, sans broadcast
  systématique. L'hôte est autoritatif ; selon une propriété de l'artefact, le
  comportement s'exécute chez l'hôte seulement ou chez chaque pair après
  revalidation. Les sources/références vivent dans la map **et** dans un store
  séparé. Un artefact manquant désactive l'élément avec diagnostic et peut être
  téléchargé automatiquement.
- **Correction stack.** Le `QUuid` existant reste l'identité d'instance. Une
  identité d'artefact immuable exige en plus hash de contenu + version de
  manifeste ; aucun store par hash n'existe encore (doc 10).

### D17 — Skill Codex + Claude générée au build
- **Décision.** Codex et Claude Code sont les deux premières cibles. Le manifeste
  versionné du canal reste la source de vérité ; la skill est générée au build.
  Une version obsolète utilise si possible un mode compatibilité et propose une
  mise à jour automatique. Seul le catalogue curé est porté depuis les hooks/MCP.
- **Précision distribution (2026-07-12).** La skill n'est **pas installée chez
  l'agent du joueur** : elle est **embarquée avec l'application** et **injectée en
  pré-prompt** à l'invocation in-app des modèles (tchat ingame, cf. D10). La
  question « emplacement d'installation multi-plateforme » devient caduque pour
  le flux nominal.
- **Encore ouvert.** Forme du client WS embarqué côté app (comment l'agent
  invoqué atteint le canal : tool fourni par l'app vs WS brut).

### D18 — Bibliothèque locale officielle unifiée
- **Décision.** Le premier jalon est une bibliothèque locale officielle unifiée,
  alimentée uniquement par les développeurs. `asset_server/` et le launcher sont
  réutilisés après audit ; GLB est le premier format 3D.
- **Validation stack.** Distribution, retry, checksum, manifestes et chargement
  GLB existent. Signature d'éditeur, adressage par hash et package V3 restent à
  créer. Les références existantes `(category,type,id)`/`modelName` seront
  étendues avec version/hash (doc 10).

### D19 — Journal configurable avec noyau d'audit obligatoire
- **Décision.** Le niveau de verbosité, la durée et l'export du journal sont
  configurables. Le noyau exigé par D11 — proposition originale, auteur, verdict,
  raisons, amendement et version appliquée — ne peut pas être désactivé tant que
  l'action reste undoable/rejouable. Sa rétention et sa politique de confidentialité
  restent à définir.

### D20 — Transport du canal : **serveur MCP local** (révise la forme de D2/D14)
- **Décision (2026-07-12).** Le canal IA↔jeu est exposé comme **serveur MCP
  local** (loopback) plutôt que comme protocole WebSocket maison. Conséquence
  directe de l'invocation in-app (D10/D17) : l'app spawne l'agent et lui injecte
  **config MCP + token + pré-prompt skill** — plus de découverte de port/secret,
  plus de client WS à livrer.
- **Pourquoi.** `claude -p` et Codex consomment des tools MCP **nativement** ;
  le manifeste (D17) génère directement les schémas de tools (même pipeline que
  le patron `automation_mcp/`) ; la boucle perception→action est native
  (req/rep corrélé, typé). Le WS custom ne se justifiait que pour un agent
  externe autonome — cas éliminé par D10.
- **Économie de tokens (contrainte de conception).** La skill pré-promptée porte
  la connaissance (workflows, recettes — stable donc cachée) ; le catalogue MCP
  reste **réduit et groupé** (tools paramétrés type `editor_place(kind,…)`,
  résultats paginés/compacts, préfixe stable pour le prompt caching,
  divulgation progressive via `help(topic)` si besoin). Doc 02 §3.
- **Événements.** Injectés par invocation (résumé depuis le dernier tour) +
  tool `events_poll(cursor)` pour se resynchroniser en cours de tâche longue.
  Pas d'agent persistant ni de canal push au premier jalon. Doc 02 §4.
- **Ce qui survit de D2/D14.** Canal dédié ≠ automation, loopback strict,
  serveur unique multiplexant rôles/namespaces (tokens distincts proposant vs
  arbitre), version globale, lots tout-ou-rien, `automation.raw` dev-only.
- ~~Encore ouvert (Q-E11)~~ **Tranché par D21** (forme d'intégration).
- **Alternatives écartées.** Output formaté seul (unidirectionnel : pas de boucle
  perception→action, l'IA travaille en aveugle) ; WS custom (client + auth +
  protocole à créer sans bénéfice, les deux CLIs cibles parlant MCP).

### D21 — Forme d'intégration : serveur MCP **streamable HTTP intégré au jeu** (ferme Q-E11)
- **Décision (2026-07-12).** Le serveur MCP est un **endpoint streamable HTTP
  loopback embarqué dans le process du jeu** — pas de pont stdio externe.
- **Pourquoi.** Vérifié 2026-07-12 : les **deux CLIs cibles supportent
  nativement le streamable HTTP avec bearer token** (Claude Code :
  `claude mcp add --transport http` / `--mcp-config` ; Codex :
  `[mcp_servers.<n>] url = …` + `bearer_token_env_var` dans `config.toml`) —
  la compatibilité n'est pas un discriminant. L'argument décisif est la
  **distribution** : un pont stdio réintroduirait un runtime Node (ou un binaire
  packagé) à livrer à chaque joueur, alors que l'option intégrée ne demande rien
  de plus que le CLI d'agent lui-même. Bonus : un seul process, cycle de vie
  trivial (le serveur vit/meurt avec le jeu), un même endpoint sert proposante
  et arbitre avec des tokens/capacités distincts.
- **Coût assumé.** Implémenter le sous-ensemble MCP soi-même en C++ (pas de SDK
  officiel) : JSON-RPC 2.0 sur HTTP POST — `initialize`, `tools/list`,
  `tools/call` suffisent au MVP ; le flux SSE est optionnel (réponses
  `application/json` simples). Suivre soi-même les évolutions de la spec.
- **Prérequis kit.** Le module **`QtHttpServer` n'est pas installé** dans le kit
  Qt 6.11.0 actuel (add-on optionnel) → à ajouter via le Maintenance Tool.
  Alternative sans intérêt : micro-serveur HTTP sur `QTcpServer`.
- **Repli documenté.** Si l'implémentation maison coince (ex. un CLI exige une
  partie non implémentée de la spec) : pont stdio via le SDK officiel
  `@modelcontextprotocol/sdk` + IPC WebSocket loopback (patron `automation_mcp/`).
- **Écarté.** « Selon l'agent » (HTTP pour l'un, pont pour l'autre) : plus de
  justification puisque les deux CLIs parlent HTTP.

### D22 — Politique de capture d'écran (ferme Q-E10)
- **Décision (2026-07-12).** Tool screenshot du canal (doc 02 §5) : captures de
  l'**écran de jeu**, à la demande de l'IA (lui donner un visuel de la map si
  elle le juge utile).
- **Plafond.** Nombre max de captures **par requête d'IA**, porté par un
  `#define` compile-time pour affiner la valeur en test — **défaut : 5**.
- **Rétention éphémère.** Les captures ne sont **pas conservées** : gardées
  brièvement, le temps de servir pendant **quelques tours d'IA**, puis purgées —
  pas d'accumulation de stockage inutile. (La rétention du journal d'audit D19,
  elle, reste à définir : Q-J02.)
- **Masquage/consentement.** **Rien n'est masqué** : jouer au mode IA implique
  la capture d'écran de jeu. Le joueur en est **informé au lancement** (une
  fois), sans redemande ensuite.

## 2. Questions ouvertes (par thème)

Cette section reste le registre synthétique proche des décisions. Le questionnaire
remplissable des **questions encore ouvertes** (épuré le 2026-07-12, arbitrages
reportés en D9→D22) est [`09_QUESTIONNAIRE_CADRAGE.md`](./09_QUESTIONNAIRE_CADRAGE.md).

### Sécurité (bloquant pour D1)
- Jusqu'où peut-on **verrouiller** un `QQmlContext` et l'allow-list d'imports dans
  Qt ? (prototype requis — risque technique n°1).
- **Réplication/exécution du QML génératif** en multi-joueurs : exécution locale
  après arbitrage hôte / répliqué+re-validé / host-validé+signé ? La source d'un
  client doit au minimum atteindre l'hôte pour arbitrage. Reco de départ :
  **exécution locale, sans broadcast aux pairs**.
- Isolation QML : contexte/moteur in-process, processus auxiliaire, ou repli
  DSL/capacités si l'arrêt préemptif d'un JS bloquant est impossible ?
- ~~Authentification du canal local : simple loopback ou token ?~~ **Tranché
  D20 : token éphémère injecté au spawn de l'agent** (l'app contrôle les deux
  bouts) ; tokens/capacités distincts pour proposant et arbitre.

### Canal IA (doc 02)
- ~~Un canal multiplexé vs plusieurs ?~~ **Tranché D14 : un canal multiplexé.**
- ~~WS custom ou autre transport ?~~ **Tranché D20 : serveur MCP local** ;
  ~~forme d'intégration (Q-E11)~~ **tranchée D21 : streamable HTTP loopback
  intégré au jeu** (`QtHttpServer` à installer ; repli pont stdio documenté).
- ~~Authentifier les deux clients locaux de l'hôte ?~~ **Tranché D20** :
  configs/tokens distincts injectés au spawn, capacités différentes par rôle.
- Schéma du **résumé d'événements injecté** par tour + sémantique du curseur
  `events_poll`, au-dessus de l'adaptateur `Game`/`EditorOpBus`/
  `ItemSnapableEvents` et du journal (D14/D19/D20).
- **Quel sous-ensemble de l'automation porter** dans le catalogue curé du canal
  (pose, caméra, introspection d'état…) et lesquelles **rester** test-only ?
  Granularité du **groupement de tools** à mesurer (économie de tokens, D20).
- ~~Échappatoire `automation.raw` ?~~ **Tranché D14 : build dev uniquement.**
- Garanties applicatives de livraison/retry/déduplication au-dessus du composant
  d'ACK `reliable.io` (doc 10) — concerne le P2P entre pairs, pas le canal local.

### Capacités manquantes (chantiers identifiés)
- Réconcilier **hooks ↔ tools MCP** (des hooks existent sans tool MCP) — prérequis
  à la génération de la skill (doc 03).
- Ajouter l'**introspection d'état** (lister tuiles par uuid/type/pos, énumérer les
  enums) — requise par la boucle perception→action.
- Ajouter l'**édition ciblée par uuid** (`deleteTile`, `moveTile`, `resizeTile`,
  `selectTile`).
- Ajouter les capacités **runtime** (piloter joueur/NPC en jeu, lire les bodies) —
  absentes en V2, requises pour « modules NPC/joueur ».

### IA arbitre / MJ (doc 00 §4, D6/D10/D11)
- ~~Nature de l'arbitre ?~~ **Tranché : LLM externe** (`claude -p`/équivalent
  Codex) pour le contextuel, entouré de validateurs mécaniques.
- **Grain d'arbitrage** : chaque action, un lot d'actions, ou seulement les
  artefacts QML génératifs ? Coût/latence d'un arbitrage LLM par action.
- ~~Amendement direct ?~~ **Tranché D11 : oui, application immédiate**, avec
  journal de l'original, des raisons et de la version appliquée.
- ~~Auto-arbitrage de l'hôte~~ **Tranché (D6)** : les propositions de l'IA cliente
  de l'hôte passent par le même arbitre ; pas d'auto-exemption.
- ~~Frontière avec le contrat de règles : l'arbitre EST-il le moteur de règles ?~~
  **Tranché (D8) sur l'autorité** : l'arbitre gouverne les règles. L'exécution
  appartient à une forme matérialisée acceptée par le jeu. Restent ouverts :
  format proposé/accepté, exécution, mémorisation et réplication (doc 06 §4).
- ~~Panne / absence d'arbitre~~ **Tranché (D6)** : l'arbitre est **obligatoire**.
  Pas d'hôte sans arbitre ; à défaut, le mode IA est indisponible (repli jeu
  classique). Reste à définir l'**UX du prérequis** : comment le jeu détecte/exige
  qu'un arbitre soit branché avant d'autoriser l'hébergement d'une partie IA.

### Espace mémoire (doc 05, sémantiques tranchées par D7)
- ~~Blob global ou par sous-paramètre ?~~ **Tranché D15 : `memory` global avec
  `config`/`state`, également porté par session et joueurs.**
- Schéma/noms de la **configuration durable** et de l'**état runtime** ; l'état
  doit-il être sauvegardable séparément pour reprendre une partie ?
- **Transport runtime** : D15 demande un bus générique nouveau ; delta/snapshot
  de réparation, retry/séquence, cadence et plafond restent ouverts.
- **Undo ciblé** (D7) : write-set durable, conflit si une clé a changé depuis,
  comportement du redo. Le snapshot global n'est plus recommandé.
- Traiter proprement la **sérialisation string-manuelle** de `ItemSnapable::toJSON`
  (piège n°1).
- Plafond de taille du blob.

### Skill client (doc 03)
- ~~Agents initiaux ?~~ **Tranché D17 : Codex + Claude Code.**
- ~~Emplacement d'installation standardisé multi-plateforme ?~~ **Caduc
  (précision D17, 2026-07-12)** : la skill est embarquée dans l'app et injectée
  en pré-prompt à l'invocation ingame — pas d'installation côté agent du joueur.
- ~~Comment l'agent atteint le canal ?~~ **Tranché D20 : connecteur MCP natif
  des CLIs**, config injectée au spawn. Forme d'intégration tranchée par **D21**
  (streamable HTTP intégré au jeu).
- ~~Génération ?~~ **Tranché D17 : au build depuis le manifeste.**

## 3. Risques majeurs

| # | Risque | Impact | Atténuation |
|---|--------|--------|-------------|
| R1 | Sandbox QML infaisable/insuffisant dans Qt | Bloque D1 | Prototyper tôt ; repli « palette + mémoire » ; démarrer en exécution locale arbitrée par l'hôte |
| R2 | RCE inter-joueurs via QML répliqué | Critique | Exécution hôte par défaut ; activation pair par artefact après R1 + revalidation |
| R3 | Canal local détourné par un autre process | Élevé | Token de session + loopback strict |
| R4 | Sérialisation cassée du blob mémoire | Moyen | Passer `toJSON` du blob par `QJsonDocument` (doc 05 §3) |
| R5 | Dérive skill ↔ capacités réelles | Moyen | Générer la skill depuis le manifeste versionné du canal (source unique) ; MCP = patron uniquement |
| R6 | Complexité multi-joueurs des règles custom | Moyen | Différé (D3) ; concevoir avec host-authoritative en tête |
| R7 | Confiance excédentaire dans l'arbitre (jugement faillible pris pour un garde-fou dur) | Élevé | Sécurité dure = sandbox + validateurs ; l'arbitre n'affine que le contextuel (doc 00 §9) |
| R8 | Arbitrage LLM par action : latence/coût dégradant l'UX collab | Moyen | Grain à cadrer (D6) : arbitrer par lot / seulement le QML génératif ; fallback mécanique |
| R9 | Flux mémoire saturant la bande passante ou rejouant des états obsolètes | Moyen | Delta/coalescence + plafond ; mesurer cadence et reliable/raw (D7) |
| R10 | Undo d'un artefact écrasant un état concurrent | Élevé | Séparer config/runtime ; inverse ciblé par write-set, jamais snapshot global |
| R11 | Boucle JS bloquant le GUI malgré `destroy()` | Critique | Prototype d'isolation préemptive ; processus séparé ou repli DSL/capacités |
| R12 | Règles acceptées mais non exécutables/rejouables | Élevé | Matérialiser chaque règle acceptée dans une forme versionnée et validée |
| R13 | Faux sentiment de fiabilité lié au nom `reliable.io` | Critique | ACK/retry/déduplication applicatifs pour commits ; séquence + resync pour état |
| R14 | Transaction V2 groupée prise pour un commit atomique | Élevé | Prévalidation, staging, commit/rollback V3 et ACK de résultat |
| R15 | Migration d'hôte sans contexte d'arbitre/règles/runtime | Élevé | Checkpoint versionné transférable avant reprise des propositions |
| R16 | Checksum SHA-256 pris pour une signature officielle | Élevé | Signature asymétrique, clé éditeur embarquée et rotation/révocation |

## 4. Séquencement suggéré (non engageant)

Le découpage technique détaillé, les fichiers d'ancrage et critères d'acceptation
sont définis dans le doc 10, chantiers **M1→M13**.

1. **Prototype sandbox QML** (R1) — dé-risque D1 avant tout le reste.
2. **Couche réseau V3** : ACK applicatif/retry/déduplication et transaction
   prepare/commit/rollback, avant de lui confier propositions et verdicts.
3. **Canal MCP minimal** (D20) : passerelle + tools d'introspection/pose,
   rôles/tokens injectés, version, enveloppe de proposition auditée.
4. **Espace mémoire** : modèle `config/state`, puis bus runtime et undo ciblé.
5. **Adaptateur agents** : supervision `claude -p`/Codex + skill générée au build.
6. **Vertical slice règles/runtime** avec modules, artefact et arbitrage.
7. **Bibliothèque officielle GLB** sur le launcher/asset_server audité.
