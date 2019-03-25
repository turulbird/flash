#!/bin/bash
# -----------------------------------------------------------------------
# This script creates flashable images for Spark and Spark7162 receivers
# Author: Schischu/Audioniek
# Date: 08-07-2014
# -----------------------------------------------------------------------
# It is assumed that an image was already built prior to executing this
# script!
# -----------------------------------------------------------------------
#
# Date     Who          Description
# 20150421 Audioniek    Maximum kernel size adapted to Spark (8M -> 7M).
# 20160310 Audioniek    Maximum kernel check now automatic.
# 20170902 Audioniek    Improved root size checking.
# 20190113 Audioniek    Add batch mode.
# 20190325 Audioniek    Correct maximum root size on Spark.
#
# -----------------------------------------------------------------------

# Set up the variables
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
#PAD=$TOOLSDIR/pad

OUTFILE=e2jffs2.img
OUTZIPFILE="$HOST"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION"

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

if [ -e $OUTDIR/enigma2 ]; then
  rm -f $OUTDIR/enigma2/*
elif [ ! -d $OUTDIR/enigma2 ]; then
  mkdir $OUTDIR/enigma2
fi

# --- KERNEL ---
# Maximum size is 7Mbyte on Spark, 8 MByte on Spark7162
echo -n " - Creating kernel output file uImage..."
cp -f $TMPKERNELDIR/uImage $OUTDIR/enigma2/uImage
echo " done."

echo -n " - Checking kernel size..."
if [[ $BOXTYPE == spark ]]; then
  SIZEMAX=7340032
  SIZEMAXH=700000
else
  SIZEMAX=8388608
  SIZEMAXH=800000
fi
SIZEK=`stat $OUTDIR/enigma2/uImage -t --format %s`
SIZEKD=`printf "%d" $SIZEK`
SIZEKH=`printf "%08X" $SIZEK`
if [[ $SIZEKD > $SIZEMAX ]]; then
  echo
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " KERNEL TOO BIG: 0x$SIZEKH instead of max. 0x00$SIZEMAXH bytes." > /dev/stderr
  echo " Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
else
  echo " OK: $SIZEKD (0x$SIZEKH, max. 0x00$SIZEMAXH) bytes."
fi

# --- ROOT ---
# Maximum size is 64 MByte
echo -n " - Creating root output file $OUTFILE..."
$MKFSJFFS2 -r $TMPROOTDIR -o $TMPDIR/mtd_root.bin -e 0x20000 -p -n > /dev/null
#echo " SUMTOOL -p -e 0x20000 -i $TMPDIR/mtd_root.bin -o $CURDIR/mtd_root.sum.bin"
$SUMTOOL -p -e 0x20000 -i $TMPDIR/mtd_root.bin -o $TMPDIR/mtd_root.sum.bin
mv $TMPDIR/mtd_root.sum.bin $OUTDIR/enigma2/$OUTFILE
echo " done."

echo -n " - Checking root size..."
SIZE=`stat $OUTDIR/enigma2/$OUTFILE -t --format %s`
SIZEH=`printf "%08X" $SIZE`
SIZED=`printf "%d" $SIZE`
SIZEDS=$(expr $SIZED / 16)
SIZEMAX=7798784
SIZEMAXH=7700000
if [[ $SIZEDS > $SIZEMAX ]]; then
  echo
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " ROOT TOO BIG: 0x$SIZEH instead of max. 0x0$SIZEMAXH bytes." > /dev/stderr
  echo
  echo " Exiting..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
else
  echo " OK: $SIZED (0x$SIZEH, max. 0x0$SIZEMAXH) bytes."
fi

# Clean up
rm -f $TMPDIR/mtd_root.bin

# Create a .zip file and an MD5 file
echo -n " - Creating .MD5 and .ZIP output files..."
md5sum -b $OUTDIR/enigma2/uImage | awk -F' ' '{print $1}' > $OUTDIR/enigma2/uImage.md5
md5sum -b $OUTDIR/enigma2/$OUTFILE | awk -F' ' '{print $1}' > $OUTDIR/enigma2/$OUTFILE.md5
cd $OUTDIR
zip $OUTZIPFILE enigma2/* > /dev/null
cd - > /dev/null
echo " done."

if [ -e $OUTDIR/enigma2/$OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " To flash the created image, copy the enigma2 folder and its contents"
  echo " to the root folder (/) of your USB stick, so the root of the stick"
  echo " has a folder enigma2."
  echo
  echo " Before flashing make sure that enigma2 is the default system on your"
  echo " receiver."
  echo " To set enigma2 as your default system press and hold OK on the front"
  echo " panel of the receiver while it is starting. As soon as \"FoRc\" is"
  echo " being displayed release the OK button and press DOWN (v) on the"
  echo " front panel to select \"ENIG\" and then press OK to confirm."
  echo " (NOTE: you only need to do this once, repeat this when you want spark"
  echo " as default system)."
  echo
  echo " Insert the USB stick in the receiver (on a Spark7162, use the rear"
  echo " USB port)."
  echo
  echo " To start the flashing process, press and hold OK on the front panel"
  echo " of the receiver while it is starting. As soon as \"FoRc\" is being"
  echo " displayed release the OK button and press RIGHT (->)."
  echo " Then \"FAct\" is displayed and flashing starts."
  echo -e "\033[00m"
fi



