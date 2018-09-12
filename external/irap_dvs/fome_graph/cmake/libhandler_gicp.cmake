macro (libhandler_gicp)
  libhandler_find_library (gicp "you need to install gicp" ${ARGN})
  if (GICP_FOUND)
    set (IRPLIB_GICP ${GICP_LIBRARIES})
  endif ()
endmacro ()