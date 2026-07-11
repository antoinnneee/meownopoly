# 09 — Questionnaire de cadrage V3

> **Statut : à remplir.** Ce questionnaire consolide toutes les interrogations
> ouvertes relevées dans les docs 00→08 et lors de leur audit de cohérence du
> 2026-07-12. Une réponse peut être courte ; les champs « Pourquoi / contraintes »
> servent à conserver l'intention derrière la décision.

## Mode d'emploi

- **B0** : bloque le choix d'architecture ou la preuve de faisabilité.
- **B1** : nécessaire avant un premier vertical slice multi-joueurs.
- **B2** : peut être différé après le prototype, mais doit rester tracé.
- Cocher une option, la remplacer, ou écrire « à prototyper » avec un critère de
  décision. Une question sans réponse reste explicitement ouverte.
- Après remplissage, reporter chaque arbitrage stable dans le doc 08 sous un ID
  de décision. Ne pas transformer une recommandation de ce fichier en décision
  tant qu'elle n'a pas été validée.

---

## A. Produit, périmètre et promesse

### Q-A01 — Quel est le premier mode livré ? — **B0**

- [ ] Éditeur solo assisté par IA
- [ ] Éditeur collaboratif assisté par IA
- [ ] Partie runtime co-construite en direct
- [ ] Vertical slice couvrant éditeur puis runtime
- **Recommandation actuelle :** éditeur solo, puis collaboration, puis runtime.
- **Réponse :**
- **Pourquoi / contraintes :**

### Q-A02 — L'arbitre est-il obligatoire en solo/offline ? — **B0**

- [ ] Oui, tout mode IA exige deux rôles
- [ ] Non, obligatoire seulement quand un état est partagé
- [ ] Non, remplacé en solo par une approbation humaine
- **Réponse :**
- **Pourquoi / contraintes :**

### Q-A03 — Le « jeu classique » doit-il rester pleinement maintenu ? — **B1**

- [ ] Oui, produit de premier rang
- [ ] Oui, mode de repli pendant la transition seulement
- [ ] Non à terme, migration complète vers V3
- **Réponse :**

### Q-A04 — À quel moment une création IA entre-t-elle dans la partie ? — **B0**

- [ ] Dès acceptation de l'arbitre et validation mécanique
- [ ] Après approbation explicite de l'hôte humain
- [ ] En prévisualisation locale, puis publication explicite
- **Réponse :**

### Q-A05 — Une proposition acceptée peut-elle modifier une partie déjà commencée ? — **B1**

- [ ] Oui, sans restriction autre que l'arbitrage
- [ ] Oui, seulement à des points sûrs/phases définies
- [ ] Non, uniquement avant le lancement
- **Réponse :**

### Q-A06 — Quel niveau de liberté constitue le succès du MVP ? — **B0**

- [ ] Composer des primitives + configurer leur mémoire
- [ ] Ajouter du JS borné sur des primitives
- [ ] Charger du QML/JS libre
- **Critère mesurable attendu :**
- **Réponse :**

### Q-A07 — Qui est l'utilisateur cible initial ? — **B1**

- [ ] Joueur non technique
- [ ] Créateur de maps
- [ ] Moddeur/développeur
- [ ] Groupe mixte
- **Réponse :**

### Q-A08 — Quelles plateformes doivent être supportées au premier jalon ? — **B1**

- [ ] Windows uniquement
- [ ] Windows + Linux
- [ ] Windows + Linux + macOS
- **Réponse :**

---

## B. IA cliente, arbitre et fournisseurs de modèles

### Q-B01 — « Deux modèles chez l'hôte » signifie-t-il deux instances distinctes ? — **B0**

- [ ] Deux fournisseurs/processus réellement distincts
- [ ] Un même fournisseur avec deux sessions/contextes isolés
- [ ] Une seule session pouvant changer de rôle
- **Recommandation actuelle :** rôles et contextes isolés ; fournisseur commun autorisé.
- **Réponse :**

