#!/bin/bash
# "-----------------------------------------------------------------------"
# "This script creates flashable images for Topfield TF77X0HDPVR receivers"
# "Author: Schischu/Audioniek, based on previous work by person(s) unknown"
# "Date: 07-12-2014"
# "-----------------------------------------------------------------------"
# "It is assumed that an image was already built prior to executing this"
# "script!"
# "-----------------------------------------------------------------------"

# Set up the variables
OUTZIPFILE="$HOST"_"$INAME"_"$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION"

echo -n " - Assembling flash file set..."
cp $TFINSTALLERDIR/Enigma_Installer.ini $OUTDIR
cp $TFINSTALLERDIR/Enigma_Installer.tfd $OUTDIR
cp $TFINSTALLERDIR/uImage $OUTDIR
cd $TMPROOTDIR
tar -cvzf $OUTDIR/rootfs.tar.gz * > /dev/null
cd - > /dev/null
echo " done."

echo -n " - Creating .MD5 and .ZIP output files..."
cd $OUTDIR
md5sum -b uImage | awk -F' ' '{print $1}' > uImage.md5
md5sum -b Enigma_Installer.tfd | awk -F' ' '{print $1}' > Enigma_Installer.tfd.md5
md5sum -b rootfs.tar.gz | awk -F' ' '{print $1}' > rootfs.tar.gz.md5
zip -j $OUTZIPFILE * > /dev/null
cd - > /dev/null
echo " done."

if [ -e $OUTDIR/rootfs.tar.gz ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " To flash the created image, copy the following files to the root (/)"
  echo " folder of your FAT32 formatted USB stick:"
  echo " - Enigma_Installer.ini"
  echo " - Enigma_Installer.tfd"
  echo " - uImage"
  echo " - rootfs.tar.gz"
  echo
  echo " Switch the receiver off and insert the stick in the receivers' USB"
  echo " port."
  echo
  echo " If the receiver is still only running the stock firmware, do the"
  echo " following extra steps (you need to do this only once):"
  echo " - Start the receiver with the stock firmware;"
  echo " - Press MENU on the remote control;"
  echo " - Select Installation in the main menu and press OK on the remote"
  echo "   control;"
  echo " - Select USB Firmware Upgrade in the Installation menu (you have"
  echo "   to scroll down to see it) and press OK on the remote control;"
  echo " - Select the file Enigma_Installer.tfd from the list and press OK"
  echo "   on the remote control;"
  echo " - Confirm the Are you sure question by selecting Yes and pressing"
  echo "   OK on the remote control;"
  echo " - When the receivers' display shows a blinking text END, switch"
  echo "   the receiver off leaving the USB stick connected. This is"
  echo "   the last of the extra steps."
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
  echo " Enigma_Installer.ini regarding the contents of the hard disk in the"
  echo " receiver before flashing."
  echo -e "\033[00m"
fi

