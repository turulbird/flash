#!/bin/bash
# "-----------------------------------------------------------------------"
# "This script creates flashable images for Kathrein UFC960 receivers."
# Author: Audioniek, based on previous work by person(s) unknown."
# "Last Change: 07-12-2014"
#
# "-----------------------------------------------------------------------"
# "An image is assumed to have been built prior to calling this script!
# "-----------------------------------------------------------------------"

# Set up the variables
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
MKSQUASHFS4=$TOOLSDIR/mksquashfs4.0
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad

#ZIPDATA=$OUTDIR/kathrein
#OUTDIR=$OUTDIR/kathrein/ufc960
OUTFILE=update.img
OUTZIPFILE="$HOST"_"$IMAGE"_"P$PATCH"_"$GITVERSION"

# Define sizes of kernel, root and var
#SIZE_KERNEL=0x160000
#SIZE_ROOT=0x9e0000
#SIZE_VAR=0x480000
SIZE_KERNEL=0x001a0000
SIZE_ROOT=0x009c0000
SIZE_VAR=0x00460000

if [ -e $OUTDIR/kathrein ]; then
  rm -f $OUTDIR/kathrein/*
elif [ ! -d $OUTDIR/kathrein ]; then
  mkdir $OUTDIR/kathrein
fi

if [ -e $OUTDIR/kathrein/ufc960 ]; then
  rm -f $OUTDIR/kathrein/ufc960/*
elif [ ! -d $OUTDIR/kathrein/ufc960 ]; then
  mkdir $OUTDIR/kathrein/ufc960
fi

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
#echo "MKSQUASHFS $TMPROOTDIR $TMPDIR/mtd_root.bin -comp lzma -all-root"
$MKSQUASHFS4 $TMPROOTDIR $TMPDIR/mtd_root.bin -comp lzma -all-root > /dev/null
#echo "PAD ${SIZE_ROOT} $CURDIR/mtd_root.bin $CURDIR/mtd_root.pad.bin"
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
#echo "MKFSJFFS2 -qUf -p$SIZE_VAR -e0x20000 -r $TMPVARDIR -o $TMPDIR/mtd_var.bin"
$MKFSJFFS2 -qUf -p$SIZE_VAR -e0x20000 -r $TMPVARDIR -o $TMPDIR/mtd_var.bin 2> /dev/null
#echo "SUMTOOL -p -e 0x20000 -i $CURDIR/mtd_var.bin -o $CURDIR/mtd_var.sum"
$SUMTOOL -p -e 0x20000 -i $TMPDIR/mtd_var.bin -o $TMPDIR/mtd_var.sum
# echo "$PAD $SIZE_VAR $TMPDIR/mtd_var.sum.bin $TMPDIR/mtd_var.pad"
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
cd $OUTDIR/kathrein/ufc960
cat $TMPDIR/mtd_kernel.pad > $OUTFILE
cat $TMPDIR/mtd_root.pad >> $OUTFILE
cat $TMPDIR/mtd_var.sum >> $OUTFILE
cp $SCRIPTDIR/$OUTTYPE/ufc960_updatescript.sh .
# Create MD5 file
md5sum -b $OUTFILE | awk -F' ' '{print $1}' > $OUTFILE.md5
cd - > /dev/null
echo " done."

echo -n " - Creating .ZIP output file..."
cd $OUTDIR
zip -r $OUTDIR/$OUTZIPFILE `basename $OUTDIR/kathrein`
cd - > /dev/null
echo " done."

# Clean up
rm -f $TMPDIR/uImage
rm -f $TMPDIR/mtd_root.bin
rm -f $TMPDIR/mtd_var.bin
rm -f $TMPDIR/mtd_var.sum
rm -f $TMPDIR/mtd_kernel.pad
rm -f $TMPDIR/mtd_root.pad
rm -f $TMPDIR/mtd_var.sum



