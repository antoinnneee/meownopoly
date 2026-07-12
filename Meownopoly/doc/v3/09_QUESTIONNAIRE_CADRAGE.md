# 09 — Questionnaire de cadrage V3

> **Statut : partiellement rempli, dépouillé le 2026-07-12.** Ce questionnaire consolide toutes les interrogations
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
- Les mentions **Vérification stack** renvoient à
  [`10_AUDIT_STACK_EXISTANTE.md`](./10_AUDIT_STACK_EXISTANTE.md).

---



## A. Produit, périmètre et promesse



### Q-A01 — Quels modes appartiennent à la V3 initiale, et dans quel ordre ? — **B0**

- [x] Éditeur solo assisté par IA
- [x] Éditeur collaboratif assisté par IA
- [x] Partie runtime co-construite en direct
- [ ] Vertical slice couvrant éditeur puis runtime

- **Recommandation actuelle :** éditeur solo, puis collaboration, puis runtime.
- **Lecture de la réponse :** les trois modes sont dans le périmètre V3. Leur
  ordre de livraison n'est pas encore tranché puisque plusieurs « premiers modes »
  ont été cochés.
- **Réponse :**
- **Pourquoi / contraintes :**



### Q-A02 — L'arbitre est-il obligatoire en solo/offline ? — **B0**

- [x] Oui, tout mode IA exige deux rôles
- [ ] Non, obligatoire seulement quand un état est partagé
- [ ] Non, remplacé en solo par une approbation humaine

- **Réponse :**
- **Pourquoi / contraintes :**



### Q-A03 — Le « jeu classique » doit-il rester pleinement maintenu ? — **B1**

- [ ] Oui, produit de premier rang
- [ ] Oui, mode de repli pendant la transition seulement
- [x] Non à terme, migration complète vers V3

- **Réponse :**



### Q-A04 — À quel moment une création IA entre-t-elle dans la partie ? — **B0**

- [x] Dès acceptation de l'arbitre et validation mécanique
- [ ] Après approbation explicite de l'hôte humain
- [ ] En prévisualisation locale, puis publication explicite

- **Réponse :**



### Q-A05 — Une proposition acceptée peut-elle modifier une partie déjà commencée ? — **B1**

- [x] Oui, sans restriction autre que l'arbitrage
- [ ] Oui, seulement à des points sûrs/phases définies
- [ ] Non, uniquement avant le lancement

- **Réponse :**



### Q-A06 — Quel niveau de liberté constitue le succès du MVP ? — **B0**

- [x] Composer des primitives + configurer leur mémoire
- [x] Ajouter du JS borné sur des primitives
- [x] Charger du QML/JS libre

- **Critère mesurable attendu : creation d'item qui modifie le gameplay, modificaiton de physique, d'element, interraction avec le joueur**
- **Réponse :**



### Q-A07 — Qui est l'utilisateur cible initial ? — **B1**

- [ ] Joueur non technique
- [ ] Créateur de maps
- [ ] Moddeur/développeur
- [x] Groupe mixte

- **Réponse :**



### Q-A08 — Quelles plateformes doivent être supportées au premier jalon ? — **B1**

- [ ] Windows uniquement
- [x] Windows + Linux
- [ ] Windows + Linux + macOS

- **Réponse :**
- **Vérification stack :** cible Linux plausible côté CMake/C++/QML, mais aucun
  packaging, CI ni test Linux n'existe encore. La réponse crée un chantier de
  qualification Linux ; elle ne décrit pas un support déjà acquis.

---



## B. IA cliente, arbitre et fournisseurs de modèles



### Q-B01 — « Deux modèles chez l'hôte » signifie-t-il deux instances distinctes ? — **B0**

- [x] Deux fournisseurs/processus réellement distincts
- [x] Un même fournisseur avec deux sessions/contextes isolés
- [ ] Une seule session pouvant changer de rôle

- **Recommandation actuelle :** rôles et contextes isolés ; fournisseur commun autorisé.
- **Réponse :**



