macro (libhandler_x11)
  libhandler_find_package (X11 "on ubuntu `sudo apt-get install libx11-dev`" ${ARGN})
  if (X11_FOUND)
    include_directories (${X11_INCLUDE_DIR})
    set (IRPLIB_X11 ${X11_LIBRARIES})
  endif ()
endmacro ()
