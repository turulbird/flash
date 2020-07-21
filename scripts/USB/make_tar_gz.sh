#!/bin/bash
# -----------------------------------------------------------------------
# This script creates a tar.gz archive of the complete image suitable
# use with Eisha's TGZ-USB-INSTALLER plugin.
#
# Author: Audioniek, based on previous work by schishu and bpanther"
# Date: 08-12-2014"

# -----------------------------------------------------------------------
# It is assumed that an image was already built prior to executing this"
# script!"
# -----------------------------------------------------------------------
#
# Date     Who          Description
# 20190518 Audioniek    Vitamin HD 5000 added.
# 20190713 Audioniek    adb_box added.
# 20200629 Audioniek    Added Edision Argus VIP1/VIP2
# 20200711 Audioniek    Added Spiderbox HD HL-101
#
# -----------------------------------------------------------------------

# Set up the variables
MKFSEXT3=$TUFSBOXDIR/host/bin/mkfs.ext3
OUTFILE="$BOXTYPE"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"$GITVERSION"
OUTZIPFILE="$BOXTYPE"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"$GITVERSION.zip"

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

case $BOXTYPE in
  adb_box)
    cd $OUTDIR
    echo "-- Creating tar.gz output file ----------------------------------------"
    echo
    # Move kernel back to /boot
    mv $TMPKERNELDIR/uImage $TMPROOTDIR/boot/uImage
    echo -n " Compressing release image..."
    cd $TMPROOTDIR
    tar -zcf $OUTDIR/$OUTFILE.tar.gz . > /dev/null 2> /dev/null
    # Create MD5 file
    md5sum -b $OUTDIR/$OUTFILE.tar.gz | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
    echo " done."
    cd $OUTDIR
    echo -n " Pack everything in a zip..."
    zip -j -q $OUTZIPFILE *
    echo " done."
    cd $CURDIR
    ;;
  atevio7500|fortis_hdbox|octagon1008)
    cd $OUTDIR
    echo "-- Creating tar.gz output file ----------------------------------------"
    echo
    # Move kernel back to /boot
    mv $TMPKERNELDIR/uImage $TMPROOTDIR/boot/uImage
    echo -n " Compressing release image..."
    cd $TMPROOTDIR
    tar -zcf $OUTDIR/$OUTFILE.tar.gz . > /dev/null 2> /dev/null
    # Create MD5 file
    md5sum -b $OUTDIR/$OUTFILE.tar.gz | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
    echo " done."
    cd $OUTDIR
    echo -n " Pack everything in a zip..."
    zip -j -q $OUTZIPFILE *
    echo " done."
    cd $CURDIR
    ;;
  cuberevo|cuberevo_mini|cuberevo_mini2|cuberevo_250hd)
    cd $OUTDIR
    echo "-- Creating tar.gz output file ----------------------------------------"
    echo
    # Move kernel back to /boot
    mv $TMPKERNELDIR/uImage $TMPROOTDIR/boot/uImage
    echo -n " Compressing release image..."
    cd $TMPROOTDIR
    tar -zcf $OUTDIR/$OUTFILE.tar.gz . > /dev/null 2> /dev/null
    # Create MD5 file
    md5sum -b $OUTDIR/$OUTFILE.tar.gz | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
    echo " done."
    cd $OUTDIR
    echo -n " Pack everything in a zip..."
    zip -j -q $OUTZIPFILE *
    echo " done."
    cd $CURDIR
    ;;
  ufs910|ufs912|ufs913|ufs922|ufc960)
    cd $OUTDIR
    echo "-- Creating tar.gz output file ----------------------------------------"
    echo
    # Move kernel back to /boot
    mv $TMPKERNELDIR/uImage $TMPROOTDIR/boot/uImage
    # Move firmwares back
    mv $TMPFWDIR/audio.elf $TMPROOTDIR/boot/audio.elf
    mv $TMPFWDIR/video.elf $TMPROOTDIR/boot/video.elf
    echo -n " Compressing release image..."
    cd $TMPROOTDIR
    tar -zcf $OUTDIR/$OUTFILE.tar.gz . > /dev/null 2> /dev/null
    md5sum -b $OUTDIR/$OUTFILE.tar.gz | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
    echo " done."
    cd $OUTDIR
    echo -n " Pack everything in a zip..."
    zip -j -q $OUTZIPFILE *
    echo " done."
    cd $CURDIR
    ;;
  hl101|vip1_v2|vip2_v1)
    cd $OUTDIR
    echo "-- Creating tar.gz output file ----------------------------------------"
    echo
    # Move kernel back to /boot
    mv $TMPKERNELDIR/uImage $TMPROOTDIR/boot/uImage
    echo -n " Compressing release image..."
    cd $TMPROOTDIR
    tar -zcf $OUTDIR/$OUTFILE.tar.gz . > /dev/null 2> /dev/null
    # Create MD5 file
    md5sum -b $OUTDIR/$OUTFILE.tar.gz | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
    echo " done."
    cd $OUTDIR
    echo -n " Pack everything in a zip..."
    zip -j -q $OUTZIPFILE *
    echo " done."
    cd $CURDIR
    ;;
  vitamin_hd5000)
    echo "-- Creating output files -------------------------------------------"
    echo
    echo " Process uImage (kernel)"
    echo
    # Move kernel back to /boot
    mv $TMPKERNELDIR/uImage $TMPROOTDIR/boot/uImage
    echo -n " Creating root image $OUTFILE..."
    $MKFSEXT3 -r $TMPROOTDIR -o $TMPDIR/$OUTFILE -e 0x20000 -p -n > /dev/null
    mv $TMPDIR/$OUTFILE $OUTDIR/
    echo " done."
    cd $CURDIR
    ;;
