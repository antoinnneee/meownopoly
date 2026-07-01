#ifndef LEVEL_MODULE_H
#define LEVEL_MODULE_H

#include "gameplay_module.h"

// Type complet requis : experienceModule est un Q_PROPERTY pointeur, moc doit
// connaître le type complet (sinon "Pointer Meta Types must point to
// fully-defined types").
#include "experience_module.h"

#include <QHash>

/// Module de niveau : niveau par joueur (départ 1, plafond `maxLevel`
/// configurable, défaut 100). Détient le sous-module `ExperienceModule` (créé
/// et enregistré dans le ctor via `registerSubModule`), qui pilote les montées
/// de niveau par accumulation d'XP.
///
/// C'est `LevelModule::leveledUp` qui annonce le passage de niveau, qu'il vienne
/// d'un `setLevel` direct ou d'un level-up déclenché par l'ExperienceModule.
///
/// Sémantique `enabled` : `setLevel` est gatée par `effectiveEnabled()`. Les
/// lectures restent permises.
class LevelModule : public GameplayModule
{
    Q_OBJECT

    // Niveau maximal atteignable. Côté QML : `levelModule.maxLevel`.
    Q_PROPERTY(int maxLevel READ maxLevel WRITE setMaxLevel NOTIFY maxLevelChanged)
    // Sous-module d'expérience (accessible aussi via moduleById("experience")).
    Q_PROPERTY(ExperienceModule *experienceModule READ experienceModule CONSTANT)

public:
    explicit LevelModule(QObject *parent = nullptr);

    int maxLevel() const { return m_maxLevel; }
    void setMaxLevel(int maxLevel);

    ExperienceModule *experienceModule() const { return m_experience; }

    // ── Lecture (autorisée même désactivé) ────────────────────────────────
    /// Niveau du joueur (1 par défaut).
    Q_INVOKABLE int level(const QString &playerId) const;

    // ── Mutation (no-op si effectiveEnabled() faux, retour false) ─────────
    /// Fixe le niveau (clampé à [1, maxLevel]). Émet levelChanged, et leveledUp
    /// si le niveau augmente (une émission par appel).
    Q_INVOKABLE bool setLevel(const QString &playerId, int level);

    void reset() override;

signals:
    void levelChanged(const QString &playerId, int level);
    /// Le joueur vient de gagner un niveau (niveau atteint en argument).
    void leveledUp(const QString &playerId, int newLevel);
    void maxLevelChanged();

private:
    // playerId -> niveau (absence = 1).
    QHash<QString, int> m_levels;
    int m_maxLevel = 100;
    ExperienceModule *m_experience = nullptr;
};

#endif // LEVEL_MODULE_H
