/*
 * reliable_impl.cpp
 *
 * Wrapper C++ qui compile reliable.c dans le projet Qt.
 * On utilise un .cpp pour éviter d'avoir à activer LANGUAGES C dans CMake
 * (le toolchain Qt Creator ne configure pas toujours gcc en mode C standalone).
 *
 * reliable.h déclare déjà extern "C" { ... } quand __cplusplus est défini,
 * donc inclure reliable.c ici est parfaitement compatible.
 */

// Désactiver les tests internes de reliable qui ont leur propre main()
#define RELIABLE_ENABLE_TESTS 0

// Forcer le mode debug pour avoir les logs et assertions même en build Release
#ifndef RELIABLE_DEBUG
#define RELIABLE_DEBUG 1
#endif

extern "C" {
#include "reliable.c"
}