### Q-B02 — Quels fournisseurs/protocoles de modèle cible-t-on d'abord ? — **B1**

- [ ] Agent local compatible skill
- [ ] API cloud appelée par un adaptateur local
- [ ] Serveur OpenAI-compatible local
- [ ] Plusieurs via interface d'adaptation
- **Réponse :**

### Q-B03 — Qui démarre et supervise les agents ? — **B1**

- [ ] Le joueur hors du jeu
- [ ] Le launcher Meownopoly
- [ ] Le jeu via un adaptateur/processus enfant
- **Réponse :**

### Q-B04 — Comment le jeu prouve-t-il qu'un arbitre est prêt ? — **B0**

- [ ] Connexion WS avec rôle + challenge de capacité
- [ ] Simple présence d'une connexion déclarée arbitre
- [ ] Test de santé et verdict sur proposition factice
- **Réponse :**

### Q-B05 — Que se passe-t-il si l'arbitre tombe en panne pendant une partie ? — **B0**

- [ ] Gel des nouvelles propositions, partie existante continue
- [ ] Pause complète de la partie
- [ ] Élection/migration vers un nouvel arbitre
- [ ] Repli humain temporaire
- **Réponse :**

### Q-B06 — Qui paie et limite le coût des appels de l'arbitre ? — **B1**

- [ ] L'hôte, sans quota produit
- [ ] L'hôte avec budget configurable
- [ ] Budget partagé/quotas par joueur
- **Réponse :**

### Q-B07 — Les joueurs voient-ils le modèle/prompt de l'arbitre ? — **B1**

- [ ] Oui, transparence complète
- [ ] Prompt/règles visibles, secrets fournisseur masqués
- [ ] Non, choix privé de l'hôte
- **Réponse :**

### Q-B08 — L'hôte peut-il changer d'arbitre en cours de partie ? — **B1**

- [ ] Oui, avec transfert d'état/version
- [ ] Oui, mais seulement à un checkpoint
- [ ] Non
- **Réponse :**

---

## C. Proposition, arbitrage et exécution des règles

### Q-C01 — Quelle est l'unité d'arbitrage ? — **B0**

- [ ] Chaque commande
- [ ] Transaction/lot atomique
- [ ] Artefacts code uniquement
- [ ] Politique hybride selon le niveau de risque
- **Recommandation actuelle :** transaction typée, avec chemin rapide mécanique.
- **Réponse :**

### Q-C02 — Quel est le schéma minimal d'une enveloppe de proposition ? — **B0**

- [ ] Auteur + intention + opérations + artefacts + write-set + version
- [ ] Texte libre + pièces jointes
- [ ] Autre schéma :
- **Réponse :**

### Q-C03 — L'arbitre peut-il amender directement une proposition ? — **B0**

- [ ] Non, accepte ou rejette avec corrections demandées
- [ ] Oui, puis le proposant confirme
- [ ] Oui, l'amendement est immédiatement appliqué
- **Recommandation actuelle :** pas de mutation silencieuse ; retour vers le proposant.
- **Réponse :**

### Q-C04 — Quelles parties du verdict sont persistées ? — **B1**

- [ ] Verdict, raisons, proposition originale et version appliquée
- [ ] Verdict + hash seulement
- [ ] Rien après application
- **Réponse :**

### Q-C05 — Quel ordre de contrôle retient-on ? — **B0**

- [ ] Préfiltre mécanique → arbitre → validation complète → exécution
- [ ] Arbitre → sandbox complet → exécution
- [ ] Sandbox complet → arbitre → exécution
- **Recommandation actuelle :** préfiltre bon marché, arbitre, validation complète.
- **Réponse :**

### Q-C06 — Sous quelle forme une règle acceptée devient-elle exécutable ? — **B0**

