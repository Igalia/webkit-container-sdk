# Ubuntu's x86_64 bootstrap Swift runtime modules use the `pc` vendor, while
# aarch64 uses `unknown`.  Normalize the compiler triple before overriding the
# Linux-x86_64 cache's target variables.
string(REPLACE ";" ":" SWIFT_PROGRAM_PATH "${CMAKE_PROGRAM_PATH}")
execute_process(
  COMMAND "${CMAKE_COMMAND}" -E env
          "PATH=${SWIFT_PROGRAM_PATH}:$ENV{PATH}"
          "${CMAKE_C_COMPILER}" -dumpmachine
  OUTPUT_VARIABLE SWIFT_NATIVE_HOST_TRIPLE
  OUTPUT_STRIP_TRAILING_WHITESPACE
  RESULT_VARIABLE SWIFT_NATIVE_HOST_TRIPLE_RESULT)
if(NOT SWIFT_NATIVE_HOST_TRIPLE_RESULT EQUAL 0 OR NOT SWIFT_NATIVE_HOST_TRIPLE)
  message(FATAL_ERROR "Could not determine the native compiler triple")
endif()
if(SWIFT_NATIVE_HOST_TRIPLE MATCHES "^x86_64-")
  set(SWIFT_NATIVE_HOST_TRIPLE "x86_64-pc-linux-gnu")
elseif(SWIFT_NATIVE_HOST_TRIPLE MATCHES "^aarch64-")
  set(SWIFT_NATIVE_HOST_TRIPLE "aarch64-unknown-linux-gnu")
endif()
set(LLVM_HOST_TRIPLE "${SWIFT_NATIVE_HOST_TRIPLE}" CACHE STRING "" FORCE)
set(LLVM_DEFAULT_TARGET_TRIPLE "${SWIFT_NATIVE_HOST_TRIPLE}" CACHE STRING "" FORCE)
set(LLVM_BUILTIN_TARGETS "${SWIFT_NATIVE_HOST_TRIPLE}" CACHE STRING "" FORCE)


list(APPEND SWIFT_INSTALL_COMPONENTS
  stdlib
  sdk-overlay
  swift-syntax-lib
)
list(REMOVE_DUPLICATES SWIFT_INSTALL_COMPONENTS)
set(SWIFT_INSTALL_COMPONENTS
    "${SWIFT_INSTALL_COMPONENTS}"
    CACHE STRING "Swift components installed with the toolchain" FORCE)

# The bootstrap swiftc adds its own in-process plugin server, which has the
# bootstrap toolchain's SwiftSyntax ABI. Run build-tree macro plugins through
# the build-tree external plugin server so they do not collide with it while
# compiling the standard library.
find_program(SWIFT_BOOTSTRAP_SWIFTC swiftc
             PATHS ${CMAKE_PROGRAM_PATH}
             NO_DEFAULT_PATH REQUIRED)
get_filename_component(SWIFT_BOOTSTRAP_BIN_DIR
                       "${SWIFT_BOOTSTRAP_SWIFTC}" DIRECTORY)
get_filename_component(SWIFT_BOOTSTRAP_ROOT
                       "${SWIFT_BOOTSTRAP_BIN_DIR}" DIRECTORY)
set(SWIFT_BOOTSTRAP_PLUGIN_SERVER
    "${CMAKE_BINARY_DIR}/bin/swift-plugin-server-bootstrap")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
file(WRITE "${SWIFT_BOOTSTRAP_PLUGIN_SERVER}"
     "#!/bin/sh\nexec \"${CMAKE_COMMAND}\" -E env \"LD_LIBRARY_PATH=${SWIFT_BOOTSTRAP_ROOT}/lib/swift/linux\" \"${CMAKE_BINARY_DIR}/bin/swift-plugin-server\" \"\$@\"\n")
file(CHMOD "${SWIFT_BOOTSTRAP_PLUGIN_SERVER}"
     PERMISSIONS
       OWNER_READ OWNER_WRITE OWNER_EXECUTE
       GROUP_READ GROUP_EXECUTE
       WORLD_READ WORLD_EXECUTE)
set(SWIFT_STDLIB_EXTRA_SWIFT_COMPILE_FLAGS
    "-external-plugin-path;${CMAKE_BINARY_DIR}/lib/swift/host/plugins#${SWIFT_BOOTSTRAP_PLUGIN_SERVER}"
    CACHE STRING "" FORCE)

# LLDB's Swift expression parser uses this to locate the in-tree Swift runtime.
# Normally LLDB's test configuration initializes it, but tests are disabled in
# this distribution.
set(LLDB_SWIFT_LIBS "${CMAKE_BINARY_DIR}/lib/swift" CACHE PATH "" FORCE)

# llvm-mt has no install target in this configuration. The remaining tools are
# not needed by the Linux Swift SDK distribution.
list(REMOVE_ITEM LLVM_DISTRIBUTION_COMPONENTS
  llvm-mt
  dsymutil
  dwp
  llvm-dwarfdump
  llvm-dwp
)

# Extend Swift's platform distribution without replacing the components
# that the Swift toolchain itself needs.
list(APPEND LLVM_DISTRIBUTION_COMPONENTS
  stdlib
  sdk-overlay
  swift-syntax-lib
  clangd
  clang-format
  clang-tidy
  clang-apply-replacements
  clang-resource-headers
  clang-scan-deps
  clang-include-cleaner
  clang-include-fixer
  LLVM
)
list(REMOVE_DUPLICATES LLVM_DISTRIBUTION_COMPONENTS)
set(LLVM_DISTRIBUTION_COMPONENTS
    "${LLVM_DISTRIBUTION_COMPONENTS}"
    CACHE STRING "Components installed with the Swift toolchain" FORCE)
