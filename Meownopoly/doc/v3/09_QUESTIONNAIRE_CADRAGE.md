# 09 — Questionnaire de cadrage V3 (questions ouvertes)

> **Statut : épuré le 2026-07-12, questions restantes détaillées le 2026-07-12.**
> Le questionnaire initial a été dépouillé et ses arbitrages reportés dans le
> doc 08 (**D9→D39**). Ce fichier ne contient plus que les **questions encore
> ouvertes**, chacune détaillée avec son contexte, ses options et une
> **proposition** prête à être validée ou amendée. Les questions tranchées ou
> devenues caduques sont retirées ; la table §0 en garde la trace.

## Mode d'emploi

- **B0** : bloque le choix d'architecture ou la preuve de faisabilité.
- **B1** : nécessaire avant un premier vertical slice multi-joueurs.
- **B2** : peut être différé après le prototype, mais doit rester tracé.
- Chaque question porte désormais une **Proposition** argumentée : valider,
amender ou refuser suffit à la fermer.
- Après remplissage, reporter chaque arbitrage stable dans le doc 08 sous un ID
de décision, puis retirer la question d'ici.
- Les mentions **Vérification stack** renvoient à
`[10_AUDIT_STACK_EXISTANTE.md](./10_AUDIT_STACK_EXISTANTE.md)`.

---



## 0. Questions retirées (traçabilité)


