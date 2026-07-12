# 13 — Schéma de l'enveloppe de proposition (D11)

> **Statut : spécification (2026-07-12).** Définit l'unité d'échange auditée
> du pivot : l'**enveloppe de proposition** (D11), son cycle de vie, le
> **verdict**, le transport et le journal. Requise par le scénario S2 du
> vertical slice (doc 11). Consommateurs : passerelle MCP (doc 02), arbitre
> (D6/D25/D32), banc d'essai (doc 12), journal (D19), P2P (Q-F06).

## 1. Rôle

**Toute mutation de l'état partagé transite par une proposition.** L'enveloppe
est le conteneur unique qui porte une intention de modification depuis son
auteur (IA cliente, via `artifact_submit` ou un lot d'ops) jusqu'à son
application par l'hôte — en passant par le préfiltre, l'arbitre (selon la
config D25), le banc d'essai (si code) et le journal.

Elle sert quatre maîtres à la fois :

- le **routage** (D25) : son `requestType` décide du chemin rapide mécanique
  ou de l'arbitrage ;
- l'**arbitre** : elle est le document qu'il juge et peut amender (D32) ;
- la **validation mécanique** : write-set déclaré, budgets, version de base ;
- l'**audit** (D19) : elle est l'entrée de journal, rejouable.

## 2. Cycle de vie

```
 draft ──▶ submitted ──▶ prefiltered ──┬─(données sûres, config D25)──▶ validated
   │            │            │         └─(code/règles, plancher)──▶ arbitrating
   │            │            └─ fail P0 ──▶ rejected(mechanical)          │
   │            │                             ┌────────── amended ◀──────┤
   │            │                             ▼ (repasse le banc, D32)   │
   │            │                          benching ◀────── accepted ◀───┘
   │            │                             │                  rejected(arbiter)
   │            │                             ├─ pass ──▶ validated
   │            │                             └─ fail ──▶ rejected(bench)
   │            │
   │            └─ (arbitre indisponible, D31) ──▶ queued (file, pas perdu)
   │
   validated ──▶ applying ──▶ applied        (échec d'application ──▶ failed)
```

Règles d'états :

- **Un seul écrivain d'états : l'hôte.** L'auteur ne voit que des
  transitions notifiées (verdict, événements injectés).
- **`amended` retourne toujours dans `benching`** si l'amendement touche du
  code (D32) ; un amendement purement « données » repasse par la validation
  mécanique seulement.
- **`queued`** (arbitre mort, D31) conserve l'ordre de la file
  transactionnelle (D12) ; à la reprise, les propositions repartent de
  `prefiltered`.
- Tous les états terminaux (`applied`, `rejected(*)`, `failed`) sont
  journalisés avec l'enveloppe complète (noyau d'audit D19).

## 3. Schéma de l'enveloppe

```json
{
  "envelopeVersion": 1,
  "proposalId": "uuid",
  "channelVersion": "1.0.0",

  "author": {
    "playerId": "id joueur (roster)",
    "role": "proposer",
    "agent": { "cli": "claude", "model": "…", "sessionId": "…" }
  },

  "intent": {
    "playerPrompt": "texte du joueur dans le tchat (ou résumé)",
    "aiSummary": "ce que l'IA déclare vouloir faire, 1-3 phrases"
  },

  "requestType": "data_safe | structure | rules | code",

  "baseVersion": {
    "rulebook": 12,
    "mapRevision": 348,
    "journalSeq": 1042
  },

  "operations": [
    { "op": "editor_place", "kind": "zone", "params": { "…": "…" }, "clientOpId": "uuid" },
    { "op": "memory_set", "scope": "tile", "uuid": "…", "key": "config/damage", "value": 5 }
  ],

  "artifacts": [
    {
      "contentHash": "sha256:…",
      "source": "…QML/JS inline (≤ 20 KB)…",
      "targetUuid": "tuile porteuse (optionnel)",
      "executionPolicy": "host_only | replicated_revalidated",
      "declaredWriteSet": ["<uuid>/state/score"],
      "listensTo": ["zoneEntered", "memory:<uuid>/config/owner"]
    }
  ],

  "writeSet": ["<uuid>/config/damage", "<uuid>/state/score"],

  "createdAt": "ISO-8601",
  "expiresAt": "ISO-8601 (optionnel : proposition liée à un état volatil)"
}
```

