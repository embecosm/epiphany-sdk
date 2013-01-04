#!/bin/sh

# Copyright (C) 2009, 2011 Embecosm Limited

# Contributor Joern Rennecke <joern.rennecke@embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>
# Contributor Simon Cook <simon.cook@embecosm.com>

# This file is a script to build key elements of the Epiphany tool chain

# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3 of the License, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.

# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.          

# Usage: ./build-toolchain.sh [ --force ] [ --build-dir <build_directory>]
#                 [--enable-cgen-maint]
#                 [ --unified-dir <unified_directory> ]
#                 [ --install-dir <install_directory> ]
# --force: remove previous unified source / build directories.
# --build-dir: specify name for build directory.
# --enable-cgen-maint: pass down to configure, for rebuilding
#                    opcodes / binutils after a change to the cgen description.
# --unified-dir: specify name for unified src directory.
# --install-dir: specify name for install directory.

component_dirs='../gcc ../src'
unified_src="${PWD}/../srcw"
build_dir="${PWD}/../bld-epiphany"
install_dir="${PWD}/../INSTALL"

# The assembler and/or linker are broken so that constant merging doesn't work.
export CFLAGS_FOR_TARGET='-O2 -g'

# Check for relative directory and makes it absolute
absolutedir() {
  case ${1} in
    /*) echo "${1}" ;;
    *)  echo "${PWD}/${1}";;
  esac
}

# Prints usage to terminal
usage() {
  echo " Usage: $0 [ --force ] [ --build-dir <build_directory>]"
  echo "                 [--enable-cgen-maint]"
  echo "                 [ --unified-dir <unified_directory> ]"
  echo "                 [ --install-dir <install_directory> ]"
  echo " --force: remove previous unified source / build directories."
  echo " --build-dir: specify name for build directory."
  echo " --enable-cgen-maint: pass down to configure, for rebuilding"
  echo "                    opcodes / binutils after a change to the cgen description."
  echo " --unified-dir: specify name for unified src directory."
  echo " --install-dir: specify name for install directory."
}

# Displays a message if the build fails
failedbuild() {
  echo " **************************************************"
  echo " The SDK build has failed."
  echo " The log for this build can be found at"
  echo " ${logfile}"
  echo " For support, visit the forums or documentation at:"
  echo "  * http://forums.parallella.org/viewforum.php?f=13"
  echo "  * https://github.com/parallella/epiphany-sdk/wiki"
  echo " **************************************************"
}

# If /proc/cpuinfo is avaliable, limit load to launch extra jobs to
# number of processors + 1, otherwise use a constant of 2.
make_load="-j -l `(echo processor;cat /proc/cpuinfo 2>/dev/null || echo processor)|grep -c processor`"
CONFIG_EXTRA_OPTS=""
# Parse Options
until
  opt=$1
  case ${opt} in
    --force)
      rm -rf ${unified_src} ${build_dir} ${install_dir} ;;
    --build-dir)
      build_dir=$(absolutedir "$2"); shift ;;
    --enable-cgen-maint)
      CONFIG_EXTRA_OPTS="$CONFIG_EXTRA_OPTS --enable-cgen-maint" ;;
    --unified-dir)
      unified_src=$(absolutedir "$2"); shift ;;
    --install-dir)
      install_dir=$(absolutedir "$2"); shift ;;
    ?*)
      usage; exit 0 ;;
    *)
      opt="";;
  esac;
  [ -z "${opt}" ]; do 
    shift
done

# Set up a log
logfile=$(echo "${PWD}")/../build-$(date -u +%F-%H%M).log
rm -f "${logfile}"

echo "START BUILD: $(date)" >> ${logfile}
echo "Build Started at $(date)"
echo "Build Log: ${logfile}"
echo " * This can be watched in another terminal via 'tail -f ${logfile}'"
echo "Build Directory: ${build_dir}"
echo "Install Directory: ${install_dir}"

# Create unified source directory
echo "Creating unified source" >> ${logfile}
echo "=======================" >> ${logfile}
echo "Creating unified source..."
./symlink-all "${unified_src}" ${component_dirs} >> "${logfile}" 2>&1
if [ $? != 0 ]; then
  echo "Failed to create ${unified_src}."
  failedbuild
  exit 1
fi

# Configure binutils, GCC, newlib and GDB
echo "Configuring tools" >> "${logfile}"
echo "=================" >> "${logfile}"
echo "Configuring tools..."
mkdir -p "${build_dir}" && cd "${build_dir}" \
  && "${unified_src}/configure" --target=epiphany-elf \
    --with-pkgversion="Epiphany toolchain 20120120 (built `date +%Y%m%d`)" \
    --with-bugurl=support-sdk@adapteva.com \
    --enable-fast-install=N/A \
    --enable-languages=c,c++ --prefix="${install_dir}" \
    --with-headers="${unified_src}/newlib/libc/include" \
    --disable-gdbtk \
    $CONFIG_EXTRA_OPTS >> "${logfile}" 2>&1
if [ $? != 0 ]; then
  echo "Error: Configure failed."
  failedbuild
  exit 1
fi

# Build binutils, GCC, newlib and GDB
echo "Building tools" >> "${logfile}"
echo "==============" >> "${logfile}"
echo "Building tools..."
make $make_load all-build all-binutils all-gas all-ld all-gcc \
    all-target-libgcc all-target-libgloss all-target-newlib \
    all-target-libstdc++-v3 all-gdb all-sim >> "${logfile}" 2>&1
if [ $? != 0 ]; then
  echo "Error: Build failed."
  failedbuild
  exit 1
fi

# Install binutils, GCC, newlib and GDB
echo "Installing tools" >> "${logfile}"
echo "================" >> "${logfile}"
echo "Installing tools..."
make install-binutils install-gas install-ld install-gcc \
    install-target-libgcc install-target-libgloss install-target-newlib \
    install-target-libstdc++-v3 install-gdb install-sim >> "${logfile}" 2>&1
if [ $? != 0 ]; then
  echo "Error: Install failed."
  failedbuild
  exit 1
fi

# Create symbolic links in install directory for e-gcc, etc.
cd "${install_dir}/bin"
for i in epiphany-elf-*; do
  ENAME=$(echo $i | sed 's/epiphany-elf-/e-/')
  if ! [ -e $ENAME ]; then ln -s $i $ENAME; fi
done
cd "${install_dir}/share/man/man1"
for i in epiphany-elf-*; do
  ENAME=$(echo $i | sed 's/epiphany-elf-/e-/')
  if ! [ -e $ENAME ]; then ln -s $i $ENAME; fi
done

echo "BUILD COMPLETE: $(date)" >> "${logfile}"
echo "Build Complete at $(date)"
echo " **************************************************"
echo " The build is complete."
echo " The tools have been installed at: ${install_dir}/bin"
echo " Please ensure that this directory is in your PATH."
echo " **************************************************"
