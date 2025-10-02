# 📝 Guide de Contribution à Meownopoly

Ce document explique comment contribuer efficacement au projet Meownopoly, que vous soyez développeur, designer ou testeur.

## 🌟 Comment Contribuer

Il existe plusieurs façons de contribuer au projet Meownopoly :

1. **Développement** : Ajout de fonctionnalités, correction de bugs
2. **Design** : Création d'assets graphiques, amélioration de l'UI/UX
3. **Tests** : Test des fonctionnalités, rapport de bugs
4. **Documentation** : Amélioration de la documentation existante
5. **Idées** : Suggestions de nouvelles fonctionnalités ou améliorations

## 🔄 Processus de Contribution

### Pour les Contributions de Code

1. **Fork le dépôt**
   - Visitez le dépôt GitHub et cliquez sur "Fork"

2. **Cloner votre fork**
   ```bash
   git clone https://github.com/votre-nom/meownopoly.git
   cd meownopoly
   ```

3. **Créer une branche**
   ```bash
   git checkout -b feature/nom-de-votre-fonctionnalite
   ```
   Conventions de nommage :
   - `feature/` pour les nouvelles fonctionnalités
   - `bugfix/` pour les corrections de bugs
   - `docs/` pour les modifications de documentation
   - `refactor/` pour les refactorisations

4. **Développer votre contribution**
   - Suivez les [conventions de codage](./DEVELOPER_GUIDE.md#conventions-de-codage)
   - Assurez-vous que votre code est bien commenté
   - Testez votre code avant de le soumettre

5. **Commiter vos changements**
   ```bash
   git add .
   git commit -m "Description claire et concise des changements"
   ```
   Format recommandé :
   ```
   [Type]: Description courte
   
   Description détaillée si nécessaire.
   
   Closes #123 (si résout une issue)
   ```
   Types: `Feat`, `Fix`, `Docs`, `Style`, `Refactor`, `Test`, `Chore`

6. **Pousser vers votre fork**
   ```bash
   git push origin feature/nom-de-votre-fonctionnalite
   ```

7. **Créer une Pull Request**
   - Visitez votre fork sur GitHub
   - Cliquez sur "Pull Request"
   - Remplissez le template avec une description détaillée

8. **Revue de code**
   - Les mainteneurs examineront votre code
   - Répondez aux commentaires et apportez les modifications nécessaires

9. **Fusion**
   - Une fois approuvée, votre PR sera fusionnée
   - Félicitations pour votre contribution !

### Pour les Contributions Graphiques

1. **Discuter de l'idée**
   - Ouvrez une issue pour discuter de vos propositions graphiques
   - Joignez des esquisses ou des mockups si possible

2. **Créer les assets**
   - Suivez les [directives artistiques](#directives-artistiques)
   - Utilisez les templates fournis dans le dossier `templates/`

3. **Soumettre les assets**
   - Par PR (comme le code)
   - Ou via le formulaire sur le site officiel

## 📋 Directives de Qualité

### Tests

Tout nouveau code doit être accompagné de tests appropriés :
- **Tests unitaires** pour les classes C++
- **Tests QML** pour les composants d'interface
- **Tests d'intégration** pour les fonctionnalités complètes

### Documentation

Toute nouvelle fonctionnalité doit être documentée :
- **Documentation technique** pour les développeurs
- **Guide utilisateur** pour les joueurs (si applicable)
- **Commentaires de code** clairs et explicatifs

### Revue de Code

Critères de validation lors des revues de code :
- Respect des conventions de codage
- Performance et optimisation
- Absence de bugs évidents
- Tests appropriés
- Documentation suffisante

## 🎨 Directives Artistiques

### Style Graphique

- **Thème félin** : Tous les éléments doivent s'intégrer au thème chat
- **Style cartoon** : Style cartoon moderne, légèrement stylisé
- **Palette de couleurs** : Utiliser la palette officielle disponible dans `templates/palette.ase`
- **Cohérence** : Maintenir une cohérence visuelle avec les assets existants

### Formats et Spécifications

- **Images** : PNG transparent (UI) ou JPG (textures), résolution min. 256x256
- **Modèles 3D** : FBX ou OBJ, textures PBR
- **Sons** : WAV 44.1kHz 16-bit ou OGG
- **Nomenclature** : snake_case pour les noms de fichiers

## 🐞 Signalement de Bugs

Pour signaler un bug :

1. **Vérifiez** que le bug n'a pas déjà été signalé
2. **Créez une nouvelle issue** avec le label "bug"
3. **Décrivez le problème** de manière détaillée :
   - Étapes pour reproduire
   - Comportement attendu vs observé
   - Environnement (OS, version de Qt, etc.)
   - Captures d'écran si pertinent
4. **Utilisez le template** de rapport de bug

## 💡 Proposition de Fonctionnalités

Pour proposer une nouvelle fonctionnalité :

1. **Vérifiez** que la fonctionnalité n'a pas déjà été proposée
2. **Créez une nouvelle issue** avec le label "enhancement"
3. **Décrivez la fonctionnalité** :
   - Objectif et cas d'utilisation
   - Fonctionnement envisagé
   - Bénéfices pour le jeu
4. **Discutez** avec la communauté et les mainteneurs

## 📊 Priorités du Projet

Les contributions sont particulièrement bienvenues dans ces domaines :

### Haute Priorité
- Correction des bugs critiques
- Améliorations de performance
- Implémentation des mécaniques de jeu manquantes

### Priorité Moyenne
- Nouvelles fonctionnalités UI
- Assets supplémentaires
- Extensions de l'éditeur de maps

### Faible Priorité
- Refactorisations mineures
- Optimisations cosmétiques
- Fonctionnalités expérimentales

## 📚 Ressources Utiles

- [Guide du Développeur](./DEVELOPER_GUIDE.md)
- [Structure du Projet](./PROJECT_STRUCTURE.md)
- [Documentation de Qt](https://doc.qt.io/)
- [Canal Discord de Meownopoly](https://discord.gg/meownopoly)

## ❓ Aide et Questions

Si vous avez des questions sur la contribution :

- **Issues GitHub** pour les questions techniques
- **Discord** pour les discussions informelles
- **Email** pour les questions privées : contact@meownopoly.com

## 🙏 Code de Conduite

En contribuant à ce projet, vous acceptez de respecter notre [Code de Conduite](./CODE_OF_CONDUCT.md) :

- Soyez respectueux et inclusif
- Acceptez les critiques constructives
- Concentrez-vous sur ce qui est le mieux pour la communauté
- Montrez de l'empathie envers les autres membres

---

Merci de contribuer à Meownopoly ! Votre aide est précieuse pour faire grandir ce projet félin. 🐾





