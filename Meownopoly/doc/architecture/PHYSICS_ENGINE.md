# 🐾 Moteur Physique PattounX (The Feline Physics Solver)

**PattounX** est le moteur physique 2D dédié de Meownopoly. Conçu pour être léger, performant et facile d'utilisation depuis C++ et QML, il prend en charge des collisions 2D continues (cercles-polygones) et divers types d'interactions environnementales (zones d'effet, zones d'exclusion).

Ce document s'adresse avant tout aux **développeurs** qui souhaitent interagir avec les éléments physiques du jeu, comprendre leur cycle de vie ou étendre le comportement des objets dans l'espace.

---

## 🏗️ 1. Architecture Globale

Le système est axé autour de trois entités fondamentales :

1. **`PattounX_engine`** : Le coordinateur central.
   - Gère le cycle de vie de tous les corps (`m_bodies`) et zones (`m_zones`).
   - Effectue la détection et la résolution globale de toutes les collisions.
   - Exécute l'intégration temporelle à chaque mise à jour de frame (`updateAll(dt)`).
2. **`PattounX_body`** : Un corps physique 2D représentant des entités mouvantes (joueurs, familiers, etc.).
   - Possède une position, vélocité, accélération, masse, rayon de collision et coefficients de friction.
   - Subit les impulsions, forces et calculs de restitution.