| Questions                                                                                                                                       | Sort                                                                                                                                                                                                                                | Décision                                           |
| ----------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| A02→A08 (arbitre solo, mode classique, entrée auto, modif en cours, liberté MVP, cible, plateformes)                                            | tranchées                                                                                                                                                                                                                           | **D9**                                             |
| B01→B03, B05→B08 (instances isolées, fournisseurs, supervision, panne/migration, budget, visibilité règles, changement d'arbitre)               | tranchées                                                                                                                                                                                                                           | **D10**                                            |
| C02→C05 (enveloppe, amendement immédiat, persistance verdict, ordre de contrôle)                                                                | tranchées                                                                                                                                                                                                                           | **D11**                                            |
| C10→C12 (tour, GameplayModuleManager, application d'un effet partagé)                                                                           | tranchées                                                                                                                                                                                                                           | **D12 / D16**                                      |
| C09 (anti-boucle : profondeur + file + cycles, tous requis)                                                                                     | tranchée                                                                                                                                                                                                                            | **D12**                                            |
| D01→D03, D07→D10 (niveau d'isolation, lieu d'exécution, repli, revue humaine, menace, artefacts disque, tests R1)                               | tranchées (conditionnel R1)                                                                                                                                                                                                         | **D13**                                            |
| E01, E04, E05, E07, E09 (canal multiplexé, version globale, adaptateur d'événements, tout-ou-rien, automation.raw dev-only)                     | tranchées                                                                                                                                                                                                                           | **D14** (transport révisé par **D20** : MCP local) |
| F01, F03, F04, F08, F09, F11 (namespaces config/state, portée tuiles+session+joueurs, bus générique, séquencement hôte/LWW, write-set, signaux) | tranchées                                                                                                                                                                                                                           | **D15**                                            |
| G01→G05 (source → hôte, exécution par propriété, identité UUID+hash, store map+séparé, artefact manquant)                                       | tranchées                                                                                                                                                                                                                           | **D16**                                            |
| H01, H03, H05→H07 (Codex+Claude, manifeste source de vérité, génération au build, skill obsolète, catalogue curé)                               | tranchées                                                                                                                                                                                                                           | **D17**                                            |
| H04 (emplacement d'installation de la skill)                                                                                                    | caduque : skill embarquée dans l'app, injectée en pré-prompt à l'invocation ingame                                                                                                                                                  | précision **D17** (2026-07-12)                     |
| E02, E03 (découverte du secret, authentification locale)                                                                                        | tranchées par construction : l'app spawne l'agent et lui injecte config MCP + token éphémère ; tokens/capacités distincts par rôle                                                                                                  | **D20** (2026-07-12)                               |
| H02 (comment l'agent atteint le canal)                                                                                                          | tranchée : connecteur MCP natif de `claude -p`/Codex, config injectée au spawn                                                                                                                                                      | **D20** (2026-07-12)                               |
| I01→I03, I06, I07 (bibliothèque locale officielle, asset_server réutilisé, GLB, imports devs)                                                   | tranchées                                                                                                                                                                                                                           | **D18**                                            |
| I08 (référencement d'un asset)                                                                                                                  | tranchée dans son principe : clés existantes + version/hash                                                                                                                                                                         | **D16/D18**                                        |
| J01 (journal configurable, noyau d'audit non désactivable)                                                                                      | tranchée (rétention → Q-J02)                                                                                                                                                                                                        | **D19**                                            |
| E11 (forme d'intégration du serveur MCP)                                                                                                        | tranchée : streamable HTTP loopback **intégré au jeu** (les deux CLIs le supportent nativement, vérifié 2026-07-12 ; `QtHttpServer` à installer ; repli pont stdio documenté)                                                       | **D21** (2026-07-12)                               |
| E10 (politique de capture d'écran)                                                                                                              | tranchée : écran de jeu à la demande de l'IA, plafond par requête via `#define` (défaut 5), rétention éphémère (quelques tours), aucun masquage, information une fois au lancement                                                  | **D22** (2026-07-12)                               |
| **A01 (ordre de livraison des trois modes)**                                                                                                    | **tranchée** : éditeur solo → collaboratif → runtime                                                                                                                                                                                | **D23** (2026-07-12)                               |
| **B04 — principe (preuve qu'un arbitre est prêt)**                                                                                              | **tranchée** : handshake de rôle sur le canal + challenge de capacité ; **l'UX du prérequis reste ci-dessous**                                                                                                                      | **D24** (2026-07-12)                               |
| **C01 (unité déclenchant un appel arbitre)**                                                                                                    | **tranchée** : grain **configurable par UI** (types de requêtes soumis à l'arbitre) ; plancher proposé sur code/règles, défaut hybride                                                                                              | **D25** (2026-07-12)                               |
| **Note section D (nature de la sandbox)**                                                                                                       | **tranchée** : la sandbox de validation est un **banc d'essai hors-process** (moteur/process distincts, réinstancie la carte depuis un snapshot, détecte non-chargement/boucle infinie) ; D13 recentré sur le confinement en partie | **D26** (2026-07-12)                               |
| **F02 (persistance de l'état runtime)**                                                                                                         | **tranchée** : sauvegarde de partie **distincte** de la map                                                                                                                                                                         | **D27** (2026-07-12)                               |
| **F10 (undo sur valeur modifiée depuis)**                                                                                                       | **tranchée** : **restaure malgré tout** (LWW assumé, R10 accepté, trace au journal)                                                                                                                                                 | **D28** (2026-07-12)                               |
| **I04 — principe (format de package)**                                                                                                          | **tranchée dans son principe** : même format que l'`AssetManager`/asset_server, étendu ; **les champs exacts restent ci-dessous**                                                                                                   | **D29** (2026-07-12)                               |
| **J05 (scénarios du vertical slice)**                                                                                                           | **tranchée** : slice solo S1/S2/S3, défini dans `[11_VERTICAL_SLICE.md](./11_VERTICAL_SLICE.md)`                                                                                                                                    | **D30** (2026-07-12)                               |
| **B04 — reste (UX du prérequis arbitre)**                                                                                                       | **tranchée** : proposition validée telle quelle (indicateur 4 états, bouton grisé hors `Prêt`, test manuel + auto, bandeau + file si l'arbitre meurt)                                                                               | **D31** (2026-07-12)                               |
| **C06 (qui choisit/valide la forme exécutable)**                                                                                                | **tranchée** : sélection mécanique d'abord, arbitre confirme/rétrograde ; **un élément amendé par l'arbitre repasse par la sandbox de validation (banc D26)**                                                                       | **D32** (2026-07-12)                               |
| **C08 — restes (autorité/ordre des événements)**                                                                                                | **tranchée** : **autorité par source** (tout passe par l'hôte), ordre déterministe physique → mémoire → actions → tick via la file D12                                                                                              | **D33** (2026-07-12)                               |
| **D04, D05, D06 (allow-list, façade** `Meow.GameApi`**, budgets)**                                                                              | **tranchées** : propositions validées, allow-list **élargie à** `QtQuick.Controls` **+ modules QML custom existants** (ex. `SnapableElement` surchargés, liste énumérée dans le manifeste)                                          | **D34** (2026-07-12)                               |
| **F05, F06, F07 (delta/snapshot, garanties réseau, plafonds du bus)**                                                                           | **tranchées** : delta 30 Hz + snapshot de réparation + snapshot structurel + resync à la demande ; hybride commits ACK/retry/dédup vs état supersedable séquencé ; plafonds chiffrés, rejet `quota_exceeded`                        | **D35** (2026-07-12)                               |
| **G06 (artefact attaché à plusieurs tuiles)**                                                                                                   | **tranchée** : store par hash + références `{hash, version}`, refcount, GC au save, migration référence par référence                                                                                                               | **D36** (2026-07-12)                               |
| **G07 (transfert au changement d'hôte)**                                                                                                        | **tranchée** : checkpoint règlement + hashes artefacts + snapshot `state` (bloquants) + contexte arbitre (best-effort) ; propositions suspendues jusqu'au handshake D24 + ACK du checkpoint                                          | **D37** (2026-07-12)                               |
| **I04 — reste (champs du manifeste de package)**                                                                                                | **tranchée** : champs étendus validés (identité/métadonnées/contenu/dépendances/confiance/compat)                                                                                                                                   | **D38** (2026-07-12)                               |
| **I05 (modèle de confiance de la bibliothèque)**                                                                                                | **différée explicitement** : « on verra plus tard la sécurisation de la bibliothèque » ; champs `signature`/`publisherKeyId` réservés, R16 à régler avant tout contenu communautaire                                                | **D38** (2026-07-12)                               |
| **I09 (budgets assets)**                                                                                                                        | **tranchée provisoirement** : valeurs de départ acceptées, à confirmer à l'implémentation avec un premier package d'asset de test                                                                                                   | **D38** (2026-07-12)                               |
| **J03 (diagnostic de divergence entre pairs)**                                                                                                  | **tranchée** : hash périodique du `state` diffusé avec le snapshot de réparation + `RequestStateSnapshot` en cas de divergence                                                                                                      | **D39** (2026-07-12)                               |




---



## E. Canal local : événements et catalogue



### Q-E06 — Sémantique du résumé d'événements injecté et du curseur `events_poll` — **B1**

À spécifier : schéma du résumé, garanties du curseur, filtrage par rôle.

**Proposition.**

- **Curseur = séquence monotone du journal métier hôte** (D19). Chaque entrée :
`{seq, ts, type, actor, summary, refs}` (`refs` = uuids touchés).
- **Résumé injecté par invocation** : l'app génère un bloc compact
« depuis ton dernier tour (seq N→M) : X tuiles posées (par qui), Y verdicts
(accepté/rejeté + raison courte), Z changements d'état pertinents », plafonné
(ex. 30 lignes) avec mention explicite `+ K événements omis — events_poll(N)`.
- **Garanties du curseur** : relecture idempotente depuis n'importe quel `seq`
conservé ; si le journal est tronqué en deçà du curseur demandé, réponse
`{truncated: true, oldestSeq}` → l'agent resynchronise par `state_query`
(état courant) au lieu de rejouer l'historique.
- **Filtrage par rôle** : le proposant voit les événements « publics » de la
partie ; l'arbitre voit en plus les propositions en file et les
amendements. Filtrage fait côté serveur MCP (capacités du token, D20).
- **Réponse :**



### Q-E08 — Sous-ensemble exact des tools portés au MVP — **B1**

Familles retenues (doc 02 §5). **Proposition de manifeste MVP — 10 tools** :


| Tool                                                        | Rôle                                                                            | Regroupe                                                      |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `help(topic)`                                               | divulgation progressive de la doc détaillée                                     | —                                                             |
| `state_query(what, filter?, cursor?)`                       | lecture : `tiles`, `tile`, `enums`, `roster`, `players`, `rules`, `memory`      | listTiles/getTile/enum/roster/getMemory                       |
| `editor_place(kind, params)`                                | pose : asset/case/zone/NPC/ennemi/caisse                                        | placeAsset/placeCase/placeZone/placeNPC/placeEnemy/placeCrate |
| `editor_edit(uuid, op, params)`                             | édition d'existant : move/resize/delete/link/set_param/set_trigger/set_dialogue | moveTile/resizeTile/deleteTile/setZoneTrigger/setNpcDialogue  |
| `memory_set(scope, uuid?, key, value)`                      | écriture mémoire `config` (pipeline édition)                                    | setMemory                                                     |
| `roster_edit(op, params)`                                   | profils joueurs + min/max                                                       | ops collab 12-16                                              |
| `artifact_submit(source, target?, meta)`                    | soumission d'un artefact QML/JS → enveloppe de proposition (D11)                | qml.instantiate                                               |
| `events_poll(cursor)`                                       | resynchronisation en cours de tâche                                             | —                                                             |
| `screenshot(view?)`                                         | retour visuel (plafond D22)                                                     | —                                                             |
| `arbiter_verdict(proposalId, verdict, reasons, amendment?)` | **token arbitre uniquement**                                                    | —                                                             |


- **Post-MVP** (hors manifeste v1) : `runtime_input` (piloter joueur/NPC),
`save_map`, tools caméra (`editor_camera`) — utiles mais non requis par le
vertical slice.
- Le groupement exact reste à **mesurer** sur les premiers workflows
(tokens des schémas vs ambiguïté, doc 02 §3).
- **Sous-ensemble retenu :**

---



## J. Observabilité et sortie du cadrage



### Q-J02 — Politique de stockage/effacement des données privées — **B1**

Prompts (tchat ingame), sources générées et identifiants fournisseur peuvent
contenir des données privées. Le noyau d'audit D19 est non désactivable.
*(Les captures d'écran sont réglées par D22 : rétention éphémère de quelques
tours d'IA, aucun masquage, information une fois au lancement.)*

**Proposition.**

- **Tout reste local** : aucun prompt/source/journal n'est envoyé à un serveur
du projet (les fournisseurs LLM voient évidemment les prompts — c'est couvert
par l'information au lancement, D22).
- **Rétention** : journal d'audit conservé **avec la sauvegarde de partie**
(D27) tant que la partie existe ; purge à la suppression de la partie.
Prompts du tchat hors noyau d'audit : purgés à la fin de session.
- **Identifiants fournisseur** (clés API/config CLI) : jamais copiés dans les
logs ni le journal ; ils restent dans la config de l'agent du joueur.
- **Export** : un bouton d'export du journal (D19) pour debug/partage,
action explicite du joueur uniquement.
- **Réponse :**



### Q-J04 — Quels indicateurs mesurent la qualité de l'arbitrage ? — **B2**

**Proposition de tableau de bord initial** (mesuré dès le vertical slice,
cibles à recaler ensuite) :

- **Latence** : p50 < 5 s, p95 < 15 s entre soumission et verdict (risque R8).
- **Taux** : acceptation / rejet / amendement par session (pas de « bonne »
valeur a priori ; sert à détecter un arbitre trop laxiste ou bloquant).
- **Rollback post-acceptation** : < 5 % des propositions acceptées annulées
ensuite (banc d'essai D26 devrait tendre vers ~0 les échecs techniques).
- **Coût** : tokens par proposition arbitrée, budget par session (config D10).
- **Réponse :**



### Q-J06 — Quels critères font abandonner ou réduire D1 ? — **B0**

**Proposition de critères de sortie** (à évaluer à la fin du prototype R1
recentré par D26) :

- **Échec d'isolation** : si, même **hors-process** (banc d'essai D26), on ne
sait pas produire un verdict fiable (faux positifs massifs, comportements
non reproductibles au banc) **ou** si le confinement runtime (contexte
restreint, masquage des singletons) est contournable trivialement → repli.
- **Budget performance** : si un artefact validé ne peut être exécuté en
partie sous les budgets Q-D06 (tick > 0,5 ms systématique) → réduire à
la config de modules + DSL (pas de JS libre).
- **Complexité multi-joueurs** : si la réplication des effets d'artefacts
rend le collab instable au vertical slice multi → geler le JS embarqué au
mode solo, données seules en multi, le temps d'une itération.
- **Repli choisi** : « palette + mémoire » (D1, alternatives écartées) —
briques + espace mémoire + règles en config/DSL, sans QML génératif.
- **Réponse :**



### Q-J07 — Quel est le prochain document à produire ? — **B1**

- [x] Spécification du prototype sandbox R1 — **fait** :
  ```
  `[12_BANC_ESSAI_R1.md](./12_BANC_ESSAI_R1.md)` (banc d'essai
  hors-process D26 : job/verdict JSON, préfiltre P0 in-game + phases
  P1→P5 au banc, corpus de test,
  critères de sortie R1, pool, cache de verdicts)
  ```
- [x] Plan du vertical slice — **fait** : `[11_VERTICAL_SLICE.md](./11_VERTICAL_SLICE.md)`
- [x] Schéma du protocole/enveloppe de proposition — **fait** :
  ```
  `[13_ENVELOPPE_PROPOSITION.md](./13_ENVELOPPE_PROPOSITION.md)`
  (enveloppe, cycle de vie, verdict à deux audiences, transport, journal)
  ```
- [ ] ADR consolidés supplémentaires

- **Ordre retenu :** spec R1 ✓ → slice ✓ → enveloppe ✓ → les trois documents
de sortie de cadrage sont produits ; la suite est l'**implémentation**
(prototype R1 doc 12, puis chantiers M1/M-adaptateur du slice).



### Q-J08 — Qui valide définitivement chaque famille de décisions ? — **B1**

À répartir entre les deux développeurs (Antoine / Valou) — proposer un
responsable par famille, l'autre relisant :

- **Produit/vision :**
- **Sécurité :**
- **Réseau :**
- **Gameplay/règles :**
- **Bibliothèque/assets :**

---



## Synthèse (état au 2026-07-12)

- **Arbitré (D9→D39)** : périmètre trois modes **livrés solo → collab →
runtime**, arbitre obligatoire partout avec **handshake + challenge** et
**UX de prérequis validée** (4 états, blocage, file de propositions),
grain d'arbitrage **configurable par UI**, **un amendement d'arbitre repasse
par le banc de validation**, événements en **autorité par source** (tout
passe par l'hôte, ordre déterministe), agents `claude -p`/Codex supervisés
et **invoqués in-app via tchat ingame**, sandbox de validation = **banc
d'essai hors-process** (spécifié doc 12) avec **allow-list élargie**
(`QtQuick.Controls` + modules custom énumérés), **façade** `Meow.GameApi` **et
budgets validés**, canal = serveur MCP local en **streamable HTTP intégré au
jeu**, screenshots plafonnés/éphémères/annoncés, mémoire `config`/`state`
avec **sauvegarde de partie distincte**, **undo qui restaure malgré tout** et
**bus d'état complet** (delta 30 Hz + snapshots de réparation/structurel +
resync, garanties hybrides commits/supersedable, plafonds chiffrés, D35),
**divergence détectée par hash périodique + resync** (D39), artefacts sous
autorité hôte avec **cycle de vie multi-tuiles** (store par hash, refcount,
GC au save, D36) et **checkpoint de migration d'hôte** (D37), skill générée
au build et injectée en pré-prompt, bibliothèque locale officielle GLB au
**format asset manager étendu** avec **manifeste de package validé** (D38 ;
sécurisation différée, budgets assets provisoires), journal configurable à
noyau d'audit obligatoire, **vertical slice solo S1/S2/S3 défini (doc 11)**,
**enveloppe de proposition spécifiée (doc 13)**.
- **Encore ouvert — chaque question ci-dessus porte une proposition prête à
valider** : résumé/curseur d'événements (E06), manifeste des tools MVP (E08),
données privées (J02), indicateurs d'arbitrage (J04), critères de repli D1
(J06), responsables par famille (J08).

