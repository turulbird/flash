#!/bin/bash
# -----------------------------------------------------------------------
# This script creates a a set of files to be used on the following
# receivers in order to run neutrino/enigma2 off an USB stick:
# - Kathrein UFS910 (untested)
# - Kathrein UFS922
# - Kathrein UFC960 (untested)
#
# Due to the very small flash memory, this model use the following
# setup:
#  - Kernel: flashed in the same location as the factory kernel;
#  - Companion CPU firmwares: flashed in the same location as the factory
#    firmware;
#  - RootFS: on an ext2 formatted USB stick.
#
# Author: Audioniek, based on previous work by schishu and bpanther"
# Date: 13-06-2021"

# -----------------------------------------------------------------------
# It is assumed that an image was already built prior to executing this"
# script!"
# -----------------------------------------------------------------------
#
# Date     Who          Description
# 20210612 Audioniek    Initial version.
# 20210624 Audioniek    Update help text.
# 20210912 Audioniek    Fix spelling errors.
#
# -----------------------------------------------------------------------

# Set up the variables
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
MKFSEXT3=$TUFSBOXDIR/host/bin/mkfs.ext3

OUTFILE="$BOXTYPE"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"$GITVERSION"
OUTZIPFILE="$BOXTYPE"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION.zip"

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

case $BOXTYPE in
  ufs910)
    SIZE_KERNELD=1703936
    SIZE_KERNELH=1A0000
    SIZE_ROOTD=
    SIZE_ROOTH=
    SIZE_VARD=3014656
    SIZE_VARH=2E0000;;
 ufs922)
    SIZE_KERNELD=2883584
    SIZE_KERNELH=2C0000
    SIZE_UKERNELH=980000
    SIZE_ROOTD=
    SIZE_ROOTH=
    SIZE_VARD=2621440
    SIZE_VARH=280000;;
  ufc960)
    SIZE_KERNELD=1703936
    SIZE_KERNELH=1A0000
    SIZE_ROOTD=
    SIZE_ROOTH=
    SIZE_VARD=3014656
    SIZE_VARH=2E0000;;
esac

echo -n " - Prepare kernel file..."
cp $TMPKERNELDIR/uImage $TMPDIR/uImage
$PAD $SIZE_KERNELH $TMPDIR/uImage $TMPDIR/uImage.pad
echo " done."

echo -n " - Checking kernel size..."
SIZE=`stat $TMPDIR/uImage -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "0x%08X" $SIZE`
if [[ $SIZEH > "$SIZE_KERNELH" ]]; then
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " KERNEL TOO BIG. $SIZED (0x$SIZEH, max. 0x$SIZE_KERNELH) bytes." > /dev/stderr
  echo
  echo " Press ENTER to exit..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  read
  exit
else
echo " OK: $SIZED ($SIZEH, max. 0x00$SIZE_KERNELH) bytes."
fi

# --- Update kernel ---
echo -n " - Prepare update kernel file..."
cp $BASEDIR/ufsinstaller/uImage $TMPFWDIR/uImage
$PAD $SIZE_UKERNELH $TMPFWDIR/uImage $TMPFWDIR/uImage.pad
echo " done."

# --- ROOT ---
echo -n " - Create root tar.gz file..."
cd $TMPROOTDIR
tar -cvzf $OUTDIR/rootfs.tar.gz * > /dev/null
cd - > /dev/null
echo " done."
echo