- [ ] Plan de commandes/capacités
- [ ] Configuration de modules existants
- [ ] DSL/machine à états bornée
- [ ] QML/JS sandboxé
- [ ] Combinaison hiérarchisée de ces formes
- **Réponse :**

### Q-C07 — Où vit le règlement autoritatif courant ? — **B0**

- [ ] Document structuré versionné dans l'état de session
- [ ] Prompt + historique de l'arbitre uniquement
- [ ] Artefacts exécutables + résumé structuré
- **Recommandation actuelle :** état structuré versionné, jamais prompt seul.
- **Réponse :**

### Q-C08 — Quels événements runtime peuvent déclencher une règle ? — **B1**

- [ ] Liste à fournir :
- **Autorité de chaque événement :**
- **Ordre/priorité en cas d'événements simultanés :**

### Q-C09 — Comment empêcher boucle, réentrance et cascade infinie de règles ? — **B0**

- [ ] Profondeur maximale + budget par tick
- [ ] File d'événements transactionnelle
- [ ] Détection de cycles/write-set
- [ ] Combinaison :
- **Réponse :**

### Q-C10 — Comment introduire un tour par tour ? — **B1**

- [ ] Primitive de tour fournie par le jeu, configurée par l'arbitre
- [ ] Artefact généré par l'IA
- [ ] Orchestration directe par l'arbitre
- **Recommandation actuelle :** primitive déterministe configurable.
- **Réponse :**

### Q-C11 — Quelle est la relation avec `GameplayModuleManager` ? — **B1**

- [ ] Les modules sont les primitives d'exécution privilégiées
- [ ] Les règles forment une couche au-dessus des modules
- [ ] Les deux selon le type d'effet
- **Réponse :**

### Q-C12 — Qui applique un effet partagé ? — **B0**

- [ ] Hôte uniquement, puis réplication de l'état
- [ ] Chaque pair exécute un artefact déterministe
- [ ] Hybride selon la capacité
- **Réponse :**

---

## D. Sandbox, isolation et menace

### Q-D01 — Quel niveau d'isolation est exigé avant d'activer D1 ? — **B0**

- [ ] Pas d'accès disque/réseau/process + limites de ressources préemptives
- [ ] Isolation fonctionnelle sans garantie anti-DoS
- [ ] Exécution locale assumée comme code utilisateur de confiance
- **Réponse :**

### Q-D02 — Où le code généré s'exécute-t-il ? — **B0**

- [ ] Même moteur QML / contexte restreint
- [ ] `QQmlEngine` séparé dans le même processus
- [ ] Processus auxiliaire avec IPC/rendu déporté
- [ ] Jamais de QML libre ; DSL/capacités uniquement
- **Critère de choix après prototype R1 :**
- **Réponse :**

### Q-D03 — Quel est le repli officiel si le JS ne peut pas être interrompu ? — **B0**

- [ ] Processus séparé tuable
- [ ] JS borné/instrumenté
- [ ] DSL déclaratif
- [ ] Palette + mémoire uniquement
- **Réponse :**

### Q-D04 — Quelle allow-list d'imports/types/fonctions est nécessaire au MVP ? — **B0**

- **Imports autorisés :**
- **Types autorisés :**
- **Fonctions globales interdites :**

### Q-D05 — Quelle façade de jeu minimale expose-t-on au code ? — **B0**

- [ ] Mémoire propre à l'élément seulement
- [ ] Mémoire + événements + animations
- [ ] Mémoire + capacités gameplay sélectionnées
- **Liste exacte :**

### Q-D06 — Quels budgets impose-t-on ? — **B1**

- **Taille source/artefact :**
- **CPU par événement/tick :**
- **Mémoire :**
- **Nombre d'objets :**
- **Débit d'événements :**

### Q-D07 — Quelle est la politique de revue humaine ? — **B1**

- [ ] Jamais requise
- [ ] Toujours pour du code
- [ ] Seulement avant réplication/exécution distante
- [ ] Configurable par l'hôte
- **Réponse :**

