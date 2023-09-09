#!/bin/bash
# "-----------------------------------------------------------------------"
# "This script creates the files set required to run an image off a hard
# "disk (either USB or later built in) on a Edision argus VIP (version 1)"
# "model."
# "Author: Audioniek"
# "Last Change: 14-05-2023"
#
# "-----------------------------------------------------------------------"
# "It is assumed that an image was already built prior to executing this"
# "script!"
# "-----------------------------------------------------------------------"
# ---------------------------------------------------------------------------
# Changes:
# 20230514 Audioniek   Initial version.
#

# Set up the variables
OUTZIPFILE="$HOST"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION"

echo -n " - Assembling flash file set..."
cp $INSTALLERDIR/vip/Image_Installer.ini $OUTDIR
if [ ! -d $OUTDIR/boot ]; then
  mkdir $OUTDIR/boot
fi
cp $INSTALLERDIR/vip/uImage $OUTDIR/boot/uImage
cp $TMPKERNELDIR/uImage $OUTDIR/uImage.flash
cd $TMPROOTDIR
tar -cvzf $OUTDIR/rootfs.tar.gz * > /dev/null
cd - > /dev/null
echo " done."

echo -n " - Creating .MD5 and .ZIP output files..."
cd $OUTDIR
md5sum -b boot/uImage | awk -F' ' '{print $1}' > boot/uImage.md5
md5sum -b uImage.flash | awk -F' ' '{print $1}' > uImage.flash.md5
md5sum -b rootfs.tar.gz | awk -F' ' '{print $1}' > rootfs.tar.gz.md5
zip -j $OUTZIPFILE * > /dev/null
cd - > /dev/null
echo " done."

if [ -e $OUTDIR/rootfs.tar.gz ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " The receiver must be equipped with a bootloader that is capable of"
  echo " booting the file uImage off an USB stick."
  echo
  echo " To flash the created image, copy the following files to the root (/)"
  echo " folder of your FAT32 formatted USB stick:"
  echo " - boot/uImage"
  echo " - Image_Installer.ini"
  echo " - uImage.flash"
  echo " - rootfs.tar.gz"
  echo
  echo " Switch the receiver off and insert the stick in the receivers' front"
  echo " USB port."
  echo
  echo " To start the flashing process, switch the receiver on with the USB"
  echo " stick inserted."
  echo " Follow the instructions on the front panel display if you use an"
  echo " external USB hard disk: the USB stick possibly has to be removed"
  echo " to format that hard disk."
  echo
  echo " When the process is complete, the receiver will reboot automatically."
  echo " NOTE: It may take several minutes before a picture is shown on your"
  echo " television after that."
  echo
  echo " CAUTION: read, understand and if necessary change the file"
  echo " Image_Installer.ini regarding the contents of the hard disk in the"
  echo " receiver before flashing."
  echo -e "\033[00m"
fi