### Q-B02 — Quels fournisseurs/protocoles de modèle cible-t-on d'abord ? — **B1**

- [ ] Agent local compatible skill
- [ ] API cloud appelée par un adaptateur local
- [ ] Serveur OpenAI-compatible local
- [ ] Plusieurs via interface d'adaptation

- **Réponse : claude -p et equivalent codex**



### Q-B03 — Qui démarre et supervise les agents ? — **B1**

- [ ] Le joueur hors du jeu
- [x] Le launcher Meownopoly
- [x] Le jeu via un adaptateur/processus enfant

- **Réponse :**
- **Vérification stack :** `LauncherManager` ne lance aujourd'hui aucun processus.
  La supervision de `claude -p` et de l'équivalent Codex exige un adaptateur basé
  sur `QProcess`, avec cycle de vie, logs, timeout et secrets.



### Q-B04 — Comment le jeu prouve-t-il qu'un arbitre est prêt ? — **B0**

- [ ] Connexion WS avec rôle + challenge de capacité
- [ ] Simple présence d'une connexion déclarée arbitre
- [ ] Test de santé et verdict sur proposition factice

- **Réponse : Les joueur configure ensemble l'arbitre avec des prompt avant de lancer la partie**
- **Point restant :** cette réponse décrit la configuration collective, pas la
  preuve technique de disponibilité. Le handshake de rôle et un health-check
  restent à choisir avant de pouvoir bloquer/débloquer le lancement.



### Q-B05 — Que se passe-t-il si l'arbitre tombe en panne pendant une partie ? — **B0**

- [ ] Gel des nouvelles propositions, partie existante continue
- [ ] Pause complète de la partie
- [x] Élection/migration vers un nouvel arbitre
- [ ] Repli humain temporaire

- **Réponse :**
- **Vérification stack :** l'élection/promotion d'hôte éditeur existe. Elle ne
  transfère ni contexte d'arbitre, ni règlement V3, ni état runtime générique.



### Q-B06 — Qui paie et limite le coût des appels de l'arbitre ? — **B1**

- [ ] L'hôte, sans quota produit
- [x] L'hôte avec budget configurable
- [ ] Budget partagé/quotas par joueur

- **Réponse :**



### Q-B07 — Les joueurs voient-ils le modèle/prompt de l'arbitre ? — **B1**

- [ ] Oui, transparence complète
- [ ] Prompt/règles visibles, secrets fournisseur masqués
- [ ] Non, choix privé de l'hôte

- **Réponse : l'arbitre choisis les regles qu'il affiche, elle peuvent etre modifier en cours de partie, l'affichage des regles dépendra du choix de l'arbitre (voir B04)**



### Q-B08 — L'hôte peut-il changer d'arbitre en cours de partie ? — **B1**

- [x] Oui, avec transfert d'état/version
- [ ] Oui, mais seulement à un checkpoint
- [ ] Non

- **Réponse :**

---



## C. Proposition, arbitrage et exécution des règles



### Q-C01 — Qu'est-ce qui déclenche un appel à l'arbitre ? — **B0**

- [ ] **Chaque commande** : poser une tuile et modifier une clé provoquent deux appels
- [ ] **Une proposition complète** : « créer une rivière » forme un seul lot atomique
- [ ] **Le code uniquement** : les opérations de données passent par validation mécanique
- [ ] **Politique hybride** : données sûres groupées, code/règles toujours arbitrés

- **Recommandation actuelle :** transaction typée, avec chemin rapide mécanique.
- **Réponse :**



### Q-C02 — Quel est le schéma minimal d'une enveloppe de proposition ? — **B0**

- [x] Auteur + intention + opérations + artefacts + write-set + version
- [ ] Texte libre + pièces jointes
- [ ] Autre schéma :

- **Réponse :**



### Q-C03 — L'arbitre peut-il amender directement une proposition ? — **B0**

- [ ] Non, accepte ou rejette avec corrections demandées
- [ ] Oui, puis le proposant confirme
- [x] Oui, l'amendement est immédiatement appliqué