### Q-D08 — Quel est le modèle de menace local ? — **B0**

- [ ] Processus du même utilisateur considéré hostile
- [ ] Seulement les pairs réseau sont hostiles
- [ ] Machine locale de confiance
- **Secrets/données à protéger :**

### Q-D09 — Comment valide-t-on les artefacts chargés depuis disque/bibliothèque ? — **B1**

- [ ] Revalidation complète à chaque chargement
- [ ] Cache par hash + version de validateur
- [ ] Signature officielle suffisante
- **Réponse :**

### Q-D10 — Quels tests font réussir le prototype R1 ? — **B0**

- [ ] Blocage imports/singletons interdits
- [ ] Blocage fichier/réseau/process
- [ ] Arrêt d'une boucle infinie
- [ ] Plafond mémoire/objets
- [ ] Destruction/rechargement sans fuite
- [ ] Autres :

---

## E. Canal local et protocole

### Q-E01 — Un canal multiplexé ou plusieurs serveurs ? — **B0**

- [ ] Un WS, rôles et namespaces multiplexés
- [ ] Un WS proposant + un WS arbitre
- [ ] Canaux séparés éditeur/runtime/arbitre
- **Réponse :**

### Q-E02 — Comment le port et le secret sont-ils découverts ? — **B1**

- [ ] Fichier runtime à permissions utilisateur
- [ ] Argument/variable d'environnement
- [ ] Port fixe + token affiché/copié
- [ ] IPC natif plutôt que WS
- **Réponse :**

### Q-E03 — Quel mécanisme d'authentification locale ? — **B0**

- [ ] Token éphémère par lancement
- [ ] Token persistant par installation
- [ ] Challenge/réponse lié au rôle
- [ ] Loopback seul
- **Recommandation actuelle :** token éphémère + rôle + rotation.
- **Réponse :**

### Q-E04 — Comment négocie-t-on les versions ? — **B1**

- [ ] Version protocole globale
- [ ] Version + découverte dynamique des capacités
- [ ] Versions par namespace
- **Réponse :**

### Q-E05 — Quel bus alimente les événements poussés ? — **B1**

- [ ] Adaptateur unifié au-dessus de `Game`/`EditorOpBus`/`ItemSnapableEvents`
- [ ] Connexion directe à plusieurs signaux internes
- [ ] Journal d'événements métier nouveau
- **Réponse :**

### Q-E06 — Quelles garanties d'événements ? — **B1**

- [ ] Au plus une fois
- [ ] Au moins une fois + identifiant/déduplication
- [ ] Relecture depuis un curseur/journal
- **Réponse :**

### Q-E07 — Quelle sémantique de transaction pour un lot ? — **B0**

- [ ] Tout ou rien
- [ ] Résultat partiel détaillé
- [ ] Prévalidation puis commit explicite
- **Réponse :**

### Q-E08 — Quelles commandes V2 sont portées dans le MVP ? — **B1**

- [ ] `state.listTiles/getTile`
- [ ] pose et édition par UUID
- [ ] mémoire config/runtime
- [ ] `qml.instantiate`
- [ ] screenshot
- [ ] runtime joueur/NPC
- [ ] roster/modules
- **Sous-ensemble retenu :**

### Q-E09 — Une échappatoire `automation.raw` existe-t-elle ? — **B1**

- [ ] Non
- [ ] Build dev uniquement, absent du manifeste livré
- [ ] Oui avec permission explicite
- **Recommandation actuelle :** build dev uniquement ou aucune.
- **Réponse :**

### Q-E10 — Quelle politique de capture d'écran ? — **B2**

- **Fréquence/résolution maximales :**
- **Éléments privés à masquer :**
- **Consentement utilisateur :**

---

## F. Mémoire, persistance, réseau et undo

### Q-F01 — Valide-t-on la séparation `config` / `state` ? — **B0**

- [ ] Oui, deux namespaces dans un même `memory`
- [ ] Oui, deux propriétés/conteneurs distincts
- [ ] Non, autre modèle :
- **Réponse :**

