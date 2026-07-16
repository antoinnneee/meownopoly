# 11 — Vertical slice V3 (D30)

> **Statut : défini le 2026-07-12 (D30).** Plan du premier parcours end-to-end
> qui prouve le pivot. Répond à Q-J05 et au critère produit posé par D9/A06 :
> *« création d'un item qui modifie le gameplay, la physique, d'autres éléments
> et les interactions joueur »*.

## 1. Objectif et périmètre

**Prouver la boucle complète du pivot sur le mode le plus simple** : un joueur,
dans l'**éditeur solo assisté** (premier mode livré, D23), demande en langage
naturel un élément de gameplay nouveau ; son IA cliente le matérialise via le
canal MCP ; l'arbitre le juge ; le banc d'essai le valide ; l'élément vit dans
la partie.

Le slice est **mince mais traversant** : chaque brique du pivot est traversée
au moins une fois, aucune n'est traitée en profondeur.

**Un joueur = les deux rôles IA quand même** (D6/D9) : même en solo, la
proposition passe par l'arbitre. Le slice valide donc l'architecture à deux
modèles sans la couche réseau.

## 2. Scénario fil rouge

> Le joueur tape dans le tchat ingame : *« Ajoute une plaque piégée : quand un
> chat marche dessus, il est projeté en l'air et perd 5 points, sauf s'il
> possède la case. »*

Cet exemple est choisi parce qu'il touche **tout le critère produit** :

| Exigence D9/A06 | Où dans l'exemple |
|-----------------|-------------------|
| Modifie le gameplay | perte de points, exception de propriété |
| Modifie la physique | projection du chat (impulse via la façade) |
| Touche d'autres éléments | lit la propriété de la case (mémoire) |
| Interaction joueur | déclenchement à l'entrée de zone |

Réalisation attendue : l'IA compose une **zone** (brique existante) + un
**artefact JS embarqué** qui s'abonne à l'entrée de zone (`events.on`), lit la
mémoire (`memory.get` propriétaire), applique l'effet (`stats.addModifier`,
impulsion via la façade) et écrit le score (`memory.set`).

## 3. Les trois scénarios end-to-end (D30)

### S1 — Création d'un élément avec config + comportement

1. Invocation in-app (tchat ingame) : l'app spawne `claude -p` (puis Codex en
   variante) avec config MCP + token `proposer` + pré-prompt skill (D10/D17/D20).
2. L'IA observe : `state_query(tiles)`, `screenshot` (≤ 5, D22).
3. L'IA agit : `module_config(stats, enabled)` (dépendance de l'artefact,
   D41), `editor_place(zone, …)`, `memory_set(config, …)`,
   `artifact_submit(source JS, target uuid, requiresModules: ["stats"])`.
4. L'élément apparaît dans l'éditeur, son comportement est actif, sa mémoire
   visible.

**Réussite** : l'élément fonctionne (marcher sur la plaque produit l'effet),
il est sauvegardé/rechargé avec la map (re-validation au chargement, [doc 04](./04_QML_GENERATIF_SANDBOX.md)
§3.5), l'undo structurel le retire proprement.

### S2 — Proposition arbitrée puis appliquée

1. Le `artifact_submit` de S1 crée une **enveloppe de proposition** (D11) :
   auteur, intention, opérations, artefact, write-set, version.
2. Routage selon la config de grain (D25) : l'artefact JS passe
   obligatoirement par l'**arbitre** (second agent, token `arbiter`), invoqué
   par l'app avec le contexte de la proposition.
3. Verdict de l'arbitre (via `arbiter_verdict`) : accepté (éventuellement
   amendé, journalisé D19).
4. **Banc d'essai hors-process** (D26, spécifié [doc 12](./12_BANC_ESSAI_R1.md)) : la carte est
   réinstanciée depuis un snapshot dans un process de test, l'artefact
   instancié, budgets vérifiés (chargement, boucle, CPU/mémoire — D34).
5. Application dans la partie ; le journal contient proposition, verdict,
   raisons, version.

