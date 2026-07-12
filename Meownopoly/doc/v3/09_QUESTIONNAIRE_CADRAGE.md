# 09 — Questionnaire de cadrage V3 (questions ouvertes)

> **Statut : épuré le 2026-07-12.** Le questionnaire initial a été dépouillé et
> ses arbitrages reportés dans le doc 08 (**D9→D19**). Ce fichier ne contient
> plus que les **questions encore ouvertes**, actualisées avec les décisions et
> la précision « invocation in-app via tchat ingame » (D10/D17). Les questions
> tranchées ou devenues caduques sont retirées ; la table §0 en garde la trace.

## Mode d'emploi

- **B0** : bloque le choix d'architecture ou la preuve de faisabilité.
- **B1** : nécessaire avant un premier vertical slice multi-joueurs.
- **B2** : peut être différé après le prototype, mais doit rester tracé.
- Après remplissage, reporter chaque arbitrage stable dans le doc 08 sous un ID
  de décision, puis retirer la question d'ici.
- Les mentions **Vérification stack** renvoient à
  [`10_AUDIT_STACK_EXISTANTE.md`](./10_AUDIT_STACK_EXISTANTE.md).

---

## 0. Questions retirées (traçabilité)

| Questions | Sort | Décision |
|-----------|------|----------|
| A02→A08 (arbitre solo, mode classique, entrée auto, modif en cours, liberté MVP, cible, plateformes) | tranchées | **D9** |
| B01→B03, B05→B08 (instances isolées, fournisseurs, supervision, panne/migration, budget, visibilité règles, changement d'arbitre) | tranchées | **D10** |
| C02→C05 (enveloppe, amendement immédiat, persistance verdict, ordre de contrôle) | tranchées | **D11** |
| C10→C12 (tour, GameplayModuleManager, application d'un effet partagé) | tranchées | **D12 / D16** |
| C09 (anti-boucle : profondeur + file + cycles, tous requis) | tranchée | **D12** |
| D01→D03, D07→D10 (niveau d'isolation, lieu d'exécution, repli, revue humaine, menace, artefacts disque, tests R1) | tranchées (conditionnel R1) | **D13** |
| E01, E04, E05, E07, E09 (WS multiplexé, version globale, adaptateur d'événements, tout-ou-rien, automation.raw dev-only) | tranchées | **D14** |
| F01, F03, F04, F08, F09, F11 (namespaces config/state, portée tuiles+session+joueurs, bus générique, séquencement hôte/LWW, write-set, signaux) | tranchées | **D15** |
| G01→G05 (source → hôte, exécution par propriété, identité UUID+hash, store map+séparé, artefact manquant) | tranchées | **D16** |
| H01, H03, H05→H07 (Codex+Claude, manifeste source de vérité, génération au build, skill obsolète, catalogue curé) | tranchées | **D17** |
| **H04 (emplacement d'installation de la skill)** | **caduque** : skill embarquée dans l'app, injectée en pré-prompt à l'invocation ingame | précision **D17** (2026-07-12) |
| I01→I03, I06, I07 (bibliothèque locale officielle, asset_server réutilisé, GLB, imports devs) | tranchées | **D18** |
| I08 (référencement d'un asset) | tranchée dans son principe : clés existantes + version/hash | **D16/D18** |
| J01 (journal configurable, noyau d'audit non désactivable) | tranchée (rétention → Q-J02) | **D19** |

---

## A. Produit et périmètre

### Q-A01 — Dans quel ordre livrer les trois modes V3 ? — **B0**

Le périmètre est tranché (D9 : éditeur solo assisté, éditeur collaboratif,
partie runtime co-construite — tous avec les deux rôles IA). Seul l'**ordre de
livraison** reste ouvert (les trois avaient été cochés « premier mode »).

- [ ] Éditeur solo → collaboratif → runtime (recommandation actuelle)
- [ ] Éditeur collaboratif d'abord (valide l'arbitrage réseau tôt)
- [ ] Vertical slice traversant (mince mais couvrant éditeur puis runtime)

- **Réponse :**
- **Pourquoi / contraintes :**

---

## B. Arbitre : disponibilité et UX du prérequis

### Q-B04 — Comment le jeu prouve-t-il qu'un arbitre est prêt ? — **B0**

La configuration collective (prompt/personnalité, budget) est tranchée (D10).
Reste la **preuve technique de disponibilité** : le mode IA doit être bloqué
tant qu'aucun arbitre fonctionnel n'est branché (D6), et l'app invoque
elle-même les modèles (tchat ingame) — elle peut donc tester avant de lancer.

- [ ] Handshake de rôle sur le canal + challenge de capacité
- [ ] Test de santé : verdict sur une proposition factice au démarrage
- [ ] Les deux (handshake puis health-check)

- **UX du prérequis** (comment le lobby exige/affiche l'état de l'arbitre) :
- **Réponse :**

---

## C. Arbitrage et règles

### Q-C01 — Quelle unité déclenche un appel à l'arbitre ? — **B0**

Le flux est tranché (D11 : préfiltre mécanique → arbitre → validation complète
→ exécution). Reste le **grain** — coût/latence d'un appel LLM par action
(risque R8).

- [ ] **Chaque commande**
- [ ] **Une proposition complète** (lot atomique)
- [ ] **Le code uniquement** (les données passent en validation mécanique)
- [ ] **Politique hybride** : données sûres groupées, code/règles toujours arbitrés

- **Recommandation actuelle :** transaction typée, avec chemin rapide mécanique.
- **Réponse :**

### Q-C06 — Affiner la hiérarchie des formes exécutables — **B1**

L'orientation est tranchée (D12 : plan de capacités → config de modules →
DSL/machine à états → QML/JS sandboxé, forme la moins libre suffisante).
À affiner : **qui choisit la forme** (arbitre ? validateur ?), critères de
sélection, et qui compile/valide chaque forme (doc 06 §4).

- **Réponse :**

### Q-C08 — Quels événements runtime peuvent déclencher une règle ? — **B1**

- **Liste des événements** (collision, entrée de zone, écriture mémoire, tick,
  action joueur…) :
- **Autorité de chaque événement :**
- **Ordre/priorité en cas d'événements simultanés :**

---

## D. Sandbox : contenu exact (structure tranchée D13, conditionnelle R1)

### Q-D04 — Quelle allow-list d'imports/types/fonctions au MVP ? — **B0**

- **Imports autorisés :**
- **Types autorisés :**
- **Fonctions globales interdites :**

### Q-D05 — Liste exacte de la façade « API de jeu » exposée au code — **B0**

Orientation tranchée : mémoire + événements + animations + capacités gameplay
sélectionnées. Reste la **liste exacte** (doc 04 §3.3).

- **Liste :**

### Q-D06 — Quels budgets impose-t-on ? — **B1** *(à affiner en test)*

- **Taille source/artefact :**
- **CPU par événement/tick :**
- **Mémoire :**
- **Nombre d'objets :**
- **Débit d'événements :**

---

## E. Canal local : auth, secret, garanties

### Q-E02 — Comment le secret du canal est-il découvert ? — **B1**

Le port peut réutiliser le patron automation (`--port`/variable d'env). La
stack ne fournit **aucun** mécanisme de secret. Nuance nouvelle : comme l'app
**invoque elle-même** les agents (tchat ingame, D10), elle peut leur passer le
secret directement (argument/env du process enfant) — la découverte « par un
agent externe arbitraire » n'est plus le cas nominal.

- [ ] Injection directe par l'app au lancement du process agent (env/argument)
- [ ] Fichier runtime à permissions utilisateur
- [ ] Port fixe + token affiché/copié (cas de secours/debug)

- **Réponse :**

### Q-E03 — Quel mécanisme d'authentification locale ? — **B0**

La stack n'offre que le loopback — insuffisant pour un canal qui exécute à
terme du QML (risque R3). Il faut aussi distinguer les **deux identités
locales de l'hôte** (proposant vs arbitre), avec des capacités différentes.

- [ ] Token éphémère par lancement + rôle au handshake (recommandation)
- [ ] Token persistant par installation
- [ ] Challenge/réponse lié au rôle

- **Réponse :**

### Q-E06 — Quelles garanties de livraison des événements poussés ? — **B1**

`reliable.io` acquitte et fragmente mais **ne retransmet pas** (R13). Les
garanties V3 exigent une couche applicative.

- [ ] Au plus une fois
- [ ] Au moins une fois + identifiant/déduplication
- [ ] Relecture depuis un curseur/journal

- **Réponse :**

### Q-E08 — Sous-ensemble exact des commandes portées au MVP — **B1** *(à affiner)*

Familles retenues : `state.listTiles/getTile`, pose/édition par UUID, mémoire
config/runtime, `qml.instantiate`, screenshot, runtime joueur/NPC,
roster/modules. Reste à figer la **liste commande par commande** dans le
manifeste du canal (doc 02 §4).

- **Sous-ensemble retenu :**

### Q-E10 — Quelle politique de capture d'écran ? — **B2**

- **Fréquence/résolution maximales :**
- **Éléments privés à masquer :**
- **Consentement utilisateur :**

---

## F. Mémoire et réseau runtime

### Q-F02 — Où persiste l'état runtime pour une reprise de partie ? — **B0**

Deux options avaient été cochées (contradictoires). La sauvegarde actuelle ne
contient que `mapInfo` + `snapableTiles` ; aucun format de sauvegarde runtime
n'existe.

- [ ] Sauvegarde de partie **distincte** de la map (recommandation)
- [ ] Directement dans le fichier map

- **Réponse :**

### Q-F05 — Spécifier la stratégie delta/snapshot — **B0**

Orientation donnée : delta sur modification courante, snapshot sur ajout
d'item. Mais aucun snapshot de **réparation** ne répare aujourd'hui un delta
perdu. À spécifier : coalescence, déclencheurs de snapshot, resync.

- **Réponse :**

### Q-F06 — Confirmer le modèle hybride reliable/supersedable — **B0**

Le chemin nommé `reliable` ne retransmet pas (R13). Modèle cohérent avec D15 :
**intentions/commits** avec ACK applicatif + retry ; **état supersedable** avec
séquence + snapshot de réparation. À confirmer et spécifier.

- **Réponse :**

### Q-F07 — Cadence et plafonds du bus d'état ? — **B1** *(à affiner en test)*

- **Cadence maximale :**
- **Taille max par valeur/tuile/session :**
- **Budget bande passante par pair :**
- **Politique de dépassement :**

### Q-F10 — Que fait undo si une valeur durable a changé depuis ? — **B0**

- [ ] Refuse et signale un conflit
- [ ] Restaure malgré tout
- [ ] Compensation conditionnelle par version (recommandation, sinon conflit)

- **Réponse :**

---

## G. Artefacts : cycle de vie et migration

### Q-G06 — Cycle de vie d'un artefact attaché à plusieurs tuiles ? — **B1**

- **Ownership/références :**
- **Suppression :**
- **Mise à jour/migration :**

### Q-G07 — Que transfère-t-on lors d'un changement d'hôte ? — **B0**

L'élection/promotion éditeur existe (Phase 8) mais ne transfère ni règlement,
ni artefacts, ni état runtime, ni contexte d'arbitre (R15). D10 exige la
migration d'arbitre avec état/version.

- **État du règlement transféré :**
- **Artefacts/hashes transférés :**
- **État runtime/checkpoint transféré :**
- **Nouvel arbitre requis avant reprise :**

---

## H. Skill et connexion de l'agent

### Q-H02 — Comment l'agent invoqué in-app atteint-il le canal WS ? — **B1**

Reformulée après la précision « tchat ingame » (D10/D17) : l'app invoque le
modèle et le pré-prompte avec la skill ; il n'y a plus d'installation côté
agent (ex-H04 caduque). Reste le **mécanisme de connexion** de l'agent au canal.

- [ ] Tool/CLI de connexion fourni par l'app (invoqué par l'agent)
- [ ] WS brut, protocole documenté dans le pré-prompt
- [ ] Connecteur natif propre à chaque agent (MCP local, etc.)

- **Recommandation actuelle :** tool/adaptateur livré, protocole documenté.
- **Réponse :**

---

## I. Bibliothèque : format et confiance

### Q-I04 — Quel format de package commun ? — **B1**

- **Manifeste/métadonnées :**
- **Données/config :**
- **Code éventuel :**
- **Dépendances/assets :**
- **Signature/hash :**

### Q-I05 — Quel modèle de confiance ? — **B0**

Au premier jalon la bibliothèque est locale/officielle (D18), mais la chaîne de
signature n'existe pas (R16 : le SHA-256 du launcher vérifie l'intégrité, pas
l'identité de l'éditeur).

- [ ] Officiel signé + communautaire revalidé
- [ ] Tout revalider, signature informative
- [ ] Modération serveur avant publication
- [ ] Combinaison :

- **Réponse :**

### Q-I09 — Quels budgets pour les assets ? — **B1**

- **Triangles/mesh :**
- **Textures/résolution :**
- **Taille disque/réseau :**
- **Animations/materials autorisés :**

---

## J. Observabilité et sortie du cadrage

### Q-J02 — Politique de stockage/effacement des données privées — **B1**

Dès que le canal/journal existe, prompts (tchat ingame), captures, sources
générées et identifiants fournisseur peuvent contenir des données privées. Le
noyau d'audit D19 est non désactivable : sa rétention et sa confidentialité
doivent être définies ici.

- **Politique de stockage/effacement :**
- **Durée/rétention du journal d'audit :**

### Q-J03 — Comment diagnostiquer une divergence entre pairs ? — **B1**

Le full-sync éditeur et les snapshots physiques **réparent** mais ne
**détectent** pas une divergence. Il manque au minimum hash/version d'état et
demande explicite de resync.

- [ ] Hash périodique d'état + resync
- [ ] Journal d'événements rejouable
- [ ] Snapshot autoritatif à la demande

- **Réponse :**

### Q-J04 — Quels indicateurs mesurent la qualité de l'arbitrage ? — **B2** *(à affiner selon test)*

- **Latence cible :**
- **Taux d'acceptation/rejet/amendement :**
- **Taux de rollback/erreur après acceptation :**
- **Coût cible :**

### Q-J05 — Quels scénarios end-to-end valident le vertical slice ? — **B0**

Critère produit déjà posé (D9/A06) : création d'un item qui modifie le
gameplay, la physique, d'autres éléments et les interactions joueur.

- [ ] Création solo d'un élément avec config + comportement
- [ ] Proposition cliente arbitrée puis appliquée par l'hôte
- [ ] Rejet actionnable et itération
- [ ] Undo ciblé sans écraser l'état concurrent
- [ ] Reconnexion/resync
- [ ] Migration d'hôte/arbitre
- [ ] Chargement d'une sauvegarde avec artefacts

- **Scénarios retenus :**

### Q-J06 — Quels critères font abandonner ou réduire D1 ? — **B0**

- **Échec d'isolation :**
- **Budget performance dépassé :**
- **Complexité multi-joueurs excessive :**
- **Repli choisi :**

### Q-J07 — Quel est le prochain document à produire ? — **B1**

- [ ] Spécification du prototype sandbox R1
- [ ] Schéma du protocole/enveloppe de proposition
- [ ] Plan du vertical slice
- [ ] ADR consolidés supplémentaires

- **Ordre retenu :**

### Q-J08 — Qui valide définitivement chaque famille de décisions ? — **B1**

- **Produit/vision :**
- **Sécurité :**
- **Réseau :**
- **Gameplay/règles :**
- **Bibliothèque/assets :**

---

## Synthèse (état au 2026-07-12)

- **Arbitré (D9→D19)** : périmètre trois modes, arbitre obligatoire partout,
  agents `claude -p`/Codex supervisés et **invoqués in-app via tchat ingame**,
  proposition auditable avec amendement immédiat, règles hiérarchiques,
  sandbox in-process conditionnel à R1, un WS multiplexé, mémoire
  `config`/`state` sur tuiles+session+joueurs, artefacts sous autorité hôte,
  skill générée au build et **injectée en pré-prompt**, bibliothèque locale
  officielle GLB, journal configurable à noyau d'audit obligatoire.
- **Encore bloqué par un prototype ou un choix** : grain d'arbitrage (C01),
  sandbox R1 (contenu D04-D06), auth/secret du canal (E02/E03), garanties
  réseau (E06/F06), sauvegarde runtime (F02), stratégie delta/snapshot (F05),
  undo concurrent (F10), migration complète (G07), connexion de l'agent (H02),
  signature/confiance (I05), scénarios du vertical slice (J05).