### Q-F02 — L'état runtime doit-il survivre à une sauvegarde/reprise ? — **B0**

- [ ] Non, toujours réinitialisé
- [ ] Oui, dans une sauvegarde de partie distincte de la map
- [ ] Oui, directement dans le fichier map
- **Recommandation actuelle :** sauvegarde de partie distincte.
- **Réponse :**

### Q-F03 — La mémoire existe-t-elle aussi au niveau partie/joueur ? — **B1**

- [ ] Tuiles uniquement
- [ ] Tuiles + `MapInfo`/session
- [ ] Tuiles + session + `PlayerProfile`/joueur
- **Réponse :**

### Q-F04 — Quel transport pour l'état runtime ? — **B0**

- [ ] Nouveau protocole/message dédié
- [ ] Extension de `PhysicsSession`
- [ ] Bus d'état générique partagé
- **Réponse :**

### Q-F05 — Delta ou snapshot ? — **B0**

- [ ] Delta par clé avec version
- [ ] Snapshot complet par entité
- [ ] Delta fréquent + snapshot périodique de réparation
- **Recommandation actuelle :** delta coalescé + snapshot de réparation.
- **Réponse :**

### Q-F06 — Reliable ou latest-state/raw ? — **B0**

- [ ] Reliable ordonné
- [ ] Raw/supersedable + séquence
- [ ] Hybride : intentions fiables, états supersedables
- **Recommandation actuelle :** hybride.
- **Réponse :**

### Q-F07 — Cadence et plafonds ? — **B1**

- **Cadence maximale :**
- **Taille max par valeur/tuile/session :**
- **Budget bande passante par pair :**
- **Politique de dépassement :**

### Q-F08 — Comment versionner/résoudre les écritures concurrentes ? — **B0**

- [ ] Hôte séquence tout, dernier accepté gagne
- [ ] Version par clé + rejet des écritures périmées
- [ ] Fusion spécifique au type
- **Réponse :**

### Q-F09 — Quel write-set une proposition doit-elle déclarer ? — **B1**

- [ ] Tuiles seulement
- [ ] Tuiles + clés mémoire
- [ ] Ressources/capacités complètes
- **Réponse :**

### Q-F10 — Que fait undo si une valeur durable a changé depuis ? — **B0**

- [ ] Refuse et signale un conflit
- [ ] Restaure malgré tout
- [ ] Compensation conditionnelle par version
- **Recommandation actuelle :** compensation conditionnelle, sinon conflit.
- **Réponse :**

### Q-F11 — Quel signal QML exposer ? — **B1**

- [ ] `userMemoryChanged()` global
- [ ] `memoryValueChanged(namespace, key, value, version)` ciblé
- [ ] Les deux
- **Réponse :**

---

## G. Artefacts, réplication et cycle de vie

### Q-G01 — En posture initiale, où la source QML circule-t-elle ? — **B0**

- [ ] Client auteur → hôte arbitre seulement
- [ ] Client → hôte → tous les pairs
- [ ] Aucun code client ; génération uniquement chez l'hôte
- **Recommandation actuelle :** auteur → hôte, sans broadcast aux pairs.
- **Réponse :**

### Q-G02 — Où le comportement accepté s'exécute-t-il ? — **B0**

- [ ] Auteur seulement ; l'hôte valide chaque effet partagé
- [ ] Hôte seulement ; les effets sont répliqués
- [ ] Chaque pair après revalidation
- [ ] Selon une propriété de l'artefact
- **Réponse :**

### Q-G03 — Comment identifier/versionner un artefact ? — **B1**

- [ ] Hash de contenu + manifeste + version de schéma
- [ ] UUID mutable
- [ ] Nom logique + version sémantique
- **Réponse :**

### Q-G04 — Où persister les sources acceptées ? — **B1**