case $BOXTYPE in
  ufs910|ufs922|ufc960)
    cd $OUTDIR/kathrein/$BOXTYPE
    echo "-- Creating Flash/USB files set ---------------------------------------"
    echo
    echo -n " Copy the update kernel..."
    cp $TMPDIR/uImage.pad ./uImage
    echo " done."
    echo -n " Creating updatescript.sh file..."
    echo "cmd=VFD=Image install   " > updatescript.sh
    echo "cmd=sleep 2" >> updatescript.sh
    echo "cmd=VFD=Update bootargs " >> updatescript.sh
    echo "cmd=setenv filesize" >> updatescript.sh
    echo "cmd=setenv bootdelay" >> updatescript.sh
    echo "cmd=setenv bootcmd" >> updatescript.sh
    echo "cmd=setenv bootargs" >> updatescript.sh
    echo "cmd=saveenv" >> updatescript.sh
    echo "cmd=setenv bootdelay 3" >> updatescript.sh
    echo "cmd=setenv ipaddr 192.168.0.106" >> updatescript.sh
    echo "cmd=setenv serverip 192.168.0.2" >> updatescript.sh
    echo "cmd=setenv gateway 192.168.0.1" >> updatescript.sh
    echo "cmd=setenv netmask 255.255.255.0" >> updatescript.sh
    echo "cmd=saveenv" >> updatescript.sh
    echo "cmd=VFD=Loading uImage  " >> updatescript.sh
    echo "cmd=usb reset; fatload usb 0:1 a4040000 /kathrein/ufs922/uImage" >> updatescript.sh
    echo "cmd=protect off a0040000 a02fffff" >> updatescript.sh
    echo "cmd=VFD=Erase (1 min.)  " >> updatescript.sh
    echo "cmd=erase a0040000 a02fffff" >> updatescript.sh
    echo "cmd=VFD=Flash (2 min.)  " >> updatescript.sh
    echo "cmd=cp.b a4040000 a0040000 2c0000" >> updatescript.sh
    echo "cmd=VFD=Loading updtkrnl" >> updatescript.sh
    echo "cmd=usb reset; fatload usb 0:1 a4040000 /uImage" >> updatescript.sh
    echo "cmd=protect off a0300000 a0c7ffff" >> updatescript.sh
    echo "cmd=VFD=Erase (1 min.)  " >> updatescript.sh
    echo "cmd=erase a0300000 a0c7ffff" >> updatescript.sh
    echo "cmd=VFD=Flash (3 min.)  " >> updatescript.sh
    echo "cmd=cp.b a4040000 a0300000 980000" >> updatescript.sh
    echo "cmd=setenv bootargs 'console=ttyAS0,115200 root=dev/ram0'" >> updatescript.sh
    echo "cmd=setenv bootcmd 'bootm a0300000'" >> updatescript.sh
    echo "cmd=saveenv" >> updatescript.sh
    echo "cmd=VFD=Reboot          " >> updatescript.sh
    echo "cmd=sleep 3" >> updatescript.sh
    echo "cmd=reset" >> updatescript.sh
    echo "cmd=EOF" >> updatescript.sh
    echo " done."
    echo -n " Creating updatescript1.sh file..."
    echo "cmd=VFD=Image inst (2)  " > updatescript1.sh
    echo "cmd=sleep 2" >> updatescript1.sh
    echo "cmd=VFD=Update bootargs " >> updatescript1.sh
    echo "cmd=setenv bootargs" >> updatescript1.sh
    echo "cmd=setenv bootcmd" >> updatescript1.sh
    echo "cmd=setenv bootargs ''console=ttyAS0,115200 root=/dev/sda1 rw init=/bin/devinit ip=::::ufs922:eth0:off mem=128m coprocessor_mem=4m@0x10000000,4m@0x10400000''" >> updatescript1.sh
    echo "cmd=setenv bootcmd ''bootm a0040000''" >> updatescript1.sh
    echo "cmd=saveenv" >> updatescript1.sh
    echo "cmd=sleep 4" >> updatescript1.sh
    echo "cmd=VFD=Final reboot    " >> updatescript1.sh
    echo "cmd=sleep 2" >> updatescript1.sh
    echo "cmd=reset" >> updatescript1.sh
    echo "cmd=EOF" >> updatescript1.sh
    echo " done."
    cd $OUTDIR
    echo -n " Copy the update kernel..."
    cp $TMPFWDIR/uImage.pad $OUTDIR/uImage
    echo " done."
    echo -n " Copy Enigma_Installer.ini..."
    cp $BASEDIR/ufsinstaller/Image_Installer.ini $OUTDIR/Image_Installer.ini
    echo " done."

    echo -n " Pack everything in a zip..."
    zip -r -q $OUTZIPFILE *
    echo " done."
    cd $CURDIR
    ;;
esac
cd $CURDIR

if [ -e $OUTDIR/$OUTZIPFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
case $BOXTYPE in
  ufs910|ufs922|ufc960)
    echo " The receiver must be equipped with the original factory bootloader."
    echo
    echo " Unpack the .zip file to the rootdirectory of a FAT32 formatted"
    echo "  USB stick."
    echo
    echo " The stick should now have a directory /kathrein with a"
    echo " subdirectory $BOXTYPE in it. This subdirectory should have the"
    echo " files in it:"
    echo " - directory kathrein/ufs922:"
    echo "   - updatescript.sh"
    echo "   - updatescript1.sh"
    echo "   - uImage"
    echo " - Image_Installer.ini"
    echo " - rootfs.tar.gz"
    echo " - uImage"
    echo
    echo " Switch the receiver off using the mains switch on the back."
    echo
    echo " Insert the USB stick in the USB port on the front (behind the lid"
    echo " for the CI modules)."
    echo " Press and hold the Record button on the receiver's front panel,"
    echo " and switch the receiver back on using the mains switch on the back."
    echo " Release the Record button when the display shows \"[ ]/UP2TE2/OPT\""
    echo
    echo " Press the button STOP on the front panel to start the installation."
    echo
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
    echo " receiver before flashing.";;
esac
    echo -e "\033[00m"
fi

