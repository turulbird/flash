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
OUTZIPFILE="$HOST"_"$IMAGE"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION"

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
  echo " To start the flashing process, switch the receiver on with the USB"
  echo " stick inserted."
  echo " Follow the instructions on the front panel display if you use an"
  echo " external USB hard disk: the USB stick possibly has to be removed"
  echo " to format the hard disk."
  echo
  echo " When the process is complete, the receiver will reboot automatically."
  echo " NOTE: It may take several minutes before a picture is shown on your"
  echo " television after that."
  echo
  echo " CAUTION: read, understand and if necessary change the file"
  echo " Enigma_Installer.ini regarding the contents of your hard disk before"
  echo " flashing."
  echo -e "\033[00m"
fi

