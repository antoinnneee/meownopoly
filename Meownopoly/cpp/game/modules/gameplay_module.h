#ifndef GAMEPLAY_MODULE_H
#define GAMEPLAY_MODULE_H

#include <QObject>
#include <QList>
#include <QString>

/// Classe de base de tous les modules de gameplay activables.
///
/// Un module encapsule un système de jeu optionnel (vie, inventaire,
/// monnaie…). Il porte un identifiant stable (`moduleId`), un nom lisible
/// (`name`) et un état d'activation (`enabled`). Quand il est désactivé,
/// ses opérations doivent no-oper (retour `false` / `qWarning` discret).
///
/// Les modules sont instanciés en C++ et enregistrés dans le
/// `GameplayModuleManager` (singleton QML). QML y accède via
/// `GameplayModuleManager.moduleById("...")` ou `moduleAt(i)`.
///
/// Les données sont indexées par un `playerId` (QString) simple pour cette
/// v1 — pas de branchement sur Catway/GameSession. C'est de la préparation
/// à la programmation du jeu.
///
/// ── Sous-modules ──────────────────────────────────────────────────────────
/// Un module peut détenir des **sous-modules** (ex : Expérience sous Niveau),
/// enregistrés via `registerSubModule` (le parent en prend l'ownership QObject).
/// L'état effectif d'un sous-module est `enabled() && parent->effectiveEnabled()`
/// (récursif) : désactiver le parent grise le sous-module sans perdre son flag
/// propre. Les gardes de mutation des sous-modules testent `effectiveEnabled()`
/// (pas `enabled()`). Les sous-modules ne sont PAS dans la liste plate du
/// manager (`moduleAt`/`moduleCount`), mais `moduleById` les trouve par descente
/// récursive.
class GameplayModule : public QObject
{
    Q_OBJECT

    // Nom lisible du module (affiché dans l'UI).
    Q_PROPERTY(QString name READ name CONSTANT)
    // Identifiant stable, sert de clé de lookup (moduleById).
    Q_PROPERTY(QString moduleId READ moduleId CONSTANT)
    // État d'activation propre. Côté QML : `module.enabled` (pas `isEnabled`).
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    // État d'activation effectif = flag propre ET parent effectivement actif.
    Q_PROPERTY(bool effectiveEnabled READ effectiveEnabled NOTIFY effectiveEnabledChanged)

public:
    explicit GameplayModule(const QString &moduleId,
                            const QString &name,
                            QObject *parent = nullptr);

    QString name() const { return m_name; }
    QString moduleId() const { return m_moduleId; }
    bool enabled() const { return m_enabled; }

    /// État effectif : le flag propre ET, s'il existe, le parent effectivement
    /// actif (récursif). C'est cette valeur que testent les gardes de mutation
    /// des sous-modules.
    bool effectiveEnabled() const;

    /// Active/désactive le module. Déclenche onEnabled()/onDisabled(),
    /// émet enabledChanged() sur transition effective, et propage
    /// effectiveEnabledChanged() à soi + aux sous-modules concernés.
    void setEnabled(bool enabled);

    /// Module parent (nullptr pour un module racine).
    GameplayModule *parentModule() const { return m_parentModule; }

    // ── Accès aux sous-modules (QQmlListProperty n'est pas une JS array) ────
    Q_INVOKABLE int subModuleCount() const { return m_subModules.size(); }
    Q_INVOKABLE GameplayModule *subModuleAt(int index) const;
    /// Recherche récursive d'un sous-module (descend dans les petits-enfants).
    Q_INVOKABLE GameplayModule *subModuleById(const QString &moduleId) const;

    /// Réinitialise l'état interne du module (données par joueur) ET ses
    /// sous-modules. Les modules concrets surchargent pour purger leurs
    /// conteneurs, puis DOIVENT appeler `GameplayModule::reset()` pour propager
    /// aux sous-modules.
    Q_INVOKABLE virtual void reset();

signals:
    void enabledChanged();
    void effectiveEnabledChanged();

protected:
    /// Hook appelé quand le module passe de désactivé à activé.
    virtual void onEnabled() {}
    /// Hook appelé quand le module passe d'activé à désactivé.
    virtual void onDisabled() {}

    /// Enregistre un sous-module : en prend l'ownership QObject (reparente),
    /// fixe son parentModule, l'ajoute à la liste. Appelé par le parent.
    void registerSubModule(GameplayModule *sub);

private:
    /// Émet effectiveEnabledChanged() et propage récursivement aux sous-modules
    /// dont l'état effectif dépend du nôtre.
    void notifyEffectiveEnabledChanged();

    const QString m_moduleId;
    const QString m_name;
    bool m_enabled = false;

    GameplayModule *m_parentModule = nullptr;
    QList<GameplayModule *> m_subModules;
};

#endif // GAMEPLAY_MODULE_H
