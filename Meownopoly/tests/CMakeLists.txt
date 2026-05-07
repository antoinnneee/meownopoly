# ============================================================================
# Tests unitaires PattounX (Qt6::Test)
# ============================================================================

set(PHYSICS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../cpp/game/physics")

set(PATTOUNX_TEST_SOURCES
    "${PHYSICS_DIR}/collision2d.cpp"
    "${PHYSICS_DIR}/pattounx_engine_v2.cpp"
)

# Sources additionnelles pour les tests qui ont besoin du worker/façade
set(PATTOUNX_WORKER_SOURCES
    "${PHYSICS_DIR}/physics_worker.cpp"
    "${PHYSICS_DIR}/physics_world.cpp"
)
set(PATTOUNX_WORKER_HEADERS
    "${PHYSICS_DIR}/physics_worker.h"
    "${PHYSICS_DIR}/physics_world.h"
)

# Test : Collision2D (primitives + sweep cercle/cercle)
qt_add_executable(tst_collision2d
    tst_collision2d.cpp
    ${PATTOUNX_TEST_SOURCES}
)
target_include_directories(tst_collision2d PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/../cpp"
    "${PHYSICS_DIR}"
)
target_link_libraries(tst_collision2d PRIVATE Qt6::Core Qt6::Test Qt6::Gui)
add_test(NAME tst_collision2d COMMAND tst_collision2d)

# Test : PattounX_engine v2 (smoke tests, body-body, sleep)
qt_add_executable(tst_pattounx_engine
    tst_pattounx_engine.cpp
    ${PATTOUNX_TEST_SOURCES}
)
target_include_directories(tst_pattounx_engine PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/../cpp"
    "${PHYSICS_DIR}"
)
target_link_libraries(tst_pattounx_engine PRIVATE Qt6::Core Qt6::Test Qt6::Gui)
add_test(NAME tst_pattounx_engine COMMAND tst_pattounx_engine)

# Test : PhysicsWorker + PhysicsWorld (cycle de vie + thread + buffer)
qt_add_executable(tst_physics_worker
    tst_physics_worker.cpp
    ${PATTOUNX_TEST_SOURCES}
    ${PATTOUNX_WORKER_SOURCES}
    ${PATTOUNX_WORKER_HEADERS}
)
target_include_directories(tst_physics_worker PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/../cpp"
    "${PHYSICS_DIR}"
)
target_link_libraries(tst_physics_worker PRIVATE
    Qt6::Core Qt6::Test Qt6::Gui Qt6::Qml)
add_test(NAME tst_physics_worker COMMAND tst_physics_worker)

# Test : codec snapshot réseau (round-trip serialize/applyRemoteSnapshot)
qt_add_executable(tst_snapshot_codec
    tst_snapshot_codec.cpp
    ${PATTOUNX_TEST_SOURCES}
    ${PATTOUNX_WORKER_SOURCES}
    ${PATTOUNX_WORKER_HEADERS}
)
target_include_directories(tst_snapshot_codec PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/../cpp"
    "${PHYSICS_DIR}"
)
target_link_libraries(tst_snapshot_codec PRIVATE
    Qt6::Core Qt6::Test Qt6::Gui Qt6::Qml)
add_test(NAME tst_snapshot_codec COMMAND tst_snapshot_codec)

# Cible agrégée demandée par le plan : pattounx_tests
add_custom_target(pattounx_tests
    DEPENDS tst_collision2d tst_pattounx_engine tst_physics_worker tst_snapshot_codec
    COMMENT "Build all PattounX unit tests"
)

# ============================================================================
# Benchmark : rendu des zones d'exclusion (ZoneCanvasPainter)
# ============================================================================
# Compile uniquement quand Qt6::CanvasPainter est dispo (Qt 6.11+). Le test
# instancie N ZoneCanvasPainter dans une QQuickView offscreen et mesure le
# frame time pour différents scénarios (count, complexité polygone, zoom burst).
# Sert à comparer objectivement plusieurs implémentations de rendu.

if (TARGET Qt6::CanvasPainter)
    set(PAINTER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../cpp/editor/painter")
    qt_add_executable(tst_zone_render_perf
        tst_zone_render_perf.cpp
        "${PAINTER_DIR}/zone_canvas_painter.cpp"
        "${PAINTER_DIR}/zone_canvas_painter.h"
        "${PAINTER_DIR}/zone_canvas_painter_renderer.cpp"
        "${PAINTER_DIR}/zone_canvas_painter_renderer.h"
        "${PAINTER_DIR}/zone_hatch_compute.cpp"
        "${PAINTER_DIR}/zone_hatch_compute.h"
    )
    target_compile_definitions(tst_zone_render_perf PRIVATE MEOW_HAS_CANVAS_PAINTER)
    target_include_directories(tst_zone_render_perf PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/../cpp"
    )
    target_link_libraries(tst_zone_render_perf PRIVATE
        Qt6::Core Qt6::Test Qt6::Gui Qt6::Qml Qt6::Quick
        Qt6::Concurrent Qt6::CanvasPainter)

    # Le test charge zone_render_scene.qml via QFINDTESTDATA — copier le
    # QML à côté du binaire pour que le helper le trouve.
    add_custom_command(TARGET tst_zone_render_perf POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_CURRENT_SOURCE_DIR}/zone_render_scene.qml"
            "$<TARGET_FILE_DIR:tst_zone_render_perf>/zone_render_scene.qml"
    )

    add_test(NAME tst_zone_render_perf COMMAND tst_zone_render_perf)
    # Le test ouvre une fenêtre — pas adapté à un CI headless. Marqué pour
    # exécution manuelle uniquement.
    set_tests_properties(tst_zone_render_perf PROPERTIES LABELS "manual;perf")

    # ────────────────────────────────────────────────────────────────────
    # Benchmark : rendu de la grille (GridManager / GridCanvasPainter)
    # ────────────────────────────────────────────────────────────────────
    # Compare Repeater (legacy) vs GridCanvasPainter (Qt 6.11) avec viewport
    # culling. Toggle via env var MEOW_GRID_RENDERER=repeater|canvas.
    qt_add_executable(tst_grid_render_perf
        tst_grid_render_perf.cpp
        "${PAINTER_DIR}/grid_canvas_painter.cpp"
        "${PAINTER_DIR}/grid_canvas_painter.h"
        "${PAINTER_DIR}/grid_canvas_painter_renderer.cpp"
        "${PAINTER_DIR}/grid_canvas_painter_renderer.h"
    )
    target_compile_definitions(tst_grid_render_perf PRIVATE MEOW_HAS_CANVAS_PAINTER)
    target_include_directories(tst_grid_render_perf PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/../cpp"
    )
    target_link_libraries(tst_grid_render_perf PRIVATE
        Qt6::Core Qt6::Test Qt6::Gui Qt6::Qml Qt6::Quick Qt6::CanvasPainter)

    # Le test charge grid_render_scene.qml + GridManager.qml par chemin
    # filesystem (pas qrc) pour mesurer le code QML en cours.
    add_custom_command(TARGET tst_grid_render_perf POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_CURRENT_SOURCE_DIR}/grid_render_scene.qml"
            "$<TARGET_FILE_DIR:tst_grid_render_perf>/grid_render_scene.qml"
    )

    add_test(NAME tst_grid_render_perf COMMAND tst_grid_render_perf)
    set_tests_properties(tst_grid_render_perf PROPERTIES LABELS "manual;perf")
endif()
