#!/bin/bash
#set -x
##############################################################################
#
# Copyright: (C) 2011 Department of Robotics Brain and Cognitive Sciences, Istituto Italiano di Tecnologia
# Authors: Lorenzo Natale
# CopyPolicy: Released under the terms of the LGPLv2.1 or later, see LGPL.TXT
#
# Based on build code for YARP from Paul Fitzpatrick
#
# Amalgamate builds into an NSIS package
# 

# Substitute a given string in a file
# replace_string string_old string_new file
function replace_string {
  string_old=$1
  string_new=$2
  file=$3
  
  echo "Replacing $string_old with $string_new in $file"

    ## we use comma as delimeter so not to confuse sed with / 
  ## in strings that contain paths  
  sed -i "s,$string_old,$string_new,g" $file
}

# Add string at specific place inside a file
# replace_string string_old string_new file
function insert_at {
  string=$1
  at=$2
  file=$3

    ## we use comma as delimeter so not to confuse sed with / 
  ## in strings that contain paths  
  sed -i "s,^$at,$at\r\n$string," $file
}

# Add string at specific place inside a file
# replace_string string_old string_new file
function insert_top {
  string=$1
  file=$2
  
    ## we use comma as delimeter so not to confuse sed with / 
  ## in strings that contain paths  
  sed -i "1i $string" $file
}

guard_file="build_package_${c}_${v}.txt"
if [ -e $guard_file ]; then
    echo "Skipping build_package_${c}_${v}"
    return
fi

BUILD_DIR=$PWD
VENDOR=robotology

cd $BUNDLE_YARP_DIR
source  $YARP_BUNDLE_SOURCE_DIR/src/process_options.sh $c $v Release

cd $BUILD_DIR
# brings in variables to locate GSL_DIR (we need to separate debug and release)
source gsl_${c}_${v}_Debug.sh
GSL_DIR_DBG=$GSL_DIR
source gsl_${c}_${v}_Release.sh

ACE_SUB="ace-$BUNDLE_ACE_VERSION"

######### Load env variables for iCub
## load debug variables and save them
source icub_${c}_${v}_Debug.sh
ICUB_DIR_DBG=$ICUB_DIR
ICUB_ROOT_DBG=$ICUB_ROOT
## now load release variables
source icub_${c}_${v}_Release.sh

######### Start build process
if [ ! -d "build-nsis" ]; then
  mkdir build-nsis
fi
cd build-nsis

# Get base ICUB path in unix format
ICUB_DIR_DBG_UNIX=`cygpath -u $ICUB_DIR_DBG`
ICUB_DIR_UNIX=`cygpath -u $ICUB_DIR`
SDLDIR_UNIX=`cygpath -u $SDLDIR`
GLUT_DIR_UNIX=`cygpath -u $GLUT_DIR`
GSL_DIR_UNIX=$(cygpath -u $GSL_DIR)
GSL_DIR_DBG_UNIX=$(cygpath -u $GSL_DIR_DBG)

# Make build directory
fname=iCub_package-$BUNDLE_ICUB_VERSION
fname2=$fname
if [ ! -d "$fname2" ]; then
  mkdir -p $fname2
