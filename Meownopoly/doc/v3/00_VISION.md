# 00 — Vision V3

> **Statut : cadrage (draft).**

## 1. Point de départ

Meownopoly V2 est un jeu de plateau en réseau (Qt6/QML + C++20) avec un éditeur
de map riche, un moteur physique maison (Pattounx v2), du P2P UDP et un éditeur
collaboratif host-authoritative. Le contenu d'une partie est produit par des
humains via l'UI de l'éditeur.

Le projet dispose déjà d'un fait technique décisif : **une couche d'automation**
(`AutomationServer` + hooks `editorAutomationHooks` + MCP `automation_mcp/`) qui
prouve qu'un agent externe peut piloter le jeu par WebSocket JSON — poser des
éléments, bouger la caméra, sauvegarder — **par le chemin UI exact**, donc
compatible collab/undo.

## 2. La bascule V3

V3 fait passer l'IA de **outil de développement** à **acteur de jeu de premier
plan**. Le contenu et une partie des règles ne sont plus seulement produits par
des humains dans une UI, mais **négociés en langage naturel entre un joueur et
son IA**, qui matérialise le résultat en direct dans le jeu.

**Le but central : créer le gameplay de façon très libre.** Les IA n'ajoutent pas
que du décor — elles **créent le gameplay lui-même**, en **embarquant du code JS
dans les éléments qu'elles génèrent** (comportements, événements, règles locales).
Le jeu n'est pas figé au départ : il **se construit au fur et à mesure, grâce aux
utilisateurs** et à leurs IA. Ce n'est possible que parce que la **stack technique
de l'éditeur** fournit déjà le traitement et le **partage des actions** (collab
host-authoritative) au-dessus de **briques graphiques et gameplay préexistantes**
que les IA **composent** — elles ne repartent pas de zéro à chaque fois.

Quatre idées portent le pivot :

1. **« Son IA » — modèle fourni côté client, invoqué depuis le jeu.** Chaque
   joueur branche son propre modèle (Claude, un agent local, etc.). Le jeu ne
   fournit pas l'IA ; il fournit le **point d'entrée** (canal MCP local, doc 02),
   le **mode d'emploi** (skill embarquée, doc 03) et l'**interface** : un **tchat
   ingame** depuis lequel les IA sont **invoquées directement par l'application**
   (D10/D17) — le joueur n'exécute jamais les features depuis un CLI à part.
   À chaque invocation, l'app **pré-prompte** le modèle avec les workflows des
   skills internes. L'intelligence vit côté client ; le jeu expose une surface
   d'interaction et des garde-fous.

