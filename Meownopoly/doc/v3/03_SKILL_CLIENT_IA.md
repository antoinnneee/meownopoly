# 03 — Le fichier de skill livré au joueur

> **Statut : cadrage (draft).**

## 1. Idée

À l'installation, le joueur reçoit un **fichier de skill** : le mode d'emploi que
son IA lit pour savoir **comment interagir avec le jeu**. Le joueur n'a pas à
documenter le protocole ni à écrire des tools : la skill rend son IA
opérationnelle immédiatement. Elle est **construite à partir du MCP meow
automation** (`automation_mcp/`), qui décrit déjà des capacités du jeu.

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
d'un contrat client : il servira de base rédactionnelle.

## 4. Génération à partir du MCP

Le MCP `automation_mcp/index.js` déclare déjà des **tools** (nom, description,
schéma d'entrée) mappés sur les commandes. La skill client peut être **dérivée
mécaniquement** de cette source :

```
automation_mcp/ (tools + schémas)  ──build──▶  skill client (SKILL.md + contrat)
        │                                              │
        └── source de vérité des capacités             └── livrée à l'installation
```

Bénéfice : **une seule source de vérité**. Quand une capacité est ajoutée au
canal/MCP, la skill se régénère — pas de dérive manuelle.

> **À combler (chantier) :** divergence actuelle **hooks ↔ tools MCP**. Des hooks
> existent (`placeNPC`, `placeEnemy`, `placeCrate`, `setZoneTrigger`,
> `setNpcDialogue`, stats, `saveMap`) **sans tool MCP dédié**. Si le MCP est la
> source de génération de la skill, il faut d'abord **réconcilier** MCP et hooks
> (ajouter les tools manquants ou un `editor_hook_invoke` générique documenté),
> sinon la skill générée sera incomplète.

## 5. Cycle de vie

- **Installation** : la skill est déposée dans un emplacement connu de l'IA du
  joueur (à définir selon l'agent : `.agents/skills/`, dossier de config de
  l'agent client, etc.).
- **Mise à jour** : versionner la skill avec le `protocolVersion` du canal. Au
  handshake, si l'IA annonce une version obsolète, le jeu peut signaler qu'une
  skill à jour est disponible.
- **Découvrabilité** : la skill doit être auto-suffisante — l'IA ne doit pas avoir
  besoin de lire le code du jeu pour l'utiliser.

## 6. Questions ouvertes (→ doc 08)

- Quel(s) agent(s) client cible-t-on en premier (Claude Code / autre) et donc quel
  format de skill natif ?
- La skill embarque-t-elle un tool de connexion au WS, ou suppose-t-on que l'agent
  client sait parler WebSocket brut ?
- Emplacement d'installation standardisé, multi-plateforme.
- Génération : script de build dédié, ou étape du packaging de l'installeur ?
