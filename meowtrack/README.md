# Meowtrack — suivi local des bugs / features / tâches

Service de suivi (issue tracker minimaliste) pour le projet Meownopoly, avec :

- un **serveur MCP** (stdio) pour créer / lister / filtrer / clore des entrées depuis Claude Code ;
- un **dashboard web** local pour les gérer à la main ;
- des **références fichiers/dossiers** ancrées sur le **repo git cloné** (validées + contexte git capturé).

La base est **locale par machine** (SQLite `meowtrack.db`, gitignorée) — chaque dev a sa propre liste. Le dossier `meowtrack/` lui-même est versionné dans le repo, mais pas son contenu de base.

## Installation

```bash
cd meowtrack
npm install
```

Dépendances : `@modelcontextprotocol/sdk`, `better-sqlite3`, `zod` (cf. `package.json`).

## Dashboard web

```bash
npm run dashboard       # ou: node server.js
```

Ouvre http://127.0.0.1:7702 (port configurable via `MEOWTRACK_PORT`). Le serveur écoute **uniquement sur localhost** — c'est un outil dev.

Dans le formulaire de description, taper **`@`** déclenche un autocomplete des fichiers/dossiers suivis par git : la sélection insère le chemin dans le texte **et** l'associe automatiquement à l'entrée. Un champ dédié « Fichiers / dossiers associés » permet aussi d'ajouter des chemins à la main (avec le même autocomplete) et d'indiquer des plages de lignes via la syntaxe `chemin:120-145`.

## Serveur MCP

Enregistré dans le `.mcp.json` racine (`meowtrack` → `node meowtrack/mcp.js`). Après `npm install`, redémarrer Claude Code pour qu'il charge le serveur.

Tools exposés :

| Tool | Rôle |
| --- | --- |
| `meowtrack_create` | Créer un bug / feature / tâche / chore (avec `paths` + `@mentions`). |
| `meowtrack_list` | Lister / filtrer (type, statut, priorité, tag, chemin, plein-texte). |
| `meowtrack_get` | Détail complet d'une entrée (références + commentaires). |
| `meowtrack_update` | Modifier les champs (fournir `paths` remplace toutes les références). |
| `meowtrack_set_status` | Raccourci open / in_progress / done / wontfix. |
| `meowtrack_delete` | Supprimer une entrée (cascade). |
| `meowtrack_add_reference` | Ajouter une référence fichier/dossier (`chemin:120-145`). |
| `meowtrack_remove_reference` | Retirer une référence par id. |
| `meowtrack_comment` | Ajouter une note de suivi. |
| `meowtrack_search_paths` | Autocomplete des chemins du repo (feature `@`). |
| `meowtrack_stats` | Compteurs par statut/type/priorité + contexte git. |
| `meowtrack_refresh_paths` | Re-scan `git ls-files` après un pull / changement de branche. |

Le MCP et le dashboard partagent la même base (WAL → lectures concurrentes). Les deux peuvent tourner simultanément.

## Modèle de données

- **issue** : `ref` (code lisible `BUG-1`, `FEAT-2`…), `type`, `title`, `description`, `status`, `priority`, `tags[]`, `branch`/`commit` (capturés à la création), timestamps.
- **reference** : `path` (repo-relatif, validé), `kind` (file/dir), `lineStart`/`lineEnd` optionnels, `existed` (le chemin existait-il au moment de la référence).
- **comment** : note de suivi horodatée.

### Références fichiers

Tout chemin est **normalisé en repo-relatif** et validé contre la racine résolue par `git rev-parse --show-toplevel` (anti path-traversal : un chemin hors repo est rejeté). Son existence et sa nature (fichier/dossier) sont capturées ; une référence dont le fichier a disparu est affichée « absent » dans le dashboard sans être supprimée.

## Configuration (variables d'env)

Lues via `dotenv` (fichier `.env`, cf. `.env.example`) ou directement dans l'environnement / l'unité systemd.

| Variable | Défaut | Rôle |
| --- | --- | --- |
| `MEOWTRACK_HOST` | `127.0.0.1` | Hôte d'écoute. `0.0.0.0` pour être joignable sur le réseau (déploiement). |
| `MEOWTRACK_PORT` | `7702` | Port HTTP du dashboard (choisir un port **libre**, pas 80). |
| `MEOWTRACK_TOKEN` | _(vide)_ | Si défini, `/api/*` exige `Authorization: Bearer <token>`. **Obligatoire en déploiement.** |
| `MEOWTRACK_REPO` | _(auto)_ | Chemin absolu du clone du repo (autocomplete + validation). Auto-détecté via `git rev-parse` en dev in-repo. |
| `MEOWTRACK_DB` | `meowtrack/meowtrack.db` | Chemin de la base SQLite. |

## Déploiement (serveur de dev, port dédié, sans nginx)

Même pattern que `chatServer`/`asset_server` : SCP + `npm install` + `systemctl restart`, mais le dashboard écoute **directement sur un port dédié** (pas de reverse-proxy, pas de port 80).

### 1. Première installation (one-shot sur le serveur)

```bash
# Sur la machine de dev : pousser les fichiers une première fois.
cd meowtrack
cp .deployEnv  # créé automatiquement au 1er run de deploy.sh, à remplir
./deploy.sh    # échouera au restart (service pas encore créé) — normal

# Sur le serveur, dans le dossier déployé :
cp .env.example .env     # éditer : MEOWTRACK_HOST=0.0.0.0, PORT libre, TOKEN, MEOWTRACK_REPO=<clone>
./install-service.sh     # crée + active le service systemd meownopoly-meowtrack
```

`install-service.sh` lit le `.env` via `EnvironmentFile`, installe les deps de prod, et `enable`/`start` le service. Aucune dépendance nginx/certbot.

### 2. Mises à jour (à chaque déploiement ultérieur)

```bash
cd meowtrack
./deploy.sh   # copie les fichiers + npm install + systemctl restart $SERVICE_NAME
```

`deploy.sh` lit `.deployEnv` (gitignored : `REMOTE_USER/HOST/DIR/PASSWORD`, `SERVICE_NAME=meownopoly-meowtrack`). **Ne copie pas** `node_modules/`, `meowtrack.db*`, `.env` ni `.deployEnv` — la base et la config de prod sont préservées.

### Accès au repo cloné

L'autocomplete `@` et la validation des références s'appuient sur `git ls-files` exécuté à la racine du clone. En déploiement, pointer `MEOWTRACK_REPO` vers le clone présent sur le serveur. Sans clone accessible, l'autocomplete renvoie une liste vide mais la création/édition/suivi restent fonctionnels (les chemins sont alors stockés tels quels, `existed:false`).

## Notes

- Pas de tests automatisés (cohérent avec le reste du repo).
- Le port `7702` suit la convention d'automation (`7700`/`7701`) ; en déploiement, choisir un port libre du serveur.
- L'API est protégée par `MEOWTRACK_TOKEN` quand il est défini ; le dashboard demande le token (stocké en `localStorage`) et réessaie sur `401`.
