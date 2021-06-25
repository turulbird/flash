#!/bin/bash
# -----------------------------------------------------------------------
# This script creates a a set of files to be used on the following
# receiver in order to run neutrino/enigma2 off an USB stick:
# - Kathrein UFS910 (untested)
# - Kathrein UFS922
# - Kathrein UFC960 (untested)
#
# Due to their very small flash memories, these models use the following
# setup:
#  -Kernel: flashed in the same location as the factory kernel;
# - Companion CPU firmwares: flashed in the same location as the factory
#   kernel;
# RootFS: on an ext2 formwatted USB stick.
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
#
# -----------------------------------------------------------------------

# Set up the variables
PAD=$TOOLSDIR/pad
MKFSEXT3=$TUFSBOXDIR/host/bin/mkfs.ext3
OUTFILE="$BOXTYPE"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"$GITVERSION"
OUTZIPFILE="$BOXTYPE"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"$GITVERSION.zip"

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

echo
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
  echo " KERNEL TOO BIG. $SIZED ($SIZEH, max. $SIZE_KERNELH) bytes." > /dev/stderr
  echo
  echo " Press ENTER to exit..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  read
  exit
else
echo " OK: $SIZED ($SIZEH, max. $SIZE_KERNEHL) bytes."
fi

# --- VAR ---
echo -n " - Create a jffs2 partition for var..."
#echo "MKFSJFFS2 -qUf -p$SIZE_VAR -e0x20000 -r $TMPVARDIR -o $TMPDIR/mtd_var.bin"
$MKFSJFFS2 -qUf -p$SIZE_VAR -e0x20000 -r $TMPVARDIR -o $TMPDIR/mtd_var.bin 2> /dev/null
#echo "SUMTOOL -p -e 0x20000 -i $CURDIR/mtd_var.bin -o $CURDIR/mtd_var.sum"
$SUMTOOL -p -e 0x8000 -i $TMPDIR/mtd_var.bin -o $TMPDIR/mtd_var.sum
# echo "$PAD $SIZE_VAR $TMPDIR/mtd_var.sum.bin $TMPDIR/mtd_var.pad"
$PAD $SIZE_VAR $TMPDIR/mtd_var.sum $CURDIR/mtd_var.pad
echo " done."


case $BOXTYPE in
  ufs910|ufs922|ufc960)
    cd $OUTDIR
    mkdir /kathrein/$BOXTYPE
    cd kathrein/$BOXTYPE
    echo "-- Creating Flash/USB files set ---------------------------------------"
    echo
#    echo -n " Compressing release image..."
#    cd $TMPROOTDIR
#    tar -zcf $OUTDIR/$OUTFILE.tar.gz . > /dev/null 2> /dev/null
#    md5sum -b $OUTDIR/$OUTFILE.tar.gz | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
#    echo " done."
    echo -n "Copy the kernel..."
    # Move the kernel
    mv $TMP/uImage.pad $OUTDIR/$BOXTYPE/uImage
    echo " done."
    echo -n " Creating .img file for the firmwares..."
    # Move firmwares back
    cat $TMPFWDIR/audio.elf > $OUTDIR/$BOXTYPE/firmware.img
    cat $TMPFWDIR/video.elf >> $OUTDIR/$BOXTYPE/firmware.img
    echo " done."
    echo -n " Creating updatescript.sh file..."
    echo "cmd=VFD=Flash update" > updatescript.sh
    echo "cmd=sleep 2" >> $OUTDIR/$BOXTYPE
    echo "cmd=VFD=Loading uImage" >> $OUTDIR/$BOXTYPE
    echo "cmd=usb reset; fatload usb 0:1 a4040000 /kathrein/ufs922/uImage" >> updatescript.sh
    echo "cmd=sleep 1" >> updatescript.sh
    echo "cmd=protect off a0040000 a02fffff" >> updatescript.sh
    echo "cmd=VFD=Erase wait 1 min" >> updatescript.sh
    echo "cmd=erase a0040000 a02fffff" >> updatescript.sh
    echo "cmd=sleep 1" >> updatescript.sh
    echo "cmd=cp.b a4040000 a0040000 2c0000" >> updatescript.sh
    echo "cmd=sleep 1" >> updatescript.sh
    echo "cmd=set bootargs" >> updatescript.sh
    echo "cmd=set ipaddr 192.168.0.106" >> updatescript.sh
    echo "cmd=set serverip 192.168.0.2" >> updatescript.sh
    echo "cmd=set gateway 192.168.0.1" >> updatescript.sh
    echo "cmd=set netmask 255.255.255.0" >> updatescript.sh
    echo "cmd=set bootargs ''console=ttyAS0,115200 root=/dev/mtdblock2 ip=::::kathrein:eth0:off mem=128m init=/bin/devinit coprocessor_mem=4m@0x10000000,4m@0x10400000''" >> updatescript.sh
    echo "cmd=set bootcmd 'bootm a0040000'" >> updatescript.sh
    echo "cmd=saveenv" >> updatescript.sh
    echo "cmd=crc32 a0040000 2c0000" >> updatescript.sh
    echo "cmd=crc32 a4040000 2c0000" >> updatescript.sh
    echo "cmd=VFD=Ready to go" >> updatescript.sh
    echo "cmd=sleep 2" >> updatescript.sh
    echo "cmd=reset" >> updatescript.sh
    echo "cmd=EOF" >> updatescript.sh
    cd $OUTDIR
    echo -n " Pack everything in a zip..."
    zip -j -q $OUTZIPFILE *
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
  ufs910|ufs922|ufc960)
    echo " The receiver must be equipped with the original factory bootloader."
    echo
    echo " Unpack the .zip file to the rootdirectory of a FAT32 formatted"
    echo "  USB stick."
    echo
    echo " The stick should now have a directory /kathrein with a"
    echo " subdirectory $BOXTYPE in it. This subdirectory should have the"
    echo " files in it:"
    echo " - uImage"
    echo " - firmware.img"
    echo " - updatescript.sh"
    echo " - rootfs.tar.gz"
    echo
    echo " Switch the receiver off using the mains switch on the back."
    echo " Insert the USB stick in the USB port on the front (behind the lid"
    echo " for the CI modules)."
    echo " Press and hold the Record butten on the receiver's front panel,"
    echo " and switch the receiver back on using the mains switch on the back."
    echo " Release the Record button when the display shows \"
and unpack the .tar.gz file in one of its ext2 partitions,"
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

