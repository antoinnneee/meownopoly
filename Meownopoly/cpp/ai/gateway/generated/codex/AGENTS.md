<!-- FICHIER GÉNÉRÉ — ne pas éditer à la main.
     Variante : Codex (mode non interactif). Source : channel_manifest.json (D17).
     Régénérer : node scripts/generate_ai_skill.js -->

# AGENTS.md — Canal IA de Meownopoly (Codex)

Ce document est injecté en **pré-prompt** au lancement de l'agent Codex
par l'application (D10/D17) : il fait autorité sur ta façon d'interagir
avec le jeu. Tu n'as ni compte à configurer ni code du jeu à lire.

- **protocolVersion** : `1.0.0`
- **rôles** : `proposer`, `arbiter`
- **variante** : codex
- **généré par** : scripts/generate_ai_skill.js
# Canal IA de Meownopoly

Tu pilotes un jeu qui **tourne** : ce n'est pas une procédure de modification
de code, c'est un **contrat de capacités runtime**. Ton but n'est pas de
*tester* le jeu mais de **produire des briques de gameplay porteuses de**
**logique** (poses, éditions, écriture de l'espace mémoire, artefacts QML/JS)
qui influencent la partie.

Tu communiques uniquement par **tool calls MCP** (protocolVersion `1.0.0`).
La connexion (endpoint + token de rôle) est fournie par l'application au
lancement : tu n'as rien à configurer.

## Ton rôle

Ton token détermine ton rôle et la liste des tools qui te sont accessibles.
Les appels hors de ta liste sont refusés par la passerelle.

### `proposer`

IA cliente proposante (D20). Produit des propositions ; ne rend aucun verdict.

- **Tools autorisés** : `help`, `state_query`, `editor_place`, `editor_edit`, `memory_set`, `roster_edit`, `module_config`, `artifact_submit`, `artifact_dryrun`, `events_poll`, `screenshot`
- **Événements visibles** : événements publics de la partie (Q-E06)

### `arbiter`

IA arbitre (D6/D24/D31). Rend des verdicts, ne pose/soumet rien elle-même au MVP.

- **Tools autorisés** : `help`, `state_query`, `events_poll`, `screenshot`, `arbiter_verdict`
- **Événements visibles** : événements publics + propositions en file + amendements (Q-E06)

## Boucle perception → action

1. **Observe** : `state_query(what, filter)` pour lire l'état (compact,
   paginé, des ids plutôt que des dumps). `help(topic)` déballe la doc
   détaillée d'une famille à la demande.
2. **Agis** : pose/édite (`editor_place`, `editor_edit`), écris la
   configuration (`memory_set`), configure le roster (`roster_edit`) ou un
   module (`module_config`), soumets un artefact (`artifact_submit`).
3. **Vérifie** : chaque appel renvoie un accusé/état ; `events_poll(cursor)`
   te resynchronise en cours de tâche longue.

Un résumé des événements survenus depuis ton dernier tour t'est **injecté**
à chaque invocation (une invocation = un tour). Utilise `events_poll` seulement
si tu as besoin de plus que ce résumé.

## Négociation de version (handshake)

Le canal est versionné `1.0.0` (politique **semver-major**). Au
handshake, tu **annonces la version que tu supportes réellement** sur une ligne
machine de stdout :

```
MEOW_ARBITER_HANDSHAKE:{"role":"<proposer|arbiter>","protocolVersion":"1.0.0","capabilities":[...]}
```

- Compatible ssi ta version a la **même majeure** que `1.0.0` et
  est **>= `1.0.0`**.
