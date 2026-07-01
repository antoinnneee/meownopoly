#ifndef EXPERIENCE_MODULE_H
#define EXPERIENCE_MODULE_H

#include "gameplay_module.h"

#include <QHash>

// Forward declaration : m_level n'est PAS un Q_PROPERTY pointeur, moc n'a donc
// pas besoin du type complet. Injecté par LevelModule au câblage (setLevelModule).
class LevelModule;

/// Module d'expérience : **sous-module** de `LevelModule`. XP par joueur ;
/// quand l'XP atteint le seuil `xpForNextLevel`, déclenche un level-up via le
/// module de niveau parent. L'XP excédentaire est conservée (carry-over) et un
/// seul gain peut faire monter plusieurs niveaux (multi-level-up).
///
/// Courbe (documentée) : `xpForNextLevel(level) = round(100 * level^1.5)`.
/// Niveau 1 → 100, niveau 2 → 283, niveau 3 → 520, … (croissance douce).
///
/// Au niveau max : l'XP est **clampée** à `xpForNextLevel` (barre pleine, plus
/// de level-up possible).
///
/// Sémantique `enabled` : `addXp` est gatée par `effectiveEnabled()` (donc off
/// si le LevelModule parent est désactivé). Les lectures restent permises.
class ExperienceModule : public GameplayModule
{
    Q_OBJECT

public:
    explicit ExperienceModule(QObject *parent = nullptr);

    /// Injecte le module de niveau parent (appelé par LevelModule au câblage).
    void setLevelModule(LevelModule *level) { m_level = level; }

    // ── Lecture (autorisée même désactivé) ────────────────────────────────
    /// XP courante accumulée vers le prochain niveau.
    Q_INVOKABLE int xp(const QString &playerId) const;
    /// Seuil d'XP requis pour passer au niveau suivant (dépend du niveau courant).
    Q_INVOKABLE int xpForNextLevel(const QString &playerId) const;

    // ── Mutation (no-op si effectiveEnabled() faux, retour false) ─────────
    /// Ajoute `amount` XP. Gère le carry-over et le multi-level-up. Renvoie
    /// false si désactivé (parent inclus) ou amount <= 0.
    Q_INVOKABLE bool addXp(const QString &playerId, int amount);

    void reset() override;

signals:
    /// XP modifiée (après level-up éventuel). `xpForNext` est le seuil courant.
    void xpChanged(const QString &playerId, int xp, int xpForNext);

private:
    /// XP requise pour passer du niveau `level` au suivant : round(100*level^1.5).
    int xpForLevel(int level) const;

    // playerId -> XP accumulée vers le prochain niveau.
    QHash<QString, int> m_xp;
    LevelModule *m_level = nullptr;
};

#endif // EXPERIENCE_MODULE_H
