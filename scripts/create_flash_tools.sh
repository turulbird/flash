#!/bin/bash
#echo "-----------------------------------------------------------------------"
#echo "This script creates the flash tools programs needed for creating flash"
#echo "file(s), in case they are missing."
#echo
#echo "Author: Audioniek, based on previous work by schishu and bpanther"
#echo "Date: 07-02-2014"
#echo
#
# 20140829 Audioniek - Added mksquashfs3.0 as this version is needed by first
#                      generation Fortis receivers.

TOOLSDIR=$1
cd $TOOLSDIR
BASEDIR=`cd ../.. && pwd`

# Tool program pad..."
if [ ! -e $TOOLSDIR/pad ]; then
  clear
  echo "-------------------------------------------------------------------------------"
  echo " Tool program pad is missing, trying to compile it..."
  echo "-------------------------------------------------------------------------------"
  echo
  cd $TOOLSDIR/pad.src
  $TOOLSDIR/pad.src/compile.sh
  mv $TOOLSDIR/pad.src/pad $TOOLSDIR/pad
  cd $TOOLSDIR
  if [ ! -e $TOOLSDIR/pad ]; then
    echo " Compiling pad failed! Exiting..."
  echo "-------------------------------------------------------------------------------"
    exit 3
  else
    clear
    echo "-------------------------------------------------------------------------------"
    echo " Compiling pad successfully completed."
  fi
fi

# Tool program mksquashfs3.0..."
if [ ! -e $TOOLSDIR/mksquashfs3.0 ]; then
  echo "-----------------------------------------------------------------------"
  echo " Tool program mksquashfs3.0 is missing, trying to compile it..."
  echo "-----------------------------------------------------------------------"
  echo
  cd $TOOLSDIR/mksquash.src
  if [ ! -d ./squashfs3.0 ]; then
    rm -rf ./squashfs3.0
  fi
  if [ ! -e ./squashfs3.0.tar.gz ]; then
    wget "http://pkgs.fedoraproject.org/repo/pkgs/squashfs-tools/squashfs3.0.tar.gz/9fd05d0bfbb712f5fb95edafea5bc733/squashfs3.0.tar.gz"
  fi
  tar -xzf $TOOLSDIR/mksquash.src/squashfs3.0.tar.gz
  cd $TOOLSDIR/mksquash.src/squashfs3.0/squashfs-tools
  make
  mv $TOOLSDIR/mksquash.src/squashfs3.0/squashfs-tools/mksquashfs $TOOLSDIR/mksquashfs3.0
  mv $TOOLSDIR/mksquash.src/squashfs3.0/squashfs-tools/unsquashfs $TOOLSDIR/unsquashfs3.0
  cd $TOOLSDIR
  rm -rf $TOOLSDIR/mksquash.src/squashfs3.0
  if [ ! -e $TOOLSDIR/mksquashfs3.0 ]; then
    echo " Compiling mksquashfs3.0 failed! Exiting..."
    exit 3
  else
    clear
    echo "-----------------------------------------------------------------------"
    echo " Compiling mksquashfs3.0 successfully completed."
  fi
fi

# Tool program mksquashfs3.3..."
if [ ! -e $TOOLSDIR/mksquashfs3.3 ]; then
  echo "-----------------------------------------------------------------------"
  echo " Tool program mksquashfs3.3 is missing, trying to compile it..."
  echo "-----------------------------------------------------------------------"
  echo
  cd $TOOLSDIR/mksquash.src
  if [ ! -d ./squashfs-tools ]; then
    rm -rf ./squashfs-tools
  fi
  tar -xzf $TOOLSDIR/mksquash.src/squashfs3.3.tar.gz
  cd $TOOLSDIR/mksquash.src/squashfs-tools
  make all
  mv $TOOLSDIR/mksquash.src/squashfs-tools/mksquashfs $TOOLSDIR/mksquashfs3.3
  mv $TOOLSDIR/mksquash.src/squashfs-tools/unsquashfs $TOOLSDIR/unsquashfs3.3
  cd $TOOLSDIR
  rm -rf $TOOLSDIR/mksquash.src/squashfs-tools
  if [ ! -e $TOOLSDIR/mksquashfs3.3 ]; then
    echo " Compiling mksquashfs3.3 failed! Exiting..."
    exit 3
  else
    clear
    echo "-----------------------------------------------------------------------"
    echo " Compiling mksquashfs3.3 successfully completed."
  fi