else 
    rm -rf fname2/*
fi
cd $fname2 || exit 1
OUT_DIR=$PWD
echo $(pwd)
### Copy some iCub files from debug tree
cp $ICUB_DIR_DBG_UNIX/lib/ICUB/icub-export-install-debug.cmake $ICUB_DIR_UNIX/lib/ICUB/
cp $ICUB_DIR_DBG_UNIX/lib/*.lib $ICUB_DIR_UNIX/lib/
cd $ICUB_DIR_UNIX/lib/ICUB || exit 1

# Function to prepare stub files for adding/removing files for an NSIS
# section, and for building the corresponding zip file
function nsis_setup {
  prefix=$1
  echo -n > ${OUT_DIR}/${prefix}_add.nsi
  echo -n > ${OUT_DIR}/${prefix}_remove.nsi
  echo -n > ${OUT_DIR}/${prefix}_zip.sh
}


# Add a file or files into list to be added/removed from NSIS section,
# and to be placed into the corresponding zip file.  Implementation is
# complicated by the need to avoid calling the super-slow cygpath
# command too often.
CYG_BASE=`cygpath -w /`
function nsis_add_base {
  mode=$1
  prefix=$2
  src=$3
  dest=$4
  dir=$5 #optional
  echo "Add " "$@"
  osrc="$src"
  odest="$dest"
  if [ "k$dir" = "k" ] ; then
    src="$PWD/$src"
    osrc="$src"
    src=${src//\//\\}
    src="$CYG_BASE$src"
  else
    src="$dir/$src"
    osrc="$src"
    src=${src//\//\\}
  fi
  dest=${dest//\//\\} # flip to windows convention
  zodest1="zip/$prefix/$zip_name/$odest"
  zodest2="zip_all/$zip_name/$odest"
  if [ "$mode" = "single" ]; then
    dir=`echo $dest | sed 's/\\\\[^\\\\]*$//'`
    echo "CreateDirectory \"\$INSTDIR\\$dir\"" >> $OUT_DIR/${prefix}_add.nsi
    echo "SetOutPath \"\$INSTDIR\"" >> $OUT_DIR/${prefix}_add.nsi
    echo "File /oname=$dest $src" >> $OUT_DIR/${prefix}_add.nsi
    echo "Delete \"\$INSTDIR\\$dest\"" >> $OUT_DIR/${prefix}_remove.nsi
    echo "mkdir -p `dirname $zodest1`" >> $OUT_DIR/${prefix}_zip.sh
    echo "mkdir -p `dirname $zodest2`" >> $OUT_DIR/${prefix}_zip.sh
    echo "cp '$osrc' $zodest1" >> $OUT_DIR/${prefix}_zip.sh
    echo "cp '$osrc' $zodest2" >> $OUT_DIR/${prefix}_zip.sh
  else
    # recursive
    dir=`echo $dest | sed 's/\\\\[^\\\\]*$//'`
    echo "CreateDirectory \"\$INSTDIR\\$dir\"" >> $OUT_DIR/${prefix}_add.nsi
    echo "SetOutPath \"\$INSTDIR\\$dir\"" >> $OUT_DIR/${prefix}_add.nsi
    echo "File /r $src" >> $OUT_DIR/${prefix}_add.nsi
    echo "RmDir /r \"\$INSTDIR\\$dest\"" >> $OUT_DIR/${prefix}_remove.nsi
    echo "mkdir -p $zodest1" >> $OUT_DIR/${prefix}_zip.sh
    echo "mkdir -p $zodest2" >> $OUT_DIR/${prefix}_zip.sh
    echo "cp -r $osrc/* $zodest1" >> $OUT_DIR/${prefix}_zip.sh
    echo "cp -r $osrc/* $zodest2" >> $OUT_DIR/${prefix}_zip.sh
  fi
}

# Add a single file into list to be added/removed from NSIS section,
# and to be placed into the corresponding zip file.
function nsis_add {
  nsis_add_base single "$@"
}

# Add a directory to be added/removed from NSIS section.
function nsis_add_recurse {
  nsis_add_base recurse "$@"
}

# Set up stubs for all NSIS sections
nsis_setup icub_base
nsis_setup icub_headers
nsis_setup icub_libraries
nsis_setup icub_cmake
nsis_setup icub_vc_dlls

nsis_setup icub_modules
nsis_setup icub_data_dirs

nsis_setup icub_ipopt

nsis_setup icub_glut
nsis_setup icub_glut_bin

nsis_setup icub_sdl
nsis_setup icub_sdl_bin

nsis_setup icub_ode

nsis_setup icub_gsl

ICUB_SUB="icub-$BUNDLE_ICUB_VERSION"
IPOPT_SUB="ipopt-$BUNDLE_IPOPT_VERSION"
GLUT_SUB="glut-$BUNDLE_GLUT_VERSION"
SDL_SUB="sdl-$BUNDLE_SDL_VERSION"
ODE_SUB="ode-$BUNDLE_ODE_VERSION"
GSL_SUB="gsl-$BUNDLE_GSL_VERSION"

## First license
cd $ICUB_DIR_UNIX || exit 1
ICUB_LICENSE=`cygpath --windows "$ICUB_ROOT/conf/package/license.txt"`
ICUB_LOGO=`cygpath --windows "$ICUB_ROOT/conf/package/robotcublogo.bmp"`


cd $ICUB_DIR_UNIX
nsis_add_recurse icub_data_dirs share $ICUB_SUB/share

## CMake files
cd $ICUB_DIR_UNIX/lib/ICUB || exit 1

#replace_string "$ICUB_DIR" \${ICUB_INSTALLED_LOCATION} icub-config-tmp.cmake
files_to_fix="icub-config.cmake icub-export-inst-includes.cmake icub-export-install-release.cmake icub-export-install-debug.cmake"
for f in $files_to_fix
do
  echo "processing file ${f}"
  cp "${f}" "${f}.backup"
  replace_string "$ICUB_DIR" \${ICUB_INSTALLED_LOCATION} "${f}.backup"
  
  replace_string "$GSL_DIR" \${GSL_INSTALLED_LOCATION} "${f}.backup"
  GSL_DEBUG_STRING=$(echo $GSL_DIR | sed "s/Release/Debug/g")
  replace_string "$GSL_DEBUG_STRING" \${GSL_INSTALLED_LOCATION} "${f}.backup"
  
  replace_string "$IPOPT_DIR" \${IPOPT_INSTALLED_LOCATION} "${f}.backup"
  IPOPT_DEBUG_STRING=$(echo $IPOPT_DIR | sed "s/Release/Debug/g")
  replace_string "$IPOPT_DEBUG_STRING" \${IPOPT_INSTALLED_LOCATION} "${f}.backup"
  
  replace_string "$ACE_DIR" \${ACE_INSTALLED_LOCATION} "${f}.backup"
  ACE_DEBUG_STRING=$(echo $ACE_DIR | sed "s/Release/Debug/g")
  replace_string "$ACE_DEBUG_STRING" \${ACE_INSTALLED_LOCATION} "${f}.backup"

  insert_top "set(GSL_INSTALLED_LOCATION __NSIS_GSL_INSTALLED_LOCATION__)" "${f}.backup"
  insert_top "set(IPOPT_INSTALLED_LOCATION __NSIS_IPOPT_INSTALLED_LOCATION__)"  "${f}.backup"
  insert_top "set(ICUB_INSTALLED_LOCATION __NSIS_ICUB_INSTALLED_LOCATION__)" "${f}.backup"
  insert_top "set(ACE_INSTALLED_LOCATION __NSIS_ACE_INSTALLED_LOCATION__)" "${f}.backup"
  mv ${f}.backup ${f}
done

nsis_add icub_base icub-config.cmake $ICUB_SUB/lib/ICUB/icub-config.cmake
nsis_add icub_base icub-export-install.cmake $ICUB_SUB/lib/ICUB/icub-export-install.cmake
nsis_add icub_base icub-export-inst-includes.cmake $ICUB_SUB/lib/ICUB/icub-export-inst-includes.cmake
nsis_add icub_base icub-export-install-release.cmake $ICUB_SUB/lib/ICUB/icub-export-install-release.cmake
nsis_add icub_base icub-export-install-debug.cmake $ICUB_SUB/lib/ICUB/icub-export-install-debug.cmake

## Libraries
cd $ICUB_DIR_UNIX/lib || exit 1
for f in `ls -1 *.lib`; do
  nsis_add icub_libraries $f $ICUB_SUB/lib/$f
done

## PDB files
cd $ICUB_DIR_UNIX/lib || exit 1
echo "*** searching for PDB files in $ICUB_DIR_UNIX/lib"
for f in `ls -1 *.pdb`; do
  nsis_add icub_libraries $f $ICUB_SUB/lib/$f
  echo "** found PDB FILE : $f"
done

## Modules
cd $ICUB_DIR_UNIX/bin
for f in `ls -1 *.exe`; do
  nsis_add icub_modules $f $ICUB_SUB/bin/$f
done
cd $ICUB_DIR_UNIX/lib
nsis_add_recurse icub_modules iCub $ICUB_SUB/lib/iCub

## header files
cd $ICUB_DIR_UNIX
nsis_add_recurse icub_headers include $ICUB_SUB/include

# Add stuff to NSIS
## add SDL 
case "$v" in
"x86" )
  SDL_OBJ_PLAT="x86"
  ;;
"x64" | "x86_64" | "x86_amd64" )
  SDL_OBJ_PLAT="x64"
  ;;
*)
  echo "ERROR: platform $v not supported."
  exit 1
esac
echo "SDLDIR Release: $SDLDIR"
if [ -e "$SDLDIR" ] ; then
  cd "$SDLDIR" || exit 1
  for f in `find ./ -maxdepth 1 -type f`; do
    nsis_add icub_sdl $f $SDL_SUB/$f
  done
  nsis_add_recurse icub_sdl include $SDL_SUB/include
  nsis_add_recurse icub_sdl docs $SDL_SUB/docs
  cd "$SDLDIR/lib/${SDL_OBJ_PLAT}" || exit 1
  files="SDL.lib SDLmain.lib"
  for f in $files; do
    nsis_add icub_sdl $f $SDL_SUB/lib/$f
  done
  nsis_add icub_sdl_bin SDL.dll $SDL_SUB/lib/SDL.dll
else
  echo "ERROR: directory $SDL_SUB is missing" 
  exit 1
fi

## add GLUT 
if [ -e "$GLUT_DIR" ] ; then
  cd "$GLUT_DIR"
  case "$v" in
  "x86" )
    files="glut32.lib glut.def README-icub.txt README-win32.txt"
    nsis_add icub_glut_bin glut32.dll $GLUT_SUB/glut32.dll
    ;;
  "x64" | "x86_64" | "x86_amd64" )
    files="glut64.lib glut.def README-icub.txt README-win32.txt"
    nsis_add icub_glut_bin glut64.dll $GLUT_SUB/glut64.dll
    ;;
  *)
    echo "ERROR: platform $v not supported."
    exit 1
  esac
  for f in $files; do
    nsis_add icub_glut $f $GLUT_SUB/$f
  done
  nsis_add_recurse icub_glut GL $GLUT_SUB/GL
else
  echo "WARNING: Skipping GLUT - directory $GLUT_DIR is missing" 
fi


## add ODE
echo "ODE: $ODE_DIR"
if [ -e "$ODE_DIR" ]; then
  cd "$ODE_DIR"
  for f in `find ./ -maxdepth 1 -type f`; do
    nsis_add icub_ode $f $ODE_SUB/$f
  done
  nsis_add_recurse icub_ode lib $ODE_SUB/lib
  nsis_add_recurse icub_ode drawstuff $ODE_SUB/drawstuff
  nsis_add_recurse icub_ode GIMPACT $ODE_SUB/GIMPACT
  nsis_add_recurse icub_ode include $ODE_SUB/include
  nsis_add_recurse icub_ode ode $ODE_SUB/ode
  nsis_add_recurse icub_ode OPCODE $ODE_SUB/OPCODE
  nsis_add_recurse icub_ode ou $ODE_SUB/ou
  nsis_add_recurse icub_ode tests $ODE_SUB/tests
  nsis_add_recurse icub_ode tools $ODE_SUB/tools
else
  echo "ERROR: directory $ODE_DIR is missing" 
  exit 1
fi

echo "GSL: $GSL_DIR"
if [ -e "$GSL_DIR" ]; then
  cd "$GSL_DIR"
  nsis_add_recurse icub_gsl include ${GSL_SUB}/include 
  nsis_add_recurse icub_gsl lib ${GSL_SUB}/lib 
else
  echo "ERROR: directory $GSL_DIR is missing" 
  exit 1
fi

# Add Visual Studio redistributable material to NSIS
echo $OPT_VC_REDIST_CRT
if [ -e "$OPT_VC_REDIST_CRT" ] ; then
  cd "$OPT_VC_REDIST_CRT" || exit 1
  for f in `ls *.dll *.manifest`; do
    nsis_add icub_vc_dlls $f $ICUB_SUB/bin/$f "$OPT_VC_REDIST_CRT"
  done
fi

# Add ipopt
cd $IPOPT_DIR
nsis_add_recurse icub_ipopt include $IPOPT_SUB/include
nsis_add_recurse icub_ipopt lib $IPOPT_SUB/lib 
nsis_add_recurse icub_ipopt share $IPOPT_SUB/share
nsis_add_recurse icub_ipopt bin $IPOPT_SUB/bin

# Run NSIS
cd $OUT_DIR
echo $OUT_DIR
echo $ICUB_PACKAGE_SOURCE_DIR
cp $ICUB_PACKAGE_SOURCE_DIR/nsis/*.nsh .

#$NSIS_BIN -DACE_SUB=$ACE_SUB -DQT3_SUB=$QT3_SUB -DODE_SUB=$ODE_SUB -DGLUT_SUB=$GLUT_SUB -DSDL_SUB=$SDL_SUB -DOPENCV_SUB=$OPENCV_SUB -DIPOPT_SUB=$IPOPT_SUB -DYARP_VERSION=$BUNDLE_YARP_VERSION -DINST2=$ICUB_SUB -DGSL_VERSION=$BUNDLE_GSL_VERSION -DICUB_VERSION=$BUNDLE_ICUB_VERSION -DICUB_TWEAK=$BUNDLE_ICUB_TWEAK -DBUILD_VERSION=${OPT_COMPILER}_${OPT_VARIANT} -DVENDOR=$VENDOR -DICUB_LOGO=$ICUB_LOGO -DICUB_LICENSE=$ICUB_LICENSE -DICUB_ORG_DIR=$ICUB_DIR -DGSL_ORG_DIR=$GSL_DIR -DNSIS_OUTPUT_PATH=`cygpath -w $PWD` `cygpath -m $ICUB_PACKAGE_SOURCE_DIR/nsis/icub_package.nsi` || exit 1
$NSIS_BIN -DICUB_VARIANT="$c" -DICUB_PLATFORM="$v" -DGSL_SUB="$GSL_SUB" -DACE_SUB="$ACE_SUB" -DODE_SUB="$ODE_SUB" -DGLUT_SUB="$GLUT_SUB" -DSDL_SUB="$SDL_SUB" -DIPOPT_SUB="$IPOPT_SUB" -DYARP_VERSION="$BUNDLE_YARP_VERSION" -DINST2="$ICUB_SUB" -DGSL_VERSION="$BUNDLE_GSL_VERSION" -DICUB_VERSION="$BUNDLE_ICUB_VERSION" -DICUB_TWEAK="$BUNDLE_ICUB_TWEAK" -DBUILD_VERSION="${OPT_COMPILER}_${OPT_VARIANT}" -DVENDOR="$VENDOR" -DICUB_LOGO="$ICUB_LOGO" -DICUB_LICENSE="$ICUB_LICENSE" -DICUB_ORG_DIR="$ICUB_DIR" -DGSL_ORG_DIR="$GSL_DIR" -DNSIS_OUTPUT_PATH="$(cygpath -w $PWD)" "$(cygpath -m $ICUB_PACKAGE_SOURCE_DIR/nsis/icub_package.nsi)" || exit 1

PACKAGES_DEST_DIR="${BUILD_DIR}/icub-packages" 
if [ ! -d "${PACKAGES_DEST_DIR}" ]; then
  mkdir ${PACKAGES_DEST_DIR}
fi

PACKAGE_FILE="iCub_${BUNDLE_ICUB_VERSION}_${OPT_COMPILER}_${OPT_VARIANT}_${BUNDLE_ICUB_TWEAK}.exe"
if [ -f "${PACKAGES_DEST_DIR}/$PACKAGE_FILE}" ]; then
  rm ${PACKAGES_DEST_DIR}/$PACKAGE_FILE}
fi

cp ${OUT_DIR}/${PACKAGE_FILE} ${PACKAGES_DEST_DIR} || exit 1
cd $BUILD_DIR

touch $guard_file
