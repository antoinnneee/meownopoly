/*
 *      V3 / T4-4 — RulesEngine (D8/D12/D33) : runtime des règles de partie
 *
 * Singleton QML (`MeowRules 1.0 · RulesEngine`) qui tient le règlement
 * structuré versionné (Rulebook, doc v3/06 §5.1) et exécute les règles
 * matérialisées sur les événements du GameplayEventBus, dans l'ordre
 * déterministe D33 : physique → mémoire → actions → tick.
 *
 * Principes (doc v3/06 §5) :
 *  - AUTORITÉ HÔTE (D33) : `hostAuthority` doit être vrai pour exécuter quoi
 *    que ce soit — un client ne déclenche jamais une règle localement, il
 *    reçoit les effets par leurs canaux de réplication (StateBus, édition).
 *  - Le règlement se modifie UNIQUEMENT par opérations `rulebook_set`
 *    (applyRulebookOp) issues du pipeline de proposition D11 — chaque
 *    application bump `version` (= champ `rulebook` de baseVersion, doc 13)
 *    et publie l'événement durable `rules.changed`.
 *  - PIPELINE D33 : les événements admis par le bus sont classés en 4 phases
 *    (types 4xx = physique, 5xx = mémoire, 2xx-3xx = actions/édition,
 *    1xx/6xx = tick/divers) et traités par pas de simulation — phases dans
 *    l'ordre, puis `seq` croissante dans la phase. Le pas est coalescé sur le
 *    tour de boucle d'événements (drain différé) ; tick() publie en plus un
 *    `game.tick` explicite.
 *  - CASCADES : chaque effet est produit avec `causeId` = événement
 *    déclencheur → les garde-fous D12 du bus (profondeur, budget, cycles) et
 *    les plafonds D35 de la mémoire s'appliquent, y compris aux écritures
 *    mémoire faites pendant l'exécution d'un effet (le MemoryChanged ingéré
 *    hérite du causeId courant).
 *  - FORMES D12 : `module` → GameplayModuleManager ; `dsl` → interpréteur
 *    borné (conditions ET, actions fermées memory.set / event.emit /
 *    module.config) ; `artifact` → PAS exécuté ici : publication de
 *    `rule.triggered` consommée par la couche sandbox (S-6/D13). Aucun code
 *    ne contourne le banc (D32).
 *
 * Persistance : toJson()/loadJson() portent { rulebook } pour la sauvegarde de
 * partie (M7/T4-2) et le checkpoint de migration (D37/T4-3 — priorité 1).
 */
#ifndef MEOW_RULES_ENGINE_H
#define MEOW_RULES_ENGINE_H

#include <QJsonObject>
#include <QObject>
#include <QQmlEngine>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

#include "rulebook.h"

class RulesEngine : public QObject
{
    Q_OBJECT