esac
cd $CURDIR

if [ -e $OUTDIR/$OUTFILE.tar.gz ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
case $BOXTYPE in
  adb_box)
    echo " The receiver must be equipped with the Freebox bootloader."
    echo
    echo " Format a USB stick with an ext3 file system, and unpack the .tar.gz"
    echo " output file in its root directory, so that the entire rootfs of the"
    echo " image resides in the sticks root directory."
    echo
    echo " Press and hold the up arrow key on the receivers front panel and"
    echo " power it up by inserting the DC plug. The display will first show"
    echo " \"boot\" and then the currently selected boot option."
    echo " Select the option \"USba\" if the reciever does not have a hard disk"
    echo " (in general white models) or \"Usbb\" if it does have a built-in"
    echo " hard disk using the up and down arrow keys.When the desired option"
    echo " is shown, press the OK button on the front panel. Setting the boot"
    echo " option needs to be done only once."
    echo
    echo " Insert the thus prepared USB stick in the box's USB port,"
    echo " and switch on the receiver by insertying the DC power plug."
    ;;
  cuberevo|cuberevo_mini|cuberevo_mini2|cuberevo_250hd)
    echo " The receiver must be equipped with the original bootloader."
    echo
    echo " Format a USB stick with an ext2 file system, and unpack the .tar.gz"
    echo " output file in its root directory, so that the entire rootfs of the"
    echo " image resides in the sticks root directory."
    echo
    echo " Insert the thus prepared USB stick in the box's USB port,"
    echo " and switch on the receiver."
    ;;
  hl101|vip1_v2|vip2_v1)
    echo " The receiver must be equipped with a modified bootloader capable"
    echo " starting the file /boot/uImage off a USB stick."
    echo
    echo " Format a USB stick with an ext2 file system, and unpack the .tar.gz"
    echo " output file in its root directory, so that the entire rootfs of the"
    echo " image resides in the sticks root directory."
    echo
    echo " Insert the thus prepared USB stick in the box's USB port,"
    echo " and switch on the receiver."
    ;;
  atevio7500|fortis_hdbox|octagon1008)
    echo " The receiver must be equipped with the TDT maxiboot bootloader or"
    echo " a bootloader with similar capabilities. The bootloader must be able"
    echo " to boot the receiver by reading uImage from the first FAT32 formatted"
    echo " partition of a USB stick."
    echo " The rootfs of the image must reside on the second ext2 formatted"
    echo " partition on the same USB stick."
    echo
    echo " The kernel file is located in $TMPKERNELDIR"
    echo " The image rootfs is located in $TMPROOTDIR"
    echo " The entire image is also provided as .tar.gz in $OUTDIR"
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
    echo " To set the currently displayed boot option as default, press RED"
    echo " on the remote control while it is displayed."
    ;;
  ufs910|ufs912|ufs922|ufc960)
    echo " The receiver must be equipped with the TDT maxiboot bootloader or"
    echo " a bootloader with similar capabilities."
    echo " Prepare the USB stick per the instructions on the HDMU forum"
    echo " and unpack the .tar.gz file in one of its ext2 partitions,"
    echo " or use the AAF Recovery Tool program to prepare the USB-stick."
    echo
    echo " Insert the thus prepared USB stick in any of the box's USB ports,"
    echo " and switch on the receiver using the mains switch."
    echo " When the box displays its sign on (e.g. Kathrein UFS-910), press"
    echo " arrow down on the remote control to select the partition on"
    echo " the USB stick. The image will then be loaded and run."
    ;;
esac
    echo -e "\033[00m"
fi

