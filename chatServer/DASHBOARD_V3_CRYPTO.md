# 🔐 Dashboard v3 - Chiffrement E2EE Complet

## ✅ Nouveautés majeures

### 1. **Champ Mot de Passe ajouté** 🔑
- Nouveau champ dans le formulaire de connexion
- Valeur par défaut : "123" (comme dans l'app Qt)
- Le mot de passe est combiné avec l'ID de session pour dériver la **Lock Key**

### 2. **Implémentation du chiffrement E2EE** 🔐
Nouveau fichier `chat_crypto.js` qui implémente exactement le même système que le C++ :

#### Algorithmes utilisés :
- **Lock Key** : SHA-256(sessionId + password)
- **Chiffrement** : Stream Cipher custom (SHA-256 basé)
- **Authentification** : HMAC-SHA-256
- **Clés de session** : 256 bits aléatoires (CSPRNG)
- **Nonces** : 96 bits aléatoires

#### Fonctionnalités crypto :
- ✅ Dérivation de clé (KDF)
- ✅ Génération de nonces et clés aléatoires
- ✅ Chiffrement avec authentification (Encrypt-then-MAC)
- ✅ Déchiffrement avec vérification HMAC
- ✅ Conversion Base64 ↔ Bytes

### 3. **Client de chat fonctionnel avec déchiffrement** 💬
Le mini client peut maintenant :

#### Gestion des clés :
- 🔓 Déchiffrer les clés de session reçues du serveur
- 🔑 Générer et publier de nouvelles clés de session
- 📦 Stocker les clés déchiffrées en mémoire
- 🔄 Gérer plusieurs versions de clés (key rotation)

#### Messagerie :
- 📤 **Envoyer des messages chiffrés** avec la clé actuelle
- 📥 **Recevoir et déchiffrer les messages** automatiquement
- 📜 Afficher l'historique déchiffré
- ⚠️ Détecter les messages non déchiffrables (clé manquante ou mauvais mot de passe)

#### Interface :
- 🔐 Indicateur "Message chiffré - clé manquante" pour les messages sans clé
- 🚫 Affichage "[Échec du déchiffrement]" si mauvais mot de passe
- ✅ Messages en clair une fois déchiffrés correctement
- 💬 Distinction visuelle entre vos messages et ceux des autres

### 4. **Compatibilité totale avec l'app Qt** 🎯
- Utilise exactement les mêmes algorithmes
- Format de données identique (Base64)
- Peut communiquer avec les clients Qt
- Même gestion des erreurs

## 🔒 Sécurité

### Ce qui est implémenté :
✅ Chiffrement E2EE authentique
✅ Dérivation de clé basée sur mot de passe
✅ HMAC pour vérifier l'intégrité
✅ Rotation de clés automatique
✅ Génération cryptographique sécurisée (CSPRNG)

### Limites actuelles :
⚠️ Le serveur reste un "blind relay" (ne peut pas lire les messages)
⚠️ Pas de PBKDF2 (juste SHA-256) - à améliorer pour production
⚠️ Pas de forward secrecy
⚠️ Clés stockées en mémoire (non persistées côté dashboard)

## 📝 Utilisation

1. **Entrer un ID de session** (ex: "game_123" ou "Pattoune")
2. **Entrer votre pseudo**
3. **Entrer le mot de passe** de la session (par défaut "123")
4. **Cliquer "Rejoindre"**

Si c'est la première fois dans cette session :
- Le client génère automatiquement une nouvelle clé de session
- La clé est chiffrée avec votre mot de passe et envoyée au serveur

Si la session existe déjà :
- Le client reçoit les clés chiffrées du serveur
- Les déchiffre avec votre mot de passe
- Peut alors lire et envoyer des messages

### Test de compatibilité :
Vous pouvez :
- Envoyer des messages depuis le dashboard
- Les lire depuis l'app Qt
- Et vice-versa !

## 🔧 Architecture technique

```
Dashboard (Browser)
    ↓
Lock Key = SHA256(sessionId + password)
    ↓
[Recevoir] Encrypted Session Keys du serveur
    ↓
Decrypt avec Lock Key
    ↓
Session Keys déchiffrées en mémoire
    ↓
[Envoyer/Recevoir] Messages chiffrés avec Session Key
```

## 🚀 Déploiement

```bash
# Sur le serveur
sudo systemctl restart meownopoly-chat-server

# Tester
curl https://votre-domaine.com/chat_crypto.js
```

## 🎉 Résultat

Le dashboard est maintenant un **vrai client de chat E2EE** complètement fonctionnel !
- Chiffrement identique à l'app Qt
- Peut communiquer avec tous les clients
- Parfait pour le debug et les tests en production

---

**Note de sécurité :** Utilisation de SubtleCrypto (Web Crypto API) pour toutes les opérations cryptographiques, garantissant une implémentation sécurisée et performante côté navigateur.