2. **Le QML/JS interprété comme substrat vivant, les briques préexistantes comme
   vocabulaire.** Contrairement au C++ compilé, le QML (et le JS qu'il embarque)
   est chargé et interprété au runtime. C'est ce qui rend crédible l'idée
   d'**ajouter des éléments et surtout des comportements « à la volée »** pendant
   une session, sans recompiler ni redéployer. Le mécanisme concret : l'IA
   **compose les briques graphiques et gameplay déjà fournies** (éléments posables,
   modules de jeu activables) **et y injecte du code JS** pour le comportement
   nouveau. Elle produit du vrai code chargé en direct (décision **D1**, cf.
   doc 04), mais adossé à un vocabulaire de briques validées plutôt que généré
   intégralement de zéro (cf. bibliothèque, doc 07). Ce vocabulaire graphique a
   vocation à s'**élargir massivement** : une **bibliothèque d'assets 3D** est
   **prévue au développement** pour offrir aux IA un **large éventail de
   possibilités** de matérialisation — modèles et objets 3D piochables et
   composables — sans que chaque forme visuelle ait à être générée de zéro
   (cf. doc 07 §1).

3. **Liberté par joueur, partie co-construite.** L'objectif final est que chaque
   joueur, à travers son IA, puisse **construire une partie selon ses propres
   règles** : ajouter des éléments, leur donner des comportements (JS embarqué), et
   à terme redéfinir des règles de jeu. Le jeu devient moins « un plateau figé » et
   plus « un bac à sable négociable » qui **s'enrichit progressivement au fil des
   contributions** des joueurs et de leurs IA.

4. **Deux rôles d'IA : cliente (proposante) et arbitre (MJ) — l'arbitre est
   obligatoire.** L'IA n'est pas un acteur unique. Une IA **cliente** propose du
   contenu (éléments + JS) ; une IA **arbitre / MJ**, chez l'hôte, en vérifie la
   viabilité avant qu'il n'entre dans la partie. Cet arbitrage de la partie
   partagée n'est **pas optionnel** : **sans arbitre branché chez l'hôte, le mode
   piloté par IA ne fonctionne pas**. Ce caractère obligatoire relève de la
   gouvernance produit ; la sécurité du code reste entièrement à la charge des
   contrôles mécaniques. Détail en §4.

## 3. Boucle d'usage cible

```
Joueur ──(tchat ingame)──▶ Son IA ──(tools MCP, canal local)──▶ Meownopoly
   ▲     (invoquée par l'app,                                         │
   │      pré-promptée skills)                                        │
   └──────────────── observe le résultat en jeu / itère ◀────────────┘
```

Le dialogue joueur↔IA se fait **dans le jeu** (tchat ingame) : c'est
l'application qui invoque le modèle et lui injecte la skill en pré-prompt
(D10/D17), pas le joueur depuis un terminal.

Cette boucle est vue côté **proposant**. En multi-joueurs, une proposition n'est
introduite dans la partie qu'après passage par l'**arbitre** de l'hôte (§4).
Après préfiltre, acceptation/amendement de l'arbitre et validation mécanique, elle
est appliquée automatiquement : aucune revue humaine n'est requise. Les créations
peuvent faire évoluer une partie déjà commencée.

Exemple concret visé (éditeur) :
> « Mets une rivière qui traverse la carte du nord au sud, avec un pont au
> centre, et fais que les cases au bord de l'eau rapportent double loyer. »

L'IA traduit cette intention en une séquence d'actions sur le canal : poser des
zones/décorations, lier des cases, écrire l'espace mémoire des cases concernées
(« bonus loyer ×2 »), et — pour ce qui n'existe pas encore comme primitive —
générer du QML de comportement chargé à la volée.

## 4. Deux rôles d'IA : cliente (proposante) et arbitre (MJ)

L'IA n'est pas un acteur unique et indifférencié. Le pivot distingue **deux
rôles**, répartis selon la topologie host-authoritative existante :

- **L'IA cliente (proposante).** Présente chez **chaque** joueur, hôte compris —
  c'est le même rôle partout. À partir du langage naturel du joueur, elle
  **produit** des propositions : nouveaux éléments, événements, artefacts QML à
  charger à la volée. Elle les émet sur le canal MCP local (doc 02).
- **L'IA arbitre / MJ.** Présente **uniquement chez l'hôte**. Avant qu'une
  proposition ne touche la map partagée, elle en **vérifie la viabilité** :
  cohérence avec les règles en cours, respect des invariants, faisabilité,
  absence d'abus. Elle **accepte, amende ou rejette**. C'est le pendant
  « intelligent » du host-authoritative : l'hôte n'est pas un simple relais qui
  rebroadcaste, il **arbitre** le contenu, au sens d'un maître du jeu.
  C'est aussi **elle qui porte les règles de la partie** (décision **D8**, doc 06) :
  l'arbitre est l'autorité qui accepte l'évolution du règlement. Une règle
  acceptée est ensuite matérialisée dans une forme que le jeu sait exécuter
  (configuration, module, primitive ou QML/JS validé) : le prompt seul n'est pas
  un moteur runtime. **Aucun tour n'est imposé** — il s'introduit par le prompt à
  l'arbitre ou par une proposition d'IA cliente acceptée (règlement évolutif).

### Topologie : 2 rôles isolés chez l'hôte, 1 chez le client

```
        HÔTE                                CLIENT (× N)
┌─────────────────────────┐          ┌─────────────────────────┐
│ IA cliente   → propose  │          │ IA cliente   → propose  │
│ IA arbitre   → valide   │          │ (pas d'arbitre)         │
└────────────┬────────────┘          └────────────┬────────────┘
             │ propositions locales               │ propositions
             │                                    ▼ (via réseau)
             └──────────────┬─────────────────────┘
                            ▼
       ┌────────────────────────────────────────────┐
       │ ARBITRE (hôte) : viabilité                  │
       │ → accepte / amende / rejette                │
       └─────────────────────┬──────────────────────┘
                             ▼  contenu validé
                  map partagée  /  broadcast Catway
```

La proposition d'un client **comme** celle de l'hôte lui-même passent par le
**même** arbitre avant d'être introduites : l'hôte ne s'auto-exempte pas.
Les deux rôles de l'hôte utilisent des processus ou contextes isolés. Ils peuvent
employer deux fournisseurs distincts ou un même fournisseur avec deux sessions
séparées ; une session unique changeant de rôle est exclue. L'arbitre est, lui
aussi, un modèle **fourni par le joueur** (celui qui héberge) —
le jeu n'héberge toujours aucune IA (cf. §7).

**L'arbitre est obligatoire.** Le mécanisme central permet à plusieurs joueurs de
proposer du contenu et des règles dans un état partagé : il n'y a donc **pas** de
mode partagé « IA sans arbitre ». Héberger une partie pilotée par IA **exige** un modèle
arbitre ; à défaut, le mode IA reste indisponible (repli sur le jeu classique,
§7). C'est une condition de fonctionnement, pas un réglage de confort (décision
**D6**). Cette obligation ne constitue pas une mesure de sécurité du code.

