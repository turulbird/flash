#!/bin/bash
# "This script creates flashable images for Kathrein UFS912 receivers."
# "Author: Audioniek, based on previous work by Schischu"
# "Date: 01-31-2011, Last Change: 13-01-2019"
#
# "-----------------------------------------------------------------------"
# "An image is assumed to have been built prior to calling this script!
# "-----------------------------------------------------------------------"

#TODO: add kernel, fw, kernel+root

# Set up the variables
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
MUP=$TOOLSDIR/mup
PAD=$TOOLSDIR/pad

SIZE_KERNEL=4194304
SIZE_ROOT=67108864
SIZE_FW=8388608
#SIZE_KERNELH=0x400000
SIZE_ROOTH=0x4000000
SIZE_FWH=0x800000

OUTFILE="$BOXTYPE"_"$INAME"_"$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"full".img
OUTZIPFILE="$HOST"_"$INAME"_"$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip

if [ -e $OUTDIR/kathrein ]; then
  rm -f $OUTDIR/kathrein/*
elif [ ! -d $OUTDIR/kathrein ]; then
  mkdir $OUTDIR/kathrein
fi

if [ -e $OUTDIR/kathrein/ufs912 ]; then
  rm -f $OUTDIR/kathrein/ufs912/*
elif [ ! -d $OUTDIR/kathrein/ufs912 ]; then
  mkdir $OUTDIR/kathrein/ufs912
fi

if [ -e $OUTDIR/kathrein/ufs912_Bargs ]; then
  rm -f $OUTDIR/kathrein/ufs912_Bargs/*
elif [ ! -d $OUTDIR/kathrein/ufs912_Bargs ]; then
  mkdir $OUTDIR/kathrein/ufs912_Bargs
fi

echo -n " - Prepare kernel file..."
cp $TMPKERNELDIR/uImage $TMPDIR/uImage
echo " done."

echo -n " - Checking kernel size..."
SIZE=`stat $TMPDIR/uImage -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "0x%08X" $SIZE`
if [[ $SIZED > $SIZE_KERNEL ]]; then
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
#$MKFSJFFS2 -qUfv -p0x4000000 -e0x20000 -r $TMPROOTDIR -o $TMPDIR/mtd_root.bin
$MKFSJFFS2 -qUf -e0x20000 -r $TMPROOTDIR -o $TMPDIR/mtd_root.bin > /dev/null
echo " done."

echo -n " - Checking root size..."
SIZE=`stat $TMPDIR/mtd_root.bin -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "0x%08X" $SIZE`
if [[ $SIZED > $SIZE_ROOT ]]; then
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
$SUMTOOL -p -e 0x20000 -i $TMPDIR/mtd_root.bin -o $TMPDIR/mtd_root.sum
$PAD $SIZE_ROOTH $TMPDIR/mtd_root.sum $TMPDIR/mtd_root.pad

echo -n " - Create a jffs2 partition for firmwares..."
#$MKFSJFFS2 -qUfv -p0x800000 -e0x20000 -r $TMPFWDIR -o $TMPDIR/mtd_fw.bin
$MKFSJFFS2 -qUf -e0x20000 -r $TMPFWDIR -o $TMPDIR/mtd_fw.bin > /dev/null
echo " done."

echo -n " - Checking firmware size..."
SIZE=`stat $TMPDIR/mtd_fw.bin -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "0x%08X" $SIZE`
if [[ $SIZED > $SIZE_FW ]]; then
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
$SUMTOOL -p -e 0x20000 -i $TMPDIR/mtd_fw.bin -o $TMPDIR/mtd_fw.sum
$PAD $SIZE_FWH $TMPDIR/mtd_fw.sum $TMPDIR/mtd_fw.pad

# Create a Kathrein update file for the firmwares
# To get the partitions erased we first need to fake an yaffs2 update
echo -n " - Create output files and MD5..."
cd $OUTDIR/kathrein/ufs912
$MUP -cs $OUTFILE << EOF
2
0x00400000, 0x800000, 3, foo
0x00C00000, 0x4000000, 3, foo
0x00000000, 0x0, 1, $TMPDIR/uImage
0x00400000, 0x0, 1, $TMPDIR/mtd_fw.pad
0x00C00000, 0x0, 1, $TMPDIR/mtd_root.pad
;
EOF

cp $SCRIPTDIR/flash/ufs912_updatescript.sh ../ufs912_Bargs/updatescript.sh

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
  echo " If the receiver is still running the factory firmware, perform"
  echo " the following steps on the USB stick in order to change the bootargs:"
  echo
  echo " 1. Rename the folder /kathrein/ufs912 to /katrein/ufs912_img"
  echo " 2. Rename the folder /kathrein/ufs912_Bargs to /kathrein/ufs912"
  echo
  echo " Switch the receiver off using the mains switch on the back and"
  echo " insert the USB stick into its front USB port."
  echo
  echo " To start changing the bootargs, press and hold the key TV/RADIO on"
  echo " the front panel and switch the receiver on using the mains switch."
  echo
  echo " Release the TV/RADIO key when the display shows EMERGENCY BOOT."
  echo " Changing the bootargs will now begin and is completed when the"
  echo " display shows UPDATE SUCCESS!"
  echo
  echo " Switch the receiver off using the mains switch and remove the USB"
  echo " stick. Perform the following steps:"
  echo " 1. Rename the folder /kathrein/ufs912 to /katrein/ufs912_Bargs"
  echo " 2. Rename the folder /kathrein/ufs912_img to /kathrein/ufs912"
  echo " NOTE: Changing the bootargs needs to be done only once."
  echo
  echo " -- Flashing the image --"
  echo " Switch the receiver off using the mains switch on the back and"
  echo " connect the USB stick to its front USB port."
  echo
  echo " To start the flashing process, press and hold the key TV/RADIO on the"
  echo " front panel and switch the receiver on using the mains switch."
  echo
  echo " Release the TV/RADIO key when the display shows EMERGENCY BOOT."
  echo " Flashing the image will now begin and is completed when the receiver"
  echo " reboots."
  echo -e "\033[00m"
fi

# Clean up
#rm -f $TMPDIR/uImage
#rm -f $TMPDIR/mtd_root.bin
#rm -f $TMPDIR/mtd_root.sum
#rm -f $TMPDIR/mtd_root.pad
#rm -f $TMPDIR/mtd_fw.bin
#rm -f $TMPDIR/mtd_fw.sum
#rm -f $TMPDIR/mtd_fw.pad

