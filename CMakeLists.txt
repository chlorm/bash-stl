cmake_minimum_required (VERSION 3.0)
project(lib-bash)

install(PROGRAMS ${CMAKE_CURRENT_LIST_DIR}/src/bin/lib-bash DESTINATION bin)

install(FILES ${CMAKE_CURRENT_LIST_DIR}/src/share/lib-bash/lib.bash DESTINATION share/lib-bash)