- [ ] Dans le JSON de map
- [ ] Dans un store d'artefacts séparé, référencé par hash
- [ ] Session seulement, non persistées
- **Recommandation actuelle :** store séparé par hash.
- **Réponse :**

### Q-G05 — Que se passe-t-il si un artefact manque au chargement ? — **B1**

- [ ] Chargement refusé
- [ ] Élément désactivé avec diagnostic
- [ ] Téléchargement automatique depuis la bibliothèque
- **Réponse :**

### Q-G06 — Quel est le cycle de vie d'un artefact attaché à plusieurs tuiles ? — **B1**

- **Ownership/références :**
- **Suppression :**
- **Mise à jour/migration :**

### Q-G07 — Comment migre-t-on l'autorité lors d'un changement d'hôte ? — **B0**

- **État du règlement transféré :**
- **Artefacts/hashes transférés :**
- **État runtime/checkpoint transféré :**
- **Nouvel arbitre requis avant reprise :**

---

## H. Skill cliente et expérience d'installation

### Q-H01 — Quel agent cible-t-on en premier ? — **B1**

- [ ] Codex
- [ ] Claude Code
- [ ] Agent générique avec tools JSON
- [ ] Adaptateur indépendant de l'agent
- **Réponse :**

### Q-H02 — La skill contient-elle un client WS exécutable ? — **B1**

- [ ] Oui, tool/CLI livré
- [ ] Non, seulement la documentation du protocole
- [ ] Connecteur natif propre à chaque agent
- **Recommandation actuelle :** CLI/adaptateur livré, protocole documenté.
- **Réponse :**

### Q-H03 — Quel artefact est la source de vérité ? — **B0**

- [x] Manifeste versionné du canal IA
- [ ] MCP d'automation
- [ ] Documentation manuscrite
- **Confirmation / correction :**

### Q-H04 — Où installer la skill par plateforme/agent ? — **B1**

- **Windows :**
- **Linux :**
- **macOS :**
- **Gestion de plusieurs agents :**

### Q-H05 — Quand la skill est-elle générée/mise à jour ? — **B1**

- [ ] Build du jeu
- [ ] Packaging de l'installeur
- [ ] Génération dynamique depuis le serveur
- [ ] Combinaison :
- **Réponse :**

### Q-H06 — Comment gère-t-on une skill obsolète ? — **B1**

- [ ] Refus de connexion
- [ ] Mode compatibilité négocié
- [ ] Mise à jour automatique proposée
- **Réponse :**

### Q-H07 — Faut-il réconcilier tous les hooks avec le MCP ? — **B2**

- [ ] Non, inventorier puis porter seulement le catalogue curé
- [ ] Oui, parité complète
- [ ] Ajouter un invocateur générique
- **Recommandation actuelle :** inventaire + port explicite, pas d'invocateur générique en prod.
- **Réponse :**

---

## I. Bibliothèque et assets 3D

### Q-I01 — Quel ordre de livraison ? — **B1**

- [ ] Primitives gameplay → assets 3D → créations partagées
- [ ] Assets 3D → primitives gameplay → créations partagées
- [ ] Bibliothèque locale unifiée dès le départ
- **Réponse :**

### Q-I02 — Bibliothèque locale ou communautaire au premier jalon ? — **B1**

- [ ] Locale officielle uniquement
- [ ] Locale + imports utilisateur
- [ ] Serveur communautaire
- **Réponse :**

### Q-I03 — Réutilise-t-on `asset_server/` et le launcher ? — **B1**

- [ ] Oui
- [ ] Non, nouvelle infrastructure
- [ ] Après audit de compatibilité
- **Critères d'audit :**
- **Réponse :**

### Q-I04 — Quel format de package commun ? — **B1**

- **Manifeste/métadonnées :**
- **Données/config :**
- **Code éventuel :**
- **Dépendances/assets :**
- **Signature/hash :**

### Q-I05 — Quel modèle de confiance ? — **B0**

