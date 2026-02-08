// Mini implémentation du système crypto du chat
// Compatible HTTP (avec crypto-js) et HTTPS (avec Web Crypto API)

// Vérifier si crypto.subtle est disponible
const hasSubtleCrypto = typeof crypto !== 'undefined' && crypto.subtle;
const hasCryptoJS = typeof CryptoJS !== 'undefined';

class ChatCrypto {
    // Dérive la clé de verrouillage (Lock Key) à partir de sessionId + password
    static async deriveLockKey(sessionId, password) {
        const data = sessionId + password;
        
        if (hasSubtleCrypto) {
            const buffer = new TextEncoder().encode(data);
            const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
            return new Uint8Array(hashBuffer);
        } else if (hasCryptoJS) {
            // Utiliser crypto-js pour SHA-256
            const hash = CryptoJS.SHA256(data);
            const words = hash.words;
            const result = new Uint8Array(32);
            for (let i = 0; i < 8; i++) {
                result[i * 4] = (words[i] >>> 24) & 0xFF;
                result[i * 4 + 1] = (words[i] >>> 16) & 0xFF;
                result[i * 4 + 2] = (words[i] >>> 8) & 0xFF;
                result[i * 4 + 3] = words[i] & 0xFF;
            }
            return result;
        } else {
            throw new Error('Aucune bibliothèque crypto disponible');
        }
    }
    
    // Génère un nonce aléatoire de 12 bytes
    static generateNonce() {
        if (hasSubtleCrypto) {
            return crypto.getRandomValues(new Uint8Array(12));
        } else {
            // Utiliser crypto-js random
            const nonce = new Uint8Array(12);
            for (let i = 0; i < 12; i++) {
                nonce[i] = Math.floor(Math.random() * 256);
            }
            return nonce;
        }
    }
    
    // Génère une clé de session aléatoire de 32 bytes
    static generateSessionKey() {
        if (hasSubtleCrypto) {
            return crypto.getRandomValues(new Uint8Array(32));
        } else {
            const key = new Uint8Array(32);
            for (let i = 0; i < 32; i++) {
                key[i] = Math.floor(Math.random() * 256);
            }
            return key;
        }
    }
    
    // Génère un block de keystream pour le chiffrement stream
    static async generateKeystreamBlock(key, nonce, counter) {
        const counterBytes = new TextEncoder().encode(counter.toString());
        const combined = new Uint8Array(key.length + nonce.length + counterBytes.length);
        combined.set(key, 0);
        combined.set(nonce, key.length);
        combined.set(counterBytes, key.length + nonce.length);
        
        if (hasSubtleCrypto) {
            const hashBuffer = await crypto.subtle.digest('SHA-256', combined);
            return new Uint8Array(hashBuffer);
        } else if (hasCryptoJS) {
            // Convertir en WordArray pour crypto-js
            const wordArray = CryptoJS.lib.WordArray.create(combined);
            const hash = CryptoJS.SHA256(wordArray);
            const words = hash.words;
            const result = new Uint8Array(32);
            for (let i = 0; i < 8; i++) {
                result[i * 4] = (words[i] >>> 24) & 0xFF;
                result[i * 4 + 1] = (words[i] >>> 16) & 0xFF;
                result[i * 4 + 2] = (words[i] >>> 8) & 0xFF;
                result[i * 4 + 3] = words[i] & 0xFF;
            }
            return result;
        }
    }
    