    // Version courante du règlement (= baseVersion.rulebook des enveloppes).
    Q_PROPERTY(qint64 version READ version NOTIFY rulebookChanged)
    Q_PROPERTY(int ruleCount READ ruleCount NOTIFY rulebookChanged)
    // Interrupteur général du moteur (débogage/banc). Défaut : actif.
    Q_PROPERTY(bool engineEnabled READ engineEnabled WRITE setEngineEnabled
                   NOTIFY engineEnabledChanged)
    // Autorité D33 : vrai chez l'hôte (et en solo), faux chez un client — un
    // client garde le règlement en copie passive mais n'exécute rien.
    Q_PROPERTY(bool hostAuthority READ hostAuthority WRITE setHostAuthority
                   NOTIFY hostAuthorityChanged)
    // Compteurs d'observation (harness/audit).
    Q_PROPERTY(quint64 triggeredCount READ triggeredCount NOTIFY statsChanged)
    Q_PROPERTY(quint64 effectRejectedCount READ effectRejectedCount NOTIFY statsChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    static void registerQml();
    static RulesEngine *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    qint64  version() const        { return m_book.version; }
    int     ruleCount() const      { return m_book.rules.size(); }
    bool    engineEnabled() const  { return m_engineEnabled; }
    void    setEngineEnabled(bool enabled);
    bool    hostAuthority() const  { return m_hostAuthority; }
    void    setHostAuthority(bool host);
    quint64 triggeredCount() const { return m_triggeredCount; }
    quint64 effectRejectedCount() const { return m_effectRejectedCount; }
    QString lastError() const      { return m_lastError; }

    // Câble le moteur sur ses sources (GameplayEventBus + MemoryStore).
    // Idempotent ; appelé au boot par le bootstrap QML (patron connectSources
    // du bus). L'ingestion mémoire publie les écritures session/joueur comme
    // événements `memory.changed` sur le bus (doc v3/06 §5.3).
    Q_INVOKABLE void connectSources();

    // ---- Règlement (doc v3/06 §5.2) ----
    // Applique une opération `rulebook_set` (payload de l'op d'enveloppe D11) :
    //   { mode: "set",         rulebook: {…} }           remplace le document
    //   { mode: "add_rule",    rule: {…} }               ajoute (id unique)
    //   { mode: "update_rule", rule: {…} }               remplace par id
    //   { mode: "remove_rule", ruleId: "…" }             retire
    //   { mode: "clear" }                                vide le règlement
    // `author`/`proposalId` tracent l'origine (audit D11). Bump `version` et
    // publie `rules.changed` si appliquée. false + lastError sinon.
    Q_INVOKABLE bool applyRulebookOp(const QVariantMap &op,
                                     const QString &author = QStringLiteral("host"),
                                     const QString &proposalId = QString());

    // Vues du règlement (QML/harness/canal).
    Q_INVOKABLE QVariantMap rulebookMap() const;
    Q_INVOKABLE QVariantList rulesList() const;

    // ---- Pas de simulation (D33/D12) ----
    // Publie un événement `game.tick` (hôte) — support du tour orchestré par
    // règle/arbitre, sans primitive native de tour. No-op sans autorité.
    Q_INVOKABLE void tick();
    // Draine immédiatement les phases en attente (tests/banc). Retourne le
    // nombre d'événements traités.
    Q_INVOKABLE int drainNow();

    // ---- Persistance (M7/T4-2, checkpoint D37/T4-3) ----
    QJsonObject toJson() const;
    bool loadJson(const QJsonObject &obj, QString *error = nullptr);
    Q_INVOKABLE QVariantMap toVariantMap() const;
    Q_INVOKABLE bool loadVariantMap(const QVariantMap &map);

    // Remise à zéro (nouvelle partie) : règlement vide, version conservée
    // (monotone — les enveloppes en vol restent comparables).
    Q_INVOKABLE void reset();

signals:
    void rulebookChanged();
    void engineEnabledChanged();
    void hostAuthorityChanged();
    void statsChanged();
    void lastErrorChanged();
    // Émis à chaque déclenchement d'une règle (après exécution des effets pour
    // `dsl`, à la notification pour `artifact` — consommé par la couche S-6).
    void ruleTriggered(const QString &ruleId, const QString &form,
                       const QVariantMap &event);

private slots:
    void onBusEvent(const QVariantMap &event);

private:
    explicit RulesEngine(QObject *parent = nullptr);
    static RulesEngine *m_instance;

    void setLastError(const QString &error);
    void publishRulesChanged(const QString &mode, const QString &ruleId,
                             const QString &author, const QString &proposalId);

    // Phase D33 d'un type d'événement (0 physique, 1 mémoire, 2 actions, 3 tick).
    static int phaseOf(int type);
    void scheduleDrain();
    int  drainBuckets();
    void evaluateEvent(const QVariantMap &event);
    bool ruleMatches(const meow::rules::Rule &rule, const QString &canalType,
                     const QVariantMap &event) const;
    bool conditionHolds(const meow::rules::RuleCondition &cond,
                        const QVariantMap &event) const;
    QVariant resolveSource(const QString &source, const QVariantMap &event) const;
    void executeRule(const meow::rules::Rule &rule, const QVariantMap &event);
    bool executeEffect(const meow::rules::RuleEffect &effect,
                       const meow::rules::Rule &rule, const QVariantMap &event);

    meow::rules::Rulebook m_book;

    bool m_engineEnabled = true;
    bool m_hostAuthority = true;   // vrai en solo/hôte ; les clients le baissent
    bool m_sourcesConnected = false;

    // File par phase D33 (chaque entrée = projection QVariantMap du bus, avec
    // sa `seq` pour l'ordre intra-phase).
    QVector<QVariantMap> m_buckets[4];
    bool m_drainScheduled = false;
    bool m_draining       = false;

    // Contexte causal courant : id de l'événement en cours d'évaluation. Les
    // MemoryChanged produits par un effet en héritent (cascade D12 traçée).
    QString m_currentCauseId;

    quint64 m_triggeredCount      = 0;
    quint64 m_effectRejectedCount = 0;
    QString m_lastError;

    // Bornes anti-emballement locales (en plus des garde-fous D12 du bus) :
    // passes max d'un drainage (des événements peuvent arriver pendant le
    // drain), événements max par passe.
    static constexpr int kMaxDrainPasses     = 8;
    static constexpr int kMaxEventsPerPass   = 1024;
};

#endif // MEOW_RULES_ENGINE_H
