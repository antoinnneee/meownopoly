# 🐱 Guide du Développeur Meownopoly

Ce document est destiné aux développeurs qui souhaitent contribuer au projet Meownopoly. Il explique l'environnement de développement, les bonnes pratiques et les procédures pour ajouter de nouvelles fonctionnalités.

## 🔧 Configuration de l'environnement

### Prérequis

- **Qt 5.15** ou supérieur (recommandé : Qt 6.2+)
- **Compilateur C++17** compatible :
  - GCC 7+ (Linux)
  - MSVC 2019+ (Windows)
  - Clang 10+ (macOS)
- **Git** pour la gestion de version
- **QtCreator** recommandé comme IDE

### Installation

1. **Cloner le dépôt**
   ```bash
   git clone https://github.com/votre-repo/meownopoly.git
   cd meownopoly
   ```

2. **Ouvrir le projet dans QtCreator**
   - Ouvrir le fichier `Meownopoly.pro`
   - Configurer les kits de construction

3. **Compiler le projet**
   ```bash
   qmake Meownopoly.pro
   make
   # ou utiliser QtCreator
   ```

4. **Préparer les assets**
   ```bash
   # Windows
   copy_test_assets.bat
   # Linux/macOS
   ./copy_test_assets.sh
   ```

## 🏗️ Structure du Code

Voir [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) pour une description détaillée de l'organisation du projet.

### Points d'entrée importants

- `main.cpp` : Point d'entrée de l'application
- `qmlapp.cpp/h` : Classe principale qui initialise QML
- `game.cpp/h` : Classe qui gère la logique du jeu
- `qml/main.qml` : Point d'entrée QML

## 🧩 Ajout de Nouvelles Fonctionnalités

### 1. Création d'un Nouveau Type de Case

1. **Créer les fichiers C++**
   - Créer `case/CaseNouveauType.h` et `case/CaseNouveauType.cpp`
   - Hériter de la classe `Case` ou d'une sous-classe appropriée

   ```cpp
   // CaseNouveauType.h
   class CaseNouveauType : public Case {
       Q_OBJECT
   public:
       CaseNouveauType(QObject *parent = nullptr);
       // Implémenter les méthodes requises...
   };
   ```

2. **Enregistrer la classe pour QML**
   - Dans `game.cpp`, ajouter :
   ```cpp
   #include "case/CaseNouveauType.h"
   // ...
   void Game::registerQml() {
       // ...
       qmlRegisterType<CaseNouveauType>("CaseNouveauType", 1, 0, "CaseNouveauType");
   }
   ```

3. **Créer le composant QML**
   - Ajouter `qml/case/content/CaseNouveauType.qml`
   - Enregistrer dans `qml.qrc`

4. **Mettre à jour la configuration**
   - Ajouter l'entrée dans `config/cases.json`

### 2. Ajout d'un Nouveau Composant UI

1. **Créer le fichier QML**
   ```qml
   // MonComposant.qml
   import QtQuick 2.15
   
   Rectangle {
       id: root
       property int maValeur: 0
       signal monSignal(int valeur)
       
       // Corps du composant...
   }
   ```

2. **Intégrer le composant**
   - L'importer et l'utiliser dans d'autres composants QML

3. **Créer un test**
   - Ajouter `qml/test/TEST_MON_COMPOSANT.qml`

### 3. Utilisation du Gestionnaire d'Assets

Voir [ASSET_MANAGER_USAGE.md](../ASSET_MANAGER_USAGE.md) pour plus de détails.

```qml
// Exemple d'utilisation
Image {
    source: AssetManager.getDecorationPath("grass", "1")
    width: AssetManager.getDecorationWidth("grass", "1")
    height: AssetManager.getDecorationHeight("grass", "1")
}
```

## 🧪 Tests et Débogage

### Tests QML

Les fichiers de test sont situés dans `qml/test/`. Pour tester un composant :

1. Ouvrir le projet dans QtCreator
2. Naviguer vers le fichier de test approprié
3. Exécuter le projet avec ce fichier comme point d'entrée

### Débogage C++

1. Placer des points d'arrêt dans le code C++
2. Utiliser les macros de débogage définies dans `tools/debug_info.h`
   ```cpp
   DEBUG_INFO("Ma variable:", maVariable);
   ```

