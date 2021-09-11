#!/bin/bash
# "-----------------------------------------------------------------------"
# " This script creates flashable images for Crenova receiver:"
# " - Atemio AM 520 HD
# " with unmodified factory iBoot bootloader 6.40.
#
# "Author: Schischu/Audioniek"
# "Date: 10-09-2021"
#
# "-----------------------------------------------------------------------"
# "It is assumed that an image was already built prior to"
# "executing this script!"
# "-----------------------------------------------------------------------"
#
#

echo "-- Output selection ---------------------------------------------------"
echo
echo " What would you like to flash?"
echo "   1) The whole $IMAGE image (*)"
echo "   2) Only the kernel"
read -p " Select flash target (1-2)? "
case "$REPLY" in
#  1) echo > /dev/null;;
  2) IMAGE="kernel";;
#  *) echo > /dev/null;;
esac
echo "-----------------------------------------------------------------------"
echo

# Set up the variables
TMPDUMDIR=$TMPDIR/DUMMY
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad
MKSQUASHFS=$TOOLSDIR/mksquashfs3.3
FUP=$TOOLSDIR/fup

OUTFILE="$BOXTYPE"_"$IMAGE"_flash_R$RESELLERID.ird
OUTZIPFILE="$HOST"_"$IMAGE"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip

if [ -e $TMPDUMDIR ]; then
  rm -rf $TMPDUMDIR/*
elif [ ! -d $TMPDUMDIR ]; then
  mkdir -p $TMPDUMDIR
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
if [[ $SIZEKD > "2752512" ]]; then
  echo
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " KERNEL TOO BIG: 0x$SIZEKH instead of max. 0x0029FFFF bytes." > /dev/stderr
  echo " Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
else
  echo " OK: $SIZEKD (0x$SIZEKH, max. 0x0029FFFF) bytes."
fi

if [ "$IMAGE" != "kernel" ]; then
  echo -n " - Remove var from root..."
    mv -t $TMPVARDIR $TMPROOTDIR/var/* 
    rmdir $TMPROOTDIR/var
  echo " done."

  echo -n " - Preparing root..."
  $MKSQUASHFS $TMPROOTDIR $TMPDIR/mtd_root.bin -nopad -le > /dev/null
  echo -n " - Checking root size..."
  SIZE=`stat $TMPDIR/mtd_root.bin -t --format %s`
  SIZEH=`printf "%08X" $SIZE`
  SIZED=`printf "%d" $SIZE`
  if [[ $SIZED > "13369344" ]]; then
    echo -e "\033[01;31m"
    echo "-- ERROR! -------------------------------------------------------------"
    echo
    echo " ROOT TOO BIG: 0x$SIZEH instead of 0xCBFFFF bytes." > /dev/stderr
    echo
    echo " Exiting..."
    echo "-----------------------------------------------------------------------"
    echo -e "\033[00m"
    exit
  else
    echo " OK: $SIZED (0x$SIZEH, max. 0xCBFFFF) bytes."
  fi
  # Sign partition
  $FUP -s $TMPDIR/mtd_root.bin > /dev/null
  echo " done."

  echo -n " - Preparing var..."
  # Create a jffs2 partition for var
  $MKFSJFFS2 -qUfl -e 0x20000 -r $TMPVARDIR -o $TMPDIR/mtd_var.bin
  $SUMTOOL -p -l -e 0x20000 -i $TMPDIR/mtd_var.bin -o $TMPDIR/mtd_var.sum > /dev/null
  # Padding the var up maximum size is required to force JFFS2 to find
  # only erased flash blocks after the var on the initial kernel run.
  $PAD 0x1040000 $TMPDIR/mtd_var.sum $TMPDIR/mtd_var.pad
  echo " done."
fi

echo -n " - Creating .IRD flash file and MD5..."
if [ "$IMAGE" == "kernel" ]; then
  $FUP -c $OUTDIR/$OUTFILE \
       -6 $TMPDIR/uImage
else
  $FUP -c $OUTDIR/$OUTFILE \
       -6 $TMPDIR/uImage \
       -8 $TMPDIR/mtd_root.bin.signed \
       -9 $TMPDIR/mtd_var.bin
fi
# Set reseller ID
$FUP -r $OUTDIR/$OUTFILE $RESELLERID
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
  echo " for Titanit: V6.40"
  echo " with unmodified bootargs."
  echo
  echo " To flash the created image copy the .ird file to the root directory"
  echo " of a FAT32 formatted USB stick."
  echo
  echo " Insert the USB stick in any of the box's USB ports, and switch on"
  echo " the receiver using the power switch on the back while pressing and"
  echo " holding the power key on the frontpanel."
  echo " Release the button when the display shows SCAN, or when you see"
  echo " activity on the USB stick."
  echo " Flashing the image will then begin."
  echo -e "\033[00m"
fi

# Clean up
#rm -f $TMPDIR/uImage
#rm -f $TMPDIR/mtd_root.bin
#rm -f $TMPDIR/mtd_fakeroot.bin.signed
#rm -f $TMPDIR/mtd_root.bin
#rm -f $TMPDIR/mtd_root.bin.signed
#rm -f $TMPDIR/mtd_var.sum
#rm -f $TMPDIR/mtd_var.pad
if [ -e $TOOLSDIR/dummy.squash.signed.padded ]; then
  rm $TOOLSDIR/dummy.squash.signed.padded
fi

