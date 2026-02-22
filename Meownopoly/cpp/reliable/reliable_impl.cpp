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

extern "C" {
#include "reliable.c"
}
