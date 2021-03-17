#!/bin/bash
# "This script creates flashable images for Kathrein UFS913 receivers."
# "Author: Audioniek, based on previous work by Schischu"
# "Date: 01-31-2011, Last Change: 16-03-2021"
#
# "-----------------------------------------------------------------------"
# "An image is assumed to have been built prior to calling this script!
# "-----------------------------------------------------------------------"
#
# Date     Who          Description
# 20201003 Audioniek    Add file ufs913.software.V1.00.B00.data and
#                       change output file structure accordingly.
# 20201008 Audioniek    Fix typos.
# 20210316 Audioniek    Remove comment lines and fix some typos.
#
# -----------------------------------------------------------------------

# Set up the variables
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad

SIZE_KERNEL=0x00260000
SIZE_ROOT=0x03f80000  # allow for 4 bad blocks
SIZE_FW=0x00800000

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
  exit
else
  echo " OK: $SIZED ($SIZEH, max. $SIZE_KERNEL) bytes."
fi

echo -n " - Create a jffs2 partition for firmwares..."
$MKFSJFFS2 -qnUfl -m size -e 0x20000 -r $TMPFWDIR -o $TMPDIR/mtd_fw.bin > /dev/null
$SUMTOOL -p -e 0x20000 -i $TMPDIR/mtd_fw.bin -o $TMPDIR/mtd_fw.sum.bin
#$PAD $SIZE_FW $TMPDIR/mtd_fw.sum $TMPDIR/mtd_fw.sum.bin
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

# --- ROOT ---
echo -n " - Create a jffs2 partition for root..."
$MKFSJFFS2 -qnUf -m size -e 0x20000 -r $TMPROOTDIR -o $TMPDIR/mtd_root.bin > /dev/null
$SUMTOOL -p -e 0x20000 -i $TMPDIR/mtd_root.bin -o $TMPDIR/mtd_root.sum > /dev/null
$PAD $SIZE_ROOT $TMPDIR/mtd_root.sum $TMPDIR/mtd_root.sum.bin
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

#Create update file structure
cp $SCRIPTDIR/flash/ufs913.software.V1.00.B00.data $OUTDIR/kathrein/$BOXTYPE
mv $TMPDIR/uImage $OUTDIR/kathrein/$BOXTYPE/uImage.bin
mv $TMPDIR/mtd_fw.sum.bin $OUTDIR/kathrein/$BOXTYPE
mv $TMPDIR/mtd_root.sum.bin $OUTDIR/kathrein/$BOXTYPE

# Create MD5 files
echo -n " - Creating .md5 checksum files..."
cd $OUTDIR/kathrein/$BOXTYPE
md5sum -b ufs913.software.V1.00.B00.data | awk -F' ' '{print $1}' > ufs913.software.V1.00.B00.data.md5
md5sum -b uImage.bin | awk -F' ' '{print $1}' > uImage.bin.md5
md5sum -b mtd_fw.sum.bin | awk -F' ' '{print $1}' > mtd_fw.sum.bin.md5
md5sum -b mtd_root.sum.bin | awk -F' ' '{print $1}' > mtd_root.sum.bin.md5
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
  echo " Copy the folder kathrein and all of its contents to the root"
  echo " directory of your FAT32 formatted USB stick."
  echo
  echo " Switch the receiver off using the mains switch and connect the USB"
  echo " stick to the front USB connector. Remove all other USB devices from"
  echo " the receiver."
  echo
  echo " To start the flashing process, press and hold the key TV/R on the"
  echo " front panel and switch the receiver on."
  echo
  echo " Release the TV/R key when the display shows 'Emergency Upgrade'."
  echo " Flashing the image will now begin. During the flashing process"
  echo " the receiver will restart twice. The update is finished after the"
  echo " receiver has displayed the text 'UPDATE UMAGE' and has restarted"
  echo " for the last time. The flashed image will then start."
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