- **Recommandation actuelle :** pas de mutation silencieuse ; retour vers le proposant.
- **Réponse : l'arbitre dispose d'une personalité définie avec les regles de début de partie**
- **Décision lue :** l'amendement direct et immédiat est autorisé. La personnalité
  explique *comment* il amende, mais il reste nécessaire de journaliser exactement
  la version amendée appliquée pour rendre l'action auditée et rejouable.



### Q-C04 — Quelles parties du verdict sont persistées ? — **B1**

- [x] Verdict, raisons, proposition originale et version appliquée
- [ ] Verdict + hash seulement
- [ ] Rien après application

- **Réponse :**



### Q-C05 — Quel ordre de contrôle retient-on ? — **B0**

- [x] Préfiltre mécanique → arbitre → validation complète → exécution
- [ ] Arbitre → sandbox complet → exécution
- [ ] Sandbox complet → arbitre → exécution

- **Recommandation actuelle :** préfiltre bon marché, arbitre, validation complète.
- **Réponse :**



### Q-C06 — Sous quelle forme une règle acceptée devient-elle exécutable ? — **B0**

- [x] Plan de commandes/capacités
- [x] Configuration de modules existants
- [x] DSL/machine à états bornée
- [x] QML/JS sandboxé
- [x] Combinaison hiérarchisée de ces formes

- **Réponse : a affiner**



### Q-C07 — Où vit le règlement autoritatif courant ? — **B0**

- [x] Document structuré versionné dans l'état de session
- [ ] Prompt + historique de l'arbitre uniquement
- [ ] Artefacts exécutables + résumé structuré

- **Recommandation actuelle :** état structuré versionné, jamais prompt seul.
- **Réponse :**



### Q-C08 — Quels événements runtime peuvent déclencher une règle ? — **B1**

- [ ] Liste à fournir : 

- **Autorité de chaque événement :**
- **Ordre/priorité en cas d'événements simultanés :**
- **A Affiner**



### Q-C09 — Comment empêcher boucle, réentrance et cascade infinie de règles ? — **B0**

- [x] Profondeur maximale + budget par tick
- [x] File d'événements transactionnelle
- [x] Détection de cycles/write-set
- [ ] Combinaison :

- **Réponse :**



### Q-C10 — Comment introduire un tour par tour ? — **B1**

- [ ] Primitive de tour fournie par le jeu, configurée par l'arbitre
- [x] Artefact généré par l'IA
- [x] Orchestration directe par l'arbitre

- **Recommandation actuelle :** primitive déterministe configurable.
- **Réponse :**
- **Décision lue :** le tour, s'il existe, est généré/orchestré par l'IA et
  l'arbitre ; aucune primitive de tour native n'est exigée à ce stade.



### Q-C11 — Quelle est la relation avec `GameplayModuleManager` ? — **B1**

- [x] Les modules sont les primitives d'exécution privilégiées
- [x] Les règles forment une couche au-dessus des modules
- [x] Les deux selon le type d'effet

- **Réponse :**



### Q-C12 — Qui applique un effet partagé ? — **B0**

- [x] Hôte uniquement, puis réplication de l'état
- [ ] Chaque pair exécute un artefact déterministe
- [x] Hybride selon la capacité

- **Réponse :**

---



## D. Sandbox, isolation et menace



### Q-D01 — Quel niveau d'isolation est exigé avant d'activer D1 ? — **B0**

- [x] Pas d'accès disque/réseau/process + limites de ressources préemptives
- [ ] Isolation fonctionnelle sans garantie anti-DoS
- [ ] Exécution locale assumée comme code utilisateur de confiance

- **Réponse :**



### Q-D02 — Où le code généré s'exécute-t-il ? — **B0**

- [x] Même moteur QML / contexte restreint
- [ ] `QQmlEngine` séparé dans le même processus
- [ ] Processus auxiliaire avec IPC/rendu déporté
- [ ] Jamais de QML libre ; DSL/capacités uniquement