Notes de conception :

- **`requestType`** est **calculé par la passerelle** (P0), jamais déclaré
  seul par l'IA : une enveloppe contenant `artifacts[]` est `code` quoi
  qu'en dise l'auteur — c'est ce qui rend le plancher D25 non contournable.
  Catégories : `data_safe` (poses/écritures dans les quotas), `structure`
  (suppressions, resize, roster), `rules` (modification du règlement D12),
  `code` (au moins un artefact QML/JS).
- **`baseVersion`** permet la détection de conflit optimiste : si la carte,
  le règlement ou le journal ont trop divergé entre construction et
  application, l'hôte peut rejeter `stale_base` (l'IA reconstruit avec
  `events_poll`/`state_query`). Le slice solo n'en a pas besoin (un seul
  écrivain) mais le champ est présent dès la v1 pour ne pas casser le format
  au passage collab.
- **`writeSet` global** = union des write-sets des opérations et des
  `declaredWriteSet` des artefacts. Le banc vérifie les artefacts
  (write-set observé, doc 12 §3) ; la validation mécanique vérifie les
  opérations. Il alimente aussi l'undo ciblé (D15/D28) et la détection de
  cycles (D12).
- **`operations[].clientOpId`** : déduplication idempotente au rejeu réseau
  (Q-F06) — même id, même effet, appliqué une fois.
- **Tout-ou-rien** (D14) : l'enveloppe est le **lot atomique**. Soit toutes
  les `operations` + artefacts s'appliquent, soit rien (staging côté hôte,
  chantier M-transactions).

## 4. Schéma du verdict

```json
{
  "proposalId": "uuid",
  "verdict": "accepted | rejected | amended",
  "decidedBy": { "role": "arbiter", "agent": { "…": "…" } },

  "reasons": [
    { "audience": "player", "text": "Refusé : la plaque retirerait des points sans plafond." },
    { "audience": "ai", "code": "unbalanced_effect", "text": "Ajoute un plafond ou un cooldown, puis re-propose.", "retryable": true }
  ],

  "amendment": {
    "operationsPatch": [ "…ops remplacées/ajoutées/retirées…" ],
    "artifactsPatch": [ { "contentHash": "sha256:nouveau", "source": "…" } ],
    "note": "cooldown 5 s ajouté par l'arbitre"
  },

  "benchReport": { "verdict": "pass", "metricsRef": "journal seq 1051" },

  "appliedVersion": { "rulebook": 13, "mapRevision": 349 },
  "decidedAt": "ISO-8601"
}
```

- **`reasons` à deux audiences** : une phrase pour le **joueur** (affichée
  dans le tchat) et une entrée pour l'**IA** (code stable + consigne
  actionnable + `retryable`) — c'est la condition du scénario S3 (rejet →
  itération). Les codes mécaniques sont ceux du banc (doc 12 §4) et de la
  validation ; les codes contextuels de l'arbitre sont libres mais
  journalisés.
