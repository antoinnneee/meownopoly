#ifndef PHYSICS2D_ENGINE_H
#define PHYSICS2D_ENGINE_H

#include <QObject>
#include <QHash>
#include <QVector>
#include <QVariantList>
#include <QString>
#include "physics2d_body.h"
#include "physics2d_zone.h"
#include "collision2d.h"
#include "game/item_snapable/ZoneParameter.h"

/**
 * @brief Moteur physique 2D principal
 * 
 * Gère toutes les entités physiques (bodies) et zones de la scène.
 * Effectue la détection de collision et applique les effets de zones.
 */
class PhysicsEngine2D : public QObject
{
    Q_OBJECT
    
    Q_PROPERTY(int bodyCount READ bodyCount NOTIFY bodyCountChanged)
    Q_PROPERTY(int zoneCount READ zoneCount NOTIFY zoneCountChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool debugMode READ debugMode WRITE setDebugMode NOTIFY debugModeChanged)

public:
    explicit PhysicsEngine2D(QObject* parent = nullptr);
    ~PhysicsEngine2D();
    
    /**
     * @brief Enregistre les types du moteur physique pour QML
     */
    static void registerQml();
    
    // --- Getters ---
    int bodyCount() const { return m_bodies.size(); }
    int zoneCount() const { return m_zones.size(); }
    bool enabled() const { return m_enabled; }
    bool debugMode() const { return m_debugMode; }
    
    // --- Setters ---
    void setFriction(qreal friction);
    void setEnabled(bool enabled);
    void setDebugMode(bool debug);
    
    // --- Gestion des Bodies ---
    
    /**
     * @brief Crée un nouveau corps physique
     * @param id Identifiant unique
     * @return Pointeur vers le nouveau body (géré par le moteur)
     */
    Q_INVOKABLE PhysicsBody2D* createBody(const QString& id);
    
    /**
     * @brief Supprime un corps physique
     * @param id Identifiant du body
     * @return true si supprimé
     */
    Q_INVOKABLE bool removeBody(const QString& id);
    
    /**
     * @brief Récupère un corps physique par son ID
     * @param id Identifiant du body
     * @return Pointeur vers le body ou nullptr
     */
    Q_INVOKABLE PhysicsBody2D* getBody(const QString& id) const;
    
    /**
     * @brief Supprime tous les corps physiques
     */
    Q_INVOKABLE void clearBodies();
    
    // --- Gestion des Zones ---
    
    /**
     * @brief Crée une nouvelle zone physique
     * @param id Identifiant unique
     * @param zoneType Type de zone (enum PhysicsZone2D::ZoneType)
     * @return Pointeur vers la nouvelle zone (gérée par le moteur)
     */
    Q_INVOKABLE PhysicsZone2D* createZone(const QString& id, int zoneType = 0);
    PhysicsZone2D* createZone(const QString& id, ZoneParameter *zoneParam);

    /**
     * @brief Supprime une zone physique
     * @param id Identifiant de la zone
     * @return true si supprimée
     */
    Q_INVOKABLE bool removeZone(const QString& id);
    
    /**
     * @brief Récupère une zone par son ID
     * @param id Identifiant de la zone
     * @return Pointeur vers la zone ou nullptr
     */
    Q_INVOKABLE PhysicsZone2D* getZone(const QString& id) const;
    
    /**
     * @brief Supprime toutes les zones
     */
    Q_INVOKABLE void clearZones();
    
    /**
     * @brief Configure les zones depuis une liste d'ItemSnapable
     * @param snapables Liste de QVariant contenant des ItemSnapable*
     * 
     * Cette méthode extrait les zones d'exclusion et d'effet depuis
     * les ItemSnapable qui ont un tileType PhysicZone
     */
    Q_INVOKABLE void setZonesFromSnapables(const QVariantList& snapables);
    
    // --- Simulation ---
    
    /**
     * @brief Met à jour tous les corps physiques
     * @param dt Delta time en secondes
     * 
     * Cette méthode effectue :
     * 1. Détection des zones contenant chaque body
     * 2. Application des effets de zones
     * 3. Détection des collisions avec zones d'exclusion
     * 4. Application des rebonds et mise à jour des positions
     */
    Q_INVOKABLE void updateAll(qreal dt);
    
    /**
     * @brief Met à jour un seul corps physique
     * @param body Corps à mettre à jour
     * @param dt Delta time en secondes
     */
    Q_INVOKABLE void updateBody(PhysicsBody2D* body, qreal dt);
    
    // --- Requêtes ---
    
    /**
     * @brief Trouve toutes les zones contenant un point
     * @param point Position à tester
     * @return Liste des zones actives contenant le point
     */
    Q_INVOKABLE QVariantList getZonesAtPoint(const QVector2D& point) const;


signals:
    void bodyCountChanged();
    void zoneCountChanged();
    void frictionChanged();
    void enabledChanged();
    void debugModeChanged();
    
    // Événements globaux
    void bodyCollided(PhysicsBody2D* body, PhysicsZone2D* zone);
    void bodyEnteredZone(PhysicsBody2D* body, PhysicsZone2D* zone);
    void bodyExitedZone(PhysicsBody2D* body, PhysicsZone2D* zone);

private:
    /**
     * @brief Applique les effets des zones sur un body
     */
    void applyZoneEffects(PhysicsBody2D* body, qreal dt);

    void applyGroundFrictionAndZones(PhysicsBody2D *body, qreal dt);

    /**
     * @brief Détecte et résout les collisions pour un body
     */
    void resolveCollisions_old(PhysicsBody2D* body, qreal dt, QVector2D newPos);
    void resolveCollisions(const QVector<CollisionResult> &contacts, qreal dt);

    /**
     * @brief Corrige les positions des corps après résolution des collisions
     */
    void correctPositions(const QVector<CollisionResult> &contacts);
    // Données
    QHash<QString, PhysicsBody2D*> m_bodies;
    QHash<QString, PhysicsZone2D*> m_zones;
    
    // Suivi des zones actives par body (pour détecter entrées/sorties)
    QHash<PhysicsBody2D*, QSet<PhysicsZone2D*>> m_activeZonesPerBody;
    
    // Configuration
    bool m_enabled = true;
    bool m_debugMode = false;
};

#endif // PHYSICS2D_ENGINE_H