### Pourquoi séparer proposer et arbitrer

- **Deux postures inconciliables dans un seul agent.** Le rôle proposant est
  créatif et permissif ; le rôle arbitre est conservateur, garant de l'intégrité
  de la partie. Les fondre dilue la garantie.
- **Complément « souple » des garde-fous « durs ».** Le sandbox (doc 04) et les
  validateurs de capacités posent des invariants **mécaniques** et
  non-négociables. L'arbitre ajoute au-dessus un jugement **contextuel** (« ce
  pont est-il cohérent avec le thème et l'équilibre de cette partie ? ») que des
  règles statiques n'expriment pas. Il ne remplace pas le sandbox : une
  proposition doit passer **et** l'arbitre **et** les contrôles mécaniques. Un
  préfiltre statique peu coûteux peut précéder l'appel LLM ; la validation complète
  et l'isolation précèdent toujours l'exécution (schéma doc 01).
- **Un point d'autorité unique.** Concentrer l'arbitrage chez l'hôte évite le
  split-brain (deux pairs validant différemment) et réutilise le modèle réseau
  existant (`EditorSession`/`PhysicsSession` host-authoritative).

> **Sous-cadrage de D6 — depuis levé (doc 08).** La **nature** de l'arbitre est
> tranchée (LLM externe supervisé, D10), le **grain** est configurable par UI
> avec plancher sur code/règles (D25), la **forme du verdict** est spécifiée
> (D11 + doc 13 : verdict à deux audiences, actionnable pour itérer). Reste
> l'articulation fine avec l'exécution des règles (doc 06 §4 : mémorisation,
> réplication).

## 5. Principes directeurs

- **Le jeu expose des capacités, pas des écrans.** L'IA agit via un contrat de
  capacités stable (tools MCP du canal + skill), pas en simulant des clics
  fragiles.
- **Les pipelines métier restent la source de vérité.** Comme les hooks
  d'automation actuels, les mutations structurelles de l'IA passent par les
  mêmes pipelines que l'humain (`Game.updateMap`, `EditorOpBus`) et conservent
  leurs propriétés d'undo/collab/persistance. L'état runtime haute fréquence
  emprunte, lui, un flux distinct et non undoable (doc 05).
- **Liberté bornée par des garde-fous non-négociables.** « Grande liberté » ne
  veut pas dire « exécution arbitraire non contrôlée ». Le JS embarqué / QML
  génératif impose un **sandbox** (doc 04) ; l'arbitre (obligatoire, §4) juge la
  viabilité ; les règles custom imposent, à terme, un **contrat** (doc 06). La
  liberté vit *au-dessus* d'invariants que l'IA ne peut pas violer.
- **Local d'abord.** Le canal d'interaction est **local à la machine** (loopback).
  Il n'est qu'un point de contact jeu↔IA-du-joueur, pas un service exposé.
