# Guide de Génération Automatique de Metadata

## Vue d'ensemble

Le système AssetManager inclut maintenant des fonctionnalités de génération automatique des fichiers `metadata.json` à partir des images présentes dans les dossiers d'assets.

## Fonctionnalités Ajoutées

### 🔧 API C++
- `generateMetadataForDirectory(path)` : Génère metadata.json pour un dossier spécifique
- `generateAllMetadata()` : Génère metadata.json pour tous les dossiers d'assets
- `scanAvailableAssets()` : Scanne et liste tous les dossiers contenant des images

### 🎨 Interface QML
- Panel de génération dans "Asset Manager Test"
- Composant `MetadataGenerator.qml` pour l'éditeur
- Composant `AssetManagerPanel.qml` intégré

### 📝 Génération Automatique
- Lecture automatique des dimensions d'image (PNG, JPG, JPEG, BMP, GIF)
- Calcul automatique du ratio largeur/hauteur
- Génération d'ID basée sur le nom de fichier
- Tri naturel des fichiers (1.png, 2.png, 10.png)
- Gestion des erreurs et validation

## Utilisation

### 1. Via l'Interface de Test
1. Lancez l'application
2. Cliquez sur "🎨 Asset Manager Test"
3. Descendez jusqu'à "Metadata Generation"
4. Cliquez "🔄 Scan Assets" pour voir les dossiers disponibles
5. Cliquez "📝 Generate All Metadata" pour générer tous les fichiers

### 2. Via le Script de Configuration
```bash
# Exécutez le script de configuration
setup_test_assets.bat

# Puis dans l'application, utilisez "Generate All Metadata"
```

### 3. Programmation QML
```qml
// Scanner les assets disponibles
property var availableAssets: AssetManager.scanAvailableAssets()

// Générer pour un dossier spécifique
Button {
    text: "Generate Metadata"
    onClicked: {
        var success = AssetManager.generateMetadataForDirectory("C:/path/to/assets/decoration/grass")
        if (success) {
            console.log("Metadata generated successfully!")
        }
    }
}

// Générer pour tous les dossiers
Button {
    text: "Generate All"
    onClicked: {
        var success = AssetManager.generateAllMetadata()
        console.log("Generation result:", success)
    }
}
```

## Format de Sortie

Le metadata.json généré suit exactement le format spécifié :

```json
{
  "assets": [
    {
      "id": "1",
      "filename": "1.png",
      "ratio": 1.5,
      "width": 100,
      "height": 150
    }
  ]
}
```

## Fonctionnalités Avancées

### Tri Intelligent
- Les fichiers sont triés naturellement (1, 2, 10 au lieu de 1, 10, 2)
- Support des noms de fichiers numériques et alphabétiques

### Validation
- Vérification de l'existence des dossiers
- Validation des dimensions d'image
- Gestion des erreurs de lecture
- Messages de status informatifs

### Formats Supportés
- PNG (recommandé)
- JPG/JPEG
- BMP
- GIF

### Intégration
- Rechargement automatique des assets après génération
- Synchronisation avec l'interface utilisateur
- Feedback visuel en temps réel

## Workflow Recommandé

1. **Préparation**
   - Placez vos images dans la structure de dossiers appropriée
   - Nommez vos fichiers de façon logique (1.png, 2.png, etc.)

2. **Génération**
   - Utilisez l'interface de test pour générer les metadata
   - Vérifiez les fichiers générés

3. **Validation**
   - Rechargez les assets
   - Testez l'affichage dans l'interface

4. **Utilisation**
   - Utilisez les nouveaux assets dans vos composants QML
   - Profitez du système de cache automatique

## Dépannage

### Problèmes Courants
- **"No image files found"** : Vérifiez que les images sont dans le bon dossier
- **"Cannot read image dimensions"** : Vérifiez que les fichiers ne sont pas corrompus
- **"Cannot create metadata file"** : Vérifiez les permissions d'écriture

### Logs de Debug
Consultez la console Qt pour les messages détaillés :
```
Generated metadata for 3 assets in: C:/path/to/assets/decoration/grass
Metadata saved to: C:/path/to/assets/decoration/grass/metadata.json
```