- **Critère de choix après prototype R1 :**
- **Réponse :**
- **Vérification stack :** aucun sandbox n'existe. Le moteur courant enregistre de
  nombreux singletons globaux. Le choix « même moteur » est **conditionnel** : il
  doit réussir D10, notamment l'arrêt préemptif d'une boucle infinie, avant d'être
  considéré faisable.



### Q-D03 — Quel est le repli officiel si le JS ne peut pas être interrompu ? — **B0**

- [ ] Processus séparé tuable
- [x] JS borné/instrumenté
- [ ] DSL déclaratif
- [ ] Palette + mémoire uniquement

- **Réponse :**



### Q-D04 — Quelle allow-list d'imports/types/fonctions est nécessaire au MVP ? — **B0**

- **Imports autorisés :**
- **Types autorisés :**
- **Fonctions globales interdites :**

On affinera plus tard

### Q-D05 — Quelle façade de jeu minimale expose-t-on au code ? — **B0**

- [ ] Mémoire propre à l'élément seulement
- [x] Mémoire + événements + animations
- [x] Mémoire + capacités gameplay sélectionnées

- **Liste exacte :**



### Q-D06 — Quels budgets impose-t-on ? — **B1**

- **Taille source/artefact :**
- **CPU par événement/tick :**
- **Mémoire :**
- **Nombre d'objets :**
- **Débit d'événements :**

A affiner en test 

### Q-D07 — Quelle est la politique de revue humaine ? — **B1**

- [x] Jamais requise
- [ ] Toujours pour du code
- [ ] Seulement avant réplication/exécution distante
- [ ] Configurable par l'hôte

- **Réponse :**



### Q-D08 — Quel est le modèle de menace local ? — **B0**

- [ ] Processus du même utilisateur considéré hostile
- [x] Seulement les pairs réseau sont hostiles
- [ ] Machine locale de confiance

- **Secrets/données à protéger :**



### Q-D09 — Comment valide-t-on les artefacts chargés depuis disque/bibliothèque ? — **B1**

- [ ] Revalidation complète à chaque chargement
- [ ] Cache par hash + version de validateur
- [x] Signature officielle suffisante

- **Réponse :**
- **Vérification stack :** le launcher vérifie un SHA-256 transmis par le serveur,
  mais aucune signature cryptographique d'éditeur n'existe. « Signature officielle
  suffisante » nécessite donc une nouvelle chaîne de signature et ne couvre pas
  les artefacts générés/non officiels.



### Q-D10 — Quels tests font réussir le prototype R1 ? — **B0**

- [x] Blocage imports/singletons interdits
- [x] Blocage fichier/réseau/process
- [x] Arrêt d'une boucle infinie
- [x] Plafond mémoire/objets
- [x] Destruction/rechargement sans fuite
- [ ] Autres :

---



## E. Canal local et protocole



### Q-E01 — Un canal multiplexé ou plusieurs serveurs ? — **B0**

- [x] Un WS, rôles et namespaces multiplexés
- [ ] Un WS proposant + un WS arbitre
- [ ] Canaux séparés éditeur/runtime/arbitre

- **Réponse :**



### Q-E02 — Comment le port et le secret sont-ils découverts ? — **B1**

- [ ] Fichier runtime à permissions utilisateur
- [ ] Argument/variable d'environnement
- [ ] Port fixe + token affiché/copié
- [ ] IPC natif plutôt que WS

- **Réponse : stack reseau existante**
- **Vérification stack :** l'automation accepte `--automation-port` ou
  `MEOW_AUTOMATION_PORT`; aucun secret n'est découvert. Réutilisable pour le port,
  insuffisant pour le secret du canal IA.



### Q-E03 — Quel mécanisme d'authentification locale ? — **B0**

- [ ] Token éphémère par lancement
- [ ] Token persistant par installation
- [ ] Challenge/réponse lié au rôle
- [ ] Loopback seul

