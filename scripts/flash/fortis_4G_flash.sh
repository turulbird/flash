#!/bin/bash
# -----------------------------------------------------------------------
#  This script creates flashable images for these Fortis receivers:
#  - DP2010
#  - DP7000
#  - DP7001
#  - DP7050 -> TODO: add reduced memory sizes
#  - EP8000
#  - EPP8000
#  - FX6010
#  - GPV8000
#  with unmodified factory bootloader:
#  8.14, 8.15 or 4.00 (DP2010),
#  8.14, 8.15 or 4.00 (DP7000, NOT tested),
#  8.05 or 1.00 (DP7001),
#  8.25 or 3.00 (DP7050, NOT tested),
#  8.35, 8.37 or 2.00 (EP8000 and EPP8000) or
#  8.05 or 1.00 (FX6010),
#  8.14, 8.15 or 4.00 (GPV8000, NOT tested)
#  or with modified factory bootloader:
#  4.01 (DP2010),
#  4.01 (DP7000, NOT tested),
#  1.01 (DP7001),
#  3.01 (DP7050, NOT tested),
#  2.01 (EP8000 and EPP8000) or
#  1.01 (FX6010),
#  4.01 (GPV8000, NOT tested)
#
# Author: Schischu/Audioniek
# Date: 08-06-2022
#
# ---------------------------------------------------------------------------
# Changes:
# 20140726 Audioniek   Initial version for DP6010, DP7000, DP7001 & EPP8000
# 20191208 Audioniek   DP2010 added.
# 20200116 Audioniek   USB capable boot loader versions added.
# 20200609 Audioniek   dp6010 -> fx6010.
# 20200812 Audioniek   Automatic adding of boot picture added.
# 20200916 Audioniek   Fix automatic adding of boot picture.
# 20220806 Audioniek   Indicate default choice differently.
#
# -----------------------------------------------------------------------"
# It is assumed that an image was already built prior to executing this"
# script!"
# -----------------------------------------------------------------------"
#

if [ "$BATCH_MODE" == "yes" ]; then
  IMAGE=
else
  echo "-- Output selection ---------------------------------------------------"
  echo
  echo " What would you like to flash?"
  echo "   1*) The $IMAGE image plus kernel"
  echo "   2)  Only the kernel"
  echo "   3)  Only the $IMAGE image"
  read -p " Select flash target (1-3)? "
  case "$REPLY" in
#    1) echo > /dev/null;;
    2) IMAGE="kernel";;
    3) IMAGE="image";;
#    *) echo > /dev/null;;
  esac
  echo "-----------------------------------------------------------------------"
  echo
fi

# Set up the variables
MKFSUBIFS=$TUFSBOXDIR/host/bin/mkfs.ubifs
UBINIZE=$TUFSBOXDIR/host/bin/ubinize
FUP=$TOOLSDIR/fup

OUTFILE="$BOXTYPE"_"$INAME""$IMAGE"_flash_R$RESELLERID.ird
OUTZIPFILE="$HOST"_"$INAME""$IMAGE"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

if [ ! "$IMAGE" == "image" ]; then
  echo -n " - Preparing kernel file..."
  cp $TMPKERNELDIR/uImage $TMPDIR/uImage
  echo " done."

  echo -n " - Checking kernel size..."
  SIZEK=`stat $TMPDIR/uImage -t --format %s`
  SIZEKD=`printf "%d" $SIZEK`
  SIZEKH=`printf "%08X" $SIZEK`
  if [ "$SIZEKD" -gt "4194304" ]; then
    echo
    echo -e "\033[01;31m"
    echo "-- ERROR! -------------------------------------------------------------"
    echo
    echo " KERNEL TOO BIG: 0x$SIZEKH instead of max. 0x00400000 bytes." > /dev/stderr
    echo " Exiting..."
    echo
    echo "-----------------------------------------------------------------------"
    echo -e "\033[00m"
    exit
  else
    echo " OK: $SIZEKD (0x$SIZEKH, max. 0x00400000) bytes."
  fi
fi