**Réussite** : aucune proposition n'atteint la partie sans les étapes 2→4 ;
un artefact qui boucle à l'infini est tué **au banc**, la partie n'a jamais
gelé ; le handshake arbitre (D24) a été vérifié avant d'ouvrir le mode.

### S3 — Rejet actionnable et itération

1. Variante : l'IA soumet un artefact volontairement problématique (boucle
   infinie, import interdit, budget dépassé) **ou** l'arbitre refuse pour une
   raison contextuelle (déséquilibre).
2. Le rejet revient à l'IA cliente **sous forme actionnable** : erreur
   structurée `{code, message, details, retryable}` pour les échecs mécaniques
   / banc d'essai ; raisons de l'arbitre en clair pour les refus contextuels.
3. L'IA corrige et re-soumet dans **la même invocation ou la suivante**
   (le résumé d'événements injecté mentionne le verdict, Q-E06) ; la seconde
   proposition aboutit.

**Réussite** : l'IA converge en ≤ 2 itérations sur les cas d'échec mécanique ;
le joueur voit dans le tchat une explication compréhensible du refus.

## 4. Briques traversées ↔ chantiers

| Brique (traversée a minima) | Chantier [doc 10](./10_AUDIT_STACK_EXISTANTE.md) | Décisions |
|-----------------------------|-----------------|-----------|
| Passerelle MCP streamable HTTP + tokens par rôle | M1 | D20/D21 |
| Tools (sous-ensemble du manifeste MVP à 12 tools traversé par le slice — `help`, `roster_edit` et `artifact_dryrun` non requis) : `state_query`, `editor_place`, `editor_edit`, `memory_set`, `module_config` (D41), `artifact_submit`, `events_poll`, `screenshot`, `arbiter_verdict` | M1 | Q-E08 |
| Adaptateur agents (spawn `claude -p`, supervision, pré-prompt) + tchat ingame minimal | M-adaptateur | D10/D17 |
| Skill générée du manifeste, injectée en pré-prompt | M-skill | D17 |
| Handshake + challenge arbitre | M-adaptateur | D24 |
| Enveloppe de proposition + journal noyau d'audit | M-proposition | D11/D19 |
| Banc d'essai hors-process (snapshot → test → verdict) | M-sandbox | D26, spec [doc 12](./12_BANC_ESSAI_R1.md) |
| Confinement runtime minimal (contexte restreint + façade `Meow.GameApi` réduite aux besoins du fil rouge) | M-sandbox | D13, D34 |
| Mémoire `config` sur tuile (persistance + undo structurel) | M-mémoire | D7/D15 |

**Non requis par le slice** (différés sans risque) : bus d'état runtime
30 Hz (le solo lit/écrit en direct), couche réseau V3 (pas de pair), skill
Codex (Claude d'abord, Codex en variante de S1 si le temps le permet),
bibliothèque GLB, migration, sauvegarde de partie runtime.

## 5. Critères d'acceptation globaux

1. **Aucun accès hors canal** : l'IA n'a jamais touché l'`AutomationServer` ;
   le serveur MCP refuse une connexion sans token ou non-loopback.
2. **Aucun gel** : le thread GUI n'a jamais été bloqué par un artefact
   candidat (les cas pathologiques meurent au banc, D26).
3. **Audit complet** : chaque proposition du slice est rejouable depuis le
   journal (proposition, verdict, raisons, version — D19).
4. **Économie mesurée** : tokens consommés par invocation relevés (schémas
   tools + pré-prompt) — première mesure réelle pour Q-E08/[doc 02](./02_CANAL_IA.md) §3.
5. **Critère produit D9** : la plaque piégée du fil rouge fonctionne de bout
   en bout, survit à un save/load, et son retrait par undo laisse la map saine.

## 6. Hors périmètre explicite (post-slice)

Dans l'ordre suggéré ensuite (aligné D23 + [doc 08](./08_DECISIONS_ET_QUESTIONS.md) §4) : couche réseau V3 →
slice **collaboratif** (proposition d'un client distant, autorité hôte) →
bus d'état + slice **runtime** (règles déclenchées en partie) → undo
concurrent, reconnexion/resync, migration hôte/arbitre, sauvegarde de partie,
bibliothèque GLB.
