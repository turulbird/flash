#!/bin/bash
# "-----------------------------------------------------------------------"
# " This script creates flashable images for these Fortis receivers:"
# " - HS7119
# " - HS7429
# " - HS7819
# " with unmodified factory bootloader:
# " 7.40, 7.46 or 7.47 (HS7119),
# " 7.30, 7.36 or 7.37 (HS7429, NOT tested) or
# " 7.20, 7.26 or 7.27 (HS7819)
#
# "Author: Schischu/Audioniek"
# "Date: 09-14-2014"
#
# "-----------------------------------------------------------------------"
# "It is assumed that an image was already built prior to executing this"
# "script!"
# "-----------------------------------------------------------------------"
#

echo "-- Output selection ---------------------------------------------------"
echo
echo " What would you like to flash?"
echo "   1) The $IMAGE image plus kernel (*)"
echo "   2) Only the kernel"
echo "   3) Only the $IMAGE image"
read -p " Select flash target (1-3)? "
case "$REPLY" in
#  1) echo > /dev/null;;
  2) IMAGE="kernel";;
  3) IMAGE="$IMAGE_only";;
#  *) echo > /dev/null;;
esac
echo "-----------------------------------------------------------------------"
echo

# Set up the variables
MKFSUBIFS=$TUFSBOXDIR/host/bin/mkfs.ubifs
UBINIZE=$TUFSBOXDIR/host/bin/ubinize
FUP=$TOOLSDIR/fup

OUTFILE="$BOXTYPE"_"$IMAGE"_flash_R$RESELLERID.ird
OUTZIPFILE="$HOST"_"$IMAGE"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

echo -n " - Prepare kernel file..."
cp $TMPKERNELDIR/uImage $TMPDIR/uImage
echo " done."

echo -n " - Checking kernel size..."
SIZEK=`stat $TMPDIR/uImage -t --format %s`
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

if [ ! "$IMAGE" == "kernel" ]; then
  echo -n " - Prepare UBIFS root file system..."
  # Logical erase block size is physical erase block size (131072) minus -m parameter => -e 129024
  # Number of erase blocks is partition size / physical eraseblock size: 96Mib / 131072 => -c 768
  # Fortis bootloader expects a zlib compressed ubifs => -x zlib
  $MKFSUBIFS -d $TMPROOTDIR -m 2048 -e 129024 -c 768 -x zlib -U -o $TMPDIR/mtd_root.ubi 2> /dev/null
  echo " done."

  echo -n " - Create ubinize ini file..."
  # Create ubi.ini
  echo "[ubi-rootfs]" > $TMPDIR/ubi.ini
  echo "mode=ubi" >> $TMPDIR/ubi.ini
  echo "image=$TMPDIR/mtd_root.ubi" >> $TMPDIR/ubi.ini
  echo "vol_id=0" >> $TMPDIR/ubi.ini
  # UBI needs a few free erase blocks for bad PEB handling, say 32, so:
  # Net available for data: 736 x 129024 = 94961664 bytes
  echo "vol_size=94961664" >> $TMPDIR/ubi.ini
  echo "vol_type=dynamic" >> $TMPDIR/ubi.ini
  # Fortis bootloader requires the volume label rootfs
  echo "vol_name=rootfs" >> $TMPDIR/ubi.ini
  # Allow UBI to dynamically resize the volume
  echo "vol_flags=autoresize" >> $TMPDIR/ubi.ini
  echo "vol_alignment=1" >> $TMPDIR/ubi.ini
  echo " done."

  echo -n " - Create UBI root image..."
  # UBInize the UBI partition of the rootfs
  # Physical eraseblock size is 131072 => -p 128KiB
  # Subpage size is 512 bytes => -s 512
  $UBINIZE -o $TMPDIR/mtd_root.ubin -p 128KiB -m 2048 -s 512 -x 1 $TMPDIR/ubi.ini 2> /dev/null
  echo " done."

  echo -n " - Checking root size..."
  SIZE=`stat $TMPDIR/mtd_root.ubin -t --format %s`
  SIZEH=`printf "%08X" $SIZE`
  SIZED=`printf "%d" $SIZE`
  if [[ $SIZED > "94961664" ]]; then  echo -e "\033[01;31m"
    echo
    echo -e "\033[01;31m"
    echo "-- ERROR! -------------------------------------------------------------"
    echo
    echo " ROOT TOO BIG: 0x$SIZEH instead of max. 0x05A900000 bytes." > /dev/stderr
    echo " Exiting..."
    echo
    echo "-----------------------------------------------------------------------"
    echo -e "\033[00m"
    exit
  else
    echo " OK: $SIZED (0x$SIZEH, max. 0x05A900000) bytes."
  fi
fi

echo -n " - Creating .IRD flash file and MD5..."
cd $TOOLSDIR
if [ "$IMAGE" == "kernel" ]; then
  $FUP -c $OUTDIR/$OUTFILE \
       -6 $TMPDIR/uImage
elif [ "$IMAGE" == "image" ]; then
  $FUP -c $OUTDIR/$OUTFILE \
       -1 $TMPDIR/mtd_root.ubin
else
  $FUP -c $OUTDIR/$OUTFILE \
       -6 $TMPDIR/uImage \
       -1 $TMPDIR/mtd_root.ubin
fi
# Set reseller ID
$FUP -r $OUTDIR/$OUTFILE $RESELLERID
cd $CURDIR
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
  echo " The receiver must be equipped with a standard Fortis bootloader:"
  echo "  - HS7119: 7.40, 7.46 or 7.47"
#  echo "  - HS7429: 7.30, 7.36 or 7.37"
  echo "  - HS7819: 7.20, 7.26 or 7.27"
  echo " with unmodified bootargs."
  echo
  echo " To flash the created image copy the .ird file to the root directory"
  echo " of a FAT32 formatted USB stick."
  echo
  echo " Insert the USB stick in any of the box's USB ports, and switch on"
  echo " the receiver using the mains switch or inserting the DC power plug"
  echo " while pressing and holding the channel up key on the frontpanel."
  echo " Release the button when the display shows SCAN (USB)."
  echo " Flashing the image will then begin."
  echo -e "\033[00m"
fi

# Clean up
rm -f $TMPDIR/uImage
rm -f $TMPDIR/mtd_root.ubi
rm -f $TMPDIR/mtd_root.ubin
rm -f $TMPDIR/ubi.ini

