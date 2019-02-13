#!/bin/bash
# "This script creates flashable images for Kathrein UFS913 receivers."
# "Author: Audioniek, based on previous work by Schischu"
# "Date: 01-31-2011, Last Change: 07-13-2014"
#
# "-----------------------------------------------------------------------"
# "An image is assumed to have been built prior to calling this script!
# "-----------------------------------------------------------------------"

# Set up the variables
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
MUP=$TOOLSDIR/mup
PAD=$TOOLSDIR/pad

SIZE_KERNEL=0x00400000
SIZE_ROOT=0x07800000
SIZE_FW=0x00800000

OUTFILE="$BOXTYPE"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"full".data
OUTZIPFILE="$HOST"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip

if [ -e $OUTDIR/kathrein ]; then
  rm -f $OUTDIR/kathrein/*
elif [ ! -d $OUTDIR/kathrein ]; then
  mkdir $OUTDIR/kathrein
fi

if [ -e $OUTDIR/kathrein/$BOXTYPE ]; then
  rm -f $OUTDIR/kathrein/$BOXTYPE/*
elif [ ! -d $OUTDIR/kathrein/$BOXTYPE ]; then
  mkdir $OUTDIR/kathrein/$BOXTYPE
fi

echo
echo -n " - Prepare kernel file..."
cp $TMPKERNELDIR/uImage $TMPDIR/uImage
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
echo -n " - Create a jffs2 partition for root..."
$MKFSJFFS2 -qnUf -e0x20000 -r $TMPROOTDIR -o $TMPDIR/mtd_root.bin > /dev/null
$SUMTOOL -p -e 0x20000 -i $TMPDIR/mtd_root.bin -o $TMPDIR/mtd_root.sum > /dev/null
$PAD $SIZE_ROOT $TMPDIR/mtd_root.sum $TMPDIR/mtd_root.pad
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
  echo " Exiting..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
else
echo " OK: $SIZED ($SIZEH, max. $SIZE_ROOT) bytes."
fi

echo -n " - Create a jffs2 partition for firmwares..."
$MKFSJFFS2 -qnUf -e0x20000 -r $TMPVARDIR -o $TMPDIR/mtd_fw.bin > /dev/null
$SUMTOOL -p -e 0x20000 -i $TMPDIR/mtd_fw.bin -o $TMPDIR/mtd_fw.sum
$PAD $SIZE_FW $TMPDIR/mtd_fw.sum $TMPDIR/mtd_fw.pad
echo " done."

echo -n " - Checking firmware size..."
SIZE=`stat $TMPDIR/mtd_fw.bin -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "0x%08X" $SIZE`
if [[ $SIZEH > "$SIZE_FW" ]]; then
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " FIRMWARES TOO BIG: $SIZED ($SIZEH, max. $SIZE_FW) bytes." > /dev/stderr
  echo
  echo " Press ENTER to exit..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  read
  exit
else
echo " OK: $SIZED ($SIZEH, max. $SIZE_FW) bytes."
fi

# Create a Kathrein update file
# To get the partitions erased we first need to fake an yaffs2 update
echo -n " - Create output file and MD5..."
cd $OUTDIR/kathrein/$BOXTYPE
$MUP -c $OUTFILE << EOF
3
0x00000000, 0x800000, 3, foo
0x00800000, 0x4000000, 3, foo
0x00400000, 0x0, 0, $TMPDIR/uImage
0x00000000, 0x0, 1, $TMPDIR/mtd_fw.sum
0x00800000, 0x0, 1, $TMPDIR/mtd_root.sum
;
EOF
# REMARK:
#  SUMTOOL destroys the padding added by MKFSJFFS2, so the intended padding in effect was absent.
#  This has been corrected by removing the MKFSJFFS2 padding altogether and adding and extra call to PAD.
#  To revert back to padded files, replace .sum (2x) by .pad in the lines directly above.

#cp $SCRIPTDIR/flash/"$BOXTYPE"_updatescript.sh updatescript.sh

# Create MD5 file
md5sum -b $OUTFILE | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
cd - > /dev/null
echo " done."

echo -n " - Creating .ZIP output file..."
cd $OUTDIR
zip -r $OUTZIPFILE `basename $OUTDIR/kathrein` > /dev/null
cd - > /dev/null
echo " done."

if [ -e $OUTDIR/kathrein/$BOXTYPE/$OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " The receiver must be equipped with the original boot loader."
  echo
  echo " Copy the folder kathrein and all of its contents to your FAT32"
  echo " formatted USB stick."
  echo
  echo " Switch the receiver off using the mains switch and connect the USB"
  echo " stick to it. Remove all other USB devices from the receiver."
  echo
  echo " To start the flashing process, press and hold the key TV/R on the"
  echo " front panel and switch the receiver on."
  echo
  echo " Release the TV/R key when the display shows EMERGENCY BOOT."
  echo " Flashing the image will now begin and is completed when the receiver"
  echo " switches to standby."
  echo -e "\033[00m"
fi

# Clean up
rm -f $TMPDIR/uImage
rm -f $TMPDIR/mtd_root.bin
rm -f $TMPDIR/mtd_root.sum
rm -f $TMPDIR/mtd_root.pad
rm -f $TMPDIR/mtd_fw.bin
rm -f $TMPDIR/mtd_fw.sum
rm -f $TMPDIR/mtd_fw.pad

