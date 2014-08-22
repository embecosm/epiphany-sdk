#!/bin/sh

# Copyright (C) 2013,2014 Embecosm Limited

# Contributor Simon Cook <simon.cook@embecosm.com>

# This file is a script to download toolchain source.

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

# Usage:

# ./download-toolchain [--force | --no-force]
#                      [--clone | --download]
#                      [--infra_url <url> | --infra-us |
#                       --infra-uk | --infra-jp]
#                      [--gmp | --no-gmp]
#                      [--mpfr | --no-mpfr]
#                      [--mpc | --no-mpc]
#                      [--isl | --no-isl]
#                      [--cloog | --no-cloog]
#                      [--help | -h]

# --force | --no-force

#     If --force is specified, attempt to remove the existing repository
#     before cloning or downloading. If the removal fails, the old version
#     will be used, but a warning printed.  Default --no-force.

# --clone | --download

#     If --clone is specified, attempt to clone the repository, otherwise if
#     --download is specified, attempt to download a ZIP file of the
#     repository.  Default --download.

# --infra_url <url>

#     Set the URL of the GCC infrastructure downloads. Default
#     http://www.netgull.com/gcc/infrastructure.

# --infra-us
# --infra-uk
# --infra-jp

#     Synonyms respectively for infrastructure URLs in the USA, UK and Japan

# --gmp | --no-gmp
# --mpfr | --no-mpfr
# --mpc | --no-mpc
# --isl | --no-isl
# --cloog | --no-cloog

#     Download, or (with the --no- prefix) don't download the corresponding GCC
#     infrastructure component. The components are downloaded from the
#     infrastructure URL, which may be changed by the --infra_url option. By
#     default all components are downloaded.

# --help | -h

#     Print out a brief help about this script and return with an error code.

# Note that earlier versions allowed specification of a location where the
# tools were to be downloaded. However recent versions do not download the SDK
# directory, so the script will only work if downloading is done in a fixed
# location relative to the pre-existing SDK directory (which contains this
# script).

# The script returns 1 on failure and 0 on success. Failure to delete a
# pre-existing version when specifying --force is not considered a failure.


################################################################################
#                                                                              #
#			       Shell functions                                 #
#                                                                              #
################################################################################

# Function to clone a git repository, checking out the relevant branch.

# The cloned repository will name its remote "adapteva".

# @param[in] $1  The tool to clone
# @param[in] $2  The full repository URL
# @param[in] $3  The branch to checkout

# @return 0 on success, 1 on failure. Note that failure to remove components
#         when --force is in action is not considered a failure.
clone_tool() {
    tool=$1
    repo_url=$2
    branch=$3

    # If old source exists, delete
    if [ ${force} = "true" ]
    then
	if ! rm -rf ${tool} >> ${log} 2>&1
	then
	    echo "Warning: Unable to delete old ${tool}" | tee -a ${log}
	fi
    fi

    # Clone git repository if it does not already exist
    if [ -e ${tool} ]
    then
	echo "${tool} already clone." | tee -a ${log}
    else
	echo "Cloning ${tool}..."
	if ! git clone -q -o adapteva -b ${branch} ${repo_url} ${tool} \
	         >> ${log} 2>&1
	then
	    echo "ERROR: Unable to clone ${tool}" | tee -a ${log}
	    return 1
	fi
    fi
}

# Function to download a specific tool branch or version

# @param[in] $1  The tool to download
# @param[in] $2  URL of archive directory
# @param[in] $3  Command to unpack the download
# @parma[in] $4  Branch or version packed file (i.e. with suffix such as .zip)
# @parma[in] $5  Unpacked main directory

# @return 0 on success, 1 on failure. Note that failure to remove components
#         when --force is in action is not considered a failure.
download_tool() {
    tool=$1
    archive_url=$2
    unpack_cmd=$3
    branch=$4
    unpacked_dir=$5

    # If --force is in action and old source exists, attempt delete
    if [ ${force} = "true" ]
    then
	if ! rm -rf ${tool} ${branch} >> ${log} 2>&1
	then
	    echo "Warning: Unable to delete old ${tool}" | tee -a ${log}
	fi
    fi

    # Download and unzip source if it does not already exist
    if [ -e ${tool} ]
    then
	echo "Skipping ${tool}, already exists..." | tee -a ${log}
    else
	echo "Downloading ${tool}..."
	if ! wget ${archive_url}/${branch} \
	    >> ${log} 2>&1
	then
	    echo "ERROR: Unable to download ${tool}" | tee -a ${log}
	    return 1
	fi
	if ! ${unpack_cmd} ${branch} >> ${log} 2>&1
	then
	    echo "ERROR: Unable to unpack ${tool}" | tee -a ${log}
	    return 1
	fi
	# Only move if the unpacked_dir is different to the tool
	if [ "x${unpacked_dir}" != "x${tool}" ]
	then
	    if ! mv ${unpacked_dir} ${tool} >> ${log} 2>&1
	    then
		echo "ERROR: Unable to move unpacked dir to ${tool}" \
		    | tee -a ${log}
		return 1
	    fi
	fi
	if ! rm ${branch} >> ${log} 2>&1
	then
	    echo "ERROR: Unable to remove packed file for ${tool}" \
		| tee -a ${log}
	    return 1
	fi
    fi
}

# Function to either download a tool or clone a git repository from GitHub,
# checking out the relevant branch.

