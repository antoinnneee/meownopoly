# ParticleButton - Composant avec effet de particules

## 📋 Résumé

Un nouveau composant de bouton QML a été créé pour votre application Meownopoly. Ce bouton émet des particules en arc de cercle vers le haut lors du clic, avec un effet de gravité qui les fait retomber vers le bas de l'écran.

## 🎯 Fonctionnalités

✨ **Effet de particules au clic**
- Émission en arc de cercle vers le haut
- Effet de gravité simulé
- Rotation et transparence animées

🎨 **Entièrement personnalisable**
- Couleurs des particules
- Nombre de particules
- Taille et durée de vie
- Style du bouton

💫 **Feedback visuel**
- Animation de scale au clic
- Effet de hover
- Transition fluide

## 📁 Fichiers créés

### Composant principal
- **`qml/ParticleButton.qml`** - Le composant réutilisable

### Fichiers de test
- **`qml/test/TEST_PARTICLE_BUTTON.qml`** - Démo complète avec 6 variantes
- **`qml/test/TEST_PARTICLE_BUTTON_SIMPLE.qml`** - Exemple simple d'intégration

### Documentation
- **`qml/PARTICLE_BUTTON_GUIDE.md`** - Guide d'utilisation détaillé
- **`PARTICLE_BUTTON_README.md`** - Ce fichier (résumé)

### Modifications
- **`qml.qrc`** - Fichier de ressources mis à jour avec les nouveaux fichiers

## 🚀 Démarrage rapide

### Utilisation basique

```qml
import QtQuick

ParticleButton {
    text: "Cliquez-moi !"
    onClicked: {
        console.log("Button clicked!")
    }
}
```

### Utilisation personnalisée

```qml
ParticleButton {
    text: "Bouton Vert"
    particleColor: "#32CD32"
    particleColorVariation: "#00FF00"
    particleCount: 30
    particleSize: 10
    
    onClicked: {
        // Votre code ici
    }
}
```

## 🧪 Tester le composant

### Option 1 : Test complet (recommandé)
Ouvrez `qml/test/TEST_PARTICLE_BUTTON.qml` dans votre application pour voir :
- 6 boutons avec différentes configurations
- Un compteur de clics
- Des exemples variés (doré, bleu, rose, vert, feu, arc-en-ciel)

### Option 2 : Test simple
Ouvrez `qml/test/TEST_PARTICLE_BUTTON_SIMPLE.qml` pour un exemple minimaliste.

## 📖 Documentation complète

Pour une documentation détaillée avec tous les paramètres et exemples avancés, consultez :
**`qml/PARTICLE_BUTTON_GUIDE.md`**

## 🎨 Propriétés principales

| Propriété | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `particleColor` | color | `"#FFD700"` | Couleur principale |
| `particleColorVariation` | color | `"#FF6B6B"` | Couleur de dégradé |
| `particleCount` | int | `20` | Nombre de particules |
| `particleSize` | int | `8` | Taille des particules |
| `particleLifeSpan` | int | `2000` | Durée de vie (ms) |

## 🔧 Intégration dans votre application

Le composant est prêt à l'emploi ! Il suffit de l'utiliser comme un bouton classique :

```qml
// Dans n'importe quel fichier QML de votre application
ParticleButton {
    text: "Mon Bouton"
    width: 150
    height: 50
    onClicked: {
        // Votre logique
    }
}
```

## 💡 Exemples d'utilisation

### Bouton de validation
```qml
ParticleButton {
    text: "✓ Valider"
    particleColor: "#32CD32"
    particleColorVariation: "#00FF00"
    onClicked: validateForm()
}
```

### Bouton d'action spéciale
```qml
ParticleButton {
    text: "🎁 Récompense"
    particleColor: "#FFD700"
    particleCount: 50
    particleSize: 10
    onClicked: showReward()
}
```

### Bouton avec couleur aléatoire
```qml
ParticleButton {
    id: randomBtn
    text: "🎲 Surprise"
    onClicked: {
        var colors = ["#FF0000", "#00FF00", "#0000FF"]
        particleColor = colors[Math.floor(Math.random() * colors.length)]
    }
}
```

## ⚙️ Architecture technique

- **Système de particules** : Utilise `QtQuick.Particles`
- **Émission** : Contrôlée par événement (clic)
- **Physique** : Vélocité initiale + gravité simulée
- **Optimisation** : Émetteur désactivé par défaut, activé uniquement au clic

### Paramètres physiques
- Angle d'émission : 270° ± 60° (arc vers le haut)
- Vitesse initiale : 250 ± 100
- Gravité : 200 vers le bas
- Durée de vie : 2000 ms par défaut

## 🎯 Bonnes pratiques

### ✅ À faire
- Utiliser pour les actions importantes
- Adapter les couleurs à votre charte graphique
- Tester sur différents appareils
- Limiter le nombre de particules sur mobile

### ⚠️ À éviter
- Trop de particules (> 100) sur appareils peu puissants
- Trop de boutons avec particules visibles simultanément
- Utiliser l'effet partout (réserver aux moments clés)

## 🐛 Dépannage

### Les particules ne s'affichent pas
1. Vérifier que `QtQuick.Particles` est importé
2. Vérifier que l'image existe : `qrc:///particleresources/glowdot.png`
3. Vérifier que le parent n'a pas `clip: true`

### Les particules sont coupées
Le conteneur parent a probablement `clip: true`. Solution : ajuster le layout ou les marges.

### Performance dégradée
- Réduire `particleCount`
- Réduire `particleLifeSpan`
- Réduire `particleSize`

## 📊 Statut du projet

✅ Composant créé  
✅ Documentation complète  
✅ Tests et exemples fournis  
✅ Intégration dans qml.qrc  
✅ Prêt à l'emploi  

## 🚦 Prochaines étapes

Pour utiliser le bouton dans votre application :

1. **Compiler le projet** pour intégrer les nouvelles ressources
2. **Tester** avec `TEST_PARTICLE_BUTTON.qml`
3. **Intégrer** dans vos écrans
4. **Personnaliser** selon vos besoins

## 📝 Notes

- Le composant hérite de `QtQuick.Controls.Button`, donc toutes les propriétés standard sont disponibles
- Compatible avec le style existant de Meownopoly
- Utilise les ressources de particules déjà présentes dans le projet
- Optimisé pour les performances

## 🎉 Amusez-vous bien !

Le bouton est prêt à être utilisé. N'hésitez pas à explorer les différentes configurations dans les fichiers de test et à l'adapter à vos besoins spécifiques.

Pour toute question, référez-vous au guide détaillé : `qml/PARTICLE_BUTTON_GUIDE.md`