- **`amendment`** : patch, pas ré-enveloppe — l'original reste intact au
  journal (D11 : l'amendement ne peut être silencieux). Le `benchReport` d'un
  amendement de code référence le **nouveau** passage au banc (D32).
- **`appliedVersion`** : versions résultantes, réinjectées dans le résumé
  d'événements du tour suivant (Q-E06).

## 5. Retour au proposant (canal MCP)

`artifact_submit` (et le futur lot d'ops) se comporte ainsi :

- **Mode bloquant par défaut** : le tool call MCP ne rend la main qu'au
  verdict (accepté/rejeté/amendé), avec timeout
  `MEOW_PROPOSAL_TIMEOUT_MS` (défaut **60 000 ms** — l'arbitrage LLM p95
  visé est 15 s, Q-J04). C'est le mode le plus simple pour l'IA : soumettre,
  lire le verdict, itérer dans le même tour.
- **Au timeout** : réponse `{ "status": "pending", "proposalId": … }` —
  l'IA continue, le verdict arrivera dans le résumé d'événements injecté au
  tour suivant et reste lisible via `events_poll` / `state_query(proposals)`.
- Le verdict retourné au tool contient `reasons[audience=ai]` et, si
  amendé, le diff résumé de l'amendement.

## 6. Transport et garanties (P2P, mode collab)

En solo, tout est local (passerelle → arbitre → banc, aucun réseau). En
collab :

- **Client → hôte** : l'enveloppe est un **commit** au sens Q-F06 — ACK
  applicatif + retry + déduplication par `proposalId`. Sources > seuil
  chunkées (mécanique 20 KB existante d'`editor_session`).
- **La source d'un artefact atteint toujours l'hôte** (D16) — jamais
  broadcastée aux pairs par défaut. Si `executionPolicy =
  replicated_revalidated`, chaque pair télécharge par hash et **repasse le
  banc localement** (cache de verdicts doc 12 §7 : coût nul si déjà validé
  ailleurs avec le même `benchVersion`).
- **Hôte → auteur** : le verdict est un commit (mêmes garanties).
  **Hôte → tous** : l'application (effets) passe par le pipeline collab
  normal (ops rebroadcastées) + entrée de journal répliquée.
- **Ordre** : les propositions entrent dans la file transactionnelle (D12)
  dans l'ordre d'arrivée hôte ; une seule en `benching`/`applying` à la fois
  au MVP.

## 7. Journal (noyau d'audit D19)

Chaque proposition produit au minimum ces entrées (séquence du journal
métier, curseur Q-E06) :

| Événement | Contenu minimal |
|-----------|-----------------|
| `proposal.submitted` | enveloppe complète (source par hash si > seuil, source au store) |
| `proposal.prefiltered` | requestType calculé, résultat P0 |
| `proposal.verdict` | verdict complet, **original + amendement** si amendé |
| `proposal.benched` | verdict du banc + metrics (doc 12 §4) |
| `proposal.applied` / `.rejected` / `.failed` | versions résultantes, raisons |

Le couple (enveloppe, verdicts, versions) rend l'action **rejouable** — la
condition posée par D19 pour le noyau non désactivable.

## 8. Exemple — fil rouge du slice (doc 11)

Plaque piégée : une enveloppe `code` avec 2 opérations (`editor_place` zone,
`memory_set` config du coût) + 1 artefact (JS embarqué qui écoute
`zoneEntered`, lit `config/owner`, écrit `state/score`, `declaredWriteSet`
en conséquence). Parcours nominal : `submitted → prefiltered(code) →
arbitrating → accepted → benching(pass) → validated → applying → applied`,
5 entrées de journal, verdict bloquant rendu au tool en ~10 s.

## 9. Constantes et versionnage

| Constante | Défaut | Rôle |
|-----------|--------|------|
| `MEOW_PROPOSAL_TIMEOUT_MS` | 60 000 | attente bloquante du verdict côté tool |
| `MEOW_PROPOSAL_MAX_OPS` | 32 | taille max du lot |
| `MEOW_PROPOSAL_MAX_ARTIFACTS` | 4 | artefacts par enveloppe |
| `envelopeVersion` | 1 | bump à tout changement de schéma ; l'hôte rejette `unsupported_envelope` au-delà de sa version |

Le schéma (enveloppe + verdict) vit dans le **manifeste versionné du canal**
(D17) — la skill générée documente donc automatiquement le format que l'IA
doit produire.

## 10. Questions restantes (propres à l'enveloppe)

- **`expiresAt`** : utile dès le MVP (propositions liées à un état volatil en
  runtime) ou post-slice ? (Reco : champ présent, non appliqué au slice.)
- **Propositions concurrentes du même auteur** : file stricte (reco MVP) ou
  pipeline ?
- **Taille du `playerPrompt` journalisé** : intégral ou tronqué (données
  privées, Q-J02) ?