3. **`PattounX_zone`** : Une zone d'effet environnementale définie par un polygone 2D complexe.
   - Générée généralement via un `ItemSnapable` (des tuiles sur une grille).
   - Peut agir comme une simple zone d'exclusion (mur) ou bien altérer les caractéristiques d'un corps la traversant (modificateur de friction, de vitesse ou d'accélération).

---

## 🧑‍💻 2. Flux de Travail Principal (Workflow)

L'utilisation globale du moteur depuis le code de jeu se déroule en plusieurs étapes simples : l'initialisation du moteur, la configuration de l'espace de jeu avec des corps et des zones, puis le déroulement itératif du temps via les mises à jour de frames.

### 2.1. Initialisation et Enregistrement QML

PattounX est intimement lié à l'interface QML via le système de propriétés de Qt (`Q_PROPERTY`).
Si vous avez besoin d'instancier un nouveau moteur ou manipuler des types physiques côté QML, assurez-vous de l'enregistrement de ces derniers (généralement fait automatiquement dans l'initialisation du jeu) :

```cpp
PattounX_engine::registerQml();
```

Il vous suffit ensuite d'instancier le moteur :

```cpp
PattounX_engine* engine = new PattounX_engine(this);
engine->setEnabled(true);
```

### 2.2. Création et Configuration des Corps (Bodies)

Utilisez une chaîne unique (ID) pour créer et référencer un body au sein de votre jeu.
La fonction `createBody` retourne un pointeur, que vous pourrez directement assigner et manipuler.

```cpp
PattounX_body* myCat = engine->createBody("player_1_cat");

// Configurer les propriétés physiques de base
myCat->setPosition(QVector2D(10.0, 15.0));
myCat->setMass(1.5);
myCat->setCollisionRadius(0.8); // Rayon de la hitbox (cercle)

// Paramètres de maniabilité et mouvement
myCat->setAcceleration(45.0);
myCat->setMaxSpeed(350.0);
myCat->setBounceFactor(0.2);     // Coefficient de restitution lors d'une collision
myCat->setLinearDamping(0.1);    // Frottements linéaires dans l'air / frottement global
```

**Note** : Vous pouvez également marquer un objet comme statique (`setIsStatic(true)`), ou y désactiver temporairement les collisions (`setCollisionEnabled(false)`).

### 2.3. Gestion des Zones Environnementales

Les zones sont créées à partir d'objets `ItemSnapable`, qui définissent la typologie du terrain.

```cpp
// Option A : Création individuelle d'une zone via ItemSnapable
engine->createZone(myWallItem);

// Option B : Configuration groupée typique
QVariantList snapableTiles = getSnapablesFromMap();
engine->setZonesFromSnapables(snapableTiles);
```

Lorsque qu'un objet `ItemSnapable` porte le drapeau lié aux `PhysicZone`, le moteur extrait son polygone et intercepte tous les paramètres de zone sous-jacents (`ZoneParameter`). Un objet peut ainsi posséder des propriétés telles que `isExclusion` (mur infranchissable) ou fournir des multiplicateurs de vélocité.

### 2.4. Entrées de Mouvement et Interactions (Forces et Impulsions)

Pour faire bouger votre entité, plutôt que de manipuler sa vitesse de façon brute (bien que possible via `setVelocity(v)`), la manière idiomatique est d'appliquer un vecteur de force (de type joystick) ou une impulsion brève (de type recul / "dash") :

```cpp
QVector2D userJoystickInput(0.8, -0.6);
userJoystickInput.normalize();

// Applique une tension directionnelle constante
myCat->applyForce(userJoystickInput); 

// Si vous avez besoin d'appliquer une force en une seule fois (comme une explosion ou un dash) :
myCat->applyImpulse(QVector2D(50.0, 0.0));
```

### 2.5. La Boucle de Simulation (Update)

Il faut fournir à l'engine un "delta time" (`dt` en secondes) symbolisant l'écart de temps écoulé entre la frame courante et la précédente. C'est l'essence même du moteur qui effectuera en interne :

1. L'intégration des forces vers la vélocité.
2. L'application du comportement des zones (sable ralentissant, glace glissante...).
3. La validation des collisions pour rectifier la position et déterminer les rebonds.
4. L'intégration de la vélocité vers la position finale.

```cpp
// Dans une fonction d'update itérative de votre boucle de jeu :
void onFrameUpdate(qreal dtSec) {
    engine->updateAll(dtSec);
}
```

Il est également possible de focaliser la mise à jour sur un corps individuel avec `engine->updateBody(myCat, dt)`.

---

## 📡 3. Répondre aux Événements via Signaux/Slots

L'une des grandes de PattounX est d'être totalement intégré à la boucle d'événements Qt, facilitant grandement la vie du développeur gameplay pour déclencher des sons, des effets visuels ou des logiques de jeu sans polluer les updates manuels.

Chaque `PattounX_body` expose des signaux clairs. Certains sont aussi répliqués dans le `PattounX_engine` entier, évitant d'avoir à tracker chaque body individuellement :

```cpp
// Exemple d'un log lors d'une collision
connect(engine, &PattounX_engine::bodyCollided, this, [](PattounX_body* body, PattounX_zone* zone) {
    qDebug() << "Le chat" << body->bodyId() << "a heurté la zone" << zone->zoneId();
});

// Suivi intime des zones ("trigger zones") :
connect(myCat, &PattounX_body::enteredZone, this, [=](PattounX_zone* zone) {
    if (zone->snapable()->type() == WATER_PIT) {
        triggerSplashEffect(myCat->position());
    }
});
```

Liste utile de signaux exposés :
- Sur un corps (`PattounX_body`) : `positionChanged()`, `velocityChanged()`, `isCollidingChanged()`, `enteredZone()`, `exitedZone()`, `collisionOccurred()`.
- Sur le moteur (`PattounX_engine`) : `bodyCollided()`, `bodyEnteredZone()`, `bodyExitedZone()`.

---

## 🚦 4. Bonnes Pratiques en Mode Développeur

- **Débogage Visuel :**
  Activez le debug avec `engine->setDebugMode(true)`. Bien qu'il vous revienne de dessiner la surcouche en QML / C++, écouter son drapeau `debugModeChanged` permet de lier des rectangles ou cercles QML pour visualiser directement l'espace interne (hitbox et tracés des polygones).
- **Ménage et Nettoyage :** 
  N'oubliez pas d'appeler `clearBodies()` ou `clearZones()` lors des changements majeurs de maps, de déconnexion ou recharges de niveaux afin d'éviter les fuites de QObject et les comportements imprévus. Les corps et les zones sont détruits de la mémoire.
- **Accès Rapide (Pointeurs) :** 
  Pour des requêtes instantanées, la fonction `getZonesAtPoint(QVector2D point)` sur l'engine est très utile pour inspecter le terrain sous l'emplacement d'un clic souris sans posséder d'entité Body.
- **Position Discrète :**
  Pour un clonage paranoïaque ou des retours arrières brutaux (ex: téléportation), n'utilisez pas `applyImpulse` mais utilisez la mutation directe `setPosition(vector)`. Vous pouvez également utiliser `stop()` pour absorber toute l'inertie ou `reset()` pour faire table rase sur la mémoire tampon de vitesse et d'accumulation de vecteurs.
- **Paramètres Constantes :**
  Le moteur travaille sur des itérations prédictibles (`VELOCITY_ITERATIONS = 4`), avec un slop de pénétration (`PENETRATION_SLOP = 0.01`). Vous n'avez pas en règle générale besoin de modifier le fonctionnement des corrections de pénétration tunnel, celles-ci conviennent très bien avec les mouvements erratiques de la souris et la latence moyenne de Qt.