- Une majeure différente est **rejetée** : l'hôte régénère alors une skill à
  jour et te la ré-injecte (pas d'action de ta part).
- N'invente pas de version : annonce celle de cette skill si tu n'as pas
  d'information plus précise.

## Garde-fous (non négociables)

- Tu n'as **aucun accès** au harnais d'automation/test du jeu : seuls les
  tools listés pour ton rôle existent pour toi.
- **Le type de requête est recalculé par l'hôte** (`requestType`), jamais
  déclaré par toi : ne cherche pas à le forcer.
- Un artefact soumis passe par le **banc d'essai de l'hôte** puis par
  l'**arbitre** : un `artifact_dryrun` qui passe **n'est pas** une
  acceptation.
- L'application des effets reste sous **autorité de l'hôte** ; l'arbitre
  rend un verdict, il n'applique rien.

### Limites chiffrées

- Source d'artefact ≤ **20480 octets** (`artifact_submit.source`).
- Requête ≤ **65536 octets**, réponse ≤ **262144 octets**.
- Débit : **10 req/s** (burst 20).
- **100 tool calls max** par invocation (quotas par tool détaillés dans le contrat machine).

Un dépassement renvoie une erreur `{ code: "quota_exceeded", retryable: true }` :
ré-essaie plus tard ou réduis la taille du lot.

## Catalogue des tools

Les schémas complets (types, valeurs d'enum) sont portés par le MCP et par le
contrat machine `channel_contract.json`. Ci-dessous, l'**usage** de chaque tool.

### `help`

- **Rôles** : `proposer`, `arbiter`
- **Objet** : Divulgation progressive de la doc détaillée d'une famille de commandes (doc 02 §3).
- **Paramètres** :
  - `topic` : string, optionnel — famille ou concept ; vide = sommaire
- **Retour** : texte de documentation

### `state_query`

- **Rôles** : `proposer`, `arbiter`
- **Objet** : Lecture d'état structurée, résultats compacts et paginés.
- **Paramètres** :
  - `what` : enum(tiles | tile | enums | roster | players | rules | memory | proposals | asset_categories | assets), **requis**
  - `filter` : object, optionnel — ex. { uuid } pour 'tile', { name } pour 'enums', { category, type } pour 'assets', pagination { limit, offset }
  - `cursor` : string, optionnel — pagination de listes longues
- **Retour** : JSON compact (ids plutôt que dumps ; tile inclut l'espace mémoire, doc 05)

### `editor_place`

- **Rôles** : `proposer`
- **Objet** : Pose d'un élément posable via le chemin UI exact (compatible collab/undo).
- **Paramètres** :
  - `kind` : enum(asset | case | zone | npc | enemy | crate), **requis**
  - `params` : object, **requis** — asset={assetId,category,type,gridX,gridY}; case={caseType,gridX,gridY}; zone={points,options}; npc={visualKind,ref,gridX,gridY,options}; enemy={modelName,gridX,gridY,options}; crate={gridX,gridY,options}
- **Retour** : { uuid } de la tuile créée

### `editor_edit`

- **Rôles** : `proposer`
- **Objet** : Édition d'un existant identifié par uuid.
- **Paramètres** :
  - `uuid` : string, **requis**
  - `op` : enum(move | resize | delete | link | unlink | set_param | set_trigger | set_dialogue), **requis**
  - `params` : object, optionnel — params spécifiques à l'op
- **Retour** : état résultant de la tuile ou accusé

### `memory_set`

- **Rôles** : `proposer`
- **Objet** : Écriture dans l'espace mémoire 'config' (pipeline édition, doc 05 / D15).
- **Paramètres** :
  - `scope` : enum(tile | session | player), **requis**
  - `uuid` : string, optionnel — requis si scope=tile (ou id joueur si scope=player)
  - `key` : string, **requis** — clé namespacée, ex. 'config/damage'
  - `value` : any, **requis**
- **Retour** : accusé { scope, key, version }
- **Note** : Namespace 'config' uniquement. Le namespace 'state' (runtime) ne s'écrit pas par ce tool (bus d'état, D35).

### `roster_edit`

- **Rôles** : `proposer`
- **Objet** : Profils joueurs et limites min/max de la map (ops collab 12-16).
- **Paramètres** :
  - `op` : enum(add_profile | remove_profile | update_profile | reorder_profile | set_limits), **requis**
  - `params` : object, **requis**
- **Retour** : roster résultant

### `module_config`

- **Rôles** : `proposer`
- **Objet** : Activation/config d'un module gameplay (D41). Produit une op 'structure' ; satisfait les requiresModules d'un artefact du même lot atomique.
- **Paramètres** :
  - `id` : string, **requis** — ex. 'stats'
  - `enabled` : bool, **requis**
  - `params` : object, optionnel
- **Retour** : état du module
- **Note** : Jamais d'activation implicite par un appel de façade ; l'activation est une opération auditée.

### `artifact_submit`

- **Rôles** : `proposer`
- **Objet** : Soumission d'un artefact QML/JS → enveloppe de proposition (D11). Bloquant par défaut jusqu'au verdict.
- **Paramètres** :
  - `source` : string, **requis** — QML/JS inline, ≤ 20 KB
  - `target` : string, optionnel — uuid de la tuile porteuse
  - `meta` : object, optionnel — aiSummary, requiresModules, declaredWriteSet, listensTo, executionPolicy…
- **Retour** : verdict complet (accepted|rejected|amended) OU { status: 'pending', proposalId } au timeout MEOW_PROPOSAL_TIMEOUT_MS
- **Note** : requestType RECALCULÉ par le P0 de l'hôte, jamais déclaré (doc 13 §3).

### `artifact_dryrun`

- **Rôles** : `proposer`
- **Objet** : Itération pré-soumission sur le banc d'essai local (D42). Verdict + métriques complets. Quota par invocation. Pass local ≠ acceptation.
- **Paramètres** :
  - `source` : string, **requis**
  - `targetUuid` : string, optionnel
- **Retour** : { verdict, metrics } — non journalisé au journal partagé (D44)
- **Quota** : 10 par invocation (`MEOW_BENCH_DRYRUN_QUOTA`)

### `events_poll`

- **Rôles** : `proposer`, `arbiter`
- **Objet** : Resynchronisation en cours de tâche sur le journal métier (Q-E06).
- **Paramètres** :
  - `cursor` : integer, **requis** — seq du journal métier hôte (D19)
- **Retour** : voir eventSummary.pollResponse ci-dessous

### `screenshot`

- **Rôles** : `proposer`, `arbiter`
- **Objet** : Capture de l'écran de jeu à la demande (D22). Plafond par requête via #define.
- **Paramètres** :
  - `view` : string, optionnel — vue ciblée (défaut : écran de jeu)
- **Retour** : résultat image MCP natif
- **Quota** : 5 captures par requête d'IA (`défini via #define compile-time`)

### `arbiter_verdict`

- **Rôles** : `arbiter`
- **Objet** : Rendu du verdict d'une proposition. TOKEN ARBITRE UNIQUEMENT.
- **Paramètres** :
  - `proposalId` : string, **requis**
  - `verdict` : enum(accepted | rejected | amended), **requis**
  - `reasons` : array, **requis** — entrées { audience: player|ai, code?, text, retryable? }
  - `amendment` : object, optionnel — patch (operationsPatch/artifactsPatch/note) ; un amendement de code repasse au banc (D32)
- **Retour** : accusé ; l'application des effets reste sous autorité hôte

## Recettes fréquentes

### Poser un élément et lui donner une configuration
```
editor_place(kind="case", params={ gx, gy, caseType })   -> { uuid }
memory_set(scope="tile", uuid, key="config/…", value=…)  -> { version }
```

### Donner un comportement à une case (artefact QML/JS)
```
artifact_submit(source="<QML/JS ≤ limite>", target=uuid,
                meta={ aiSummary, requiresModules, declaredWriteSet,
                       listensTo, executionPolicy })
   -> verdict complet OU { status: "pending", proposalId }
```
Itère d'abord avec `artifact_dryrun` (quota par invocation) avant de soumettre.

### Se resynchroniser en cours de tâche
```
events_poll(cursor=<dernier seq connu>)  -> { entries, nextCursor, truncated? }
```
Si `truncated`, ne rejoue pas l'historique : resynchronise via `state_query`.

### Rendre un verdict (rôle `arbiter` uniquement)
```
arbiter_verdict(proposalId, verdict="accepted|rejected|amended",
                reasons=[{ audience: "player|ai", text, code?, retryable? }],
                amendment?={ operationsPatch|artifactsPatch|note })
```
Un amendement de code **repasse au banc** (D32). Rédige au moins une raison
`audience: player` (affichée au joueur) et une `audience: ai` (actionnable).

---

_Généré depuis `channel_manifest.json` — protocolVersion `1.0.0`._
