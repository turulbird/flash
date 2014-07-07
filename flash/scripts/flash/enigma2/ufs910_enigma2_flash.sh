#!/bin/bash
# "This script creates flashable images for UFS910 MINI/MAXI UBOOT"
# "Author: Schischu, Oxygen-1"
# "Date: 04-02-2012"
# "-----------------------------------------------------------------------"
# "It is expected that an image was already built prior to this execution!"
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

MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
MKSQUASHFS=$CURDIR/../common/mksquashfs4.0
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$CURDIR/../common/pad

OUTFILE=$OUTDIR/miniFLASH.img

if [ ! -e $OUTDIR ]; then
  mkdir $OUTDIR
fi

if [ -e $OUTDIR/$OUTFILE ]; then
  rm -f $OUTDIR/$OUTFILE
fi

# Determine name of ZIP output file
if [ -f $TMPROOTDIR/etc/hostname ]; then
	HOST=`cat $TMPROOTDIR/etc/hostname`
elif [ -f $TMPROOTDIR/var/etc/hostname ]; then
	HOST=`cat $TMPROOTDIR/var/etc/hostname`
fi

[ -d $CURDIR/../../cvs/apps/libstb-hal-exp ] && HAL_REV=_HAL-rev`cd $CURDIR/../../cvs/apps/libstb-hal-exp && git log | grep "^commit" | wc -l`-exp || HAL_REV=_HAL-rev`cd $CURDIR/../../cvs/apps/libstb-hal && git log | grep "^commit" | wc -l`
[ -d $CURDIR/../../cvs/apps/neutrino-mp-exp ] && NMP_REV=_NMP-rev`cd $CURDIR/../../cvs/apps/neutrino-mp-exp && git log | grep "^commit" | wc -l`-exp || NMP_REV=_NMP-rev`cd $CURDIR/../../cvs/apps/neutrino-mp && git log | grep "^commit" | wc -l`
gitversion="_BASE-rev`(cd $CURDIR/../../ && git log | grep "^commit" | wc -l)`$HAL_REV$NMP_REV"
OUTZIPFILE=$HOST_$gitversion

# --- KERNEL ---
# Size 1,375MB !
cp $TMPKERNELDIR/uImage $CURDIR/uImage
$PAD 0x160000 $CURDIR/uImage $CURDIR/mtd_kernel.pad.bin

# --- ROOT ---
# Create a squashfs partition for root
# Size 9,875MB ! 0x9e0000
echo "MKSQUASHFS $TMPROOTDIR $CURDIR/mtd_root.bin -comp lzma -all-root"
$MKSQUASHFS $TMPROOTDIR $CURDIR/mtd_root.bin -comp lzma -all-root > /dev/null
echo "PAD 0x9e0000 $CURDIR/mtd_root.bin $CURDIR/mtd_root.pad.bin"
$PAD 0x9e0000 $CURDIR/mtd_root.bin $CURDIR/mtd_root.pad.bin

# --- VAR ---
# Size 4,5
echo "MKFSJFFS2 -qUfv -p0x480000 -e0x20000 -r $TMPVARDIR -o $CURDIR/mtd_var.bin"
$MKFSJFFS2 -qUfv -p0x480000 -e0x20000 -r $TMPVARDIR -o $CURDIR/mtd_var.bin
echo "SUMTOOL -v -p -e 0x20000 -i $CURDIR/mtd_var.bin -o $CURDIR/mtd_var.sum.bin"
$SUMTOOL -v -p -e 0x20000 -i $CURDIR/mtd_var.bin -o $CURDIR/mtd_var.sum.bin
echo "$PAD 0x480000 $CURDIR/mtd_var.sum.bin $CURDIR/mtd_var.sum.pad.bin"
$PAD 0x480000 $CURDIR/mtd_var.sum.bin $CURDIR/mtd_var.sum.pad.bin

# --- update.img ---
#Merge all 3 together
cat $CURDIR/mtd_kernel.pad.bin >> $OUTFILE
cat $CURDIR/mtd_root.pad.bin >> $OUTFILE
cat $CURDIR/mtd_var.sum.pad.bin >> $OUTFILE

rm -f $CURDIR/uImage
rm -f $CURDIR/mtd_root.bin
rm -f $CURDIR/mtd_var.bin
rm -f $CURDIR/mtd_var.sum.bin

SIZE=`stat mtd_kernel.pad.bin -t --format %s`
SIZE=`printf "0x%x" $SIZE`
if [[ $SIZE > "0x160000" ]]; then
  echo "KERNEL TOO BIG. $SIZE instead of 0x160000" > /dev/stderr
fi

SIZE=`stat mtd_root.pad.bin -t --format %s`
SIZE=`printf "0x%x" $SIZE`
if [[ $SIZE > "0x9e0000" ]]; then
  echo "ROOT TOO BIG. $SIZE instead of 0x9e0000" > /dev/stderr
fi

SIZE=`stat mtd_var.sum.pad.bin -t --format %s`
SIZE=`printf "0x%x" $SIZE`
if [[ $SIZE > "0x480000" ]]; then
  echo "VAR TOO BIG. $SIZE instead of 0x480000" > /dev/stderr
fi

rm -f $CURDIR/mtd_kernel.pad.bin
rm -f $CURDIR/mtd_root.pad.bin
rm -f $CURDIR/mtd_var.sum.pad.bin

zip $OUTZIPFILE.zip $OUTFILE

echo "-----------------------------------------------------------------------"
echo " To flash the created image copy the file miniFLASH.img to the root (/)"
echo " of your USB stick, then insert the USB stick in the receiver."
echo
echo " To start the flashing process press RECORD for 10 sec on your remote"
echo " control while the receiver is starting"
echo