fi

# Tool program mksquashfs4.0..."
if [ ! -e $TOOLSDIR/mksquashfs4.0 ]; then
  echo "-----------------------------------------------------------------------"
  echo " Tool program mksquashfs4.0 is missing, trying to compile it..."
  echo "-----------------------------------------------------------------------"
  echo
  cd $TOOLSDIR/mksquash.src
  if [ ! -d ./squashfs4.0 ]; then
    rm -rf ./squashfs4.0
  fi
  if [ ! -e ./squashfs4.0.tar.gz ]; then
    #wget "http://heanet.dl.sourceforge.net/sourceforge/squashfs/squashfs4.0.tar.gz"
    wget "http://pkgs.fedoraproject.org/repo/pkgs/squashfs-tools/squashfs4.0.tar.gz/a3c23391da4ebab0ac4a75021ddabf96/squashfs4.0.tar.gz"
  fi
  if [ ! -e ./lzma465.tar.bz2 ]; then
    #wget "http://heanet.dl.sourceforge.net/sourceforge/sevenzip/lzma465.tar.bz2"
    wget "http://pkgs.fedoraproject.org/repo/pkgs/SevenZip/lzma465.tar.bz2/29d5ffd03a5a3e51aef6a74e9eafb759/lzma465.tar.bz2"
  fi
  if [ ! -d ./squashfs-tools ]; then
    mkdir ./squashfs-tools
  fi
  cd ./squashfs-tools
  tar -xzf $TOOLSDIR/mksquash.src/squashfs4.0.tar.gz
  tar -xjf $TOOLSDIR/mksquash.src/lzma465.tar.bz2
  cd ./squashfs4.0/squashfs-tools
  if [ -e $BASEDIR/cdk/Patches/squashfs-tools-4.0-lzma.patch ]; then
    echo "patch -p1 < $BASEDIR/cdk/Patches/squashfs-tools-4.0-lzma.patch"
    patch -p1 < $BASEDIR/cdk/Patches/squashfs-tools-4.0-lzma.patch > /dev/null
  fi
  make all
  mv ./mksquashfs $TOOLSDIR/mksquashfs4.0
  mv ./unsquashfs $TOOLSDIR/unsquashfs4.0
  cd $TOOLSDIR
  rm -rf ./mksquash.src/squashfs-tools
  if [ ! -e $TOOLSDIR/mksquashfs4.0 ]; then
    echo " Compiling mksquashfs4.0 failed! Exiting..."
    exit 3
  else
    clear
    echo "-----------------------------------------------------------------------"
    echo " Compiling mksquashfs4.0 successfully completed."
  fi
fi

# Tool program mkcramfs-1.1..."
if [ ! -e $TOOLSDIR/mkcramfs1.1 ]; then
  echo "-----------------------------------------------------------------------"
  echo " Tool program mkcramfs-1.1 is missing, trying to compile it..."
  echo "-----------------------------------------------------------------------"
  echo
  cd $TOOLSDIR
  if [ -d $TOOLSDIR/cramfs.src/cramfs.src ]; then
    rm -rf $TOOLSDIR/cramfs.src/cramfs.src
  fi
  cd ./cramfs.src
  if [ ! -e ./cramfs-1.1.tar.gz ]; then
    wget "http://downloads.sourceforge.net/project/cramfs/cramfs/1.1/cramfs-1.1.tar.gz"
  fi
  tar -xzf ./cramfs-1.1.tar.gz
  cd ./cramfs-1.1
  make all
  mv ./mkcramfs $TOOLSDIR/mkcramfs1.1
  cd $TOOLSDIR
  rm -rf $TOOLSDIR/cramfs.src/cramfs-1.1
  if [ ! -e $TOOLSDIR/mkcramfs1.1 ]; then
    echo " Compiling mkcramfs-1.1 failed! Exiting..."
    exit 3
  else
    clear
    echo "-----------------------------------------------------------------------"
    echo " Compiling mkcramfs-1.1 successfully completed."
  fi
