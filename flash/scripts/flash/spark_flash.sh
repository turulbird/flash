#!/bin/bash
# "-----------------------------------------------------------------------"
# "This script creates flashable images for Spark and Spark7162"
# "Author: Schischu/Audioniek"
# "Date: 30-08-2013"
# "-----------------------------------------------------------------------"
# "It is assumed that an image was already built prior to executing this"
# "script!"
# "-----------------------------------------------------------------------"

# Set up the variables
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
#PAD=$TOOLSDIR/pad

OUTFILE=e2jffs2.img
OUTZIPFILE=$HOST-P$PATCH-$GITVERSION

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

# --- KERNEL ---
# Maximum size is 8 MByte
echo -n " - Creating output file uImage..."
cp -f $TMPKERNELDIR/uImage $OUTDIR/uImage
echo " done."

echo -n " - Checking kernel size..."
SIZEK=`stat $TMPDIR/uImage -t --format %s`
SIZEKD=`printf "%d" $SIZEK`
SIZEKH=`printf "%08X" $SIZEK`
if [[ $SIZEKD > "3276799" ]]; then
  echo
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " KERNEL TOO BIG: 0x$SIZEKH instead of max. 0x00800000 bytes" > /dev/stderr
  echo " Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
else
  echo " OK: $SIZEKD (0x$SIZEKH, max. 0x00800000) bytes."
fi

# --- ROOT ---
# Maximum size is 64 MByte
echo -n " - Creating output file $OUTFILE..."
$MKFSJFFS2 -r $TMPROOTDIR -o $CURDIR/mtd_root.bin -e 0x20000 -p -n > /dev/null
echo " SUMTOOL -p -e 0x20000 -i $CURDIR/mtd_root.bin -o $CURDIR/mtd_root.sum.bin"
$SUMTOOL -p -e 0x20000 -i $CURDIR/mtd_root.bin -o $CURDIR/mtd_root.sum.bin
mv $CURDIR/mtd_root.sum.bin $OUTDIR/$OUTFILE
echo " done."

echo -n " - Checking root size..."
SIZE=`stat $OUTDIR/$OUTFILE -t --format %s`
SIZEH=`printf "%08X" $SIZE`
SIZED=`printf "%d" $SIZE`
if [[ $SIZEH > "4000000" ]]; then
  echo
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " ROOT TOO BIG: 0x$SIZEH instead of max. 0x04000000 bytes" > /dev/stderr
  echo
  echo " Exiting..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
else
  echo " OK: $SIZED (0x$SIZEH, max. 0x1C00000) bytes"
fi

# Clean up
rm -f $CURDIR/mtd_root.bin

# Create a .zip file and an MD5 file
echo -n " - Creating .MD5 and .ZIP output files..."
md5sum -b $OUTDIR/$OUTFILE | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
zip -j $OUTDIR/$OUTZIPFILE $OUTDIR/$OUTFILE $OUTDIR/$OUTFILE.md5 > /dev/null
echo " done."

