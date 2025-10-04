# Guide d'utilisation du Logger

## Description
La classe `Logger` permet d'envoyer des messages colorés dans le terminal depuis QML avec différents niveaux de debug et des catégories optionnelles.

## Fonctionnalités

### Niveaux de log
- **INFO** : Messages informatifs (couleur verte)
- **DEBUG** : Messages de débogage (couleur cyan)
- **ERROR** : Messages d'erreur (couleur rouge)

### Catégories optionnelles
Les messages peuvent inclure une catégorie entre crochets pour une meilleure organisation.

## Utilisation depuis QML

### Import
```qml
import Logger 1.0
```

### Méthodes disponibles
```qml
// Messages simples
Logger.info("Message informatif")
Logger.debug("Message de debug")
Logger.error("Message d'erreur")

// Messages avec catégorie
Logger.info("Chargement réussi", "MAP_LOADING")
Logger.debug("Position mise à jour", "PLAYER")
Logger.error("Échec de connexion", "NETWORK")
```

### Exemples de sortie
```
INFO: Application démarrée
DEBUG: Mode debug activé
ERROR: Erreur de connexion
INFO: [MAP_LOADING] Chargement de la carte réussi
DEBUG: [PLAYER] Position du joueur mise à jour
ERROR: [NETWORK] Échec du chargement des assets
```

## Configuration des niveaux de log

### Définitions disponibles
```cpp
#define LOG_LEVEL_INFO 1    // Active les logs INFO
#define LOG_LEVEL_DEBUG 1   // Active les logs DEBUG
#define LOG_LEVEL_ERROR 1   // Active les logs ERROR
```

### Désactiver un niveau
Pour désactiver un niveau de log, définissez la valeur à 0 :
```cpp
#define LOG_LEVEL_DEBUG 0   // Désactive les logs DEBUG
```

## Intégration dans le projet

### 1. Enregistrer le Logger dans QML
Dans votre fichier principal (ex: `main.cpp` ou `qmlapp.cpp`) :
```cpp
#include "tools/logger.h"

// Dans la fonction main ou d'initialisation
Logger::registerQml();
```

### 2. Utiliser dans vos fichiers QML
```qml
import Logger 1.0

Item {
    Component.onCompleted: {
        Logger.info("Composant initialisé", "UI")
    }
}
```

## Couleurs utilisées
- **INFO** : Vert (`DBG_CLR_GREEN`)
- **DEBUG** : Cyan (`DBG_CLR_CYAN`)
- **ERROR** : Rouge (`DBG_CLR_RED`)

Les couleurs sont définies dans `debug_info.h` et utilisent les codes ANSI pour la coloration du terminal.
