#!/bin/bash
# "This script creates flashable images for Kathrein UFS912/913"
# "Author: Schischu"
# "Date: 01-31-2011"
# "-----------------------------------------------------------------------"
# "It is expected that an image was already built prior to this execution!"
# "-----------------------------------------------------------------------"
#TODO: add kernel, fw, kernel+root

# Set up the variables
CURDIR=$1
TUFSBOXDIR=$2
OUTDIR=$3
TMPKERNELDIR=$4
TMPROOTDIR=$5
TOOLSDIR=$CURDIR/flash_tools
#echo "CURDIR       = $CURDIR"
#echo "TUFSBOXDIR   = $TUFSBOXDIR"
#echo "OUTDIR       = $OUTDIR"
#echo "TMPKERNELDIR = $TMPKERNELDIR"
#echo "TMPROOTDIR   = $TMPROOTDIR"
#echo "TOOLSDIR     = $TOOLSDIR"

MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
MUP=$TOOLSDIR/mup

OUTFILE=update_wo_fw.img

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

# Determine name of ZIP output file
[ -d $CURDIR/../../cvs/apps/libstb-hal-exp ] && HAL_REV=_HAL-rev`cd $CURDIR/../../cvs/apps/libstb-hal-exp && git log | grep "^commit" | wc -l`-exp || HAL_REV=_HAL-rev`cd $CURDIR/../../cvs/apps/libstb-hal && git log | grep "^commit" | wc -l`
[ -d $CURDIR/../../cvs/apps/neutrino-mp-exp ] && NMP_REV=_NMP-rev`cd $CURDIR/../../cvs/apps/neutrino-mp-exp && git log | grep "^commit" | wc -l`-exp || NMP_REV=_NMP-rev`cd $CURDIR/../../cvs/apps/neutrino-mp && git log | grep "^commit" | wc -l`
gitversion="_BASE-rev`(cd $CURDIR/../../ && git log | grep "^commit" | wc -l)`$HAL_REV$NMP_REV"
OUTZIPFILE=$HOST_$gitversion

# Move kernel
cp $TMPKERNELDIR/uImage $CURDIR/uImage

# Create a jffs2 partition for root
# Size 64 MByte = -p0x4000000
# Folder which contains fw's is -r fw
# e.g.
# .
# ./release
# ./release/etc
# ./release/usr
$MKFSJFFS2 -qUfv -p0x4000000 -e0x20000 -r $TMPROOTDIR -o $CURDIR/mtd_root.bin
$SUMTOOL -v -p -e 0x20000 -i $CURDIR/mtd_root.bin -o $CURDIR/mtd_root.sum.bin

# Create a Kathrein update file
# To get the partitions erased we first need to fake an yaffs2 update
$MUP c $OUTFILE << EOF
2
0x00C00000, 0x4000000, 3, foo
0x00000000, 0x0, 1, uImage
0x00C00000, 0x0, 1, mtd_root.sum.bin
;
EOF

# Clean up
rm -f $CURDIR/uImage
rm -f $CURDIR/mtd_root.bin
rm -f $CURDIR/mtd_root.sum.bin

zip $OUTZIPFILE.zip $OUTDIR/$OUTFILE


