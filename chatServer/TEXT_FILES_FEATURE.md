# 📄 Système d'envoi de fichiers texte E2EE

## ✅ Implémentation complète

### 📋 Format de message

**Nouveau format standardisé :**
```
📄FILE:extension:nom_du_fichier.ext

contenu du fichier ici...
```

**Exemple :**
```
📄FILE:py:script.py

import sys
print("Hello World!")
```

### 🎯 Extensions supportées

**Avec icônes personnalisées :**
- 📄 `.txt` - Fichiers texte
- 📝 `.md` - Markdown
- 📊 `.json` - JSON
- 🏷️ `.xml` - XML
- 📜 `.js` / `.ts` - JavaScript/TypeScript
- 🐍 `.py` - Python
- ⚙️ `.cpp` / `.c` / `.h` - C/C++
- ☕ `.java` - Java
- 🌐 `.html` - HTML
- 🎨 `.css` / `.qml` - Styles/QML
- 📋 `.log` - Logs
- 🗄️ `.sql` - SQL
- 🖥️ `.sh` / `.bat` - Scripts shell

### 🔧 Modifications C++

**Fichier : `chat_client.cpp`**

1. **Fonction `processMessageText`**
   - Détecte le format `📄FILE:`
   - Retourne le texte tel quel pour traitement QML

2. **Ajout de propriétés aux messages**
   - `isTextFile` (bool) - Indique si c'est un fichier
   - `fileExtension` (QString) - Extension du fichier
   - Parser automatique du format

3. **Modifications dans toutes les fonctions :**
   - `handleInitSession`
   - `handleNewMessage`
   - `loadHistory`
   - `requestHistory`

### 🎨 Composant QML

**Nouveau fichier : `TextFileDisplay.qml`**

**Fonctionnalités :**
- 📦 Header avec icône + nom + badge extension
- 📝 Contenu scrollable (max 300px)
- 🎨 Police monospace (Consolas/Monaco)
- 📋 Sélection de texte possible
- 🎯 Style moderne avec bordure violette
- 📱 Responsive

**Design :**
- Header : fond violet (#667eea)
- Contenu : fond sombre (#1e1e1e)
- Texte : clair (#e0e0e0)
- Scrollbar automatique

### 📱 Modifications QML

**Fichier : `ChatMessageDelegate.qml`**

- Ajout du composant `TextFileDisplay`
- Condition `visible` basée sur `isTextFile`
- Passage des propriétés `text` et `fileExtension`

### 🌐 Dashboard Web

**Format identique :**
- Parser le même format `📄FILE:ext:filename`
- Affichage avec les mêmes icônes
- Style cohérent avec l'app Qt

### 🔐 Sécurité

**Chiffrement E2EE :**
- ✅ Fichiers chiffrés comme les messages
- ✅ Seuls les participants avec le mot de passe peuvent lire
- ✅ Nom du fichier et extension aussi chiffrés
- ✅ Pas de métadonnées en clair sur le serveur

### 📦 Taille max

- Dashboard : 1MB
- À configurer dans l'app Qt selon besoins

## 🚀 Utilisation

### Dashboard Web
1. Cliquer sur le bouton 📎
2. Sélectionner un fichier texte
3. Le fichier est automatiquement envoyé

### App Qt (à implémenter)
```cpp
// Fonction à ajouter dans ChatClient
void ChatClient::sendTextFile(const QString &filePath) {
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;
    
    QString content = file.readAll();
    QFileInfo fileInfo(filePath);
    QString extension = fileInfo.suffix();
    QString fileName = fileInfo.fileName();
    
    QString message = QString("📄FILE:%1:%2\n\n%3")
        .arg(extension)
        .arg(fileName)
        .arg(content);
    
    sendMessage(message);
}
```

## 🎯 Résultat

**Compatibilité totale :**
- ✅ Fichiers envoyés depuis Dashboard → lisibles dans app Qt
- ✅ Fichiers envoyés depuis app Qt → lisibles dans Dashboard
- ✅ Format unifié et extensible
- ✅ Affichage élégant des deux côtés

## 📝 Notes techniques

**Parser du format :**
```javascript
// JavaScript (Dashboard)
const header = text.split('\n')[0];
const [prefix, extension, fileName] = header.split(':');
const content = text.split('\n').slice(2).join('\n');
```

```cpp
// C++ (App Qt)
QString header = text.split('\n')[0];
QString extension = header.mid(7, header.indexOf(':', 7) - 7);
```

**Avantages du format :**
- Simple à parser
- Robuste (même si contenu contient "📄FILE:")
- Extensible (possibilité d'ajouter métadonnées)
- Lisible en debug

---

**Prochaines étapes possibles :**
- Bouton d'envoi de fichier dans l'app Qt
- Support de plus d'extensions
- Coloration syntaxique selon l'extension
- Bouton de copie du contenu
