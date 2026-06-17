---
type: "query"
date: "2026-05-14T07:36:17.310891+00:00"
question: "Pourquoi LauncherManager relie-t-il Gameplay and Launcher Docs a Launcher Manager Implementation, C++ Classes Docs et Asset and Player Config Docs?"
contributor: "graphify"
source_nodes: ["LauncherManager (singleton C++)", "LauncherManager (updates, packages, balsam)", "launcher_manager.cpp", "FolderCompressor", ".meow model pack archive"]
---

# Q: Pourquoi LauncherManager relie-t-il Gameplay and Launcher Docs a Launcher Manager Implementation, C++ Classes Docs et Asset and Player Config Docs?

## Answer

LauncherManager est un god-object discret: une seule classe C++ concentre 3 responsabilites sans rapport (mises a jour app, telechargement/packaging de ressources et modeles, pipeline import Balsam obj/glb->qml). Le reste du codebase documente ces sujets dans des fichiers separes (LAUNCHER_ARCHITECTURE.md, ASSET_MANAGER.md, CPP_CLASSES.md, SERVEUR_RESSOURCES.md), donc le clustering les a ranges dans des communautes distinctes. Le noeud LauncherManager les recoud via: imports qmlapp.cpp/launcher_manager.cpp (implementation), references .meow model pack archive et MetadataGenerator (asset docs), FolderCompressor references QmlApp (cpp classes docs). La frontiere de decoupage naturelle est exactement celle trouvee par le graphe: updater / resource-packager / balsam-importer.

## Source Nodes

- LauncherManager (singleton C++)
- LauncherManager (updates, packages, balsam)
- launcher_manager.cpp
- FolderCompressor
- .meow model pack archive