- **Recommandation actuelle :** token éphémère + rôle + rotation.
- **Réponse : stack reseau existante**
- **Vérification stack :** **réponse non close**. La stack n'offre que le loopback,
  sans token, rôle ni challenge. L'une des trois premières options reste à choisir.



### Q-E04 — Comment négocie-t-on les versions ? — **B1**

- [x] Version protocole globale
- [ ] Version + découverte dynamique des capacités
- [ ] Versions par namespace

- **Réponse :**



### Q-E05 — Quel bus alimente les événements poussés ? — **B1**

- [x] Adaptateur unifié au-dessus de `Game`/`EditorOpBus`/`ItemSnapableEvents`
- [x] Connexion directe à plusieurs signaux internes
- [x] Journal d'événements métier nouveau

- **Réponse :** 



### Q-E06 — Quelles garanties d'événements ? — **B1**

- [ ] Au plus une fois
- [ ] Au moins une fois + identifiant/déduplication
- [ ] Relecture depuis un curseur/journal

- **Réponse : stack reseau existante**
- **Vérification stack :** **réponse non close**. `reliable.io` acquitte et
  fragmente mais ne retransmet pas automatiquement. Les garanties V3 exigent ACK
  applicatif/retry/déduplication ou snapshot de réparation.



### Q-E07 — Quelle sémantique de transaction pour un lot ? — **B0**

- [x] Tout ou rien
- [ ] Résultat partiel détaillé
- [ ] Prévalidation puis commit explicite

- **Réponse :** 
- **Vérification stack :** `groupId` groupe déjà undo/save/broadcast, mais les
  mutations sont appliquées avant commit et aucun rollback automatique n'existe.
  « Tout ou rien » est une nouvelle garantie V3.



### Q-E08 — Quelles commandes V2 sont portées dans le MVP ? — **B1**

- [x] `state.listTiles/getTile`
- [x] pose et édition par UUID
- [x] mémoire config/runtime
- [x] `qml.instantiate`
- [x] screenshot
- [x] runtime joueur/NPC
- [x] roster/modules

- **Sous-ensemble retenu :**

a affiner

### Q-E09 — Une échappatoire `automation.raw` existe-t-elle ? — **B1**

- [ ] Non
- [x] Build dev uniquement, absent du manifeste livré
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

- [x] Oui, deux namespaces dans un même `memory`
- [ ] Oui, deux propriétés/conteneurs distincts
- [ ] Non, autre modèle :

- **Réponse :**



### Q-F02 — L'état runtime doit-il survivre à une sauvegarde/reprise ? — **B0**

- [ ] Non, toujours réinitialisé
- [x] Oui, dans une sauvegarde de partie distincte de la map
- [x] Oui, directement dans le fichier map

- **Recommandation actuelle :** sauvegarde de partie distincte.
- **Réponse : Voir système de sauvegarde existant. A affiner, snaphot système /= runtime**    
- **Vérification stack :** la sauvegarde actuelle ne contient que `mapInfo` et
  `snapableTiles`; il n'existe aucun format de sauvegarde runtime séparé. Les deux
  options cochées restent donc contradictoires. **À trancher :** état runtime dans
  un fichier de partie séparé (recommandé) ou mélange dans la map.



### Q-F03 — La mémoire existe-t-elle aussi au niveau partie/joueur ? — **B1**

- [ ] Tuiles uniquement
- [ ] Tuiles + `MapInfo`/session
- [x] Tuiles + session + `PlayerProfile`/joueur

- **Réponse :**



### Q-F04 — Quel transport pour l'état runtime ? — **B0**

- [ ] Nouveau protocole/message dédié
- [ ] Extension de `PhysicsSession`
- [x] Bus d'état générique partagé

- **Réponse :**
- **Vérification stack :** le bus générique choisi n'existe pas. La V2 possède
  deux protocoles spécialisés (`EditorSession`, `PhysicsSession`) pouvant servir
  de modèles, pas de bus commun réutilisable directement.



### Q-F05 — Delta ou snapshot ? — **B0**

