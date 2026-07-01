#ifndef GAMEPLAY_MODULE_H
#define GAMEPLAY_MODULE_H

#include <QObject>
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
class GameplayModule : public QObject
{
    Q_OBJECT

    // Nom lisible du module (affiché dans l'UI).
    Q_PROPERTY(QString name READ name CONSTANT)
    // Identifiant stable, sert de clé de lookup (moduleById).
    Q_PROPERTY(QString moduleId READ moduleId CONSTANT)
    // État d'activation. Côté QML : `module.enabled` (pas `isEnabled`).
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit GameplayModule(const QString &moduleId,
                            const QString &name,
                            QObject *parent = nullptr);

    QString name() const { return m_name; }
    QString moduleId() const { return m_moduleId; }
    bool enabled() const { return m_enabled; }

    /// Active/désactive le module. Déclenche onEnabled()/onDisabled()
    /// et émet enabledChanged() sur transition effective.
    void setEnabled(bool enabled);

    /// Réinitialise l'état interne du module (données par joueur).
    /// L'implémentation de base vide juste le flag ; les modules concrets
    /// surchargent pour purger leurs conteneurs.
    Q_INVOKABLE virtual void reset();

signals:
    void enabledChanged();

protected:
    /// Hook appelé quand le module passe de désactivé à activé.
    virtual void onEnabled() {}
    /// Hook appelé quand le module passe d'activé à désactivé.
    virtual void onDisabled() {}

private:
    const QString m_moduleId;
    const QString m_name;
    bool m_enabled = false;
};

#endif // GAMEPLAY_MODULE_H