if [ ! "$IMAGE" == "kernel" ]; then
  echo -n " - Preparing UBIFS root file system..."
  # Logical erase block size is physical erase block size (131072) minus -m parameter => -e 129024
  # Number of erase blocks is partition size / physical eraseblock size: 182Mib / 131072 => -c 1456
  # Fortis bootloader expects a zlib compressed ubifs => -x zlib
  $MKFSUBIFS -d $TMPROOTDIR -m 2048 -e 129024 -c 1456 -x zlib -U -o $TMPDIR/mtd_root.ubi 2> /dev/null
  echo " done."

  echo -n " - Creating ubinize ini file..."
  # Create ubi.ini
  echo "[ubi-rootfs]" > $TMPDIR/ubi.ini
  echo "mode=ubi" >> $TMPDIR/ubi.ini
  echo "image=$TMPDIR/mtd_root.ubi" >> $TMPDIR/ubi.ini
  echo "vol_id=0" >> $TMPDIR/ubi.ini
  # UBI needs a few free erase blocks for bad PEB handling, say 64, so:
  # Net available for data: (1456-64) x 129024 = 179601408 bytes
  echo "vol_size=179601408" >> $TMPDIR/ubi.ini
  echo "vol_type=dynamic" >> $TMPDIR/ubi.ini
  # Fortis bootloader requires the volume label rootfs
  echo "vol_name=rootfs" >> $TMPDIR/ubi.ini
  # Allow UBI to dynamically resize the volume
  echo "vol_flags=autoresize" >> $TMPDIR/ubi.ini
  echo "vol_alignment=1" >> $TMPDIR/ubi.ini
  echo " done."

  echo -n " - Creating UBI root image..."
  # UBInize the UBI partition of the rootfs
  # Physical eraseblock size is 131072 => -p 128KiB
  # Subpage size is 512 bytes => -s 512
  $UBINIZE -o $TMPDIR/mtd_root.ubin -p 128KiB -m 2048 -s 512 -x 1 $TMPDIR/ubi.ini 2> /dev/null
  echo " done."

  echo -n " - Checking root size..."
  SIZE=`stat $TMPDIR/mtd_root.ubin -t --format %s`
  SIZEH=`printf "%08X" $SIZE`
  SIZED=`printf "%d" $SIZE`
  if [ "$SIZED" -gt "179601408" ]; then  echo -e "\033[01;31m"
    echo
    echo -e "\033[01;31m"
    echo "-- ERROR! -------------------------------------------------------------"
    echo
    echo " ROOT TOO BIG: 0x$SIZEH instead of max. 0x0AB480000 bytes." > /dev/stderr
    echo " Exiting..."
    echo
    echo "-----------------------------------------------------------------------"
    echo -e "\033[00m"
    exit
  else
    echo " OK: $SIZED (0x$SIZEH, max. 0x0AB480000) bytes."
  fi
fi

# Create command line arguments for fup
if [ "$IMAGE" == "kernel" ]; then
  FUPARGS="-c $OUTDIR/$OUTFILE -6 $TMPDIR/uImage"
elif [ "$IMAGE" == "image" ]; then
  FUPARGS="-c $OUTDIR/$OUTFILE -1 $TMPDIR/mtd_root.ubin"
else
  FUPARGS="-c $OUTDIR/$OUTFILE -6 $TMPDIR/uImage -1 $TMPDIR/mtd_root.ubin"
fi

# Check if a bootscreen picture for the bootloader exists
if [ -e $CURDIR/../root/bootscreen/bootscreen.gz ]; then
  echo " - Bootscreen picture for the loader found, adding it."
  FUPARGS=$FUPARGS" -9 $CURDIR/../root/bootscreen/bootscreen.gz"
fi

echo -n " - Creating .IRD flash file and MD5..."
cd $TOOLSDIR
$FUP $FUPARGS

# Set reseller ID
$FUP -r $OUTDIR/$OUTFILE $RESELLERID
cd $CURDIR
# Create MD5 file
md5sum -b $OUTDIR/$OUTFILE | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
echo " done."

echo -n " - Creating .ZIP output file..."
cd $OUTDIR
zip -j $OUTZIPFILE $OUTFILE $OUTFILE.md5 > /dev/null
cd $CURDIR
echo " done."

if [ -e $OUTDIR/$OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " The receiver must be equipped with a standard Fortis bootloader:"
  echo "  - DP2010: 8.14, 8.15 or 4.00"
  echo "  - DP7000: 8.14, 8.15 or 4.00"
  echo "  - DP7001: 8.05 or 1.00"
  echo "  - DP7050: 8.24, 8.25 or 3.00"
  echo "  - EP8000: 8.35, 8.37 or 2.00"
  echo "  - EPP8000: 8.35, 8.37 or 2.00"
  echo "  - FX6010: 8.05 or 1.00"
  echo "  - GPV8000: 8.14, 8.15 or 4.00"
  echo " or a modified USB bootloader:"
  echo "  - DP2010: 4.01"
  echo "  - DP7000: 4.01"
  echo "  - DP7001: 1.01"
  echo "  - DP7050: 3.01"
  echo "  - EP8000: 2.01"
  echo "  - EPP8000: 2.01"
  echo "  - FX6010: 1.01"
  echo "  - GPV8000: 4.01"
  echo " with unmodified bootargs."
  echo
  echo " To flash the created image copy the .ird file to the root directory"
  echo " of a FAT32 formatted USB stick."
  echo
  echo " Insert the USB stick in any of the box's USB ports, and switch on"
  echo " the receiver using the mains switch or inserting the DC power plug"
  echo " while pressing and holding the channel up key on the frontpanel."
  echo " Release the button when the display shows SCAN (USB) or when you see"
  echo " regular activity on the USB stick."
  echo " Flashing the image will then begin."
  echo -e "\033[00m"
fi

# Clean up
rm -f $TMPDIR/uImage
rm -f $TMPDIR/mtd_root.ubi
rm -f $TMPDIR/mtd_root.ubin
rm -f $TMPDIR/ubi.ini