- [x] Delta par clé avec version
- [x] Snapshot complet par entité
- [ ] Delta fréquent + snapshot périodique de réparation

- **Recommandation actuelle :** delta coalescé + snapshot de réparation.
- **Réponse : stack existante; delta sur modification courante du runtime, snapshot sur ajout de nouvelle item . A affiner**
- **Vérification stack :** l'éditeur utilise des deltas puis un `FullSync` à la
  connexion/changement de carte ; la physique utilise des snapshots périodiques.
  Aucun snapshot automatique « sur ajout d'item » ne répare actuellement un delta
  perdu. La stratégie V3 delta + snapshot de réparation reste à spécifier.



### Q-F06 — Reliable ou latest-state/raw ? — **B0**

- [ ] Reliable ordonné
- [ ] Raw/supersedable + séquence
- [ ] Hybride : intentions fiables, états supersedables

- **Recommandation actuelle :** hybride.
- **Réponse : stack reseau existante**
- **Vérification stack :** **réponse non close**. Le chemin nommé `reliable` ne
  retransmet pas les paquets non acquittés. Pour le bus V3, le modèle cohérent avec
  les réponses est : intentions/commits avec retry fiable applicatif ; état
  supersédable avec séquence et snapshot de réparation.



### Q-F07 — Cadence et plafonds ? — **B1**

- **Cadence maximale :**
- **Taille max par valeur/tuile/session :**
- **Budget bande passante par pair :**
- **Politique de dépassement :**

A affiner en test

### Q-F08 — Comment versionner/résoudre les écritures concurrentes ? — **B0**

- [x] Hôte séquence tout, dernier accepté gagne
- [ ] Version par clé + rejet des écritures périmées
- [ ] Fusion spécifique au type

- **Réponse :**



### Q-F09 — Quel write-set une proposition doit-elle déclarer ? — **B1**

- [ ] Tuiles seulement
- [x] Tuiles + clés mémoire
- [x] Ressources/capacités complètes

- **Réponse :**



### Q-F10 — Que fait undo si une valeur durable a changé depuis ? — **B0**

- [ ] Refuse et signale un conflit
- [ ] Restaure malgré tout
- [ ] Compensation conditionnelle par version

- **Recommandation actuelle :** compensation conditionnelle, sinon conflit.
- **Réponse : a affiner** 



### Q-F11 — Quel signal QML exposer ? — **B1**

- [ ] `userMemoryChanged()` global
- [ ] `memoryValueChanged(namespace, key, value, version)` ciblé
- [x] Les deux

- **Réponse :** 

---



## G. Artefacts, réplication et cycle de vie



### Q-G01 — En posture initiale, où la source QML circule-t-elle ? — **B0**

- [x] Client auteur → hôte arbitre seulement
- [ ] Client → hôte → tous les pairs
- [ ] Aucun code client ; génération uniquement chez l'hôte

- **Recommandation actuelle :** auteur → hôte, sans broadcast aux pairs.
- **Réponse : stack reseau existante**
- **Vérification stack :** Catway/EditorSession savent transporter et chunker du
  JSON, mais aucun message proposition/artefact/arbitre n'existe. La topologie est
  décidée ; son protocole est à créer.



### Q-G02 — Où le comportement accepté s'exécute-t-il ? — **B0**

- [ ] Auteur seulement ; l'hôte valide chaque effet partagé
- [x] Hôte seulement ; les effets sont répliqués
- [x] Chaque pair après revalidation
- [x] Selon une propriété de l'artefact

- **Réponse :**



### Q-G03 — Comment identifier/versionner un artefact ? — **B1**

- [ ] Hash de contenu + manifeste + version de schéma
- [x] UUID mutable
- [ ] Nom logique + version sémantique

- **Réponse : stack existante**
- **Vérification stack :** **réponse à corriger.** Le `QUuid` existant identifie
  une instance de tuile, pas le contenu/version d'un artefact partagé. Conserver
  un UUID d'instance est utile, mais l'artefact requiert aussi un hash de contenu
  et une version de manifeste.



