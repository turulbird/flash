#!/bin/bash
# -----------------------------------------------------------------------
# This script creates a tar.gz archive of the complete image suitable
# use with Eisha's TGZ-USB-INSTALLER plugin.
#
# Author: Audioniek, based on previous work by schishu and bpanther"
# Date: 08-07-2014"

# -----------------------------------------------------------------------
# It is assumed that an image was already built prior to executing this"
# script!"
# -----------------------------------------------------------------------
#

OUTFILE="$BOXTYPE"_"$IMAGE"_USB_"$GITVERSION"

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

case $BOXTYPE in
  fortis_hdbox|octagon1008)
    cd $OUTDIR
    echo "-- Creating tar.gz output file ----------------------------------------"
    echo
#    echo -n " Rename kernel file uImage to uImage1..."
#    mv $TMPROOTDIR/boot/uImage $TMPROOTDIR/boot/uImage1
#    echo " done."
    echo -n " Compressing release image..."
    tar -pczf $OUTFILE.tar.gz $TMPROOTDIR > /dev/null 2> /dev/null
    echo " done."
    echo -n " Move kernel..."
    mv $TMPROOTDIR/boot/uImage $TMPKERNELDIR/uImage
    echo " done.";;
esac
cd $CURDIR

if [ -e $OUTDIR/$OUTFILE.tar.gz ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " The receiver must be equipped with the TDT maxiboot bootloader or"
  echo " a bootloader with similar capabilities. The bootloader must be able"
  echo " to boot the receiver by reading uImage from the first FAT32 formatted"
  echo " partition of a USB stick."
  echo " The rootfs of the image must reside on the second ext2 formatted"
  echo " partition on the same USB stick."
  echo
  echo " The kernel file is located in $TMPKERNELDIR"
  echo " The image rootfs is located in $TMPROOTDIR"
  echo
  echo " There are several ways to prepare the USB stick:"
  echo " - By hand using (G)parted and copying the files to the correct"
  echo "   partitions;"
  echo " - Under Windows: using the createMINI program;"
  echo " - On some receivers (e.g. Fortis) by using Eisha's TGZ installer"
  echo "   plugin."
  echo
  echo " Insert the thus prepared USB stick in any of the box's USB ports,"
  echo " and switch on the receiver using the mains switch."
  echo " With TDT maxiboot bootloader, select the partition and USB port to"
  echo " start from using the up and down buttons (RC or front panel)."
  echo " To set the currently display boot option as default, press RED on"
  echo " the remote control while it is displayed."
  echo -e "\033[00m"
fi