### Console QML

Pour déboguer QML, utilisez `console.log()` :
```qml
console.log("Débogage:", maValeur)
```

## 🔄 Workflow Git

### Branches

- `main` - Branche principale stable
- `develop` - Branche de développement
- `feature/nom-fonctionnalite` - Branches de fonctionnalités

### Procédure pour les Contributions

1. **Créer une branche**
   ```bash
   git checkout develop
   git pull
   git checkout -b feature/ma-fonctionnalite
   ```

2. **Développer la fonctionnalité**
   - Suivre les conventions de codage
   - Tester votre code

3. **Commiter vos changements**
   ```bash
   git add .
   git commit -m "Description détaillée de la fonctionnalité"
   ```

4. **Pousser vers le dépôt distant**
   ```bash
   git push origin feature/ma-fonctionnalite
   ```

5. **Créer une Pull Request** vers `develop`

## 📋 Conventions de Codage

### C++

- Indentation : 4 espaces
- Nommage des classes : PascalCase
- Nommage des méthodes : camelCase
- Nommage des variables membres : m_camelCase
- Accolades sur la même ligne pour les fonctions :
  ```cpp
  void maFonction() {
      // code
  }
  ```

### QML

- Indentation : 4 espaces
- ID des composants : camelCase
- Propriétés : camelCase
- Organisation :
  1. id
  2. propriétés
  3. signaux
  4. fonctions
  5. sous-composants

## 🛠️ Outils et Utilitaires

### Metadata Generator

Outil qui génère automatiquement les fichiers de métadonnées pour les assets.

```bash
# Dans QtCreator, exécuter le projet metadata_generator
# Ou en ligne de commande :
./metadata_generator --input=path/to/assets --output=path/to/output
```

### Asset Manager

Interface pour accéder aux ressources graphiques du jeu. Voir [ASSET_MANAGER.md](./ASSET_MANAGER.md).

### Launcher Manager

Gère les connexions au serveur de ressources et les mises à jour. Voir [LAUNCHER_ARCHITECTURE.md](./LAUNCHER_ARCHITECTURE.md).

## 📚 Documentation

### Comment Documenter votre Code

- **C++** : Utiliser les commentaires de style Doxygen
  ```cpp
  /**
   * @brief Description de la fonction
   * @param param1 Description du paramètre
   * @return Description de la valeur de retour
   */
  int maFonction(int param1);
  ```

- **QML** : Utiliser les commentaires de bloc
  ```qml
  /*!
   * Composant qui fait X et Y
   * Utilisation :
   * ```
   * MonComposant {
   *     propriete: valeur
   * }
   * ```
   */
  ```

### Mise à jour de la Documentation

1. Modifier les fichiers Markdown dans `doc/`
2. Ajouter des exemples d'utilisation lorsque pertinent
3. Mettre à jour le README.md général si nécessaire

## 🐞 Résolution des Problèmes Courants

### Erreur de Compilation QML
- Vérifier les importations
- S'assurer que toutes les classes C++ sont correctement enregistrées
- Vérifier les accolades et parenthèses

### Assets Manquants
- Exécuter le script `copy_test_assets.bat`
- Vérifier que les fichiers sont correctement référencés dans `assets.qrc`

### Problèmes avec l'Éditeur
- Vérifier la console pour les erreurs
- S'assurer que les modèles d'assets sont chargés correctement
- Vérifier les connexions entre les composants

## 🚀 Optimisation des Performances

### Bonnes pratiques QML
- Éviter les bindings complexes
- Utiliser des Images au lieu de BorderImage quand possible
- Préférer les propriétés attachées aux propriétés calculées
- Limiter l'utilisation des effets visuels coûteux

### Optimisation C++
- Éviter les allocations mémoire inutiles
- Utiliser des références pour les grands objets
- Préférer `const &` pour les paramètres complexes

## 📞 Ressources et Support

- **Documentation Qt** : [https://doc.qt.io/](https://doc.qt.io/)
- **Canal Discord** : [lien vers le Discord]
- **Trello/Jira** : [lien vers le tableau de gestion de projet]

---

Ce guide est en constante évolution. N'hésitez pas à suggérer des améliorations ou à poser des questions à l'équipe de développement.

Bon développement ! 🐾

