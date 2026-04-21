# Bypass compiler detection (clang NDK plante via FEX sur ce test)
set(CMAKE_C_COMPILER_WORKS   TRUE  CACHE BOOL "" FORCE)
set(CMAKE_CXX_COMPILER_WORKS TRUE  CACHE BOOL "" FORCE)
set(CMAKE_C_COMPILER_FORCED   TRUE CACHE BOOL "" FORCE)
set(CMAKE_CXX_COMPILER_FORCED TRUE CACHE BOOL "" FORCE)

set(CMAKE_C_COMPILER_ID   "Clang" CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER_ID "Clang" CACHE STRING "" FORCE)
set(CMAKE_C_COMPILER_VERSION   "18.0.3" CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER_VERSION "18.0.3" CACHE STRING "" FORCE)
set(CMAKE_C_COMPILER_ID_RUN   TRUE CACHE BOOL "" FORCE)
set(CMAKE_CXX_COMPILER_ID_RUN TRUE CACHE BOOL "" FORCE)

# ABI facts (aarch64 LP64)
set(CMAKE_C_COMPILER_ABI   "ELF" CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER_ABI "ELF" CACHE STRING "" FORCE)
set(CMAKE_C_SIZEOF_DATA_PTR   8 CACHE STRING "" FORCE)
set(CMAKE_CXX_SIZEOF_DATA_PTR 8 CACHE STRING "" FORCE)

# Standards par défaut de clang 18 (= gnu17 / gnu++17)
set(CMAKE_C_STANDARD_COMPUTED_DEFAULT       "17" CACHE STRING "" FORCE)
set(CMAKE_CXX_STANDARD_COMPUTED_DEFAULT     "17" CACHE STRING "" FORCE)
set(CMAKE_C_EXTENSIONS_COMPUTED_DEFAULT     "ON" CACHE STRING "" FORCE)
set(CMAKE_CXX_EXTENSIONS_COMPUTED_DEFAULT   "ON" CACHE STRING "" FORCE)

# Features supportées par Clang 18 — liste complète car CMake check des
# features granulaires (cxx_decltype, cxx_constexpr, etc.) pas seulement std.
set(CMAKE_C_COMPILE_FEATURES
    "c_std_90;c_std_99;c_std_11;c_std_17;c_std_23;c_function_prototypes;c_restrict;c_static_assert;c_variadic_macros"
    CACHE STRING "" FORCE)
set(CMAKE_C90_COMPILE_FEATURES "c_std_90;c_function_prototypes" CACHE STRING "" FORCE)
set(CMAKE_C99_COMPILE_FEATURES "c_std_99;c_restrict;c_variadic_macros" CACHE STRING "" FORCE)
set(CMAKE_C11_COMPILE_FEATURES "c_std_11;c_static_assert" CACHE STRING "" FORCE)
set(CMAKE_C17_COMPILE_FEATURES "c_std_17" CACHE STRING "" FORCE)
set(CMAKE_C23_COMPILE_FEATURES "c_std_23" CACHE STRING "" FORCE)

set(CMAKE_CXX_COMPILE_FEATURES
    "cxx_std_98;cxx_std_11;cxx_std_14;cxx_std_17;cxx_std_20;cxx_std_23;cxx_std_26;cxx_template_template_parameters;cxx_alias_templates;cxx_alignas;cxx_alignof;cxx_attributes;cxx_auto_type;cxx_constexpr;cxx_decltype;cxx_decltype_incomplete_return_types;cxx_default_function_template_args;cxx_defaulted_functions;cxx_defaulted_move_initializers;cxx_delegating_constructors;cxx_deleted_functions;cxx_enum_forward_declarations;cxx_explicit_conversions;cxx_extended_friend_declarations;cxx_extern_templates;cxx_final;cxx_func_identifier;cxx_generalized_initializers;cxx_inheriting_constructors;cxx_inline_namespaces;cxx_lambdas;cxx_local_type_template_args;cxx_long_long_type;cxx_noexcept;cxx_nonstatic_member_init;cxx_nullptr;cxx_override;cxx_range_for;cxx_raw_string_literals;cxx_reference_qualified_functions;cxx_right_angle_brackets;cxx_rvalue_references;cxx_sizeof_member;cxx_static_assert;cxx_strong_enums;cxx_thread_local;cxx_trailing_return_types;cxx_unicode_literals;cxx_uniform_initialization;cxx_unrestricted_unions;cxx_user_literals;cxx_variadic_macros;cxx_variadic_templates;cxx_aggregate_default_initializers;cxx_attribute_deprecated;cxx_binary_literals;cxx_contextual_conversions;cxx_decltype_auto;cxx_digit_separators;cxx_generic_lambdas;cxx_lambda_init_captures;cxx_relaxed_constexpr;cxx_return_type_deduction;cxx_variable_templates"
    CACHE STRING "" FORCE)

