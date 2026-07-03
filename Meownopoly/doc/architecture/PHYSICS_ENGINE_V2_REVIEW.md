# Review Pattounx v2 — Modifications à réaliser

> Review complète du moteur physique (2026-07-03) : cœur moteur + collisions, threading worker/façade,
> netcode PhysicsSession, couche présentation/gameplay QML `world3d/`.
> ~7 600 lignes couvertes. Chaque item est une modification actionnable avec fichier:ligne et fix suggéré.
>
> Légende sévérité : 🔴 critique · 🟠 majeur · 🟡 mineur

---

## Ordre de traitement suggéré

1. **P0 — Critiques** : data race du triple buffer (T1), cercle-dans-polygone (M1).
2. **P1 — Sécurité réseau** (N1–N3) : fixes d'une à trois lignes chacun, à faire immédiatement.
3. **P1 — Robustesse arrêt/lifecycle** : T2, T3, N4, N5.
4. **P2 — Correction moteur** : M2–M5, stabilité des contacts.
5. **P2 — Claims & sync réseau** : N6–N9.
6. **P3 — Bugs QML gameplay** : Q1–Q6 (reset d'état, autorité réactive, debounce bridge).
7. **P4 — Design réseau** (chantier) : transport lossy des snapshots + interpolation (N12, N13).
8. **P5 — Perf & dette** : le reste, au fil de l'eau.

---

## 1. Cœur moteur & collisions (`pattounx_engine_v2`, `collision2d`)

### Correction

- [x] 🔴 **M1 — Cercle dont le centre est dans le polygone : normale inversée, body activement enfoncé** *(corrigé 2026-07-03 : `pointInPolygon` dans `checkCirclePolygon`/`checkCirclePolygonAll` → contact d'expulsion unique, normale extérieure, `penetration = radius + minDist` ; + `correctPositions` détecte le cas inside via `dot(toBody, normal) < 0` et pousse le long de la normale stockée)*
  `collision2d.cpp:111-173` (`checkCirclePolygon`) + `:206-244` (`checkCirclePolygonAll`).
  Détection purement "distance aux arêtes" : centre à l'intérieur → `toCenter` pointe vers l'intérieur → normale inversée ; `runStaticPass` (`pattounx_engine_v2.cpp:522-523`) skip l'impulsion et `correctPositions` (`:568-575`) pousse le body **plus profondément**. Centre au cœur du polygone (> radius de toute arête) → aucune collision détectée du tout. Le sweep CCD ne couvre pas : spawn dans une zone, téléport (`setBodyPosition`), **zone déplacée sur un body** (cas réel : drag éditeur avec sync live 30 Hz), body poussé dans une zone par la résolution body-body.
  **Fix** : tester `pointInPolygon(center)` dans `checkCirclePolygon*` ; si vrai, normale orientée extérieur + `penetration = radius + minDist` ; chemin de dépénétration "expulser vers l'arête la plus proche".

- [x] 🟠 **M2 — `trySegmentSide` accepte les crossings de *sortie* de la bande ±radius** *(corrigé 2026-07-03 : garde `targetDist > 0 ? dv > 0 : dv < 0` → return, seuls les crossings rapprochants produisent un contact)*
  `collision2d.cpp:331-352`. Un cercle qui démarre dans la bande (près d'un coin) et s'en éloigne produit un `t > 0` valide au moment où il **quitte** la capsule → faux contact ; `resolveBodyZoneCCD` (`pattounx_engine_v2.cpp:324-326`) applique le rewind de position même si le bounce est skippé → body stoppé/collé en quittant un coin.
  **Fix** : n'accepter `+radius` que si `dv < 0` et `-radius` que si `dv > 0` (crossing rapprochant).

- [x] 🟠 **M3 — NaN si `currentDamping >= 1`** *(corrigé 2026-07-03 : `std::clamp(currentDamping, 0.0, 0.999)` dans `applyGroundFrictionAndZones` — couvre les deux sources, `spec.linearDamping` et `zone.frictionStrength`)*
  `pattounx_engine_v2.cpp:229/234/252`. `std::pow(1.0 - damping, dt*60)` avec damping > 1 (valeur pilotée par l'éditeur, non bornée) → NaN qui contamine velocity puis position définitivement — et se propage à tous les clients via snapshot.
  **Fix** : `std::clamp(currentDamping, 0.0, 0.999)` dans `applyGroundFrictionAndZones` (ou clamp à l'entrée `upsertBody`/`upsertZone`).

- [x] 🟠 **M4 — Pas de correction positionnelle pour les overlaps body-body installés** *(corrigé 2026-07-03 : sur `t == 0`, plus de rewind — correction Baumgarte proportionnelle à la profondeur (mêmes `PENETRATION_SLOP`/`POSITION_CORRECTION_PERCENT` que `correctPositions`), normale recalculée aux positions courantes, répartie selon `effInvMass` avec fallback 50/50 si mobiles sans masse ; `effInvMass` hissé et dédupliqué)*
  `pattounx_engine_v2.cpp:408-433`. Sur `t=0` (déjà en interpénétration), séparation par `push` fixe de 0.01/frame indépendant de la profondeur : deux cercles enfoncés de 0.3 mettent ~30 frames à se séparer, avec normale instable (centres quasi confondus) → jitter.
  **Fix** : sur `t == 0`, `penetration = (rA+rB) - |relStart|` + correction Baumgarte proportionnelle (mêmes `PENETRATION_SLOP`/`POSITION_CORRECTION_PERCENT`), répartie selon `invMass`. Utiliser le `sumR` actuellement calculé puis ignoré (`(void)sumR`, `:416/434`).

- [x] 🟠 **M5 — Ordre du pipeline : `resolveBodyBodyCCD` après la collecte des contacts résiduels body-zone** *(corrigé 2026-07-03 : collecte extraite dans `collectResidualZoneContacts()`, appelée dans `step()` APRÈS `resolveBodyBodyCCD`)*
  `pattounx_engine_v2.cpp:131-141` (`step`). Un body poussé dans une zone d'exclusion par la résolution body-body n'a aucun contact résiduel ce frame → pénétration d'au moins une frame, potentiellement définitive combiné à M1.
  **Fix** : déplacer la collecte des résiduels après `resolveBodyBodyCCD`, ou re-sweeper les bodies déplacés.

- [x] 🟠 **M6 — Impulsions dupliquées sur contacts multi-arêtes (coins)** *(corrigé 2026-07-03 : dédup par body dans `collectResidualZoneContacts` — un seul contact résiduel, le plus pénétrant, toutes zones confondues ; le mur "perdant" est repris au frame suivant par la Baumgarte)*
  `pattounx_engine_v2.cpp:513-558` (`runStaticPass`). `checkCirclePolygonAll` produit un contact par arête : dans un coin, deux impulsions normales avec restitution chacune → sur-restitution + jitter ; idem `correctPositions` (jusqu'à 1.2× de sur-correction).
  **Fix** : dédupliquer les contacts par body (garder le plus pénétrant ou moyenner les normales), et/ou accumulated impulse avec clamp à la Box2D.

- [x] 🟡 **M7 — Mouvement restant après impact jeté** *(corrigé 2026-07-03 : `resolveBodyZoneCCD(dt)` — boucle de slide bornée par `MAX_SLIDE_ITERATIONS=2` : après rewind+bounce, ré-intégration `position += velocity * remainingDt` avec `remainingDt *= (1-t)` puis re-sweep ; sur la dernière passe on s'arrête au contact, le résiduel est repris par les contacts résiduels)* — `pattounx_engine_v2.cpp:324-345`. Après rewind à `t`, pas de ré-intégration sur `(1-t)*dt` → murs "collants", slide oblique ralenti. Fix : `position += velocity * (1-t)*dt` + re-sweep (1-2 itérations).
- [x] 🟡 **M8 — Body endormi exclu de la détection zone** *(corrigé 2026-07-03 : `wakeBodiesTouchingZone` (AABB gonflée du rayon) appelé sur `upsertZone` — ancienne ET nouvelle empreinte — et `removeZone`)* — `pattounx_engine_v2.cpp:352-374`. Zone draguée sur une caisse endormie = caisse enfouie jusqu'à réveil externe. Fix : réveiller les bodies dans l'AABB d'une zone sur `upsertZone`/`removeZone`.
- [x] 🟡 **M9 — `sweepCircleVertex` incohérent avec `sweepCircleCircle` sur départ en pénétration** *(corrigé 2026-07-03 : `c <= 0` → contact t=0, normale `startPos - vertex` ; combiné à M7, un départ en overlap au coin dépénètre sans figer le mouvement du frame)* — `collision2d.cpp:287-310`. Si déjà dans le disque du sommet, aucun contact (au lieu de `t=0`). Fix : si `c <= 0`, retourner `t=0` avec normale `startPos - vertex`.
- [x] 🟡 **M10 — Cap de vitesse max inopérant si `linearDamping == 0`** *(corrigé 2026-07-03 : `capDamping = max(currentDamping, DEFAULT_GROUND_DAMPING)` dans la branche cap)* — `pattounx_engine_v2.cpp:251-257`. `decel == 1` → un body sans damping recevant une grosse impulsion dépasse `maxSpeed` indéfiniment. Fix : decel minimal garanti dans la branche cap, ou clamp dur à 2× maxSpeed.
- [x] 🟡 **M11 — `ShapeType::Polygon` = API morte** *(corrigé 2026-07-03 : `upsertBody` rejette tout non-Circle avec qWarning — aucun appelant ne créait de body polygone, `physics_world.cpp` force `Circle`)* — `pattounx_types.h:27-30` + `pattounx_engine_v2.cpp:283/390-391`. Un body polygone ne collisionne avec rien, silencieusement. Fix : rejeter/logguer à l'`upsertBody` (ou le supporter).
- [x] 🟡 **M12 — Friction de zone par défaut 0.5 hardcodée** *(corrigé 2026-07-03 : `zoneFriction = max(0, frictionStrength)` si la zone existe, défaut 0.5 réservé au cas "zone disparue entre collecte et solve")* — `pattounx_engine_v2.cpp:543-547`. `if (zf > 0.0)` empêche d'exprimer une friction nulle (zone glissante) — `frictionStrength=0` est une valeur légitime. Fix : utiliser la valeur clampée ≥ 0, réserver le défaut au cas "zone introuvable".
- [x] 🟡 **M13 — `isColliding` incohérent** *(corrigé 2026-07-03 : reset en début de `step()` pour les bodies éveillés (un endormi garde son dernier état, cinématique gelée) ; levé par body-zone CCD, body-body (A et B, avec `lastCollisionNormal` ±normal) et contacts résiduels)* — `pattounx_engine_v2.cpp:337/503-508`. Ne reflète que body-zone, jamais body-body ; reset seulement dans une branche. Fix : reset en début de step, set dans les deux résolutions.
- [x] 🟡 **M14 — `removeBody` n'émet pas les `exited` des zones actives** *(corrigé 2026-07-03 : émission d'un `exited` par zone de `m_activeZonesPerBody[id]` avant le remove)* — `pattounx_engine_v2.cpp:46-50`. Les consommateurs à pile de zones (QML) gardent un état orphelin. Fix : émettre `exited` pour chaque zone de `m_activeZonesPerBody[id]` avant remove.
- [x] 🟡 **M15 — `upsertBody` : sémantique d'update non documentée** *(corrigé 2026-07-03 : doc dans le .h (spec.position ignorée sur update, setBodyPosition pour téléporter) + `wakeUp` sur changement de shape type/radius)* — `pattounx_engine_v2.cpp:31-44`. `spec.position` ignorée sur body existant (voulu, non documenté) ; changement de radius ne réveille pas le body. Fix : documenter dans le .h + `wakeUp` sur changement de shape.
- [x] 🟡 **M16 — `EPSILON` unique pour des grandeurs hétérogènes** *(corrigé 2026-07-03 : documenté dans `collision2d.h` — unité = coordonnées grille, partagé volontairement, epsilons dédiés si l'échelle du monde change)* — `collision2d.h:214`. Longueurs, produits scalaires, longueurs² partagent 1e-4. Fix : documenter l'unité de référence ou epsilons dédiés.
- [x] 🟡 **M17 — Nettoyages** *(corrigé 2026-07-03 : `<=` sur le clamp de friction statique aux deux sites (body-body + runStaticPass, désormais dans `pattounx_engine_v2.cpp`) ; bbox de `pointInPolygon` gonflée d'un EPSILON avant `contains`, le ray casting reste le juge exact)* : clamp friction statique `<` → `<=` (`collision2d.cpp:489`) ; bbox `QRectF::contains` exclut bords droit/bas (`collision2d.cpp:184`, gonfler d'un epsilon).

### Performance moteur

- [ ] 🟠 **M18 — Allocations + lookups hash dans la boucle chaude body-body**
  `pattounx_engine_v2.cpp:377-390`. `QVector<QString>` reconstruit chaque step + 2 hash-lookups QString par paire O(n²) à 60 Hz.
  **Fix** : `QVector<InternalBody*>` construit une fois (pointeurs QHash stables), filtrer d'emblée non-cercles/statiques, early-out AABB avant `sweepCircleCircle`.

- [ ] 🟡 **M19 — `QSet<QString>` alloué par body/frame dans `applyGroundFrictionAndZones`** — `pattounx_engine_v2.cpp:154-199` + O(bodies × zones) `pointInPolygon`. Fix : diff in-place + index spatial grossier des zones (grid hash sur bbox) partagé avec `resolveBodyZoneCCD`.
- [ ] 🟡 **M20 — Double boucle bodies×zones dupliquée** entre sweep et détection résiduelle — `collision2d.cpp:310-374`. Factoriser en un seul parcours.
- [ ] 🟡 **M21 — Déterminisme : itération sur `QHash` partout** — `pattounx_engine_v2.cpp:146, 170, 298, 358, 383`. L'ordre de résolution body-body dépend du seed de hash → deux instances divergent à inputs égaux. OK en host-authoritative, mais ferme la porte au lockstep/replay. Fix si souhaité : ids entiers + `std::vector` trié, ou a minima trier `ids` dans `resolveBodyBodyCCD`.
- [ ] 🟡 **M22 — Le "cœur Qt-free" inclut `QObject` (inutilisé) et du code de bridge QML** — `collision2d.h:4-8`. `fromVariantList` à déplacer côté `PhysicsWorld`.

---

## 2. Threading (`physics_worker`, `physics_world`, `item_snapable_events`)

- [x] 🔴 **T1 — Data race (UB) sur le peek du triple buffer** *(corrigé 2026-07-03 : `std::atomic<quint64> m_pendingTick` dans PhysicsWorld, stocké par le worker en release APRÈS son exchange ; le peek GUI lit cet atomique, plus aucun deref d'un buffer non possédé)*
  `physics_world.cpp:333-334` + `physics_worker.cpp:140,150-151`. Le peek déréférence `m_pending` sans ownership : entre le `load(acquire)` et la lecture de `peek->tick`, le worker peut faire son `exchange` puis, au tick suivant, `writeSnapshot` écrit dans ce buffer pendant que la GUI lit. Fenêtre ~16 ms — data race C++ réelle, pas théorique.
  **Fix** : `std::atomic<quint64> tick` dans `WorldSnapshot` (store release en fin de `writeSnapshot`, load acquire au peek), ou triple buffer canonique à index atomique + flag "new data", ou seqlock par buffer.

- [x] 🟠 **T2 — `stop()` réentrant : nested event loop + état publié trop tôt** *(corrigé 2026-07-03 : plus de QEventLoop — `cmdRequestStop` (DirectConnection) + `quit()` + `wait(5000)` bloquant sans traitement d'événements ; `runningChanged` émis après le teardown complet. Règle aussi T6 : le destructeur n'exécute plus de nested loop)*
  `physics_world.cpp:208-231`. `m_running=false` + `runningChanged()` émis **avant** l'arrêt réel, puis `loop.exec()` (500 ms) : un handler QML peut rappeler `start()` qui réinitialise `m_buffers` pendant que l'ancien worker écrit dedans → corruption.
  **Fix** : supprimer la nested loop — `cmdRequestStop` est `DirectConnection`, donc `emit cmdRequestStop(); m_thread->quit(); m_thread->wait(2000);` suffit ; n'émettre `runningChanged` qu'après teardown. Règle aussi **T6** (`~PhysicsWorld()` qui exécute une nested loop pendant la destruction, `physics_world.cpp:115-118`).

- [x] 🟠 **T3 — `QThread::terminate()` + `deleteLater()` d'un thread potentiellement vivant** *(corrigé 2026-07-03 : `terminate()` supprimé ; si `wait(5000)` échoue on fuit le thread avec qCritical au lieu de le tuer, et `deleteLater()` n'est appelé que si le wait a réussi)*
  `physics_world.cpp:233-245`. `terminate()` en plein step = UB documenté par Qt ; les retours de `wait()` sont ignorés → `deleteLater()` d'un QThread encore running possible.
  **Fix** : supprimer `terminate()` ; `wait()` sans timeout (ou timeout long + log), `deleteLater()` seulement si `wait()` a retourné true.

- [ ] 🟠 **T4 — Snapshot GUI gelé si personne n'appelle `beginFrame()`**
  `physics_world.h:184` + `physics_world.cpp:308-316`. `m_guiAdvancedThisFrame` n'est reset que par `beginFrame()` : un consommateur sans FrameAnimation (ex. hôte réseau qui sérialise à 30 Hz sans scène 3D montée) avance une fois puis reste figé pour toujours.
  **Fix** : auto-expirer le verrou — reset dans `onSnapshotPublished`, ou compteur de frame au lieu d'un bool.

- [ ] 🟠 **T5 — Ownership de `ItemSnapableEvents` cédé au moteur QML**
  `item_snapable_events.cpp:20-30`. Le QQmlEngine prend l'ownership du singleton retourné par callback et le détruit avec l'engine, alors que `instance()` est aussi utilisé côté C++ → pointeur pendouillant.
  **Fix** : `QQmlEngine::setObjectOwnership(inst, QQmlEngine::CppOwnership)` dans `qmlInstance`.

- [ ] 🟠 **T7 — Tile détruite hors flow Map : pas de `tileDeleted` → zone physique orpheline**
  `item_snapable_events.cpp:127-130`. La lambda `destroyed` retire du set mais n'émet pas `tileDeleted` → le bridge ne fait jamais `removeZone`.
  **Fix** : capturer `uniqueId`/`tileType` par valeur au connect et émettre `tileDeleted` dans la lambda (garde anti-double-émission via le retour de `m_attachedTiles.remove`).

- [ ] 🟡 **T8 — Branche `prev == nullptr` du worker : aliasing latent** — `physics_worker.cpp:150-156`. Si `exchange` retournait null, le worker garderait un pointeur déjà déposé dans `m_pending`. Inatteignable aujourd'hui mais piège pour toute évolution. Fix : `Q_ASSERT(prev)` + `m_workerBack = nullptr` si null.
- [ ] 🟡 **T9 — Premier snapshot jamais consommé (off-by-one)** — `physics_worker.cpp:108-109,140`. Premier tick publié = 0 = tick initial des buffers GUI → rejeté par le peek. Fix : incrémenter `m_tick` avant `runStep`.
- [ ] 🟡 **T10 — `m_tick` avance quand `!m_simEnabled`** — `physics_worker.cpp:108-109`. Saut de ticks à la reprise, dangereux pour tout dt dérivé de Δtick. Fix : n'incrémenter que quand on steppe (ou documenter).
- [ ] 🟡 **T11 — Anti-spiral avec `now` périmé + busy-spin possible** — `physics_worker.cpp:100-113`. Re-échantillonner `now` après le step ; clamp `sleepUs` à un minimum.
- [ ] 🟡 **T12 — Événements worker livrés après `stop()`** — `physics_world.cpp:208-249`. `snapshotPublished`/`actorCollided` queued délivrés après `runningChanged(false)`. Fix : garde `if (!m_running) return;` dans les forwards.
- [ ] 🟡 **T13 — `bodyState()` : 1 QVariantMap par body par frame de rendu** — `physics_world.cpp:364-405`. Voir Q13 (fix commun : API batch). Côté worker, `WorldSnapshot::bodies` en QHash re-copie les QString à 60 Hz — `QVector<BodySnapshot>` réutilisé serait plus doux.
- [ ] 🟡 **T14 — `onTileRemovedFromMap` : scan linéaire** — `item_snapable_events.cpp:113-117`. O(n²) sur purge de map. Fix : index `QHash<QUuid, ItemSnapable*>`.
- [ ] 🟡 **T15 — `ItemSnapableEvents` silencieusement inerte si construit avant `MapFileManager`** — `item_snapable_events.cpp:35-41`. Fix : `qWarning` a minima, ou connexion différée.
- [ ] 🟡 **T16 — `velocityForce` : `{x,y}` JS silencieusement perdu** — `physics_world.cpp:74-79`. Seul QVector2D accepté, contrairement aux points de polygone. Fix : même fallback `toMap()`.
- [ ] 🟡 **T17 — `qmlRegisterType<PhysicsWorld>` rend le monde instanciable en QML** — `physics_world.cpp:107`. Un `PhysicsWorld {}` par erreur = second thread physique concurrent. Fix : `qmlRegisterUncreatableType`.

---

## 3. Réseau (`physics_session`, `physics_protocol`, sérialisation dans `physics_world`)

### Sécurité (host-side, fixes courts — à faire en premier)

- [x] 🟠 **N1 — `InputUpdate` : n'importe quel client peut piloter n'importe quel acteur** *(corrigé 2026-07-03 : rejet si `m_remoteClaims.value(senderId) != actorId`, avec qWarning throttlé 1/64 — attention, rend N7 (Hello perdu) plus visible : les inputs d'un client sans claim enregistré sont désormais droppés)*
  `physics_session.cpp:364-374`. L'hôte fait `pushInput(actorId, …)` sans vérifier que `senderId` a claimé cet acteur (le filtrage par claim n'existe que côté émetteur, donc chez l'attaquant).
  **Fix** : `if (m_remoteClaims.value(senderId) != actorId) break;`.

- [x] 🟠 **N2 — Vecteur d'input non borné : speed-hack + empoisonnement NaN** *(corrigé 2026-07-03 : `std::isfinite` sur x/y + normalisation si norme > 1)*
  `physics_session.cpp:371-373`. `x`/`y` pris tels quels du JSON — `(1e6, 0)` ou NaN possible, un NaN se propage à toute la sim puis à tous les clients.
  **Fix** : `if (!std::isfinite(x) || !std::isfinite(y)) break;` + clamp de la norme à 1.

- [x] 🟠 **N3 — `BodiesAnnounce` accepté de n'importe quel sender** *(corrigé 2026-07-03 : `if (m_isHost || senderId != m_hostPlayerId) break;`, aligné sur Snapshot/CombatEvent)*
  `physics_session.cpp:345-346`. Contrairement à Snapshot et CombatEvent qui vérifient `senderId == m_hostPlayerId`, BodiesAnnounce ne vérifie que `!m_isHost` : un pair tiers peut corrompre la table idIndex de tous les clients.
  **Fix** : `if (m_isHost || senderId != m_hostPlayerId) break;`.

### Robustesse

- [x] 🟠 **N4 — L'hôte qui `stop()` ne prévient personne : clients gelés jusqu'au timeout Catway (~10-30 s)** *(corrigé 2026-07-03 : `HostLeaving = 0x46` ajouté (+ extension `isPhysicsPacket`), broadcasté en tête de `stop()` côté hôte ; le client fait `stop()` immédiat à réception. Reste à brancher le pattern Timer 300 ms côté QML pour la fermeture d'app — cf. doc du type)*
  `physics_session.cpp:153-188`. Pas d'équivalent du `HostLeaving` (0x2A) de l'éditeur.
  **Fix** : `PhysicsMessageType::HostLeaving = 0x46` (valeur la plus haute + étendre `isPhysicsPacket`), broadcasté dans `stop()` quand `m_isHost`, avec le pattern Timer 300 ms de `onClosing`.

- [x] 🟠 **N5 — Client déconnecté : son dernier input reste appliqué par l'hôte** *(corrigé 2026-07-03 : `pushInput(claimedActor, (0,0))` dans le branch host de `onPlayerTimedOut` avant libération du claim)*
  `physics_session.cpp:430-448`. Un client qui crash flèche enfoncée laisse son acteur courir dans un mur indéfiniment.
  **Fix** : dans le branch host de `onPlayerTimedOut`, `m_world->pushInput(claimedActor, QVector2D(0,0))` avant de retirer le claim.

- [x] 🟠 **N6 — Aucun rejet des snapshots obsolètes / out-of-order** *(corrigé 2026-07-03 : gate `qint32(tick - m_lastRemoteTick) <= 0` wraparound-aware dans `applyRemoteSnapshot`, membres dédiés `m_hasRemoteTick`/`m_lastRemoteTick` — distincts de `m_lastTick` qui est aussi alimenté par la sim locale — reset par `resetNetworkState()`)*
  `physics_world.cpp:494-543`. `m_lastTick` stocké mais jamais comparé : une retransmission reliable.io livrée après un snapshot plus récent est appliquée → rubber-banding. Prérequis de tout passage en transport lossy (N12).
  **Fix** : `if (!first && int32(tick - m_lastTick) <= 0) return;` (wraparound-aware sur quint32).

- [x] 🟠 **N7 — Claims fragiles (3 bugs liés)** *(corrigé 2026-07-03 : `sendHelloToHost()` factorisé + retry QTimer 500 ms tant que l'hôte est introuvable dans Catway ; `setClaimedActorId` re-Hello si `m_active && !m_isHost` ; côté hôte, claim refusé si déjà pris par un autre sender (premier arrivé premier servi ; le Welcome de refus est arrivé avec N11), et l'acteur relâché lors d'un changement de claim voit son input neutralisé comme N5)*
  - Hello jamais renvoyé si l'hôte est introuvable au `startAsClient` (`physics_session.cpp:130-142`) → l'hôte ignore le claim, clavier hôte et inputs client se battent pour le même acteur. **Fix** : retry QTimer 500 ms ou re-Hello sur `Catway::playerConnected`.
  - `setClaimedActorId` après `startAsClient` ne re-notifie pas l'hôte (`physics_session.cpp:60-65`). **Fix** : renvoyer un Hello si `m_active && !m_isHost`.
  - Conflit de claims entre deux clients non arbitré (`physics_session.cpp:386-392`) : deux senders peuvent claimer le même acteur, leurs inputs s'écrasent. **Fix** : refuser le claim déjà pris (→ Welcome de refus, cf. N11) + vérifier `m_remoteClaims.value(senderId) == actorId` dans InputUpdate (= N1).

- [x] 🟡 **N8 — Claim vide non purgé** *(corrigé 2026-07-03, avec N7 : Hello sans claim → `m_remoteClaims.remove(senderId)` + input de l'ancien acteur remis à zéro)* — `physics_session.cpp:386-392`. `if (!claim.isEmpty())` ne retire jamais l'ancien claim. Fix : `remove(senderId)` si vide.
- [x] 🟡 **N9 — Full table 1 Hz mergée au lieu de remplacée** *(corrigé 2026-07-03 : flag `"full": true` dans `buildAnnouncePayload` pour le re-broadcast 1 Hz ET la réponse au Hello ; `applyBodiesAnnounce(…, fullTable)` clear la table avant insertion côté client, les deltas restent en merge)* — `physics_session.cpp:301-310` + `physics_world.cpp:583-597`. Un client qui rate un delta `removed` garde un mapping fantôme pour toujours ; devient une vraie corruption dès que les idIndex sont recyclés (N15). Fix : flag `"full": true` → remplacement intégral côté client.
- [ ] 🟡 **N10 — Retour en sim locale après perte d'hôte = téléportation** — `physics_session.cpp:433-439`. `stop()` client purge le remote buffer puis reprend la sim locale sur l'état d'avant-session. Fix : réinjecter le dernier snapshot dans le moteur local avant purge (ou documenter que l'appelant re-spawne).
- [x] 🟡 **N11 — Hello sans Welcome** *(corrigé 2026-07-03 : `Welcome = 0x47` (+ extension `isPhysicsPacket`), envoyé par l'hôte après chaque Hello avec `{claimAccepted, claim, takenBy?}` ; côté client : Q_PROPERTY `claimAccepted` (reset optimiste au start/stop et au changement de claim, Welcome périmé ignoré si `claim != claimedActorId`) + signal `claimRejected(claim, takenBy)` pour l'UI ; le refus N7c n'est plus silencieux)* — `physics_message_type.h:42`. Le client ne sait jamais si son claim a été accepté (la "réponse" est un BodiesAnnounce anonyme). Fix : message `Welcome` hôte→client avec `{claimAccepted: bool}`.

### Design (chantier)

- [ ] 🟠 **N12 — Snapshots 30 Hz en reliable : anti-pattern state-sync**
  `physics_session.cpp:277-279`. Retransmettre un snapshot périmé est du gâchis (le suivant le remplace 33 ms plus tard) et une retransmission tardive est appliquée (cf. N6). **Fix minimal** : N6. **Fix cible** : basculer Snapshot sur `Catway.broadcastRaw` (canal lossy existant, cf. curseurs éditeur `EC:`) en gardant BodiesAnnounce/Hello/Combat en reliable.

- [ ] 🟠 **N13 — Zéro interpolation ni prédiction côté client**
  Design global (`physics_session.cpp:209-240`). Latence input = RTT complet + cadence snapshot ; rendu du dernier snapshot brut → escalier à 30 Hz sur écran 144 Hz.
  **Fix** : (a) buffer de 2-3 snapshots + interpolation avec render-delay ~1.5 intervalle — gros gain seul ; (b) à terme, prédiction locale de l'acteur claimé + réconciliation.

- [ ] 🟡 **N14 — Pas de versionning de protocole** — `physics_protocol.cpp:5-25`. Deux builds au format différent désérialisent du garbage silencieusement. Fix : octet `kProtocolVersion` après le type byte, rejet avec warning si mismatch.
- [ ] 🟡 **N15 — Wrap de `m_nextIdIndex` (quint16)** — `physics_world.cpp:440`. Jamais recyclé : wrap vers 0 (sentinel !) après 65535 spawns cumulés puis collisions d'index. Fix : free-list des index libérés, ou quint32 + resync forcé au wrap.
- [x] 🟡 **N16 — Validations d'entrée** *(corrigé 2026-07-03 : taille exacte du snapshot vérifiée (`payload.size() != 14 + count*19` → rejet, plus d'octets excédentaires acceptés) ; cap 64 KB sur `unpackJson` avant tout parse JSON ; `AttackRequest` : whitelist `type ∈ {attack, grab}` + rate-limit 20/s par sender (fenêtre glissante 1 s, `m_combatReqWindows` purgé au stop) ; Hello : sender validé contre le roster Catway AVANT d'enregistrer le claim)* : borner `count` vs taille réelle (`if (payload.size() != 14 + count*19) return;`, `physics_world.cpp:496-511`) ; taille max sur `unpackJson` (64 KB, `physics_protocol.cpp:45-60`) ; rate-limit + whitelist minimale sur `AttackRequest` relayé tel quel (`physics_session.cpp:410-416`) ; valider le sender du Hello contre le roster de session (`physics_session.cpp:377-407`).
- [ ] 🟡 **N17 — `pushOrSendInput` : un paquet reliable par appel** — `physics_session.cpp:229-239`. Si appelé chaque frame, 60-144 pkts/s pour un vecteur quasi constant. Fix : n'envoyer que si `input != m_lastSentInput`.
- [ ] 🟡 **N18 — Nits** : `1000 / m_snapshotHz` en division entière (`physics_session.cpp:55,94`, → `qRound(1000.0/hz)`) ; documenter la comparaison wraparound-aware du tick quint32 dans le header.

---

## 4. Couche QML 3D & gameplay (`qml/world3d/`)

### Bugs

- [x] 🟠 **Q1 — EditorPhysicsBridge : le "debounce 30 Hz" est un trailing debounce — zéro sync pendant un drag continu** *(corrigé 2026-07-03 : throttle leading — `if (!flushTimer.running) flushTimer.start()`, le timer n'est plus repoussé par les events → flush de l'état le plus récent toutes les ~33 ms pendant un drag, dernier état garanti < 33 ms après l'arrêt)*
  `EditorPhysicsBridge.qml:70-75,98`. `flushTimer.restart()` à chaque event : tant que `tileMoved` pleut, `_flushPending` n'est jamais appelé → zone fantôme dans le moteur pendant tout le drag.
  **Fix** : throttle leading — `if (!flushTimer.running) flushTimer.start()` (sans restart), ou flush immédiat si `now - _lastFlushMs > flushIntervalMs`.

- [x] 🟠 **Q2 — CameraRig : `FixedTopDown`/`OrbitDebug` écrasent définitivement pitch/yaw** *(corrigé 2026-07-03 : `_savedAngles` capturé à l'entrée du PREMIER mode destructeur (pas d'écrasement FixedTopDown↔OrbitDebug), restauré dans `setMode` avant le `recomputeOffset()` du mode entrant ; + `onEulerRotationChanged → invalidateGridBasis()` dans les Connections caméra de World3D)*
  `CameraRig.qml:89-94,195-207`. Le pitch d'origine (-55) n'est sauvegardé nulle part : retour en Follow → `recomputeOffset()` avec `tan(-90°)` → caméra top-down pour toujours ; yaw résiduel d'OrbitDebug casse le mapping affine (pas d'invalidation de `_gridBasis` sur `eulerRotation`).
  **Fix** : capturer `{pitch, yaw}` à l'entrée des modes destructeurs, restaurer dans `setMode` avant `recomputeOffset()` ; invalider le basis sur `eulerRotationChanged`.

- [x] 🟠 **Q3 — Spawners : `isAuthority` non réactif → bodies dupliqués ou manquants au changement d'autorité** *(corrigé 2026-07-03 : `isAuthority` intégré au `wantBody` (plus d'early-return) + `Connections { target: combat; onIsAuthorityChanged: _syncBody() }` dans les delegates des deux spawners)*
  `CrateSpawner.qml:98`, `EnemySpawner.qml:76`. L'autorité n'est évaluée qu'aux triggers existants : session démarrée après création des bodies → doublons locaux + snapshots hôte ; promotion en hôte → bodies jamais créés.
  **Fix** : `wantBody = running && isAuthority && !dead` dans `_syncBody` + `Connections { onIsAuthorityChanged: _syncBody() }` dans chaque delegate.

- [x] 🟠 **Q4 — CombatController : aucun reset d'état à l'arrêt du moteur** *(corrigé 2026-07-03 : branche `else` de `onActiveChanged` — reset `_states`/`_pendingPlayerRespawns`/`_playerDead`/`_playerLastAttackMs` + `stateRevision++`, aligné sur TriggerController)*
  `CombatController.qml:210`. `_states`/`_pendingPlayerRespawns`/`_playerDead` survivent au stop : ennemis restent morts au test suivant, respawns pendants fired instantanément, flags `registered` périmés. TriggerController (`:134-145`) fait le nettoyage correctement — s'aligner.
  **Fix** : `else { _states = ({}); _pendingPlayerRespawns = ({}); stateRevision++ }` dans `onActiveChanged`.

- [x] 🟠 **Q5 — GrabController : `_heldBy`/`_lastHolder` jamais purgés à l'arrêt** *(corrigé 2026-07-03 : `onActiveChanged` purge `_heldBy` ET `_lastHolder` + `grabRevision++` quand `!active`)*
  `GrabController.qml:47-50`. Au redémarrage, impulsions de ressort appliquées à des caisses que personne ne tient ; `_lastHolder` périmé fausse l'attribution des loots.
  **Fix** : `onActiveChanged: if (!active) { _heldBy = ({}); grabRevision++ }`.

- [x] 🟠 **Q6 — PhysicsActor : lissage exponentiel dépendant du framerate** *(corrigé 2026-07-03 : le tick de World3D passe `frameTime` (secondes) à `pullAndApply(dt)` ; `smoothing`/`orientLerp` gardent leur sémantique "fraction par frame 60 Hz de référence" et sont convertis par `1 - pow(1-s, dt·60)` — même pattern que le damping moteur et CameraRig ; fallback dt=1/60)*
  `PhysicsActor.qml:150-151`. `smoothing = 0.3` par frame : ~2.4× plus raide à 144 Hz qu'à 60 Hz — même famille que la régression jitter déjà corrigée. CameraRig (`:169`) fait correctement `1-exp(-k·dt)`.
  **Fix** : passer `frameTime` depuis le tick de World3D (le paramètre `_unusedAlpha` est déjà là) et `const t = 1 - Math.exp(-k * dt)`.

- [ ] 🟡 **Q7 — Fantôme à l'origine côté client avant le premier snapshot** — `CrateSpawner.qml:144-146`, `EnemySpawner.qml:149-151`. `visible: running` mais `bodyState` échoue tant que le BodiesAnnounce n'est pas arrivé → node à (0,0,0) ; body retiré côté hôte = node figé (rien ne couvre les caisses). Fix : exposer `seeded` sur PhysicsActor et conditionner `visible` dessus ; dé-seeder après N échecs de `bodyState`.
- [x] 🟡 **Q8 — Calcul d'alpha triplement cassé (code mort)** *(corrigé 2026-07-03 avec Q6 : calcul d'alpha supprimé, le tick passe désormais `frameTime` à `pullAndApply(dt)` ; la vraie interpolation prev/next reste liée au chantier N13)* — `World3D.qml:245-248`. `stepDurationNs` référencé sans parenthèses (Q_INVOKABLE → référence de fonction), `Date.now()*1e6` vs horloge worker, et alpha ignoré par `pullAndApply`. Fix : supprimer (ou implémenter réellement l'interpolation prev/next → lié à N13).
- [ ] 🟡 **Q9 — Orientation `atan2(vx, vy)` incohérente avec le mapping `Z3D = -gy`** — `PhysicsActor.qml:156` vs `World3D.qml:52`. Yaw en miroir sur Z, peut-être compensé par le modèle — vérifier visuellement, corriger ou documenter.
- [ ] 🟡 **Q10 — `enemyParameter` déréférencé sans garde** — `CombatController.qml:164-166`. TypeError au milieu de `_aiTick` si tile Enemy sans paramètre (partout ailleurs il est traité nullable).
- [ ] 🟡 **Q11 — Caisse déplacée dans l'éditeur moteur tournant : body jamais repositionné** — contrairement aux zones (bridge `tileMoved`). Documenter le choix, ou écouter `tileMoved` et `removeBody`+`create` (ou commande `teleportBody`).
- [ ] 🟡 **Q12 — Divers** : TriggerController appelle le privé `physicsBridge._upsertZoneNow` + manipule les zones sur un monde client sim-désactivée (`TriggerController.qml:195-196`, promouvoir une API publique + gater sur `isAuthority`) ; `el.opacity = …` impératif écrase les bindings (`:200`) ; `keysHandler` Item jamais parenté = code mort trompeur (`InputController.qml:148-152`) ; `removeBody` conditionné à `running` dans LocalPlayerSpawner + bodyId `"player"` global partagé entre scènes (`LocalPlayerSpawner.qml:33-35`).

### Performance

- [ ] 🟡 **Q13 — Pull pattern : N appels `bodyState()` QML→C++ par frame, 1 QVariantMap chacun**
  `PhysicsActor.qml:127` + `physics_world.cpp:364-405`. À 144 Hz × 20 entités ≈ 2 900 maps/s de churn GC.
  **Fix** : API batch `Q_INVOKABLE QVariantList bodyStates(QStringList)` — ou boucle de pull en C++ avec Node3D exposés. (= T13.)

- [ ] 🟡 **Q14 — 7 composants refiltrent `snapableTilesList` à chaque `tilesRevision`** — `Editor.qml:1527-1611`. Fix : un "TileIndex" partagé qui classe par tileType une fois par revision.
- [ ] 🟡 **Q15 — Recherches linéaires par uuid dans les tick-paths** — `CombatController.qml:139-146`, `GrabController.qml:210-218`. Fix : map `{uuid: tile}` reconstruit avec les listes filtrées.
- [ ] 🟡 **Q16 — ~90 lignes d'instrumentation jitter dans le présentateur de prod** — `PhysicsActor.qml:53-123`. Le bug 144 Hz est résolu : extraire dans un composant debug attachable.

### Architecture

- [ ] 🟠 **Q17 — Duplication CrateSpawner/EnemySpawner (~80 % de squelette commun)**
  Y compris la spec du body dupliquée **dans le même fichier** (`EnemySpawner.qml:79-87` vs `:121-130` — radius 0.25, accel 30.0 deux fois : divergence garantie).
  **Fix** : composant `BodyLifecycle {}` réutilisable (bodyId, specBuilder, wantBody) + un `_bodySpec()` unique par spawner.

- [ ] 🟡 **Q18 — Préfixes de bodyId éparpillés** — `"crate:"` dans CrateSpawner:48 et GrabController:69, `substring(6)` magique dans TriggerController:113-119. Fix : module JS partagé (`BodyIds.crate(uuid)`, `BodyIds.isCrate(id)`).
- [ ] 🟡 **Q19 — Gameplay dans le dossier présentation + appels cross-privés** — `combat._applyLoot` (TriggerController:218), `actor._seeded = false` (spawners). Fix : promouvoir `applyLoot`/`reseed()` en API publiques ; viser `qml/gameplay/` à terme.
- [ ] 🟡 **Q20 — CombatController force `enabled = true` sur les modules gameplay** — `:203,296,416,420`. Le GameplayModuleManager est censé posséder l'activation ; ré-activer un module que l'utilisateur vient de couper est surprenant. Déplacer vers le câblage du manager ou documenter.
- [ ] 🟡 **Q21 — Constantes magiques à promouvoir en properties** — ressort du grab (`GrabController.qml:201-205`), radius/accel ennemi, `cam.z - 600`, tick IA 100 ms.
- [ ] 🟡 **Q22 — Doc : CLAUDE.md liste encore `PhysicsObjectSpawner.qml`** (absorbé par CrateSpawner) — corriger la dérive.

---

## Points forts (à préserver dans les refactors)

- **CCD analytique propre** : décomposition Minkowski correcte (quadratique sommets + bandes ±radius), sweep cercle-cercle en mouvement relatif — pas de substepping fragile.
- **Damping framerate-indépendant** (`pow(1-d, dt*60)`) et solver vitesse/position séparé avec slop + correction Baumgarte (pattern Box2D) ; friction Coulomb à deux régimes avec la bonne tangente des deux côtés ; gestion Kinematic documentée et juste (`effInvMass`).
- **API moteur Qt-free découplée** (`step`/`takeEvents`/`writeSnapshot`), testable en isolation ; `setBodyPosition` qui synchronise `previousPosition` pour annuler le sweep au téléport.
- **Threading** : invariant de monotonie worker→GUI documenté au bon endroit avec `Q_ASSERT_X` côté consommateur ; `requestStop` en DirectConnection sur atomic ; chokepoint unique des mutations par signaux queued.
- **Protocole** : endianness + version QDataStream explicites des deux côtés ; snapshot compact (19 bytes/body : idIndex quint16, quantification ×1000, flags bitfield) ; pattern announce-then-snapshot avec drop-and-heal + re-broadcast 1 Hz qui ferme la course au join ; anti-spoof déjà présent sur Snapshot/CombatEvent (à généraliser, N3).
- **QML** : mapping affine caméra↔grille stable et bien commenté ; modèle d'autorité cohérent sur les trois contrôleurs ; pattern revision-counter systématique (conforme aux gotchas repo) ; lifecycle des bodies globalement propre (`Component.onDestruction → removeBody`).
