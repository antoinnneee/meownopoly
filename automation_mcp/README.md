# Meownopoly — Serveur MCP d'automation

Serveur MCP (Model Context Protocol, transport **stdio**) qui pilote l'application
Meownopoly via son **serveur d'automation WebSocket embarqué**
(`Meownopoly/cpp/automation/automation_server.{h,cpp}`).

Il permet à un agent (Claude Code) de tester l'app : introspecter l'arbre QML,
lire/écrire des propriétés, appeler des méthodes, synthétiser des clics/molette/touches,
prendre des captures d'écran, et attendre des conditions.

## Architecture

```
Claude Code  ──(MCP stdio)──▶  automation_mcp (Node)  ──(WebSocket 127.0.0.1)──▶  Meownopoly.exe
```

Le serveur d'automation côté app écoute **uniquement sur 127.0.0.1** (canal de debug
local) et n'est instancié **que si un port est explicitement demandé** (opt-in). Voir
`Meownopoly/doc/architecture/AUTOMATION_API.md` pour le protocole JSON complet.

## 1. Lancer l'app avec le serveur d'automation

Le serveur d'automation est désactivé par défaut. Pour l'activer, fournir un port :

```bash
# Via argument CLI (priorité)
../build/Release/Meownopoly.exe --automation-port 7700

# Ou via variable d'environnement
MEOW_AUTOMATION_PORT=7700 ../build/Release/Meownopoly.exe
```

### Deux instances (dual_test_p2p)

Convention de ports : **7700** pour l'instance 1, **7701** pour l'instance 2.

```bash
Meownopoly.exe --automation-port 7700
Meownopoly.exe --instance 2 --automation-port 7701
```

Chaque tool MCP accepte un paramètre `port` optionnel pour cibler une instance précise
(défaut : `MEOW_AUTOMATION_PORT` ou 7700).

## 2. Installer les dépendances du MCP

```bash
cd automation_mcp
npm install
```

## 3. Enregistrer le serveur MCP

Un fichier `.mcp.json` à la racine du repo enregistre déjà le serveur pour Claude Code :

```json
{
  "mcpServers": {
    "meownopoly-automation": {
      "command": "node",
      "args": ["automation_mcp/index.js"],
      "env": { "MEOW_AUTOMATION_PORT": "7700" }
    }
  }
}
```

La connexion au WebSocket de l'app est **lazy** (à la première commande) avec reconnexion
automatique si l'app a redémarré. Si l'app n'est pas lancée, une erreur explicite rappelle
de la démarrer avec `--automation-port 7700`.

## Tools MCP disponibles

| Tool | Description |
|------|-------------|
| `app_ping` | Infos app (nom, version, instance, scène courante). À appeler en premier. |
| `qml_tree` | Arbre des objets QML (objectName, className, geometry, visible, enabled). |
| `qml_find` | Trouve des items par objectName/className → id stable + géométrie. |
| `qml_get` / `qml_set` | Lit / écrit une propriété. |
| `qml_invoke` | Appelle une méthode Q_INVOKABLE/slot/fonction QML. |
| `mouse_click` / `_double_click` / `_press` / `_release` / `_move` | Synthèse souris. |
| `mouse_wheel` | Molette (zoom de l'éditeur). |
| `send_keys` | Texte ou touche (Qt::Key) avec modifiers. |
| `screenshot` | Capture PNG → chemin absolu (lisible directement). |
| `wait_for` | Attend existence / visibilité / valeur de propriété (timeout). |
| `app_quit` | Ferme l'app proprement. |

## Note Qt 6.11

L'éditeur de carte (`Editor.qml`) importe le module `MeowPainter` qui nécessite
**Qt 6.11+** (CanvasPainter, Tech Preview). Sur Qt 6.10 le chargement de `main.qml`
échoue et aucune scène n'est créée (le serveur d'automation démarre quand même, mais
n'a rien à introspecter). Utiliser Qt 6.11+ pour les scénarios complets.
