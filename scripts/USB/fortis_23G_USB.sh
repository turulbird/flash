#!/bin/bash
# "-----------------------------------------------------------------------"
# " This script creates the files needed to run Enigma2/Neutrino off an
# " USB stick for Fortis receivers:"
# " - HS7110
# " - HS7420
# " - HS7810A
# " - HS7119
# " - HS7429
# " - HS7819
# " with unmodified factory bootloader:
# " 6.46 or 6.47 (HS7110),
# " 6.36 or 6.37 (HS7420, NOT tested),
# " 6.26 or 6.27 (HS7810A)
# " 7.06 or 7.07 (HS7119),
# " 7.36 or 7.37 (HS7429) or
# " 7.26 or 7.27 (HS7819)
#
# "Author: Schischu/Audioniek"
# "Date: 16-12-2016"
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
dd if=/dev/zero of=$OUTDIR/root.img bs=1M count=256 2> /dev/null
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
  rmdir --ignore-fail-on-non-empty $TMPDUMDIR/lost+found
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
  echo " The receiver must be equipped with a standard Fortis bootloader that"
  echo " is capable of booting linux off an USB stick:"
  echo "  - HS7110 : 6.46 or 6.47"
  echo "  - HS7420 : 6.36 or 6.37"
  echo "  - HS7810A: 6.26 or 6.27"
  echo "  - HS7119 : 7.06 or 7.07"
  echo "  - HS7429 : 7.36 or 7.37"
  echo "  - HS7819 : 7.26 or 7.27"
  echo " with unmodified bootargs."
  echo
  echo " To use the stick prepare the receiver to boot from it by doing:"
  echo " Switch off the receiver using the switch on the back or by pulling the"
  echo " DC power plug as appropriate. Press and hold the key channel down on"
  echo " the front panel and switch on or put back the DC power plug with the"
  echo " other hand. Release the channel down key when the display showns ON."
  echo " If the display shows OFF, the feature was already on. In that case"
  echo " repeat the above procedure."
  echo " This needs to be done once."
  echo
  echo " To run the image off an USB stick, copy the files uImage and"
  echo " rootfs.img to the root directory of a FAT32 formatted USB stick."
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

