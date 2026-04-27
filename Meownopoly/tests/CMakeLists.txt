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
