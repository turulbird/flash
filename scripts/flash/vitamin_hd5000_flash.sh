#!/bin/bash
# "-----------------------------------------------------------------------"
# " This script creates flashable images for this receiver:"
# " - Showbox Vitamin HD 5000 (256 MB NAND flash version)
# " with bootloader: V1.70.
#
# "Author: Schischu/Audioniek"
# "Date: 05-17-2019"   Last change 06-05-2019
#
# "-----------------------------------------------------------------------"
# "It is assumed that an image was already built prior to executing this"
# "script!"
# "-----------------------------------------------------------------------"
#

# Set up the variables
MKFSUBIFS=$TUFSBOXDIR/host/bin/mkfs.ubifs
UBINIZE=$TUFSBOXDIR/host/bin/ubinize
PAD=$TOOLSDIR/pad
MKIMAGE=mkimage

OUTFILE=usb_nand.img
OUTZIPFILE="$HOST"_256MB_NAND_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip

if [ "$BATCH_MODE" == "yes" ]; then
  FIMAGE=
else
  FIMAGE="image"
fi

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

echo -n " - Preparing kernel file..."
cp $TMPKERNELDIR/uImage $TMPDIR/uImage
$PAD 0x300000 $TMPDIR/uImage $TMPDIR/uImage.pad
echo " done."

echo -n " - Checking kernel size..."
SIZEK=`stat $TMPDIR/uImage -t --format %s`
SIZEKD=`printf "%d" $SIZEK`
SIZEKH=`printf "%08X" $SIZEK`
if [[ $SIZEKD > "3145728" ]]; then
  echo
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " KERNEL TOO BIG: 0x$SIZEKH instead of max. 0x00300000 bytes." > /dev/stderr
  echo " Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
else
  echo " OK: $SIZEKD (0x$SIZEKH, max. 0x00300000) bytes."
fi

if [ ! "$FIMAGE" == "kernel" ]; then
  echo -n " - Preparing UBIFS root file system..."
  # Minimum I/O size is 2048 => -m 2048
  # Logical erase block (LEB) size is physical erase block (PEB) size (131072) minus -m parameter => -e 129024
  # Number of erase blocks is partition size / physical eraseblock size: 252.5Mib / 131072 => -c 2020
  # Vitamin bootloader expects an lzo compressed ubifs => -x lzo
  # Key hash 5 => -k r5
  # 1 orphanage LEB => -p 1
  # Use 5 LEBs for logging: -l 5
  $MKFSUBIFS -d $TMPROOTDIR -m 2048 -e 129024 -c 2048 -x lzo -f 8 -k r5 -p 1 -l 5 $TMPDIR/mtd_root.ubi
# 2> /dev/null
  echo " done."

  echo -n " - Checking root size..."
  SIZE=`stat $TMPDIR/mtd_root.ubi -t --format %s`
  SIZEH=`printf "%08X" $SIZE`
  SIZED=`printf "%d" $SIZE`
  SIZEDS=$(expr $SIZED / 256)
  SIZEMAX=953568 # 244113408 / 256, to prevent overflows
  if [[ $SIZEDS > $SIZEMAX ]]; then  echo -e "\033[01;31m"
   echo
    echo -e "\033[01;31m"
    echo "-- ERROR! -------------------------------------------------------------"
    echo
    echo " ROOT TOO BIG: 0x$SIZEH instead of max. 0x0E8CE000 bytes." > /dev/stderr
    echo " Exiting..."
    echo
    echo "-----------------------------------------------------------------------"
    echo -e "\033[00m"
    exit
  else
    echo " OK: $SIZED (0x$SIZEH, max. 0x0E8CE000) bytes."
  fi

  echo -n " - Creating ubinize.ini file..."
  # Create ubi.ini
  echo "[rootfs]" > $TMPDIR/ubi.ini
  echo "mode=ubi" >> $TMPDIR/ubi.ini
  echo "image=$TMPDIR/mtd_root.ubi" >> $TMPDIR/ubi.ini
  echo "vol_id=0" >> $TMPDIR/ubi.ini
  # UBI needs some free erase blocks for bad PEB handling, say 128, so:
  # Net available for data: (2020 - 128) x 129024 = 244113408 bytes
  echo "vol_size=209793024" >> $TMPDIR/ubi.ini
  echo "vol_type=dynamic" >> $TMPDIR/ubi.ini
  # Vitamin bootloader requires the volume label rootfs
  echo "vol_name=rootfs" >> $TMPDIR/ubi.ini
  # Allow UBI to dynamically resize the volume
  echo "vol_flags=autoresize" >> $TMPDIR/ubi.ini
  echo "vol_alignment=1" >> $TMPDIR/ubi.ini
  echo " done."

  echo -n " - Creating UBI root image..."
  # UBInize the UBI partition of the rootfs
  # Physical eraseblock size (PEB) is 131072 => -p 131072
  # Subpage size is 512 bytes => -s 512
  # VID header offset = 512 => -O 512
  # version 1 => -x 1
  $UBINIZE -o $TMPDIR/mtd_root.ubin -p 131072 -m 2048 -O 512 -s 512 -x 1 $TMPDIR/ubi.ini 2> /dev/null
  echo " done."
fi

echo -n " - Creating flash file(s) and MD5(s)..."
cd $TOOLSDIR
cp vitamin_nandboot.bin $TMPDIR/update.dat
cat $TMPDIR/uImage.pad >> $TMPDIR/update.dat
cat $TMPDIR/mtd_root.ubin >> $TMPDIR/update.dat
$MKIMAGE -A sh -T firmware -n vitamin -d $TMPDIR/update.dat $OUTDIR/$OUTFILE > /dev/null
cd $CURDIR
# Create MD5 file
md5sum -b $OUTDIR/$OUTFILE | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
echo " done."

echo -n " - Creating .ZIP output file..."
cd $OUTDIR
zip -j $OUTZIPFILE $OUTFILE $OUTFILE.md5 > /dev/null
cd $CURDIR
echo " done."

if [ -e $OUTDIR/$OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " NOTE: The image and these instructions are only valid for a receiver"
  echo " that has been upgraded with 256 Mbyte NAND flash memory."
  echo
  echo " The receiver must be equipped with a normal bootloader V1.70"
  echo " with unmodified bootargs."
  echo
  echo " To flash the created image copy the file $OUTFILE to the root"
  echo " directory of a FAT32 formatted USB stick."
  echo
  echo " Insert the USB stick in the rear USB port, and switch on"
  echo " the receiver using the mains switch. After about one to two seconds"
  echo " briefly press the power key on the front panel."
  echo " The display should show USBUPGRADE."
  echo
  echo " Flashing the image will then begin."
  echo -e "\033[00m"
fi

# Clean up
#rm -f $TMPDIR/uImage
#rm -f $TMPDIR/uImage.pad
#rm -f $TMPDIR/update.dat
#rm -f $TMPDIR/mtd_root.ubi
#rm -f $TMPDIR/mtd_root.ubin
#rm -f $TMPDIR/ubi.ini