- **Déterminisme réseau préservé.** L'ajout de contenu IA doit rester compatible
  avec le modèle host-authoritative (collab éditeur, `PhysicsSession`). Ce qui est
  généré chez un joueur doit pouvoir être répliqué/validé chez les autres, ou
  rester explicitement local.

## 6. Ce qui change / ce qui reste

| Domaine | V2 | V3 |
|---------|----|----|
| Producteur de contenu | Humain via UI éditeur | Humain **+ son IA cliente** via canal MCP |
| Validation du contenu | Règles C++ figées + host relais | + **IA arbitre / MJ** chez l'hôte (viabilité contextuelle) |
| Extension d'un élément | Recompilation C++ (nouveau `TileType`, paramètre) | **Variables typées synchronisées** (espace mémoire réactif) + **JS embarqué** sur briques préexistantes (comportement) (doc 04/05) |
| Auteur du gameplay | Développeurs (C++/QML compilé) | **IA + joueurs**, au fil des parties (JS embarqué, briques composées) |
| Point d'entrée IA | Automation (debug/dev) | **Canal WS dédié** IA-joueur (doc 02) |
| Règles de partie | Pas de moteur de règles formel ni de système de tour | **Gouvernées par l'arbitre**, matérialisées/exécutées par les capacités du jeu ; tour optionnel (doc 06, D8) |
| Partage de contenu | Fichiers map JSON | + **Bibliothèque** de primitives/créations (doc 07, différé) |
| Physique / rendu 3D | Pattounx v2 / World3D | Inchangé (piloté à terme par l'IA) ; **palette visuelle élargie par une bibliothèque d'assets 3D prévue** (doc 07) |
| Réseau P2P / collab | Catway / EditorSession | Inchangé, socle réutilisé |

## 7. Transition et non-buts

- Le jeu « classique » reste disponible pendant la transition, mais la cible
  produit à terme est une migration complète vers V3, pas le maintien indéfini de
  deux produits de premier rang.
- Pas d'IA hébergée par le jeu : **les deux** modèles (cliente et arbitre) sont
  **fournis par le joueur** ; l'hôte fait simplement tourner l'arbitre en plus de
  sa propre IA cliente.
- Pas d'exposition réseau du canal hors de la machine locale à ce stade.
- **Pas d'accès de l'IA à l'automation de test.** L'IA cliente dialogue uniquement
  avec le **canal curé** (doc 02, appels d'API locaux) dont le but est de **créer
  des briques de gameplay avec logique** ; le harnais d'automation
  (`AutomationServer`, `automation_mcp/`) reste **test-only**. Certaines features
  de l'automation sont **portées** dans le canal, jamais exposées telles quelles.
- Les **détails de représentation et d'exécution des règles** (doc 06) et
  l'**architecture de la bibliothèque** (doc 07) sont explicitement reportés.

## 8. Périmètre produit validé

- Les trois usages appartiennent à la cible V3 : **éditeur solo assisté**,
  **éditeur collaboratif assisté** et **runtime co-construit en direct**.
- L'arbitre reste obligatoire dans les trois, y compris en solo/offline.
- Le niveau de liberté cible couvre composition de primitives, JS borné et QML/JS
  libre si R1 rend son isolation viable.
- Public initial : groupe mixte, du joueur non technique au moddeur.
- Plateformes visées : **Windows et Linux**. Linux demande encore packaging, CI
  et qualification (doc 10).

## 9. Risque central assumé

Le choix **D1 (QML génératif complet)** offre la liberté maximale mais ouvre la
**plus grande surface de sécurité du projet** : du code non fait-maison est
chargé et exécuté dans le process du jeu. Tout le cadrage V3 est structuré pour
que cette liberté soit **encadrée par un sandbox** (doc 04) plutôt que subie.
C'est le sujet le plus important à traiter avant toute implémentation.

L'**IA arbitre** (§4) est une seconde ligne de défense, mais **de nature
différente** : le sandbox est un garde-fou *mécanique et fiable* (invariants
durs), l'arbitre un jugement *souple et faillible* (cohérence, équilibre). On ne
délègue donc **jamais** à l'arbitre une garantie de sécurité que le sandbox doit
tenir : l'arbitre affine, il ne remplace pas.