fi

# Tool program fup..."
if [ ! -e $TOOLSDIR/fup ]; then
  echo "-----------------------------------------------------------------------"
  echo " Tool program fup is missing, trying to compile it..."
  echo "-----------------------------------------------------------------------"
  echo
  cd $TOOLSDIR/fup.src
  $TOOLSDIR/fup.src/compile.sh USE_ZLIB
  mv $TOOLSDIR/fup.src/fup $TOOLSDIR/fup
  cd $TOOLSDIR
  if [ ! -e $TOOLSDIR/fup ]; then
    echo " Compiling fup failed! Exiting..."
    echo " If the error is \"cannot find -lz\" then you"
    echo " need to install the 32bit version of libz."
    exit 3
  else
    clear
    echo "-----------------------------------------------------------------------"
    echo " Compiling fup successful."
  fi
fi

# Tool program mup..."
if [ ! -e $TOOLSDIR/mup ]; then
  echo "-----------------------------------------------------------------------"
  echo " Tool program mup is missing, trying to compile it..."
  echo "-----------------------------------------------------------------------"
  echo
  cd $TOOLSDIR/mup.src
  $TOOLSDIR/mup.src/compile.sh
  mv $TOOLSDIR/mup.src/mup $TOOLSDIR/mup
  cd $TOOLSDIR
  if [ ! -e $TOOLSDIR/mup ]; then
    echo " Compiling mup failed! Exiting..."
    exit 3
  else
    clear
    echo "-----------------------------------------------------------------------"
    echo " Compiling mup successful."
  fi
fi

# Tool programs for ubifs..."
#if [ ! -e $TOOLSDIR/mkfs.ubifs1.5.0 ] || [ ! -e $TOOLSDIR/ubinize1.5.0 ]; then
#  echo "-----------------------------------------------------------------------"
#  echo " UBI tool programs ubinize and/or mkfs.ubifs are missing,"
#  echo " trying to compile them..."
#  echo "-----------------------------------------------------------------------"
#  echo
#  cd $TOOLSDIR
#  if [ ! -d ./mtd-utils.src ]; then
#    mkdir ./mtd-utils.src
#  fi
#  cd ./mtd-utils.src
#  if [ ! -e $TOOLSDIR/mtd-utils.src/mtd-utils-1.5.0.tar.bz2 ]; then
#    wget "ftp://ftp.infradead.org/pub/mtd-utils/mtd-utils-1.5.0.tar.bz2"
#  fi
#  tar -xvjf $TOOLSDIR/mtd-utils.src/mtd-utils-1.5.0.tar.bz2 > /dev/null
#  cd ./mtd-utils-1.5.0
#  make
#  mv ./mkfs.ubifs/mkfs.ubifs $TOOLSDIR/mkfs.ubifs1.5.0
#  mv ./ubi-utils/ubinize $TOOLSDIR/ubinize1.5.0
#  cd $TOOLSDIR
#  rm -rf $TOOLSDIR//mtd-utils.src/mtd-utils-1.5.0
#  if [ ! -e $TOOLSDIR/mkfs.ubifs1.5.0 ] || [ ! -e $TOOLSDIR/ubinize1.5.0 ]; then
#    echo " Compiling UBI tool programs failed! Exiting..."
#    exit 3
#  else
#    clear
#    echo "-----------------------------------------------------------------------"
#    echo " Compiling UBI tools ubinize and mkfs.ubifs successfully completed."
#  fi
#fi