    // HMAC-SHA256
    static async hmac(key, data) {
        if (hasSubtleCrypto) {
            const cryptoKey = await crypto.subtle.importKey(
                'raw',
                key,
                { name: 'HMAC', hash: 'SHA-256' },
                false,
                ['sign']
            );
            const signature = await crypto.subtle.sign('HMAC', cryptoKey, data);
            return new Uint8Array(signature);
        } else if (hasCryptoJS) {
            // Convertir en WordArray pour crypto-js
            const keyWords = CryptoJS.lib.WordArray.create(key);
            const dataWords = CryptoJS.lib.WordArray.create(data);
            const hmac = CryptoJS.HmacSHA256(dataWords, keyWords);
            const words = hmac.words;
            const result = new Uint8Array(32);
            for (let i = 0; i < 8; i++) {
                result[i * 4] = (words[i] >>> 24) & 0xFF;
                result[i * 4 + 1] = (words[i] >>> 16) & 0xFF;
                result[i * 4 + 2] = (words[i] >>> 8) & 0xFF;
                result[i * 4 + 3] = words[i] & 0xFF;
            }
            return result;
        }
    }
    
    // Chiffrement (Stream Cipher + HMAC)
    static async encrypt(data, key, nonce) {
        if (!key || !nonce || key.length === 0 || nonce.length === 0) {
            throw new Error('Key and nonce are required');
        }
        
        // 1. Chiffrement avec stream cipher
        const cipherText = new Uint8Array(data.length);
        let blockIndex = 0;
        let keystream = null;
        
        for (let i = 0; i < data.length; i++) {
            if (i % 32 === 0) {
                keystream = await this.generateKeystreamBlock(key, nonce, blockIndex++);
            }
            cipherText[i] = data[i] ^ keystream[i % 32];
        }
        
        // 2. Authentification avec HMAC
        const combined = new Uint8Array(nonce.length + cipherText.length);
        combined.set(nonce, 0);
        combined.set(cipherText, nonce.length);
        const tag = await this.hmac(key, combined);
        
        // Résultat: [Tag (32 bytes)] + [CipherText]
        const result = new Uint8Array(32 + cipherText.length);
        result.set(tag, 0);
        result.set(cipherText, 32);
        
        return result;
    }
    
    // Déchiffrement (vérifie HMAC puis déchiffre)
    static async decrypt(encryptedData, key, nonce) {
        if (!key || !nonce || encryptedData.length < 32) {
            return null;
        }
        
        // 1. Séparer Tag et CipherText
        const receivedTag = encryptedData.slice(0, 32);
        const cipherText = encryptedData.slice(32);
        
        // 2. Vérifier l'intégrité
        const combined = new Uint8Array(nonce.length + cipherText.length);
        combined.set(nonce, 0);
        combined.set(cipherText, nonce.length);
        const expectedTag = await this.hmac(key, combined);
        
        // Comparaison constant-time
        let diff = 0;
        for (let i = 0; i < 32; i++) {
            diff |= receivedTag[i] ^ expectedTag[i];
        }
        if (diff !== 0) {
            console.error('HMAC verification failed - wrong password or corrupted data');
            return null;
        }
        
        // 3. Déchiffrement
        const plainText = new Uint8Array(cipherText.length);
        let blockIndex = 0;
        let keystream = null;
        
        for (let i = 0; i < cipherText.length; i++) {
            if (i % 32 === 0) {
                keystream = await this.generateKeystreamBlock(key, nonce, blockIndex++);
            }
            plainText[i] = cipherText[i] ^ keystream[i % 32];
        }
        
        return plainText;
    }
    
    // Helpers pour conversion
    static bytesToBase64(bytes) {
        return btoa(String.fromCharCode(...bytes));
    }
    
    static base64ToBytes(base64) {
        return Uint8Array.from(atob(base64), c => c.charCodeAt(0));
    }
    
    static bytesToString(bytes) {
        return new TextDecoder().decode(bytes);
    }
    
    static stringToBytes(str) {
        return new TextEncoder().encode(str);
    }
}

// Avertissement au chargement
if (!hasSubtleCrypto) {
    if (hasCryptoJS) {
        console.warn('⚠️ Web Crypto API non disponible - utilisation de crypto-js');
        console.warn('Pour de meilleures performances, utilisez HTTPS');
    } else {
        console.error('❌ Aucune bibliothèque crypto disponible!');
    }
}
