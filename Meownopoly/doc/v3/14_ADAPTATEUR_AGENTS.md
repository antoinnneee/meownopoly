# 14 — Adaptateur d'agents & tchat ingame

> **Statut : cadrage (draft, créé le 2026-07-13).** Brique identifiée dès le
> chantier M2 ([doc 10](./10_AUDIT_STACK_EXISTANTE.md)) mais sans document dédié jusqu'ici — le [doc 01](./01_ARCHITECTURE_CIBLE.md) §2.7 la
> réintègre dans la vue d'ensemble. Ce document rassemble ce qui est déjà
> tranché (D10/D17/D20/D24/D31) et liste ce qui reste à cadrer.

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
- **Politique de redémarrage** : combien de retries avant `Failed` définitif ?
  Backoff ?
- **Multi-invocations** : une invocation à la fois par rôle (file), ou
  proposante et arbitre en parallèle ? (Le pipeline [doc 13](./13_ENVELOPPE_PROPOSITION.md) sérialise déjà les
  propositions côté hôte.)
- **UI du tchat** : panneau dédié, drawer (façon `ChatDrawer`), ou scène ?
  Partage de composants avec le chat multijoueur ?
- **Détection de fin d'invocation** : critère de terminaison d'un `claude -p`
  (exit process) vs timeout applicatif ; affichage de la progression pendant
  les tours longs.
