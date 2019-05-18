#!/bin/bash
# "-----------------------------------------------------------------------"
# " This script creates the files needed to run Enigma2/Neutrino off an
# " USB stick for the Showbox Vitamin HD 5000.
#
# "Author: Schischu/Audioniek"
# "Date: 18-05-2019"
#
# "-----------------------------------------------------------------------"
# "It is assumed that an image was already built prior to executing this  "
# " script!"
# "-----------------------------------------------------------------------"
#

# Set up the variables
TMPDUMDIR=$TMPDIR/DUMMY
MKFSEXT3="mke2fs -t ext3"

OUTZIPFILE="$HOST"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

if [ -e $TMPDUMDIR ]; then
  rm -rf $TMPDUMDIR/*
elif [ ! -d $TMPDUMDIR ]; then
  mkdir -p $TMPDUMDIR
fi

echo -n " - Prepare kernel file..."
cp $TMPKERNELDIR/uImage $OUTDIR/uImage
cp $TMPKERNELDIR/uImage $TMPROOTDIR/boot/uImage
echo " done."

# remove old MAKEDEV
if [ -e $TMPROOTDIR/dev/MAKEDEV ]; then
  rm -f $TMPROOTDIR/dev/MAKEDEV
fi
if [ -e $TMPROOTDIR/sbin/MAKEDEV ]; then
  rm -f $TMPROOTDIR/sbin/MAKEDEV
fi

echo -n " - Preparing root image..."
dd if=/dev/zero of=$OUTDIR/root.img bs=1M count=192 2> /dev/null
# Create a ext3 partition for the complete root
cd $TMPROOTDIR
$MKFSEXT3 -q -F -L $IMAGE $OUTDIR/root.img
# mount the image file
#sudo mount -o loop $OUTDIR/root.img $TMPDUMDIR
mount -o loop $OUTDIR/root.img $TMPDUMDIR
# copy the image to it
#sudo cp -r . $TMPDUMDIR
cp -r . $TMPDUMDIR
#sudo rm -rf lost+found
if [ -d $TMPDUMDIR/lost+found ];then
#  sudo rmdir --ignore-fail-on-non-empty $TMPDUMDIR/lost+found
  rmdir --ignore-fail-on-non-empty lost+found
fi
#sudo umount $TMPDUMDIR
umount $TMPDUMDIR
cd $CURDIR
echo " done."

echo -n " - Creating MD5 checksums..."
md5sum -b $OUTDIR/uImage | awk -F' ' '{print $1}' > $OUTDIR/uImage.md5
md5sum -b $OUTDIR/root.img | awk -F' ' '{print $1}' > $OUTDIR/root.img.md5
echo " done."

echo -n " - Creating .ZIP output file..."
cd $OUTDIR
zip -j $OUTZIPFILE uImage root.img uImage.md5 root.img.md5 > /dev/null
cd $CURDIR
echo " done."

if [ -e $OUTDIR/$OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " The receiver must be equipped with a bootloader that is capable of"
  echo " booting linux off an USB stick."
  echo
  echo " To run the image off an USB stick, copy the files uImage and root.img"
  echo " to the root directory of an empty FAT32 formatted USB stick."
  echo
  echo " Insert the USB stick in any of the box's USB ports, and switch on"
  echo " the receiver. The receiver will then the boot from the USB stick and"
  echo " run the image."
  echo
  echo " To run the firmware programmed in flash memory, remove the USB stick"
  echo " before switching the receiver on."
  echo -e "\033[00m"
fi

# Clean up
rm -f $TMPKERNELDIR/uImage
rm -f $TMPROOTDIR/uImage

