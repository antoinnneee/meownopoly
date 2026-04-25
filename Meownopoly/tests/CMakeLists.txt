# ============================================================================
# Tests unitaires PattounX (Qt6::Test)
# ============================================================================

set(PHYSICS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../cpp/game/physics")

set(PATTOUNX_TEST_SOURCES
    "${PHYSICS_DIR}/collision2d.cpp"
    "${PHYSICS_DIR}/pattounx_engine_v2.cpp"
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

# Cible agrégée demandée par le plan : pattounx_tests
add_custom_target(pattounx_tests
    DEPENDS tst_collision2d tst_pattounx_engine
    COMMENT "Build all PattounX unit tests"
)
