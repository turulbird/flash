#!/bin/bash
#echo "-----------------------------------------------------------------------"
#echo "This script creates the flash tools programs needed for creating flash"
#echo "file(s), in case they are missing."
#echo
#echo "Author: Audioniek, based on previous work by schishu and bpanther"
#echo "Date: 07-02-2014"
#echo
#
# 20180729 Audioniek - Use Archive directory for source code retrieved from
#                      the internet; squashfs4.0 replaced by squashfs4.2.
# 20180829 Audioniek - Added mksquashfs3.0 as this version is needed by first
#                      generation Fortis receivers.
# 20190207 Audioniek - Added mkdnimg.
# 20200716 Audioniek - Fix URL for squashfs4.2.tar.gz download.
# 20210820 Audioniek - Add mkdnimg program.
# 20210825 Audioniek - Add oup program.
#
ARCHIVE=~/Archive
TOOLSDIR=$1
cd $TOOLSDIR
BASEDIR=`cd .. && pwd`

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
  if [ -d ./squashfs3.0 ]; then
    rm -rf ./squashfs3.0
  fi
  if [ ! -e $ARCHIVE/squashfs3.0.tar.gz ]; then
    wget "http://pkgs.fedoraproject.org/repo/pkgs/squashfs-tools/squashfs3.0.tar.gz/9fd05d0bfbb712f5fb95edafea5bc733/squashfs3.0.tar.gz" -P $ARCHIVE
  fi
  tar -C $TOOLSDIR/mksquash.src -xzf $ARCHIVE/squashfs3.0.tar.gz 
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
  if [ -d ./squashfs3.3 ]; then
    rm -rf ./squashfs3.3
  fi
  if [ ! -e $ARCHIVE/squashfs3.3.tar.gz ]; then
    wget "https://sourceforge.net/projects/squashfs/files/OldFiles/squashfs3.3.tar.gz" -P $ARCHIVE
  fi
  tar -C $TOOLSDIR/mksquash.src -xzf $ARCHIVE/squashfs3.3.tar.gz
  cd $TOOLSDIR/mksquash.src/squashfs3.3/squashfs-tools
  make all
  mv $TOOLSDIR/mksquash.src/squashfs3.3/squashfs-tools/mksquashfs $TOOLSDIR/mksquashfs3.3
  mv $TOOLSDIR/mksquash.src/squashfs3.3/squashfs-tools/unsquashfs $TOOLSDIR/unsquashfs3.3
  cd $TOOLSDIR
  rm -rf $TOOLSDIR/mksquash.src/squashfs3.3
  if [ ! -e $TOOLSDIR/mksquashfs3.3 ]; then
    echo " Compiling mksquashfs3.3 failed! Exiting..."
    exit 3
  else
    clear
    echo "-----------------------------------------------------------------------"
    echo " Compiling mksquashfs3.3 successfully completed."
  fi
fi

# Tool program mksquashfs4.2..."
if [ ! -e $TOOLSDIR/mksquashfs4.2 ]; then
  echo "-----------------------------------------------------------------------"
  echo " Tool program mksquashfs4.2 is missing, trying to compile it..."
  echo "-----------------------------------------------------------------------"
  echo
  cd $TOOLSDIR/mksquash.src
  if [ -d ./squashfs4.2 ]; then
    rm -rf ./squashfs4.2
  fi
  if [ ! -e $ARCHIVE/squashfs4.2.tar.gz ]; then
     wget "http://sourceforge.net/projects/squashfs/files/squashfs/squashfs4.2/squashfs4.2.tar.gz" -P $ARCHIVE
  fi
  if [ ! -e $ARCHIVE/lzma-4.65.tar.bz2 ]; then
    wget "http://downloads.openwrt.org/sources/lzma-4.65.tar.bz2" -P $ARCHIVE
  fi
  tar -C $TOOLSDIR/mksquash.src -xzf $ARCHIVE/squashfs4.2.tar.gz
  tar -C $TOOLSDIR/mksquash.src -xjf $ARCHIVE/lzma-4.65.tar.bz2
  cd ./squashfs4.2/squashfs-tools
#  if [ -e $BASEDIR/patches/squashfs-tools-4.0-lzma.patch ]; then
#    echo "patch -p1 < $BASEDIR/patches/squashfs-tools-4.0-lzma.patch"
#    patch -p1 < $BASEDIR/patches/squashfs-tools-4.0-lzma.patch > /dev/null
#  fi
  make LZMA_SUPPORT=1 LZMA_DIR=../../lzma-4.65 XATTR_SUPPORT=0 XATTR_DEFAULT=0 install
  mv ./mksquashfs $TOOLSDIR/mksquashfs4.2
  mv ./unsquashfs $TOOLSDIR/unsquashfs4.2
  cd $TOOLSDIR
  rm -rf ./mksquash.src/squashfs4.2
  rm -rf ./mksquash.src/lzma-4.65
  if [ ! -e $TOOLSDIR/mksquashfs4.2 ]; then
    echo " Compiling mksquashfs4.2 failed! Exiting..."
    exit 3
  else
    clear
    echo "-----------------------------------------------------------------------"
    echo " Compiling mksquashfs4.2 successfully completed."
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
  if [ ! -e $ARCHIVE/cramfs-1.1.tar.gz ]; then
    wget "http://downloads.sourceforge.net/project/cramfs/cramfs/1.1/cramfs-1.1.tar.gz" -P $ARCHIVE
  fi
  tar -xzf $ARCHIVE/cramfs-1.1.tar.gz
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
  $TOOLSDIR/fup.src/compile.sh
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

# Tool program oup..."
if [ ! -e $TOOLSDIR/oup ]; then
  echo "-----------------------------------------------------------------------"
  echo " Tool program oup is missing, trying to compile it..."
  echo "-----------------------------------------------------------------------"
  echo
  cd $TOOLSDIR/oup.src
  $TOOLSDIR/oup.src/compile.sh
  mv $TOOLSDIR/oup.src/oup $TOOLSDIR/oup
  cd $TOOLSDIR
  if [ ! -e $TOOLSDIR/oup ]; then
    echo " Compiling oup failed! Exiting..."
    exit 3
  else
    clear
    echo "-----------------------------------------------------------------------"
    echo " Compiling oup successful."
  fi
fi

# Tool program mkdnimg..."
if [ ! -e $TOOLSDIR/mkdnimg ]; then
  echo "-----------------------------------------------------------------------"
  echo " Tool program mkdnimg is missing, trying to compile it..."
  echo "-----------------------------------------------------------------------"
  echo
  cd $TOOLSDIR/mkdnimg.src
  $TOOLSDIR/mkdnimg.src/compile.sh
  mv $TOOLSDIR/mkdnimg.src/mkdnimg $TOOLSDIR/mkdnimg
  cd $TOOLSDIR
  if [ ! -e $TOOLSDIR/mkdnimg ]; then
    echo " Compiling mkdnimg failed! Exiting..."
    exit 3
  else
    clear
    echo "-----------------------------------------------------------------------"
    echo " Compiling mkdnimg successful."
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

