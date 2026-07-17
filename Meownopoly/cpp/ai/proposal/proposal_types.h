/*
 *      V3 / Phase 2 — S-1 · Enveloppe de proposition + cycle de vie (doc v3 13)
 *
 * Types fondamentaux du pivot de proposition (D11) : catégorie de requête
 * (`requestType`), états du cycle de vie, et constantes MEOW_PROPOSAL_*.
 *
 * Périmètre S-1 : le SCHÉMA de l'enveloppe (proposal_envelope) et sa MACHINE À
 * ÉTATS (proposal_lifecycle). Le verdict à deux audiences et son retour MCP
 * bloquant sont S-2 (le cycle de vie n'accepte ici qu'une issue d'arbitrage
 * sous forme d'énumération — le document de verdict complet est bâti en S-2 et
 * pilote ces mêmes transitions).
 *
 * Aucune dépendance réseau ni QML : types Qt purs, réutilisables côté hôte
 * (P0 fait foi) comme côté auteur (P0 fail-fast, confort local, doc 12 §3).
 */
#ifndef MEOW_PROPOSAL_TYPES_H
#define MEOW_PROPOSAL_TYPES_H

#include <QString>

// ---------------------------------------------------------------------------
// Constantes et versionnage (doc v3 13 §9). Surclassables à la compilation via
// -DMEOW_PROPOSAL_* pour les bancs de test ; les valeurs par défaut sont celles
// figées par la spécification.
// ---------------------------------------------------------------------------

// Attente bloquante du verdict côté tool MCP (consommée en S-2). Défini ici car
// il fait partie du bloc de constantes de l'enveloppe (source de vérité unique).
#ifndef MEOW_PROPOSAL_TIMEOUT_MS
#define MEOW_PROPOSAL_TIMEOUT_MS 60000
#endif

// Taille max du lot d'opérations d'une enveloppe.
#ifndef MEOW_PROPOSAL_MAX_OPS
#define MEOW_PROPOSAL_MAX_OPS 32
#endif

// Nombre max d'artefacts (QML/JS embarqué) par enveloppe.
#ifndef MEOW_PROPOSAL_MAX_ARTIFACTS
#define MEOW_PROPOSAL_MAX_ARTIFACTS 4
#endif

// Taille max de la source d'un artefact embarqué (doc 13 §3 : « ≤ 20 KB »,
// aligné sur le préfiltre statique A4). En octets.
#ifndef MEOW_PROPOSAL_MAX_ARTIFACT_BYTES
#define MEOW_PROPOSAL_MAX_ARTIFACT_BYTES 20480
#endif

namespace meow::proposal {

// Version courante du schéma d'enveloppe (doc 13 §9 : bump à tout changement ;
// l'hôte rejette `unsupported_envelope` au-delà de sa version).
constexpr int    kEnvelopeVersion       = 1;
constexpr int    kMaxOps                = MEOW_PROPOSAL_MAX_OPS;
constexpr int    kMaxArtifacts          = MEOW_PROPOSAL_MAX_ARTIFACTS;
constexpr int    kMaxArtifactBytes      = MEOW_PROPOSAL_MAX_ARTIFACT_BYTES;
constexpr int    kProposalTimeoutMs     = MEOW_PROPOSAL_TIMEOUT_MS;

// ---------------------------------------------------------------------------
// requestType (doc 13 §3) — TOUJOURS recalculé par le P0, jamais repris du
// champ déclaré par l'auteur (c'est ce qui rend le plancher D25 non
// contournable). Ordonné du plus permissif au plus contraint : la valeur d'une
// enveloppe est le MAX des catégories de ses opérations et artefacts.
//   data_safe : poses / écritures dans les quotas ;
//   structure : suppressions, resize, roster, activation de module ;
//   rules     : modification du règlement (D12) ;
//   code      : au moins un artefact QML/JS embarqué.
// ---------------------------------------------------------------------------
enum class RequestType {
    DataSafe  = 0,
    Structure = 1,
    Rules     = 2,
    Code      = 3,
};

// ---------------------------------------------------------------------------
// États du cycle de vie (doc 13 §2). Un seul écrivain d'états : l'hôte.
// L'auteur ne voit que des transitions notifiées.
// ---------------------------------------------------------------------------
enum class ProposalState {
    Draft,               // construite, pas encore soumise
    Submitted,           // reçue par l'hôte
    Prefiltered,         // requestType recalculé + P0 mécanique passé
    Queued,              // arbitre indisponible (D31) : en file, pas perdu
    Arbitrating,         // soumise à l'arbitre (code/règles, ou config D25)
    Amended,             // arbitre a amendé (repasse au banc si code, D32)
    Benching,            // au banc d'essai (artefacts, D26)
    Validated,           // prête à appliquer (P0 + banc/arbitre OK)
    Applying,            // application atomique en cours (staging hôte)
    Applied,             // état terminal : effets appliqués + broadcast

    // États terminaux de rejet / échec (tous journalisés, D19).
    RejectedMechanical,  // P0 : write-set/quota/version/module invalide
    RejectedArbiter,     // verdict arbitre = rejeté
    RejectedBench,       // banc : fail (fuite, dépassement budget, hors write-set)
    Failed,              // échec pendant l'application
};

// Issue d'un arbitrage (entrée de la transition depuis Arbitrating). Le
// document de verdict complet (reasons 2 audiences, amendment, benchReport) est
// construit en S-2 ; S-1 ne modélise que la branche empruntée.
enum class VerdictOutcome {
    Accepted,   // → benching (si code) ou validated
    Rejected,   // → rejected(arbiter)
    Amended,    // → amended → benching (code) / validated (données)
};

// Résultat d'un passage au banc (entrée de la transition depuis Benching).
enum class BenchOutcome {
    Pass,   // → validated
    Fail,   // → rejected(bench)
};

// --- Helpers de nommage (chaînes stables, journal / schéma canal) ---
QString      requestTypeName(RequestType t);
RequestType  requestTypeFromName(const QString &name, bool *ok = nullptr);

QString       proposalStateName(ProposalState s);
ProposalState proposalStateFromName(const QString &name, bool *ok = nullptr);
bool          isTerminalState(ProposalState s);
bool          isRejectedState(ProposalState s);

QString        verdictOutcomeName(VerdictOutcome v);
VerdictOutcome verdictOutcomeFromName(const QString &name, bool *ok = nullptr);

} // namespace meow::proposal

#endif // MEOW_PROPOSAL_TYPES_H