# @param[in] $1 The tool to clone (will appear as a subdirectory of ${topdir}.
# @param[in] $2 The GitHub repo (within the adapteva organization) to
#               clone/download.
# @param[in] $3 The branch to checkout/download.

# @return  The result of the underlying call to clone or download a tool.
github_tool () {
    tool=$1
    repo=$2
    branch=$3

    if [ ${clone} = "true" ]
    then
	clone_tool "${tool}" "git://github.com/adapteva/${repo}" "${branch}"
    else
	download_tool "${tool}" "https://github.com/adapteva/${repo}/archive" \
	              "unzip" "${branch}.zip" "${repo}-${branch}"
    fi
}


# Function to download a GCC component

# @param[in] $1 Component name
# @param[in] $2 File name with version
# @param[in] $3 Compressed file suffix

# @return  The result of the underlying call to download a tool.
gcc_component () {
    tool=$1
    file=$2
    packed_name=${file}.$3

    download_tool "${tool}" "${infra_url}" "tar xf" "${packed_name}" "${file}"
}


# Function to check for relative directory and makes it absolute

# @param[in] $1  The directory to make absolute if necessary.
absolutedir() {
    case ${1} in

	/*)
	    echo "${1}"
	    ;;

	*)
	    echo "${PWD}/${1}"
	    ;;
    esac
}


################################################################################
#                                                                              #
#			       Parse arguments                                 #
#                                                                              #
################################################################################

force="false"
clone="false"
infra_url="http://mirrors-uk.go-parts.com/gcc/infrastructure"
do_gmp="true"
do_mpfr="true"
do_mpc="true"
do_isl="true"
do_cloog="true"

until
opt=$1
case ${opt} in

    --force)
	force="true"
	;;

    --no-force)
	force="false"
	;;

    --clone)
	clone="true"
	;;

    --download)
	clone="false"
	;;

    --infra_url)
	shift
	infra_url="$1"
	;;

    --infra-us)
	infra_url="http://www.netgull.com/gcc/infrastructure"
	;;

    --infra-uk)
	infra_url="http://mirrors-uk.go-parts.com/gcc/infrastructure"
	;;

    --infra-jp)
	infra_url="http://ftp.tsukuba.wide.ad.jp/software/gcc/infrastructure"
	;;

    --gmp)
	do_gmp="true"
	;;

    --no-gmp)
	do_gmp="false"
	;;

    --mpfr)
	do_mpfr="true"
	;;

    --no-mpfr)
	do_mpfr="false"
	;;

    --mpc)
	do_mpc="true"
	;;

    --no-mpc)
	do_mpc="false"
	;;

    --isl)
	do_isl="true"
	;;

    --no-isl)
	do_isl="false"
	;;

    --cloog)
	do_cloog="true"
	;;

    --no-cloog)
	do_cloog="false"
	;;

    ?*)
	echo "Usage: ./download-toolchain [--force | --no-force]"
	echo "                            [--clone | --download]"
	echo "                            [--infra_url <url> | --infra-us |"
	echo "                             --infra-uk | --infra-jp]"
	echo "                            [--gmp | --no-gmp]"
	echo "                            [--mpfr | --no-mpfr]"
	echo "                            [--mpc | --no-mpc]"
	echo "                            [--isl | --no-isl]"
	echo "                            [--cloog | --no-cloog]"
	echo "                            [--help | -h]"
	exit 1
	;;

    *)
	;;
esac
[ "x${opt}" = "x" ]
do
    shift
done

################################################################################
#                                                                              #
#			     Download everything                               #
#                                                                              #
################################################################################

# Move to basedir location

d=`dirname "$0"`
basedir=`(cd "$d/.." && pwd)`
if ! cd "${basedir}"
then
    echo "ERROR: Unable to change to base directory for downloads/clones"
    exit 1
fi

# Set the release parameters
. ${basedir}/sdk/define-release.sh

# Set up a log file
log="${LOGDIR}/clone-$(date -u +%F-%H%M).log"
rm -f "${log}"

echo "Logging to ${log}"

# Clone repositories from GitHub
res="ok"
github_tool gcc      epiphany-gcc      epiphany-gcc-4.8       || res="failed"
github_tool binutils epiphany-binutils epiphany-binutils-2.23 || res="failed"
github_tool gdb      epiphany-gdb      epiphany-gdb-7.6       || res="failed"
github_tool newlib   epiphany-newlib   epiphany-newlib-1.20   || res="failed"
github_tool cgen     epiphany-cgen     epiphany-cgen-1.1      || res="failed"

# Download optional GCC components
if [ "${do_gmp}" = "true" ]
then
    gcc_component "gmp" "gmp-4.3.2" "tar.bz2" || res="failed"
fi

if [ "${do_mpfr}" = "true" ]
then
    gcc_component "mpfr" "mpfr-2.4.2" "tar.bz2" || res="failed"
fi

if [ "${do_mpc}" = "true" ]
then
    gcc_component "mpc" "mpc-0.8.1" "tar.gz" || res="failed"
fi

if [ "${do_isl}" = "true" ]
then
    gcc_component "isl" "isl-0.12.2" "tar.bz2" || res="failed"
fi

if [ "${do_cloog}" = "true" ]
then
    gcc_component "cloog" "cloog-0.18.1" "tar.gz" || res="failed"
fi

if [ "${res}" = "ok" ]
then
    echo "Download complete"
else
    echo "Download incomplete - see log for failures"
fi
