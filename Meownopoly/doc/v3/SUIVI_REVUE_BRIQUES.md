# Suivi de revue des briques logicielles V3 (Antoine + Valou)

> **⚠️ PROTOCOLE MULTI-SESSIONS — À LIRE EN PREMIER PAR TOUTE NOUVELLE SESSION CLAUDE.**
>
> Ce document pilote un travail de revue qui s'étale sur **plusieurs sessions Claude**
> (le contexte est réinitialisé entre chaque session). Toute nouvelle session doit :
>
> 1. **Lire ce fichier en entier** (état d'avancement §2, journal des modifs §4).
> 2. Reprendre au **prochain document marqué "à traiter" ou "en cours"** dans la table §2.
> 3. Pour le document en cours : le lire intégralement, puis **paragraphe par paragraphe
>    (ou bloc de paragraphes)** :
>    a. résumer les **briques logicielles** à implémenter/créer,
>    b. exposer les **concepts & définitions** principaux,
>    c. poser à Antoine/Valou une **série de questions** dont les réponses mènent à
>       des **modifications des docs**,
>    d. appliquer les modifications validées dans les docs concernés.
> 4. **Journaliser chaque modification** dans §4 (date, fichier, lignes approx., nature —
>    notes concises).
> 5. Mettre à jour la table §2 (statut + date) et, si une brique change, l'inventaire §3.
>
> But final : vérifier chaque brique logicielle **avant** d'écrire le plan
> d'implémentation V3. Ne pas implémenter de code pendant cette revue.

---

## 1. Contexte

- Cadrage V3 dans `Meownopoly/doc/v3/` (docs [00](./00_VISION.md)→[13](./13_ENVELOPPE_PROPOSITION.md) + README + RECAP), branche **V3**.
- Décisions D1→D39 déjà actées (registre : [doc 08](./08_DECISIONS_ET_QUESTIONS.md)). Le travail ici est une **revue de
  vérification** : s'assurer que chaque brique est comprise, cohérente et validée par
  les deux devs avant le plan d'implémentation.
- Les chantiers techniques M1→M13 sont décrits dans le [doc 10](./10_AUDIT_STACK_EXISTANTE.md) §9.

## 2. État d'avancement par document

Ordre de traitement = ordre de lecture du README (00 → 13). Statuts :
`à traiter` / `en cours` / `traité (date)`.

| # | Document | Statut | Notes de session |
|---|----------|--------|------------------|
| — | `README.md` + `RECAP_CADRAGE.md` | lus (contexte) | pas de revue dédiée, servent d'index |
| 00 | [`00_VISION.md`](./00_VISION.md) | traité (S1 2026-07-13) | 4 questions arbitrées : IA commerciales d'abord (locaux à terme), coût 2 modèles assumé + extension « personnalité arbitre » (nouvelle idée, tracée [doc 08](./08_DECISIONS_ET_QUESTIONS.md)), pas de revue humaine (D9 confirmé), prérequis onboarding explicité |
| 01 | [`01_ARCHITECTURE_CIBLE.md`](./01_ARCHITECTURE_CIBLE.md) | traité (S1 2026-07-13) | 4 questions arbitrées : briques §2.7/§2.8 ajoutées + [doc 14](./14_ADAPTATEUR_AGENTS.md) créé ; D40 (ProposalSession dédiée) ; P0 hôte + copie auteur ; D41 (requiresModules + module_config au MVP, variante A). 4 corrections de cohérence appliquées. Ancrages V2 vérifiés (GameplayModuleManager OK, hooks l.2634 OK) |
| 02 | [`02_CANAL_IA.md`](./02_CANAL_IA.md) | en cours (S1 2026-07-13) | passerelle MCP (M1) |
| 03 | [`03_SKILL_CLIENT_IA.md`](./03_SKILL_CLIENT_IA.md) | à traiter | skill générée au build (M12) |
| 04 | [`04_QML_GENERATIF_SANDBOX.md`](./04_QML_GENERATIF_SANDBOX.md) | à traiter | sandbox 2 étages (M9) |
| 05 | [`05_ESPACE_MEMOIRE_SNAPABLE.md`](./05_ESPACE_MEMOIRE_SNAPABLE.md) | à traiter | memory config/state (M6) |
| 06 | [`06_MOTEUR_REGLES.md`](./06_MOTEUR_REGLES.md) | à traiter | règles arbitre (le moins cadré) |
| 07 | [`07_BIBLIOTHEQUE.md`](./07_BIBLIOTHEQUE.md) | à traiter | bibliothèque GLB (M11) |
| 08 | [`08_DECISIONS_ET_QUESTIONS.md`](./08_DECISIONS_ET_QUESTIONS.md) | à traiter | registre D1→D39 + risques R1→R16 |
| 09 | [`09_QUESTIONNAIRE_CADRAGE.md`](./09_QUESTIONNAIRE_CADRAGE.md) | à traiter | 6 questions ouvertes restantes |
| 10 | [`10_AUDIT_STACK_EXISTANTE.md`](./10_AUDIT_STACK_EXISTANTE.md) | à traiter | audit V2 + chantiers M1→M13 |
| 11 | [`11_VERTICAL_SLICE.md`](./11_VERTICAL_SLICE.md) | à traiter | slice solo S1/S2/S3 |
| 12 | [`12_BANC_ESSAI_R1.md`](./12_BANC_ESSAI_R1.md) | à traiter | banc hors-process (meow_testbench) |
| 13 | [`13_ENVELOPPE_PROPOSITION.md`](./13_ENVELOPPE_PROPOSITION.md) | à traiter | schéma enveloppe/verdict |
| 14 | [`14_ADAPTATEUR_AGENTS.md`](./14_ADAPTATEUR_AGENTS.md) | créé S1 (2026-07-13) | rédigé pendant la revue du [doc 01](./01_ARCHITECTURE_CIBLE.md) ; à relire par Antoine/Valou en fin de revue |

## 3. Inventaire des briques logicielles V3 (issu de la 1re lecture générale, 2026-07-13)

Briques **à créer ou modifier**, croisées avec les chantiers M du [doc 10](./10_AUDIT_STACK_EXISTANTE.md) :

| Brique | Nature | Chantier | Docs sources | Existe en V2 ? |
|--------|--------|----------|--------------|----------------|
| Passerelle MCP `AiGatewayServer` (streamable HTTP loopback, tokens par rôle, ~10 tools, quotas) | nouveau C++ (`QtHttpServer` à installer) | M1 | 01, 02, 09 Q-E08 | non (AutomationServer = patron seulement) |
| Superviseur d'agents `AiProcessSupervisor` (spawn `claude -p`/Codex, health-check, handshake arbitre D24) + tchat ingame | nouveau C++ + QML | M2 | 00, 01, 02, 08 D10/D24/D31 | non |
| Fiabilité applicative P2P (ACK/retry/dédup commits, séquence état supersedable, chunking réparé) | couche au-dessus de Catway | M3 | 05, 08 D35, 10 §2 | non (reliable.io ≠ retransmission) |
| Transactions atomiques prepare/commit/rollback | évolution `Game`/`EditorOpBus` | M4 | 10 §3, 13 §3 | partiel (groupées, pas atomiques) |
| Journal d'événements métier `GameplayEventBus` (curseur, audit D19, adaptateur événements IA) | nouveau C++ | M5 | 02 §4, 08 D19/D33, 09 Q-E06 | non |
| Espace mémoire `memory.config/state` sur `ItemSnapable` + session + joueurs, signaux réactifs | évolution `ItemSnapable` + bus | M6 (Étape A/B/C [doc 05](./05_ESPACE_MEMOIRE_SNAPABLE.md)) | 05, 08 D7/D15/D35 | non |
| Bus d'état runtime (delta 30 Hz, snapshots réparation/structurel, resync, hash divergence D39) | nouveau protocole réseau | M6 | 05, 08 D35/D39 | non (PhysicsSession = inspiration) |
| Sauvegarde de partie `GameSave` distincte de la map | nouveau format + I/O | M7 | 08 D27, 10 §5 | non |
| Store d'artefacts par hash (refcount, GC au save, manifeste) | nouveau C++ | M8 | 08 D16/D36 | non |
| Sandbox étage 1 : banc d'essai `meow_testbench` hors-process (P0→P5, corpus, pool, cache verdicts) — **prototype R1, priorité n°1** | nouvelle cible CMake | M9 | 04, 12 | non |
| Sandbox étage 2 : confinement runtime (contexte restreint, masquage singletons, façade `Meow.GameApi`, budgets D34) | nouveau C++ (`cpp/ai/sandbox/`) | M9 | 04, 08 D13/D34 | non |
| Enveloppe de proposition + pipeline verdict (préfiltre P0, requestType, cycle de vie, verdict 2 audiences) | nouveau C++ + schémas | M-proposition | 13, 08 D11/D25/D32 | non |
| Migration d'hôte V3 (checkpoint règlement + artefacts + state + contexte arbitre) | extension `EditorSession` | M10 | 08 D37, 10 §4 | partiel (migration éditeur existe) |
| Bibliothèque officielle GLB (package asset manager étendu, manifeste D38 ; signature différée) | extension asset_server/launcher | M11 | 07, 08 D18/D29/D38 | partiel (distribution existe) |
| Génération de skill au build (manifeste du canal = source de vérité, injection pré-prompt) | nouveau script build | M12 | 03, 08 D17 | non |
| Règles : règlement structuré versionné + matérialisation hiérarchique D12 (config → DSL → QML/JS) | à cadrer (doc le moins mûr) | — | 06, 08 D8/D12/D32/D33 | non (pas de système de tour V2) |
| Qualification Linux (packaging, CI) | transversal | M13 | 08 D9, 10 §7 | non |
| Capacités canal manquantes (introspection état, édition par uuid, enums, roster, runtime input) | extension hooks + tools | M1 | 02 §5.2 | partiel |

**Prérequis bloquants identifiés** : assainir `ItemSnapable::toJSON` (concat manuelle
de strings, R4 — bloque le snapshot du banc, [doc 12](./12_BANC_ESSAI_R1.md) §10) ; installer `QtHttpServer`
(D21) ; ordre [doc 10](./10_AUDIT_STACK_EXISTANTE.md) §10 : M9 → M3 → M4 → M1 → M2 → …

**Questions encore ouvertes ([doc 09](./09_QUESTIONNAIRE_CADRAGE.md))** : Q-E06 (résumé d'événements/curseur),
Q-E08 (manifeste 10 tools), Q-J02 (données privées), Q-J04 (indicateurs arbitrage),
Q-J06 (critères de repli D1), Q-J08 (responsables par famille Antoine/Valou).

## 4. Journal des modifications de docs (notes concises : date, fichier, lignes, nature)

| Date | Session | Fichier | Lignes (~) | Modification |
|------|---------|---------|------------|--------------|
| 2026-07-13 | S1 | `SUIVI_REVUE_BRIQUES.md` | — | Création du document de suivi + inventaire initial des briques (1re lecture générale) |
| 2026-07-13 | S1 | [`00_VISION.md`](./00_VISION.md) | ~37 (§2 idée 1) | Précision : IA commerciales (`claude -p`/Codex) en priorité, agents locaux à terme hors premier jalon |
| 2026-07-13 | S1 | [`00_VISION.md`](./00_VISION.md) | ~130 (§4, avant Topologie) | Ajout note « Extension prévue » : personnalité de l'arbitre avec objectifs propres (divertissement, même solo) |
| 2026-07-13 | S1 | [`00_VISION.md`](./00_VISION.md) | ~225 (§6 tableau) | Correction incohérence : « Canal WS dédié » → « Canal MCP local dédié (D20) » |
| 2026-07-13 | S1 | [`00_VISION.md`](./00_VISION.md) | ~252 (§8) | Coût 2 modèles assumé tel quel (pas d'arbitre allégé) + renvoi note personnalité |
| 2026-07-13 | S1 | [`00_VISION.md`](./00_VISION.md) | ~256 (§8) | Prérequis d'onboarding explicité : compte fournisseur + CLI installé, le jeu guide mais ne fournit pas |
| 2026-07-13 | S1 | [`08_DECISIONS_ET_QUESTIONS.md`](./08_DECISIONS_ET_QUESTIONS.md) | ~633 (§2 IA arbitre) | Nouvelle question ouverte : personnalité/objectifs propres de l'arbitre (au-delà du paramétrage D10) |
| 2026-07-13 | S1 | [`01_ARCHITECTURE_CIBLE.md`](./01_ARCHITECTURE_CIBLE.md) | ~126 (fin §2) | Ajout briques §2.7 (adaptateur agents + tchat ingame, M2) et §2.8 (journal d'événements métier, M5) — Q1 [doc 01](./01_ARCHITECTURE_CIBLE.md), option A |
| 2026-07-13 | S1 | [`01_ARCHITECTURE_CIBLE.md`](./01_ARCHITECTURE_CIBLE.md) | ~160 (§3 tableau) | Ajout lignes adaptateur agents (LauncherManager) et journal d'événements (signaux existants) |
| 2026-07-13 | S1 | [`14_ADAPTATEUR_AGENTS.md`](./14_ADAPTATEUR_AGENTS.md) | — | Création du [doc 14](./14_ADAPTATEUR_AGENTS.md) : adaptateur d'agents & tchat ingame (rôle, responsabilités, socle V2, questions ouvertes) |
| 2026-07-13 | S1 | `README.md` (v3) | ~46 (table) | Ajout ligne [doc 14](./14_ADAPTATEUR_AGENTS.md) dans l'ordre de lecture |
| 2026-07-13 | S1 | [`01_ARCHITECTURE_CIBLE.md`](./01_ARCHITECTURE_CIBLE.md) | ~109 (§2.5) | Q2 [doc 01](./01_ARCHITECTURE_CIBLE.md) tranchée : transport des propositions = session dédiée (D40), pas d'extension d'EditorSession |
| 2026-07-13 | S1 | [`08_DECISIONS_ET_QUESTIONS.md`](./08_DECISIONS_ET_QUESTIONS.md) | ~578 (fin §1) | Nouvelle décision D40 : ProposalSession dédiée (patron COLLAB_SESSION_PATTERN, plage messages V3 propre, fiabilité M3) |
| 2026-07-13 | S1 | [`12_BANC_ESSAI_R1.md`](./12_BANC_ESSAI_R1.md) | ~97 (§3) | Q3 [doc 01](./01_ARCHITECTURE_CIBLE.md) : P0 exécuté chez l'hôte (fait foi) + copie best-effort chez l'auteur (fail-fast), même code aux deux endroits |
| 2026-07-13 | S1 | [`13_ENVELOPPE_PROPOSITION.md`](./13_ENVELOPPE_PROPOSITION.md) | ~109 (§3 notes) | requestType recalculé par le P0 de l'hôte à réception, jamais repris d'une enveloppe reçue |
| 2026-07-13 | S1 | [`13_ENVELOPPE_PROPOSITION.md`](./13_ENVELOPPE_PROPOSITION.md) | ~97, ~126 (§3) | D41 : champ `requiresModules` dans artifacts[] + notes (vérif P0, erreur missing_module, module_config = op structure du même lot) |
| 2026-07-13 | S1 | [`12_BANC_ESSAI_R1.md`](./12_BANC_ESSAI_R1.md) | ~67, ~95, ~101 | D41 : snapshot du job étendu à l'état des modules ; P0 vérifie requiresModules ; P1 recharge les modules |
| 2026-07-13 | S1 | [`09_QUESTIONNAIRE_CADRAGE.md`](./09_QUESTIONNAIRE_CADRAGE.md) | ~105-120 (Q-E08) | Manifeste MVP passe à 11 tools : ajout `module_config(id, enabled, params?)` (D41) |
| 2026-07-13 | S1 | [`08_DECISIONS_ET_QUESTIONS.md`](./08_DECISIONS_ET_QUESTIONS.md) | ~600 (fin §1) | Nouvelle décision D41 : dépendances requiresModules + tool module_config au MVP |
| 2026-07-13 | S1 | [`01_ARCHITECTURE_CIBLE.md`](./01_ARCHITECTURE_CIBLE.md) | ~137 (§2.6) | Note D41 : modules gameplay pilotables par l'IA (module_config + requiresModules) |
| 2026-07-13 | S1 | [`11_VERTICAL_SLICE.md`](./11_VERTICAL_SLICE.md) | ~50, ~98 | S1 exerce module_config(stats) + requiresModules ; table §4 passe au manifeste 11 tools |
| 2026-07-13 | S1 | [`01_ARCHITECTURE_CIBLE.md`](./01_ARCHITECTURE_CIBLE.md) | ~40 (§1), ~77 (§2.3), ~90 (§2.4), ~185 (§4 ét.5) | 4 corrections de cohérence : pipeline P0→arbitre→banc figé (docs [12](./12_BANC_ESSAI_R1.md)/[13](./13_ENVELOPPE_PROPOSITION.md)), sandbox 2 étages (D26), transport runtime tranché (D35) ×2 |
| 2026-07-13 | S1 | [`08_DECISIONS_ET_QUESTIONS.md`](./08_DECISIONS_ET_QUESTIONS.md) | ~625 (fin §1) | Nouvelle décision D42 : banc exposé à l'IA cliente — artifact_dryrun (MVP, local, quota 10) + session atelier interactive (palier 2 tracé) |
| 2026-07-13 | S1 | [`09_QUESTIONNAIRE_CADRAGE.md`](./09_QUESTIONNAIRE_CADRAGE.md) | ~105-122 (Q-E08) | Manifeste MVP passe à 12 tools : ajout `artifact_dryrun` (D42) |
| 2026-07-13 | S1 | [`12_BANC_ESSAI_R1.md`](./12_BANC_ESSAI_R1.md) | ~200 (§6 bis), ~250 (§9), ~285 (§11) | Nouveau §6 bis mode atelier (D42) ; constante MEOW_BENCH_DRYRUN_QUOTA ; palier 2 (session interactive) tracé en §11 |
| 2026-07-13 | S1 | [`02_CANAL_IA.md`](./02_CANAL_IA.md) | ~180 (§5.2) | Ajout capacité artifact_dryrun (D42) au catalogue à créer |
| 2026-07-13 | S1 | [`11_VERTICAL_SLICE.md`](./11_VERTICAL_SLICE.md) | ~98 (§4) | Table tools : manifeste 12 tools, artifact_dryrun non requis par le slice |
| 2026-07-17 | S2 | *(code, branche V3_earlytest)* | — | **Implémentation Phase 0 + Piste A + Piste D** (commits cf21c142→5d074596) : P0-2 toJSON assaini, P0-3 plage 0x60-0x7F, banc `meow_testbench` complet (P0→P5), `GameplayEventBus`. **Mesures R1 ([doc 12](./12_BANC_ESSAI_R1.md) §8) : corpus 9/9 conformes, 4 runs reproductibles, froid ~50 ms, masquage prouvé (`acces_singleton` → ReferenceError)** — les 5 critères R1 verts au MVP ; résidus non confinés documentés dans le commit 5d074596 (globals JS/Qt.* = défense P0 seule). **Décision go/no-go R1 (Q-J06) à prendre par Antoine/Valou.** P0-1 QtHttpServer toujours à installer (absent du kit, vérifié) |
| 2026-07-17 | S2 | [`15_PLAN_IMPLEMENTATION.md`](./15_PLAN_IMPLEMENTATION.md) | — | Création du plan d'implémentation V3 (demande Antoine, **draft** : la revue docs [02](./02_CANAL_IA.md)→[13](./13_ENVELOPPE_PROPOSITION.md) n'est pas terminée — le plan référence ses docs sources pour amendement). Phases 0→5 + transversal Linux, fichiers impactés vérifiés contre le code, complexité par tâche, lots parallélisables |

## 5. Questions/réponses en attente (inter-sessions)

*(Reporter ici les questions posées à Antoine/Valou non encore répondues en fin de
session, pour que la session suivante les repose.)*

- **[Doc 02](./02_CANAL_IA.md), Q1 — validation de Q-E06** (schéma résumé d'événements + curseur) :
  posée, en attente de réponse (valider → D43 / amender / laisser ouverte).
  Suggestion associée : les verdicts de dry-run (D42) n'entrent pas au journal partagé.
- **[Doc 02](./02_CANAL_IA.md), Q2 — frontière tools locaux vs proposition** : pas encore posée.
- **[Doc 02](./02_CANAL_IA.md), Q3 — quotas du canal (chiffrer maintenant ou à l'implémentation)** : pas encore posée.