### Q-G04 — Où persister les sources acceptées ? — **B1**

- [x] Dans le JSON de map
- [x] Dans un store d'artefacts séparé, référencé par hash
- [ ] Session seulement, non persistées

- **Recommandation actuelle :** store séparé par hash.
- **Réponse : stack existante a compléter** 
- **Vérification stack :** la map JSON et le stockage d'assets sous
  `AppDataLocation` existent ; aucun store adressé par hash n'existe. La réponse
  implique un nouveau store séparé, référencé depuis la map.



### Q-G05 — Que se passe-t-il si un artefact manque au chargement ? — **B1**

- [ ] Chargement refusé
- [x] Élément désactivé avec diagnostic
- [x] Téléchargement automatique depuis la bibliothèque

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
- **Vérification stack :** l'élection et la promotion éditeur existent, avec
  préservation de la carte locale puis full-sync. Tous les quatre champs ci-dessus
  sont nouveaux pour la V3 et restent à remplir.

---



## H. Skill cliente et expérience d'installation



### Q-H01 — Quel agent cible-t-on en premier ? — **B1**

- [x] Codex
- [x] Claude Code
- [ ] Agent générique avec tools JSON
- [ ] Adaptateur indépendant de l'agent

- **Réponse :**



### Q-H02 — La skill contient-elle un client WS exécutable ? — **B1**

- [ ] Oui, tool/CLI livré
- [ ] Non, seulement la documentation du protocole
- [ ] Connecteur natif propre à chaque agent

- **Recommandation actuelle :** CLI/adaptateur livré, protocole documenté.
- **Réponse : a affiner**



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

- [x] Build du jeu
- [ ] Packaging de l'installeur
- [ ] Génération dynamique depuis le serveur
- [ ] Combinaison :

- **Réponse :**



### Q-H06 — Comment gère-t-on une skill obsolète ? — **B1**

- [ ] Refus de connexion
- [x] Mode compatibilité négocié
- [x] Mise à jour automatique proposée

- **Réponse :**



### Q-H07 — Faut-il réconcilier tous les hooks avec le MCP ? — **B2**

- [x] Non, inventorier puis porter seulement le catalogue curé
- [ ] Oui, parité complète
- [ ] Ajouter un invocateur générique

- **Recommandation actuelle :** inventaire + port explicite, pas d'invocateur générique en prod.
- **Réponse :**

---



## I. Bibliothèque et assets 3D



### Q-I01 — Quel ordre de livraison ? — **B1**

- [ ] Primitives gameplay → assets 3D → créations partagées
- [ ] Assets 3D → primitives gameplay → créations partagées
- [x] Bibliothèque locale unifiée dès le départ

- **Réponse :**



### Q-I02 — Bibliothèque locale ou communautaire au premier jalon ? — **B1**

- [x] Locale officielle uniquement
- [ ] Locale + imports utilisateur
- [ ] Serveur communautaire

- **Réponse :**



### Q-I03 — Réutilise-t-on `asset_server/` et le launcher ? — **B1**

- [x] Oui
- [ ] Non, nouvelle infrastructure
- [x] Après audit de compatibilité

- **Critères d'audit :**
- **Réponse :**
- **Vérification stack :** audit favorable pour la distribution : file, reprise,
  retry, SHA-256 et manifestes existent. Il faut ajouter signature d'éditeur,
  dépendances par hash et type de package artefact V3.



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

- [x] glTF/GLB
- [ ] OBJ
- [ ] Formats convertis au build/import vers un format interne

- **Réponse :**
- **Vérification stack :** GLB est déjà importé par `createModelFromGlb` et chargé
  par `RuntimeLoader` avec `model_manifest.json`. Choix directement supporté.



### Q-I07 — Qui peut importer un asset 3D ? — **B1**

- [x] Développeurs seulement
- [ ] Hôte
- [ ] Tout joueur, après validation/arbitrage

- **Réponse :**



