# 03 — Le fichier de skill livré au joueur

> **Statut : cadrage (draft).**

## 1. Idée

Le jeu embarque un **fichier de skill** : le mode d'emploi que l'IA du joueur
lit pour savoir **comment interagir avec le jeu**. Le joueur n'a pas à
documenter le protocole ni à écrire des tools : la skill rend son IA
opérationnelle immédiatement.

**Invocation in-app via tchat ingame (précision 2026-07-12, cf. D10/D17).**
Le joueur n'exécute **pas** les features depuis un CLI à part : les IA clientes
sont **invoquées directement depuis l'application**, à travers un **tchat
ingame**. Les CLIs (`claude -p`, Codex non interactif) restent le mécanisme
d'exécution **sous-jacent**, lancé et supervisé par l'app (D10) — invisibles
pour le joueur. Conséquence directe : l'app **pré-prompte** chaque modèle à
l'invocation pour qu'il suive les **workflows des skills internes** — la skill
n'a pas besoin d'être installée dans la configuration de l'agent du joueur,
elle est **injectée** par l'app.

**La skill décrit le canal IA (doc 02), pas l'automation de test.** L'IA cliente
n'a **aucun accès** au harnais d'automation (`automation_mcp/`, `AutomationServer`)
— voir la frontière doc 02 §1. La skill est le **contrat du canal** : un catalogue
**curé, orienté création de briques de gameplay**. Le MCP d'automation sert de
**patron d'outillage** pour bâtir ce canal, et **certaines** de ses capacités y
sont **portées** (§4), mais la skill n'expose jamais la surface de test.

## 2. Ce qu'une skill « client-IA » doit contenir

Différence fondamentale avec les skills de dev existantes
(`.agents/skills/editor-feature/SKILL.md`, `gameplay-module/SKILL.md`) : ces
dernières décrivent **comment modifier le code du repo** (phases
d'implémentation, fichiers à décalquer). La skill client-IA décrit **comment
piloter un jeu qui tourne** — c'est un **contrat de capacités runtime**, pas une
procédure d'implémentation.

Contenu cible :

1. ~~Comment se connecter au canal~~ **Caduc (D20)** : la connexion est portée
   par la **config MCP injectée au spawn** par l'app — la skill n'a plus à
   documenter port/handshake.
2. **Catalogue de capacités** : porté par les **schémas de tools MCP** générés
   depuis le manifeste (D20) ; la skill n'en donne que l'usage (recettes), pas
   les schémas — c'est la clé de l'économie de tokens (doc 02 §3).
3. **La boucle perception→action** : comment observer l'état, agir, vérifier.
4. **Les garde-fous** : ce que l'IA **ne peut pas** faire (allow-list),
   contraintes du QML génératif (doc 04), tailles/quotas.
5. **Des recettes** : patrons de tâches fréquentes (« ajouter une rivière »,
   « donner un comportement à une case », « écrire l'espace mémoire »).
6. **Conventions de l'espace mémoire** (doc 05) : forme recommandée des blobs, clés
   réservées éventuelles.

## 3. Format

Deux couches sont retenues pour servir **Codex et Claude Code** en première cible :

- **Couche lisible par un agent générique** : un `SKILL.md` (front-matter YAML
  `name`/`description` + corps procédural), cohérent avec le format déjà en place
  dans `.agents/skills/`. C'est ce que consomme un agent type Claude Code.
- **Couche machine** : un **contrat structuré** (JSON Schema / manifeste d'outils)
  décrivant les commandes, généré automatiquement — c'est lui qui garantit que la
  skill reste synchrone avec le canal réel.

`doc/architecture/AUTOMATION_API.md` est aujourd'hui le document le plus proche
d'un contrat client : il servira de **base rédactionnelle** — en gardant qu'il
documente l'**automation de test** ; le contrat du canal en est un **dérivé curé**,
pas une copie.

## 4. Génération : le manifeste du canal comme source de vérité

La **source de vérité** de la skill est le **manifeste de capacités du canal IA**
(son catalogue curé, doc 02 §4) — **pas** le MCP d'automation. La skill en est
**dérivée mécaniquement** :

```
  automation_mcp/ (tools + schémas)      ← patron d'outillage (déclaration de tools)
        │  porte un SOUS-ENSEMBLE curé
        ▼
  Manifeste du canal IA (catalogue gameplay)  ──build──▶  skill client (SKILL.md + contrat)
        └── SOURCE DE VÉRITÉ de la skill                        └── livrée à l'installation
```

Le MCP d'automation fournit le **format de déclaration** des tools (nom,
description, schéma) et **certaines** commandes qu'on **porte** dans le manifeste
du canal ; il n'est pas, lui, exposé à l'IA. Bénéfice : **une seule source de
vérité** — le manifeste du canal. Quand une capacité y est ajoutée, la skill se
régénère, pas de dérive manuelle.

> **À combler (chantier) :** divergence actuelle **hooks ↔ tools MCP**. Des hooks
> existent (`placeNPC`, `placeEnemy`, `placeCrate`, `setZoneTrigger`,
> `setNpcDialogue`, stats, `saveMap`) **sans tool MCP dédié**. Comme le manifeste
> du canal se construit en **portant** un sous-ensemble depuis ces deux surfaces,
> il faut les inventorier pour décider lesquels sont portés. Cela ne rend pas le
> MCP source de vérité et n'impose pas un invocateur générique, qui recréerait la
> surface permissive rejetée par D2. Le manifeste curé reste explicite.

## 5. Cycle de vie

- **Distribution** : la skill est **embarquée avec l'application** et **injectée
  en pré-prompt** à chaque invocation in-app d'un modèle (tchat ingame, §1).
  ~~Dépôt dans un emplacement connu de l'IA du joueur (`.agents/skills/`,
  dossier de config de l'agent…)~~ — caduc pour le flux nominal : il n'y a pas
  d'installation côté agent du joueur.
- **Génération** : la skill est produite au **build** depuis le manifeste du canal.
- **Mise à jour** : versionner la skill avec le `protocolVersion` global. Une
  version obsolète utilise si possible un mode compatibilité négocié et reçoit une
  proposition de mise à jour automatique.
- **Découvrabilité** : la skill doit être auto-suffisante — l'IA ne doit pas avoir
  besoin de lire le code du jeu pour l'utiliser.

## 6. Questions ouvertes (synthèse doc 08 ; questions ouvertes : doc 09)

- ~~Quels agents cibler en premier ?~~ **Tranché D17 : Codex + Claude Code.**
- ~~La skill embarque-t-elle un client de connexion ?~~ **Tranché D20** :
  connecteur MCP natif des CLIs, config injectée au spawn — rien à embarquer
  dans la skill. Forme d'intégration tranchée **D21** : streamable HTTP
  loopback intégré au jeu (doc 02 §2 bis).
- ~~Emplacement d'installation standardisé, multi-plateforme ?~~ **Caduc**
  (précision 2026-07-12, §1) : skill embarquée dans l'app, injectée en pré-prompt.
- ~~Génération au build ou au packaging ?~~ **Tranché D17 : au build.**
