Epiphany/Parallella GNU Tool Chain
==================================

This directory contains the sources and build scripts required to compile and
test the Epiphany/Parallela GNU tool chain.

Prerequisites
-------------

To build the tool chain, you will need a Linux like environment (Cygwin/MinGW
running under Windows should also work). This includes the standard GNU tool
chain prerequisites as can be found on http://gcc.gnu.org/install/prerequisites.html

Under a standard Ubuntu Desktop install, the required prerequisites can be
installed via:

    sudo apt-get install bison flex libgmp-dev libncurses-dev libmpc-dev \
    libmpfr-dev texinfo

Under a standard Fedora Desktop install, the required prerequisites can be
installed via:

    sudo yum install bison flex gcc gmp-devel libmpc-devel ncurses-devel \
    mpfr-devel texinfo

In addition, you will need to clone the repositories for each tool chain
component (there are three repositories, not just one). These should be
peers of this toolchain directory. If you have yet to clone this directory
then the following commands are appropriate for creating a new directory
with all the components in the correct location.

    mkdir parallella
    cd parallella
    git clone git://github.com/parallella/gcc.git
    git clone git://github.com/parallella/src.git
    git clone git://github.com/parallella/toolchain.git
    cd toolchain


Building the tool chain
-----------------------

The `build-toolchain.sh` script will build and install the tool chain to an
`INSTALL` directory.

The script accepts an `--install-dir` parameter to change the location
where the tool chain will be installed.

Similarly, `--build-dir` and `--unified-dir` specify where the tool chain's
build and unified source directories go (to for example, place these in /tmp).

`--force` removes any previous build and unified source directories.

Details on these parameters can be found in the comments at the head of the
`build-toolchain.sh` script.
