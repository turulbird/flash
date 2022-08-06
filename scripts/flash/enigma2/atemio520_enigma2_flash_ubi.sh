#!/bin/bash
# "-----------------------------------------------------------------------"
# " This script creates Enigma2 .ird flash files for Crenova receiver:"
# " - Atemio AM 520 HD
# " with unmodified factory iBoot bootloader 6.40.
#
# This version generates an image using UBIFS in NAND flash.
#
# "Author: Schischu/Audioniek"
# "Date: 22-06-2022"
#
# "-----------------------------------------------------------------------"
# "It is assumed that an image was already built prior to"
# "executing this script!"
# "-----------------------------------------------------------------------"
#
# Date     Who          Description
# 20220622 Audioniek    Initial version.
# 20220806 Audioniek    Indicate default choice differently.
#
# -----------------------------------------------------------------------
#
#

# Set up the variables
PAD=$TOOLSDIR/pad
MKFSUBIFS=$TUFSBOXDIR/host/bin/mkfs.ubifs
UBINIZE=$TUFSBOXDIR/host/bin/ubinize
FUP=$TOOLSDIR/fup

OUTFILE="$BOXTYPE"_"$IMAGE"_flash_R$RESELLERID.ird
OUTZIPFILE="$HOST"_"$IMAGE"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip

if [ "$BATCH_MODE" == "yes" ]; then
  IMAGE=
else
  echo "-- Output selection ---------------------------------------------------"
  echo
  echo " What would you like to flash?"
  echo "   1*) The whole $IMAGE image"
  echo "   2)  Only the kernel"
  read -p " Select flash target (1-2)? "
  case "$REPLY" in
#    1) echo > /dev/null;;
    2) IMAGE="kernel";;
#    *) echo > /dev/null;;
  esac
  echo "-----------------------------------------------------------------------"
  echo
fi

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi


echo -n " - Preparing kernel file..."
cp $TMPKERNELDIR/uImage $TMPDIR/uImage
echo " done."

echo -n " - Checking kernel size..."
SIZEK=`stat $TMPKERNELDIR/uImage -t --format %s`
SIZEKD=`printf "%d" $SIZEK`
SIZEKH=`printf "%08X" $SIZEK`
if [[ $SIZEKD > "3145728" ]]; then
  echo
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " KERNEL TOO BIG: 0x$SIZEKH instead of max. 0x00300000 bytes." > /dev/stderr
  echo " Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
else
  echo " OK: $SIZEKD (0x$SIZEKH, max. 0x00300000) bytes."
fi

# Because of autoresize while flashing, pad kernel to its maximum size minus a few bytes
$PAD 2F0000 $TMPDIR/uImage $TMPDIR/uImage.pad

if [ "$IMAGE" != "kernel" ]; then
  echo -n " - Preparing UBIFS root file system..."
  # The Atemio AM 520 HD is equipped with a Spansion S34ML04G NAND flash memory,
  # having the following properties:
  # - Page size: 2048 bytes -> Minimum I/O size = 2048 bytes => -m 2048
  # - Subpage size = 512 bytes
  # - Block size: 128 kbytes or 131072 bytes
  # - Total number of blocks = 4 Gbit / 8 / 131072 (blocksize) = 4096
  # Logical erase block size is physical erase block size (131072) minus -m parameter => -e 129024
  #
  # Receiver specifics:
  # The rootfs mtd has a size of 128 Mib
  # Number of erase blocks is partition size / physical eraseblock size: 128Mib / 131072 => -c 1024
  # iBoot bootloader expects a zlib compressed ubifs => -x zlib
  # The kernel supports a zlib compressed ubifs => -x zlib
  # Enigma2 is run as root => -U (changes ownership of all files to root)
  $MKFSUBIFS -d $TMPROOTDIR -m 2048 -e 129024 -c 1024 -x zlib -U -o $TMPDIR/mtd_root.ubi
  echo " done."

  echo -n " - Creating ubinize ini file..."
  # Create ubi.ini
  echo "[ubi-rootfs]" > $TMPDIR/ubi.ini
  echo "mode=ubi" >> $TMPDIR/ubi.ini
  echo "image=$TMPDIR/mtd_root.ubi" >> $TMPDIR/ubi.ini
  echo "vol_id=0" >> $TMPDIR/ubi.ini
  # UBI needs a few free erase blocks for bad PEB handling, say 24, so:
  # Net available for data: (1024-24) x 129024 = 129024000 bytes
  echo "vol_size=129024000" >> $TMPDIR/ubi.ini
  echo "vol_type=dynamic" >> $TMPDIR/ubi.ini
  # iBoot bootloader requires the volume label rootfs
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
  SIZEDS=$(expr $SIZED / 16)
  SIZEMAX=8388608
  SIZEMAXH=8000000
  if [[ $SIZEDS > $SIZEMAX ]]; then
    echo -e "\033[01;31m"
    echo "-- ERROR! -------------------------------------------------------------"
    echo
    echo " ROOT TOO BIG: 0x$SIZEH instead of 0x0$SIZEMAXH bytes." > /dev/stderr
    echo
    echo " Exiting..."
    echo "-----------------------------------------------------------------------"
    echo -e "\033[00m"
    exit
  else
    echo " OK: $SIZED (0x$SIZEH, max. 0x0$SIZEMAXH) bytes."
  fi
fi

# Create dummy file to use for fake root
dd if=/dev/random of=$FLASHDIR/dummy bs=1 skip=0 count=128 2> /dev/null

echo -n " - Creating .IRD flash file and MD5..."
if [ "$IMAGE" == "kernel" ]; then
  $FUP -c $OUTDIR/$OUTFILE \
       -6 $TMPDIR/uImage.pad
else
  $FUP -c $OUTDIR/$OUTFILE \
       -6 $TMPDIR/uImage.pad \
       -7 $FLASHDIR/dummy \
       -8 $TMPDIR/mtd_root.ubin
fi
# Set reseller ID
$FUP -r $OUTDIR/$OUTFILE $RESELLERID
# Set SW version to 2.10.00 to force flashing to NAND flash
$FUP -n $OUTDIR/$OUTFILE 21000
# Create MD5 file
md5sum -b $OUTDIR/$OUTFILE | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
echo " done."

echo -n " - Creating .ZIP output file...       "
cd $OUTDIR
zip -j $OUTZIPFILE $OUTFILE $OUTFILE.md5 > /dev/null
cd $CURDIR
echo " done."

if [ -e $OUTDIR/$OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " The receiver must be equipped with the standard iBoot bootloader used"
  echo " for TitanNit with unmodified bootargs."
  echo
  echo " To flash the created image copy the .ird file to the root directory"
  echo " of a FAT32 formatted USB stick."
  echo
  echo " Insert the USB stick in any of the box's USB ports, and switch on"
  echo " the receiver using the power switch on the back while pressing and"
  echo " holding the power key on the frontpanel."
  echo " Release the button when the display shows 'SrcH', or when you see"
  echo " activity on the USB stick."
  echo " Flashing the image will then begin."
  echo -e "\033[00m"
fi

# Clean up
rm -f $TMPDIR/uImage
rm -f $TMPDIR/uImage.pad
rm -f $TMPKERNELDIR/uImage
rm -f $TMPDIR/ubi.ini
rm -f $TMPDIR/mtd_root.bin
rm -f $TMPDIR/mtd_root.ubin
rm -f $FLASHDIR/dummy
if [ -e $FLASHDIR/dummy.squash.signed.padded ]; then
  rm $FLASHDIR/dummy.squash.signed.padded
fi

