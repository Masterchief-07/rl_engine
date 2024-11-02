include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(rl_engine_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(rl_engine_setup_options)
  option(rl_engine_ENABLE_HARDENING "Enable hardening" ON)
  option(rl_engine_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    rl_engine_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    rl_engine_ENABLE_HARDENING
    OFF)

  rl_engine_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR rl_engine_PACKAGING_MAINTAINER_MODE)
    option(rl_engine_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(rl_engine_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(rl_engine_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(rl_engine_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(rl_engine_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(rl_engine_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(rl_engine_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(rl_engine_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(rl_engine_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(rl_engine_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(rl_engine_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(rl_engine_ENABLE_PCH "Enable precompiled headers" OFF)
    option(rl_engine_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(rl_engine_ENABLE_IPO "Enable IPO/LTO" ON)
    option(rl_engine_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(rl_engine_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(rl_engine_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(rl_engine_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(rl_engine_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(rl_engine_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(rl_engine_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(rl_engine_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(rl_engine_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(rl_engine_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(rl_engine_ENABLE_PCH "Enable precompiled headers" OFF)
    option(rl_engine_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      rl_engine_ENABLE_IPO
      rl_engine_WARNINGS_AS_ERRORS
      rl_engine_ENABLE_USER_LINKER
      rl_engine_ENABLE_SANITIZER_ADDRESS
      rl_engine_ENABLE_SANITIZER_LEAK
      rl_engine_ENABLE_SANITIZER_UNDEFINED
      rl_engine_ENABLE_SANITIZER_THREAD
      rl_engine_ENABLE_SANITIZER_MEMORY
      rl_engine_ENABLE_UNITY_BUILD
      rl_engine_ENABLE_CLANG_TIDY
      rl_engine_ENABLE_CPPCHECK
      rl_engine_ENABLE_COVERAGE
      rl_engine_ENABLE_PCH
      rl_engine_ENABLE_CACHE)
  endif()

  rl_engine_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (rl_engine_ENABLE_SANITIZER_ADDRESS OR rl_engine_ENABLE_SANITIZER_THREAD OR rl_engine_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(rl_engine_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(rl_engine_global_options)
  if(rl_engine_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    rl_engine_enable_ipo()
  endif()

  rl_engine_supports_sanitizers()

  if(rl_engine_ENABLE_HARDENING AND rl_engine_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR rl_engine_ENABLE_SANITIZER_UNDEFINED
       OR rl_engine_ENABLE_SANITIZER_ADDRESS
       OR rl_engine_ENABLE_SANITIZER_THREAD
       OR rl_engine_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${rl_engine_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${rl_engine_ENABLE_SANITIZER_UNDEFINED}")
    rl_engine_enable_hardening(rl_engine_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(rl_engine_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(rl_engine_warnings INTERFACE)
  add_library(rl_engine_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  rl_engine_set_project_warnings(
    rl_engine_warnings
    ${rl_engine_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(rl_engine_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    rl_engine_configure_linker(rl_engine_options)
  endif()

  include(cmake/Sanitizers.cmake)
  rl_engine_enable_sanitizers(
    rl_engine_options
    ${rl_engine_ENABLE_SANITIZER_ADDRESS}
    ${rl_engine_ENABLE_SANITIZER_LEAK}
    ${rl_engine_ENABLE_SANITIZER_UNDEFINED}
    ${rl_engine_ENABLE_SANITIZER_THREAD}
    ${rl_engine_ENABLE_SANITIZER_MEMORY})

  set_target_properties(rl_engine_options PROPERTIES UNITY_BUILD ${rl_engine_ENABLE_UNITY_BUILD})

  if(rl_engine_ENABLE_PCH)
    target_precompile_headers(
      rl_engine_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(rl_engine_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    rl_engine_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(rl_engine_ENABLE_CLANG_TIDY)
    rl_engine_enable_clang_tidy(rl_engine_options ${rl_engine_WARNINGS_AS_ERRORS})
  endif()

  if(rl_engine_ENABLE_CPPCHECK)
    rl_engine_enable_cppcheck(${rl_engine_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(rl_engine_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    rl_engine_enable_coverage(rl_engine_options)
  endif()

  if(rl_engine_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(rl_engine_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(rl_engine_ENABLE_HARDENING AND NOT rl_engine_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR rl_engine_ENABLE_SANITIZER_UNDEFINED
       OR rl_engine_ENABLE_SANITIZER_ADDRESS
       OR rl_engine_ENABLE_SANITIZER_THREAD
       OR rl_engine_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    rl_engine_enable_hardening(rl_engine_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
