# 🐾 Moteur Physique PattounX (The Feline Physics Solver) — V1 LEGACY

> ⚠️ **Document V1 obsolète.** Le moteur a été remplacé par **Pattounx v2**
> (Phases 1–9 du refactor, code en place dans `cpp/game/physics/`). Pour
> la doc à jour : [PHYSICS_ENGINE_V2.md](./PHYSICS_ENGINE_V2.md).
> Cette page est conservée pour archive ; elle contient des erreurs
> factuelles listées au §10.4 de `PHYSICS_REFACTOR_PLAN.md` — ne pas
> s'y référer aveuglément.

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
   - Dispose d'un système de **mise en veille automatique** (sleep) : un body quasi-immobile pendant `SLEEP_FRAMES_REQUIRED` frames est endormi et ignoré par la simulation jusqu'à réception d'un input ou d'une force externe.
3. **`PattounX_zone`** : Une zone d'effet environnementale définie par un polygone 2D complexe.
   - Générée généralement via un `ItemSnapable` (des tuiles sur une grille).
   - Peut agir comme une simple zone d'exclusion (mur) ou bien altérer les caractéristiques d'un corps la traversant (modificateur de friction, de vitesse ou d'accélération).
4. **`Collision2D`** : Classe utilitaire statique fournissant les primitives de collision.
   - Sweep analytique cercle-segment (`sweepCircleSegment`) par résolution quadratique.
   - Tests statiques cercle-polygone, point-dans-polygone, cercle-AABB.
   - Fonction de rebond (`applyBounce`) avec coefficients de restitution et glissement.

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

1. **Intégration** : application de la friction au sol et des effets de zones, puis intégration d'Euler semi-implicite (forces → vélocité → position). Le damping est exponentiel et indépendant du framerate : `factor = pow(1 - damping, dt * 60)`.
2. **CCD Sweep + Rewind** : pour chaque body en mouvement, un balayage analytique (sweep) cercle-polygone détecte la collision la plus proche le long du déplacement. Le body est **ramené au point d'impact** (rewind CCD) et sa vélocité est corrigée (bounce/slide). Cela empêche le tunneling même à haute vitesse.
3. **Détection statique résiduelle** : une passe de détection statique cercle-polygone à la position corrigée gère les cas de repos (body appuyé contre un mur, coincé dans un coin).
4. **Solver itératif** : résolution des impulsions par `VELOCITY_ITERATIONS` passes (friction Coulomb avec moyenne géométrique body/zone), puis correction de position anti-pénétration.
5. **Signaux dédupliqués** : émission d'un seul signal `collisionOccurred` / `bodyCollided` par paire body/zone unique.

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
- Sur un corps (`PattounX_body`) : `positionChanged()`, `velocityChanged()`, `isCollidingChanged()`, `isSleepingChanged()`, `enteredZone()`, `exitedZone()`, `collisionOccurred()`, `inputVectorChanged()`.
- Sur le moteur (`PattounX_engine`) : `bodyCollided()`, `bodyEnteredZone()`, `bodyExitedZone()`.

**Note** : les signaux de collision sont dédupliqués par paire body/zone — même si un body touche plusieurs segments d'une même zone dans la même frame, un seul `collisionOccurred` est émis pour cette paire.

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
  Le moteur travaille sur des itérations prédictibles (`VELOCITY_ITERATIONS = 4`), avec un slop de pénétration (`PENETRATION_SLOP = 0.01`). Le rewind CCD empêche le tunneling même à haute vitesse — le body est replacé au point d'impact exact avant toute résolution.
- **Sleep System :**
  Un body dont la vélocité reste sous `SLEEP_VELOCITY_THRESHOLD` (0.5) pendant `SLEEP_FRAMES_REQUIRED` (30) frames est automatiquement endormi. Les bodies endormis sont ignorés par la simulation (pas d'intégration, pas de collision), ce qui économise du CPU. Ils se réveillent automatiquement dès qu'un input ou une force externe est appliquée.
- **Broadphase AABB :**
  Avant chaque test de collision (sweep ou statique), un test rapide de recouvrement AABB filtre les zones éloignées. Cela réduit significativement le nombre de tests narrowphase, surtout sur les maps avec beaucoup de zones.

---

## 🔬 5. Détails Techniques : CCD Analytique

Le CCD (Continuous Collision Detection) utilise un **sweep analytique** cercle-segment plutôt qu'un échantillonnage discret. Pour chaque segment du polygone, la résolution se décompose en :

1. **Cercle vs sommets** : résolution quadratique `|P0 + t*V - vertex|² = r²` pour trouver le premier `t ∈ [0,1]` de contact.
2. **Cercle vs corps du segment** : projection de la trajectoire sur la normale du segment, résolution linéaire `d0 + t*dv = ±radius`, puis vérification que le point de contact est bien sur le segment.

Le plus petit `t` trouvé parmi tous les segments donne le point d'impact. Le body est rembobiné à cette position, puis le bounce/slide est appliqué sur la vélocité.

### Friction Coulomb

La résolution des collisions utilise le modèle de friction de Coulomb :
- **Coefficient combiné** : moyenne géométrique `μ = √(μ_body × μ_zone)`
- **Friction statique** : si `|jt| < j × μ`, l'impulsion tangentielle arrête le mouvement
- **Friction dynamique** : sinon, glissement avec `μ_dynamique = √(μ_dyn_body × μ_zone)`