set(CMAKE_CXX98_COMPILE_FEATURES "cxx_std_98;cxx_template_template_parameters" CACHE STRING "" FORCE)
set(CMAKE_CXX11_COMPILE_FEATURES "cxx_std_11;cxx_alias_templates;cxx_alignas;cxx_alignof;cxx_attributes;cxx_auto_type;cxx_constexpr;cxx_decltype;cxx_decltype_incomplete_return_types;cxx_default_function_template_args;cxx_defaulted_functions;cxx_defaulted_move_initializers;cxx_delegating_constructors;cxx_deleted_functions;cxx_enum_forward_declarations;cxx_explicit_conversions;cxx_extended_friend_declarations;cxx_extern_templates;cxx_final;cxx_func_identifier;cxx_generalized_initializers;cxx_inheriting_constructors;cxx_inline_namespaces;cxx_lambdas;cxx_local_type_template_args;cxx_long_long_type;cxx_noexcept;cxx_nonstatic_member_init;cxx_nullptr;cxx_override;cxx_range_for;cxx_raw_string_literals;cxx_reference_qualified_functions;cxx_right_angle_brackets;cxx_rvalue_references;cxx_sizeof_member;cxx_static_assert;cxx_strong_enums;cxx_thread_local;cxx_trailing_return_types;cxx_unicode_literals;cxx_uniform_initialization;cxx_unrestricted_unions;cxx_user_literals;cxx_variadic_macros;cxx_variadic_templates" CACHE STRING "" FORCE)
set(CMAKE_CXX14_COMPILE_FEATURES "cxx_std_14;cxx_aggregate_default_initializers;cxx_attribute_deprecated;cxx_binary_literals;cxx_contextual_conversions;cxx_decltype_auto;cxx_digit_separators;cxx_generic_lambdas;cxx_lambda_init_captures;cxx_relaxed_constexpr;cxx_return_type_deduction;cxx_variable_templates" CACHE STRING "" FORCE)
set(CMAKE_CXX17_COMPILE_FEATURES "cxx_std_17" CACHE STRING "" FORCE)
set(CMAKE_CXX20_COMPILE_FEATURES "cxx_std_20" CACHE STRING "" FORCE)
set(CMAKE_CXX23_COMPILE_FEATURES "cxx_std_23" CACHE STRING "" FORCE)
set(CMAKE_CXX26_COMPILE_FEATURES "cxx_std_26" CACHE STRING "" FORCE)

# Threads : Android bionic a pthread dans libc, pas besoin de -lpthread
set(CMAKE_HAVE_LIBC_PTHREAD     TRUE CACHE BOOL "" FORCE)
set(CMAKE_USE_PTHREADS_INIT     TRUE CACHE BOOL "" FORCE)
set(THREADS_FOUND               TRUE CACHE BOOL "" FORCE)
set(Threads_FOUND               TRUE CACHE BOOL "" FORCE)
set(CMAKE_THREAD_LIBS_INIT      "" CACHE STRING "" FORCE)
set(THREADS_PREFER_PTHREAD_FLAG FALSE CACHE BOOL "" FORCE)

# Atomic (stdatomic dans libc sur Android)
set(HAVE_STDATOMIC           TRUE CACHE BOOL "" FORCE)
set(HAVE_STDATOMIC_WITH_LIB  TRUE CACHE BOOL "" FORCE)

# EGL / GLES : présents dans le sysroot NDK (libEGL.so, libGLESv2.so)
# check_cxx_source_compiles plante sur link stage via FEX → on bypass
set(HAVE_EGL                 TRUE CACHE BOOL "" FORCE)
set(HAVE_GLESv2              TRUE CACHE BOOL "" FORCE)
set(HAVE_GLESv3              TRUE CACHE BOOL "" FORCE)
set(HAVE_OPENGL_ES_2         TRUE CACHE BOOL "" FORCE)
set(HAVE_OPENGL_ES_3         TRUE CACHE BOOL "" FORCE)

# Ne PAS ajouter sysroot/usr/include comme -isystem : les headers NDK sont
# déjà résolus par clang via --target + --sysroot, et si on les ajoute
# explicitement ils court-circuitent libc++ (cstdint cherche libc++/stdint.h
# mais trouve le C stdint.h d'abord).
# EGL.h et GLES[23]/gl*.h sont dans <sysroot>/usr/include/EGL/ et /GLES2,
# mais clang les résout sans besoin d'-isystem explicite.
set(EGL_INCLUDE_DIR              "/home/don404/android-gfx-include" CACHE PATH "" FORCE)
set(GLESv2_INCLUDE_DIR           "/home/don404/android-gfx-include" CACHE PATH "" FORCE)
set(Vulkan_INCLUDE_DIR           "/home/don404/android-gfx-include" CACHE PATH "" FORCE)
set(VulkanHeaders_INCLUDE_DIR    "/home/don404/android-gfx-include" CACHE PATH "" FORCE)
set(WrapVulkanHeaders_INCLUDE_DIR "/home/don404/android-gfx-include" CACHE PATH "" FORCE)
# Libraries aussi — pointer directement sur le .so évite search path parasite
set(EGL_LIBRARY     "/home/don404/Android/Sdk/ndk/27.2.12479018/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/28/libEGL.so" CACHE FILEPATH "" FORCE)
set(GLESv2_LIBRARY  "/home/don404/Android/Sdk/ndk/27.2.12479018/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/28/libGLESv2.so" CACHE FILEPATH "" FORCE)
