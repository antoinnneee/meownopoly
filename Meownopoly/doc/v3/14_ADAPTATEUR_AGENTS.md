# 14 — Adaptateur d'agents & tchat ingame

> **Statut : socle implémenté (mis à jour le 2026-07-19).** Le superviseur,
> la passerelle MCP loopback, le préflight arbitre, le parcours d'hébergement
> et le drawer du proposant sont intégrés. Le pipeline d'arbitrage complet des
> propositions continue dans le vertical slice Phase 2.

## 0. Parcours utilisateur implémenté

1. Depuis le titre, **Héberger une partie IA** ouvre `AiHostLobby`.
2. L'hôte choisit séparément adaptateur/programme/modèle de l'arbitre et du
   proposant, puis valide le handshake de l'arbitre.
3. **Héberger une partie IA** ouvre directement `SessionCreation`, verrouillé
   sur le mode éditeur, avec choix carte vierge/existante.
4. La session est publiée sous le préfixe compatible serveur
   `[AI-EDIT:<hostId>]`. Les autres clients la voient avec un badge `✨` et
   rejoignent le même parcours éditeur/P2P que les sessions `[EDIT:]`.
5. À l'entrée dans `Editor.qml`, `AiChatDrawer` s'ouvre automatiquement. Il
   reste accessible par le bouton **✨ Assistant proposant** dans l'interface
   classique comme dans `NewEditorChrome`; la messagerie multijoueur reste un
   drawer distinct.

La configuration de modèle est persistée dans `QSettings/AI/ModelConfig` et
transmise à l'éditeur sans token. Le drawer récupère directement auprès de la
passerelle locale l'URL et le token éphémère du rôle proposant.

Pour le développement, lancer l'application avec `--ai-chat-errors` affiche
dans le drawer un badge `DEV · stderr` et regroupe les sorties d'erreur du CLI
dans des messages `🛠 Diagnostic CLI`. Le flag est désactivé par défaut.

## 1. Rôle

L'adaptateur d'agents est le composant par lequel le joueur **entre** dans la
V3 : c'est lui qui matérialise « son IA » ([doc 00](./00_VISION.md) §2). Il couvre deux
responsabilités liées :

1. **Supervision des processus d'agents** : lancer, surveiller et arrêter les
   CLIs (`claude -p`, mode non interactif Codex) qui exécutent les rôles
   `proposer` et `arbiter`, sans que le joueur ne touche jamais un terminal
   (D10 : le CLI est le mécanisme sous-jacent, invisible).
2. **Tchat ingame** : l'UI de dialogue joueur↔IA depuis laquelle chaque
   invocation part et dans laquelle reviennent réponses, verdicts et
   explications de rejet (S3 du slice, [doc 11](./11_VERTICAL_SLICE.md)).

## 2. Responsabilités détaillées

### 2.1 Cycle de vie des processus (M2)
- Démarrage/arrêt gracieux, kill, timeout, détection de crash, redémarrage,
  capture bornée de stdout/stderr (`QProcess`, nouveau
  `AiProcessSupervisor` — `cpp/ai/ai_process_supervisor.*` conseillé).
- **Aucun orphelin** : la fermeture du jeu tue tous les process enfants
  (critère M2).
- Chez l'hôte : **deux processus/sessions isolés** (proposante + arbitre,
  D6/D10) ; jamais une session unique qui change de rôle.
- État exposé à QML : `Stopped/Starting/Ready/Failed/Restarting` (M2), mappé
  sur l'indicateur lobby à 4 états de D31 (`Absent`/`Test en cours`/`Prêt`/
  `Erreur`).

### 2.2 Injection au spawn (D10/D17/D20)
- Config MCP (endpoint streamable HTTP loopback, D21) + **token éphémère de
  rôle** + **pré-prompt skill** (générée au build, D17) injectés par
  env/config du process enfant — jamais dans une ligne de commande
  journalisée (secrets hors logs, critère M2).
- Adaptateurs séparés par CLI (`claude -p` vs Codex), arguments non codés en
  dur dans l'UI.
- Claude reçoit un fichier MCP JSON temporaire (permissions propriétaire),
  `--strict-mcp-config`, le mode non interactif `dontAsk` et uniquement les
  tools `mcp__meownopoly__*`.
