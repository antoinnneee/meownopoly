# 03 — Le fichier de skill livré au joueur

> **Statut : cadrage (draft).**

## 1. Idée

À l'installation, le joueur reçoit un **fichier de skill** : le mode d'emploi que
son IA lit pour savoir **comment interagir avec le jeu**. Le joueur n'a pas à
documenter le protocole ni à écrire des tools : la skill rend son IA
opérationnelle immédiatement.

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

1. **Comment se connecter** au canal WS local (doc 02) : hôte loopback, port,
   handshake/token éventuel, version de protocole.
2. **Catalogue de capacités** : chaque commande avec `cmd`, schéma des `params`,
   schéma du `result`, erreurs possibles, exemple d'appel/réponse.
3. **La boucle perception→action** : comment observer l'état, agir, vérifier.
4. **Les garde-fous** : ce que l'IA **ne peut pas** faire (allow-list),
   contraintes du QML génératif (doc 04), tailles/quotas.
5. **Des recettes** : patrons de tâches fréquentes (« ajouter une rivière »,
   « donner un comportement à une case », « écrire l'espace mémoire »).
6. **Conventions de l'espace mémoire** (doc 05) : forme recommandée des blobs, clés
   réservées éventuelles.

## 3. Format

Deux couches, à décider (doc 08) :

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

- **Installation** : la skill est déposée dans un emplacement connu de l'IA du
  joueur (à définir selon l'agent : `.agents/skills/`, dossier de config de
  l'agent client, etc.).
- **Mise à jour** : versionner la skill avec le `protocolVersion` du canal. Au
  handshake, si l'IA annonce une version obsolète, le jeu peut signaler qu'une
  skill à jour est disponible.
- **Découvrabilité** : la skill doit être auto-suffisante — l'IA ne doit pas avoir
  besoin de lire le code du jeu pour l'utiliser.

## 6. Questions ouvertes (synthèse doc 08 ; questionnaire exhaustif doc 09)

- Quel(s) agent(s) client cible-t-on en premier (Claude Code / autre) et donc quel
  format de skill natif ?
- La skill embarque-t-elle un tool de connexion au WS, ou suppose-t-on que l'agent
  client sait parler WebSocket brut ?
- Emplacement d'installation standardisé, multi-plateforme.
- Génération : script de build dédié, ou étape du packaging de l'installeur ?
