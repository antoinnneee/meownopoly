# 07 — Bibliothèque

> **Statut : STUB — cadrage différé (décision D4).** Réserve l'emplacement de la
> brique et fixe le périmètre pressenti + les questions à instruire. **Ne tranche
> rien.**

## 1. Intention (telle qu'exprimée)

Le brief mentionne *« l'ajout d'une bibliothèque »* sans en préciser le contenu.
Deux lectures possibles, non exclusives :

- **Bibliothèque de primitives** : un catalogue de briques fournies par le jeu
  (composants QML de base, actions, templates de comportement/règles) dans lequel
  l'IA **pioche** pour construire. C'est le **vocabulaire de base** offert aux IA —
  et, pour le QML génératif (doc 04), la source de blocs **déjà validés** que
  l'IA assemble plutôt que de tout générer de zéro (réduit la surface du sandbox).
- **Bibliothèque de créations partagées** : un dépôt d'éléments/comportements
  **produits par les IA/joueurs**, sauvegardables et échangeables entre parties et
  entre joueurs (capitalisation du contenu custom).

## 2. Ancrages avec le reste du cadrage

- **Primitives ↔ sandbox (doc 04)** : plus la bibliothèque de primitives est
  riche, moins l'IA a besoin de générer du QML libre → surface de risque réduite.
  Une primitive de la bibliothèque est un artefact **pré-validé/signé**.
- **Créations partagées ↔ espace mémoire (doc 05)** : une « création » = un blob
  mémoire (données + réf. comportement) + éventuellement un artefact QML. Le format
  d'échange s'appuie sur la sérialisation existante (`toJSON`, map JSON).
- **Distribution** : le projet a déjà un `asset_server/` (serveur HTTP de
  distribution d'assets, launcher avec queue/retry/checksum). C'est un **candidat
  naturel** de support pour une bibliothèque partagée — à évaluer.
- **Sécurité** : toute création téléchargée depuis un dépôt est **non fiable** →
  re-validation obligatoire par le sandbox (doc 04) avant exécution.

## 3. Questions à instruire (avant de sortir du stub)

- Bibliothèque = **primitives**, **créations partagées**, ou **les deux** ?
  (question posée, réponse différée).
- Local (par installation) vs partagé (serveur communautaire) ?
- Modèle de confiance : signature des primitives officielles, modération des
  créations, re-validation systématique ?
- Réutilisation d'`asset_server/` + launcher, ou nouvelle infra ?
- Format de packaging d'une « entrée » de bibliothèque.

## 4. Prochaine action

Rouvrir après les docs 04 (sandbox) et 05 (espace mémoire) : le format d'une
entrée de bibliothèque dépend directement de la façon dont un comportement/donnée
est représenté et validé. Poser alors une décision **D-bibliothèque** dans le
doc 08.