- Codex reçoit les clés TOML `mcp_servers.meownopoly.*` via `-c`; son token est
  lu depuis `MEOW_AI_MCP_BEARER_TOKEN`. Le faux appel historique
  `codex exec --config <json>` a été supprimé (`--config` attend `clé=valeur`).
- Les descripteurs `tools/list` portent les annotations MCP 2025-06-18
  (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`). Elles
  sont obligatoires pour Codex en `exec` non interactif : sans annotations,
  Codex 0.144.5 considère l'appel potentiellement destructif et l'annule avant
  d'envoyer `tools/call` (`user cancelled MCP tool call`).
- `state_query(asset_categories)` puis `state_query(assets,
  {category,type})` exposent le catalogue de l'éditeur avant un
  `editor_place(kind=asset)` ; l'agent ne doit jamais deviner un `assetId`.

### 2.3 Handshake & challenge de l'arbitre (D24/D31)
- Avant d'ouvrir le mode IA : handshake de rôle (l'agent `arbiter` répond et
  revendique son rôle) + challenge de capacité (accès aux tools de verdict,
  version du protocole).
- Test automatique à l'ouverture du lobby + bouton de re-test manuel ;
  « Héberger une partie IA » grisé hors état `Prêt`.
- Arbitre mort en partie : bandeau persistant + propositions mises en file
  (D31), déclenchement du flow de migration d'arbitre (D10) sans corrompre la
  partie.

### 2.4 Tchat ingame
- Une invocation = un tour de tchat (modèle d'événements [doc 02](./02_CANAL_IA.md) §4).
- Le tchat affiche uniquement stdout (réponse finale de l'agent) ; stderr reste
  conservé dans `recentOutput` pour le diagnostic CLI/MCP, afin de ne pas
  montrer les en-têtes et avertissements internes Codex au joueur.
- Affiche : réponses de l'IA, verdicts (`reasons[audience=player]`, [doc 13](./13_ENVELOPPE_PROPOSITION.md) §4),
  progression des propositions, erreurs actionnables.
- Information « captures d'écran actives » affichée une fois au lancement du
  mode IA (D22) ; de même pour le prérequis compte + CLI ([doc 00](./00_VISION.md) §8).
- Budget/coût : l'hôte configure un budget (D10) ; les joueurs configurent
  ensemble le prompt/personnalité initiale de l'arbitre (D10 — extension
  « objectifs propres » à cadrer, [doc 00](./00_VISION.md) §4 note, [doc 08](./08_DECISIONS_ET_QUESTIONS.md) §2).

## 3. Socle V2 et frontières

- **Socle repris** : `LauncherManager` comme patron du cycle d'opérations
  longues (statuts, erreurs, intégration QML) — il ne lance aucun processus
  aujourd'hui ([doc 10](./10_AUDIT_STACK_EXISTANTE.md), B03) : la supervision est un chantier neuf.
- **Frontières** : l'adaptateur ne parle pas MCP (c'est le canal, [doc 02](./02_CANAL_IA.md)) et
  ne juge rien (c'est l'arbitre) ; il fournit l'environnement d'exécution des
  agents et l'UI de dialogue. Le tchat ingame V3 est distinct du chat
  multijoueur existant (`ChatClient`/chatServer) — réutilisation éventuelle de
  composants UI seulement.

## 4. Questions ouvertes (propres à l'adaptateur)

- **Onboarding guidé** : détection des CLIs installés, aide à la connexion au
  compte fournisseur (prérequis [doc 00](./00_VISION.md) §8) — périmètre exact à cadrer.
- **Politique de redémarrage** : le socle utilise 2 retries et un backoff
  linéaire de 1,5 s ; confirmer ces valeurs après instrumentation réelle.
- **Multi-invocations** : une invocation à la fois par rôle (file), ou
  proposante et arbitre en parallèle ? (Le pipeline [doc 13](./13_ENVELOPPE_PROPOSITION.md) sérialise déjà les
  propositions côté hôte.)
- **UI du tchat** : le choix actuel est un drawer dédié `AiChatDrawer`, qui
  réutilise les bulles/statuts du chat mais aucun `ChatClient`.
- **Détection de fin d'invocation** : critère de terminaison d'un `claude -p`
  (exit process) vs timeout applicatif ; affichage de la progression pendant
  les tours longs.
