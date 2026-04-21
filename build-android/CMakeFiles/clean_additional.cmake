# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "Release")
  file(REMOVE_RECURSE
  "CMakeFiles/Meownopoly_autogen.dir/AutogenUsed.txt"
  "CMakeFiles/Meownopoly_autogen.dir/ParseCache.txt"
  "Meownopoly_autogen"
  )
endif()
