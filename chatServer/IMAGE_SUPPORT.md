# 🖼️ Support des Images dans le Dashboard

## ✅ Fonctionnalités implémentées

### 📸 Détection automatique des images
Le dashboard détecte automatiquement les images envoyées au format `data:image/FORMAT;base64,...`

**Formats supportés :**
- ✅ WEBP
- ✅ PNG
- ✅ JPEG/JPG
- ✅ GIF
- ✅ BMP
- ✅ SVG

### 🎨 Affichage optimisé

**Informations affichées :**
- 🖼️ Type d'image (WEBP, PNG, etc.)
- 📊 Taille en KB
- 🏷️ Badge de taille en overlay (coin supérieur droit)

**Contraintes visuelles :**
- Largeur max : 100% du conteneur
- Hauteur max : 400px
- Chargement lazy (loading="lazy")
- Bordures arrondies et ombre portée

### 🖱️ Interactions

**Survol (hover) :**
- Léger zoom (scale 1.02)
- Bordure colorée (violet)
- Ombre plus prononcée

**Clic :**
- Ouvre l'image en plein écran dans un nouvel onglet
- Tooltip "Cliquez pour ouvrir en taille réelle"

**Clic actif (active) :**
- Léger effet de pression (scale 0.98)

### 🛡️ Gestion des erreurs

- Gestion des erreurs de chargement
- Message d'erreur si l'image ne peut pas être affichée
- Chargement progressif pour les grandes images

### 📱 Responsive

- Images adaptées à la largeur du conteneur
- Fonctionne sur mobile et desktop
- Scroll automatique après ajout

## 🔐 Sécurité

- ✅ Compatible avec le chiffrement E2EE
- ✅ Les images sont déchiffrées avant affichage
- ✅ Validation du format data:image

## 📝 Exemples de messages

### Message texte simple
```
Bonjour ! Comment ça va ?
```
→ Affichage normal

### Message avec image WEBP
```
data:image/WEBP;base64,UklGRnaqAABXRUJQVlA4...
```
→ Affichage de l'image avec infos

### Message avec image PNG
```
data:image/PNG;base64,iVBORw0KGgoAAAANSUhEUgAA...
```
→ Affichage de l'image avec infos

## 🎯 Utilisation

1. **Envoyer une image depuis l'app Qt**
   - Utilisez la fonction d'envoi d'image
   - L'image est automatiquement encodée en base64

2. **Visualiser dans le dashboard**
   - L'image s'affiche automatiquement
   - Cliquez pour ouvrir en plein écran

3. **Compatibilité totale**
   - Les images envoyées depuis le dashboard sont visibles dans l'app Qt
   - Les images envoyées depuis l'app Qt sont visibles dans le dashboard

## 🚀 Performance

- **Chargement lazy** : Les images ne sont chargées que quand elles sont visibles
- **Taille optimisée** : Limitation de la hauteur pour éviter les surcharges
- **Messages longs** : Zone scrollable pour les très grandes images

## 🎨 Design

- Style cohérent avec le reste du dashboard
- Animation fluide et moderne
- Badge de taille élégant
- Effets visuels au survol

---

**Note :** Les images sont chiffrées de bout en bout (E2EE) comme tous les messages. Seuls les participants avec le bon mot de passe peuvent les voir !