- [ ] Officiel signé + communautaire revalidé
- [ ] Tout revalider, signature informative
- [ ] Modération serveur avant publication
- [ ] Combinaison :
- **Réponse :**

### Q-I06 — Quels formats 3D supportés d'abord ? — **B1**

- [ ] glTF/GLB
- [ ] OBJ
- [ ] Formats convertis au build/import vers un format interne
- **Réponse :**

### Q-I07 — Qui peut importer un asset 3D ? — **B1**

- [ ] Développeurs seulement
- [ ] Hôte
- [ ] Tout joueur, après validation/arbitrage
- **Réponse :**

### Q-I08 — Comment l'IA référence-t-elle un asset ? — **B1**

- [ ] ID logique versionné
- [ ] Hash de contenu
- [ ] URL
- [ ] ID + hash résolu par manifeste
- **Réponse :**

### Q-I09 — Quels budgets pour les assets ? — **B1**

- **Triangles/mesh :**
- **Textures/résolution :**
- **Taille disque/réseau :**
- **Animations/materials autorisés :**

---

## J. Observabilité, gouvernance et critères de sortie du cadrage

### Q-J01 — Quel journal d'audit conserve-t-on ? — **B1**

- [ ] Propositions + verdicts + opérations + hashes
- [ ] Erreurs uniquement
- [ ] Journal configurable
- **Durée/rétention :**
- **Réponse :**

### Q-J02 — Quelles données peuvent contenir des informations privées ? — **B1**

- [ ] Prompts/conversations
- [ ] Captures d'écran
- [ ] Sources générées
- [ ] Identifiants/fournisseurs
- **Politique de stockage/effacement :**

### Q-J03 — Comment diagnostiquer une divergence entre pairs ? — **B1**

- [ ] Hash périodique d'état + resync
- [ ] Journal d'événements rejouable
- [ ] Snapshot autoritatif à la demande
- **Réponse :**

### Q-J04 — Quels indicateurs mesurent la qualité de l'arbitrage ? — **B2**

- **Latence cible :**
- **Taux d'acceptation/rejet/amendement :**
- **Taux de rollback/erreur après acceptation :**
- **Coût cible :**

### Q-J05 — Quels scénarios end-to-end valident le vertical slice ? — **B0**

- [ ] Création solo d'un élément avec config + comportement
- [ ] Proposition cliente arbitrée puis appliquée par l'hôte
- [ ] Rejet actionnable et itération
- [ ] Undo ciblé sans écraser l'état concurrent
- [ ] Reconnexion/resync
- [ ] Migration d'hôte/arbitre
- [ ] Chargement d'une sauvegarde avec artefacts
- **Scénarios retenus :**

### Q-J06 — Quels critères font abandonner ou réduire D1 ? — **B0**

- **Échec d'isolation :**
- **Budget performance dépassé :**
- **Complexité multi-joueurs excessive :**
- **Repli choisi :**

### Q-J07 — Quel est le prochain document à produire après réponses ? — **B1**

- [ ] ADR consolidés D9+
- [ ] Spécification du prototype sandbox R1
- [ ] Schéma du protocole/enveloppe de proposition
- [ ] Plan du vertical slice
- **Ordre retenu :**

### Q-J08 — Qui valide définitivement chaque famille de décisions ? — **B1**

- **Produit/vision :**
- **Sécurité :**
- **Réseau :**
- **Gameplay/règles :**
- **Bibliothèque/assets :**

---

## Synthèse à remplir en dernier

- **Premier mode livré :**
- **Politique d'arbitre solo / multi :**
- **Forme d'exécution des règles :**
- **Niveau d'isolation QML retenu :**
- **Politique de réplication des artefacts :**
- **Modèle mémoire config/runtime :**
- **Transport runtime retenu :**
- **Agent client initial :**
- **Périmètre initial de bibliothèque :**
- **Critères de réussite du vertical slice :**
- **Décisions encore bloquées par un prototype :**
