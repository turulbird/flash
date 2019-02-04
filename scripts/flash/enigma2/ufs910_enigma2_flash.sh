#!/bin/bash
# "-----------------------------------------------------------------------"
# "This script creates flashable images for Kathrein UFS910 receivers"
# " equipped with MINI/MAXI UBOOT boot loader."
# "Author: Audioniek, based on previous work by Schischu, Oxygen-1"
# "Date: 04-02-2012", Last Change: 10-25-2017"
#
# "-----------------------------------------------------------------------"
# "An image is assumed to have been built prior to calling this script!
# "-----------------------------------------------------------------------"

CURDIR=$1
TUFSBOXDIR=$2
OUTDIR=$3
TMPKERNELDIR=$4
TMPROOTDIR=$5
TMPVARDIR=$6

#echo "CURDIR       = $CURDIR"
#echo "TUFSBOXDIR   = $TUFSBOXDIR"
#echo "OUTDIR       = $OUTDIR"
#echo "TMPKERNELDIR = $TMPKERNELDIR"
#echo "TMPROOTDIR   = $TMPROOTDIR"
#echo "TMPVARDIR    = $TMPVARDIR"

# Set up the variables
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
MKSQUASHFS4=$TOOLSDIR/mksquashfs4.0
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad

SIZE_KERNEL=0x00160000
SIZE_ROOT=0x009e0000
SIZE_VAR=0x00480000

OUTFILE=$OUTDIR/miniFLASH.img
OUTZIPFILE="$HOST"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION"

echo
echo -n " - Prepare kernel file..."
cp $TMPKERNELDIR/uImage $TMPDIR/uImage
$PAD $SIZE_KERNEL $TMPDIR/uImage $TMPDIR/mtd_kernel.pad
echo " done."

echo -n " - Checking kernel size..."
SIZE=`stat $TMPDIR/uImage -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "0x%08X" $SIZE`
if [[ $SIZEH > "$SIZE_KERNEL" ]]; then
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " KERNEL TOO BIG. $SIZED ($SIZEH, max. $SIZE_KERNEL) bytes." > /dev/stderr
  echo
  echo " Press ENTER to exit..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  read
  exit
else
echo " OK: $SIZED ($SIZEH, max. $SIZE_KERNEL) bytes."
fi

# --- ROOT ---
echo -n " - Create a squashfs 4.0 partition for root..."
$MKSQUASHFS4 $TMPROOTDIR $TMPDIR/mtd_root.bin -comp lzma -all-root > /dev/null
$PAD $SIZE_ROOT $TMPDIR/mtd_root.bin $TMPDIR/mtd_root.pad
echo " done."

echo -n " - Checking root size..."
SIZE=`stat $TMPDIR/mtd_root.bin -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "0x%08X" $SIZE`
if [[ $SIZEH > "$SIZE_ROOT" ]]; then
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " ROOT TOO BIG: $SIZED ($SIZEH, max. $SIZE_ROOT) bytes." > /dev/stderr
  echo
  echo " Press ENTER to exit..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  read
  exit
else
echo " OK: $SIZED ($SIZEH, max. $SIZE_ROOT) bytes."
fi

# --- VAR ---
echo -n " - Create a jffs2 partition for var..."
$MKFSJFFS2 -qUf -p$SIZE_VAR -e0x20000 -r $TMPVARDIR -o $TMPDIR/mtd_var.bin 2> /dev/null
$SUMTOOL -p -e 0x20000 -i $TMPDIR/mtd_var.bin -o $TMPDIR/mtd_var.sum
$PAD $SIZE_VAR $TMPDIR/mtd_var.sum $CURDIR/mtd_var.pad
echo " done."

echo -n " - Checking var size..."
SIZE=`stat $TMPDIR/mtd_var.sum -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "0x%08X" $SIZE`
if [[ $SIZEH > "$SIZE_VAR" ]]; then
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " VAR TOO BIG: $SIZED ($SIZEH, max. $SIZE_VAR) bytes." > /dev/stderr
  echo
  echo " Press ENTER to exit..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  read
  exit
else
echo " OK: $SIZED ($SIZEH, max. $SIZE_VAR) bytes."
fi

# --- update.img ---
# Merge all parts together
echo -n " - Create output file(s) and MD5..."
cd $OUTDIR
cat $TMPDIR/mtd_kernel.pad > $OUTFILE
cat $TMPDIR/mtd_root.pad >> $OUTFILE
cat $TMPDIR/mtd_var.sum >> $OUTFILE
# Create MD5 file
md5sum -b $OUTFILE | awk -F' ' '{print $1}' > $OUTFILE.md5
cd - > /dev/null
echo " done."

echo -n " - Creating .ZIP output file..."
cd $OUTDIR
zip -j $OUTDIR/$OUTZIPFILE *
cd - > /dev/null
echo " done."

if [ -e $OUTDIR/$OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " The receiver must be equipped with a TDTmaxiboot boot loader,"
  echo " or a boot loader with compatible capabilities."
  echo
  echo " To flash the created image copy the file miniFLASH.img"
  echo " to the root (/) of your FAT32 formatted USB stick."
  echo " Insert the USB stick in the/a USB port on the receiver."
  echo
  echo " To start the flashing process press RECORD for 10 sec on your"
  echo " remote control while the receiver is starting."
  echo -e "\033[00m"
fi

# Clean up
rm -f $TMPDIR/uImage
rm -f $TMPDIR/mtd_root.bin
rm -f $TMPDIR/mtd_var.bin
rm -f $TMPDIR/mtd_var.sum
rm -f $TMPDIR/mtd_kernel.pad
rm -f $TMPDIR/mtd_root.pad
rm -f $TMPDIR/mtd_var.sum