### Q-I08 — Comment l'IA référence-t-elle un asset ? — **B1**

- [ ] ID logique versionné
- [ ] Hash de contenu
- [ ] URL
- [ ] ID + hash résolu par manifeste

- **Réponse : stack  existante**
- **Vérification stack :** la référence existante est `(category, type, id)` pour
  les assets 2D et `modelName` + manifeste pour les modèles. La V3 doit y ajouter
  version/hash ; aucune des options proposées n'est donc entièrement cochée.



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
- [x] Journal configurable

- **Durée/rétention :**
- **Réponse :**



### Q-J02 — Quelles données peuvent contenir des informations privées ? — **B1**

- [ ] Prompts/conversations
- [ ] Captures d'écran
- [ ] Sources générées
- [ ] Identifiants/fournisseurs

- **Politique de stockage/effacement :**

**Correction :** non applicable uniquement tant que ces données ne sont pas
stockées. Dès que le canal/journal existe, prompts, captures, sources générées et
identifiants fournisseur peuvent tous contenir des données privées. La politique
de stockage/effacement reste à définir.

### Q-J03 — Comment diagnostiquer une divergence entre pairs ? — **B1**

- [ ] Hash périodique d'état + resync
- [ ] Journal d'événements rejouable
- [ ] Snapshot autoritatif à la demande

- **Réponse : stack reseau existante**
- **Vérification stack :** full-sync éditeur et snapshots physiques savent
  réparer certains états, mais ne **détectent** pas génériquement une divergence.
  Il manque au minimum hash/version d'état et demande explicite de resync ; la
  question reste ouverte.



### Q-J04 — Quels indicateurs mesurent la qualité de l'arbitrage ? — **B2**

- **Latence cible :**
- **Taux d'acceptation/rejet/amendement :**
- **Taux de rollback/erreur après acceptation :**
- **Coût cible :**

a affiner selon test 

### Q-J05 — Quels scénarios end-to-end valident le vertical slice ? — **B0**

- [ ] Création solo d'un élément avec config + comportement
- [ ] Proposition cliente arbitrée puis appliquée par l'hôte
- [ ] Rejet actionnable et itération
- [ ] Undo ciblé sans écraser l'état concurrent
- [ ] Reconnexion/resync
- [ ] Migration d'hôte/arbitre
- [ ] Chargement d'une sauvegarde avec artefacts

- **Scénarios retenus :**

a affiner

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

- **Premier mode livré :** les trois modes sont dans le périmètre ; ordre encore ouvert.
- **Politique d'arbitre solo / multi :** obligatoire partout, rôles isolés,
  configuration collective et migration avec état/version.
- **Forme d'exécution des règles :** hiérarchie capacités → modules → DSL →
  QML/JS ; document de règlement structuré versionné.
- **Niveau d'isolation QML retenu :** même moteur + contexte restreint + JS
  borné, **conditionnel à la réussite de R1**.
- **Politique de réplication des artefacts :** auteur → hôte ; exécution hôte ou
  pairs après revalidation selon une propriété de l'artefact.
- **Modèle mémoire config/runtime :** un `memory` avec namespaces `config` et
  `state`, porté par tuiles, session et joueurs.
- **Transport runtime retenu :** bus d'état générique nouveau ; garanties exactes
  encore ouvertes, la stack `reliable.io` étant insuffisante seule.
- **Agent client initial :** Codex + Claude Code, supervisés par launcher/jeu.
- **Périmètre initial de bibliothèque :** locale officielle unifiée, développeurs
  uniquement, GLB, réutilisation du launcher/asset_server.
- **Critères de réussite du vertical slice :** création d'un item modifiant le
  gameplay, la physique, d'autres éléments et les interactions joueur ; scénarios
  E2E exacts encore à sélectionner en J05.
- **Décisions encore bloquées par un prototype :** unité d'arbitrage C01,
  sandbox R1, auth/découverte canal, garanties réseau, atomicité transactionnelle,
  sauvegarde runtime, undo concurrent, migration complète et signature officielle.
