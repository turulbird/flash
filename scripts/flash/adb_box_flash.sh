#!/bin/bash
# "-----------------------------------------------------------------------"
# " This script creates flashable images for these receivers:"
# " - ADB-box ITI-5800S (BSKA and BSLA models) and
# " - ADB-box ITI-5800SX (BZXB and BZZB models),
# " with Freebox or compatible bootloader"
#
# "Author: Schischu/Audioniek"
# "Date: 05-30-2019"   Last change 05-30-2019
#
# "-----------------------------------------------------------------------"
# "It is assumed that an image was already built prior to executing this"
# "script!"
# "-----------------------------------------------------------------------"
#

# Set up the variables
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad
MKIMAGE=mkimage
MKCRC32=crc32
OUTFILEK=kernel.img
OUTFILER=rootfs.img
OUTFILEU=update.img
OUTZIPFILE="$HOST"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip

if [ "$BATCH_MODE" == "yes" ]; then
  IMAGE=
else
  echo "-- Output selection ---------------------------------------------------"
  echo
  echo " What would you like to flash?"
  echo "   1) The $IMAGE image plus kernel (*)"
  echo "   2) Only the kernel"
  echo "   3) Only the $IMAGE image"
  read -p " Select flash target (1-3)? "
  case "$REPLY" in
#    1) echo > /dev/null;;
    2) FIMAGE="kernel";;
    3) FIMAGE="image";;
    *) echo > /dev/null;;
  esac
  echo "-----------------------------------------------------------------------"
  echo
fi

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

echo -n " - Preparing kernel file..."
cp $TMPKERNELDIR/uImage $TMPDIR/uImage
KERNELCRC=`$MKCRC32 $TMPDIR/uImage`
echo " done."

echo -n " - Checking kernel size..."
SIZEK=`stat $TMPDIR/uImage -t --format %s`
SIZEKD=`printf "%d" $SIZEK`
SIZEKH=`printf "%08X" $SIZEK`
KERNELSIZE=`printf "%x" $SIZEK`
if [[ $SIZEKD > "4194304" ]]; then
  echo
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " KERNEL TOO BIG: 0x$SIZEKH instead of max. 0x00400000 bytes." > /dev/stderr
  echo " Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
else
  echo " OK: $SIZEKD (0x$SIZEKH, max. 0x00400000) bytes."
fi

if [ ! "$FIMAGE" == "kernel" ]; then
  echo -n " - Preparing JFFS root file system..."
  # Create a jffs2 partition for the complete root
  $MKFSJFFS2 -qUfl -e 0x20000 -r $TMPROOTDIR -o $TMPDIR/root.bin
  $SUMTOOL -p -l -e 0x20000 -i $TMPDIR/root.bin -o $TMPDIR/root.sum > /dev/null
  # Padding the root up maximum size is required to force JFFS2 to find
  # only erased flash blocks on the initial kernel run.
  $PAD 0x3C00000 $TMPDIR/root.sum $TMPDIR/root.pad
  echo " done."
fi
echo -n " - Checking root size..."
SIZE=`stat $TMPDIR/root.bin -t --format %s`
SIZEH=`printf "%08X" $SIZE`
SIZED=`printf "%d" $SIZE`
ROOTSIZE=`printf "%x" $SIZE`
if [[ $ROOTSIZE > "62914560" ]]; then
  echo -e "\033[01;31m"
  echo
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " ROOT TOO BIG: 0x$SIZEH instead of max. 0x03C00000 bytes." > /dev/stderr
  echo " Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
else
  echo " OK: $ROOTSIZE (0x$SIZEH, max. 0x03C00000) bytes."
fi
ROOTCRC=`$MKCRC32 $TMPDIR/root.pad`
# note: rootfs is not converted to an u-boot image

# TODO: integrate uboot and depencies for kernel-only/image-only
echo -n " - Creating update.img file..."
cd $OUTDIR
echo "if crc32; then" > update.txt
echo >> update.txt
echo "vfd L--1" >> update.txt
echo >> update.txt
echo "if fatload usb 0:1 84010000 kernel.img; then" >> update.txt
echo -e "\tif crc32 -v 84010000 $KERNELSIZE $KERNELCRC; then" >> update.txt
echo -e "\t\tvfd S--1" >> update.txt
echo -e "\t\tnand unlock" >> update.txt
echo -e "\t\tnand erase 3c00000 400000" >> update.txt
echo -e "\t\tnand write.i 84010000 3c00000 $KERNELSIZE" >> update.txt
echo -e "\t\tnand read.i 84010000 3c00000 $KERNELSIZE" >> update.txt
echo -e "\t\tif crc32 -v 84010000 $KERNELSIZE $KERNELCRC; then" >> update.txt
echo -e "\t\t\techo" >> update.txt
echo -e "\t\telse" >> update.txt
echo -e "\t\t\tvfd CS-1" >> update.txt
echo -e "\t\t\tstop" >> update.txt
echo -e "\t\tfi" >> update.txt
echo -e "\telse" >> update.txt
echo -e "\t\tvfd CR-1" >> update.txt
echo -e "\t\tstop" >> update.txt
echo -e "\tfi" >> update.txt
echo -e "else" >> update.txt
echo -e "\tvfd LE-1" >> update.txt
echo -e "\tstop" >> update.txt
echo "fi" >> update.txt
echo >> update.txt
echo "vfd L--2" >> update.txt
echo "if fatload usb 0:1 84010000 rootfs.img; then" >> update.txt
echo -e "\tif crc32 -v 84010000 $ROOTSIZE $ROOTCRC; then" >> update.txt
echo -e "\t\tvfd S--2" >> update.txt
echo -e "\t\tnand unlock" >> update.txt
echo -e "\t\tnand erase 0 3c00000" >> update.txt
echo -e "\t\tnand write.jffs2 84010000 0 $ROOTSIZE" >> update.txt
echo -e "\t\tnand read.jffs2 84010000 0 $ROOTSIZE" >> update.txt
echo -e "\t\tif crc32 -v 84010000 $ROOTSIZE $ROOTCRC; then" >> update.txt
echo -e '\t\t\techo ""' >> update.txt
echo -e "\t\telse" >> update.txt
echo -e "\t\t\tvfd CS-2" >> update.txt
echo -e "\t\t\tstop" >> update.txt
echo -e "\t\tfi" >> update.txt
echo -e "\telse" >> update.txt
echo -e "\t\tvfd CR-2" >> update.txt
echo -e "\t\tstop" >> update.txt
echo -e "\tfi" >> update.txt
echo "else" >> update.txt
echo -e "\tvfd LE-2" >> update.txt
echo -e "\tstop" >> update.txt
echo "fi" >> update.txt
echo >> update.txt
echo "vfd -OK-" >> update.txt
echo "stop" >> update.txt
echo >> update.txt
echo "else" >> update.txt
echo >> update.txt
echo 'echo "No crc32 program found; do not check u-boot CRC32"' >> update.txt
echo >> update.txt
echo "vfd L--1" >> update.txt
echo "if fatload usb 0:1 84010000 kernel.img; then" >> update.txt
echo -e "\tvfd S--1" >> update.txt
echo -e "\tnand unlock" >> update.txt
echo -e "\tnand erase 3c00000 400000" >> update.txt
echo -e "\tnand write.i 84010000 3c00000 $KERNELSIZE" >> update.txt
echo "else" >> update.txt
echo -e "\tvfd LE-1" >> update.txt
echo -e "\tstop" >> update.txt
echo "fi" >> update.txt
echo >> update.txt
echo "vfd L--2" >> update.txt
echo "if fatload usb 0:1 84010000 rootfs.img; then" >> update.txt
echo -e "\tvfd S--2" >> update.txt
echo -e "\tnand unlock" >> update.txt
echo -e "\tnand erase 0 3c00000" >> update.txt
echo -e "\tnand write.jffs2 84010000 0 3174000" >> update.txt
echo "else" >> update.txt
echo -e "\tvfd LE-2" >> update.txt
echo -e "\tstop" >> update.txt
echo "fi" >> update.txt
echo >> update.txt
echo "vfd -OK-" >> update.txt
echo "stop" >> update.txt
echo >> update.txt
echo "fi" >> update.txt
# update.img
mkimage -T script -C none -n update -d update.txt $OUTDIR/$OUTFILEU > /dev/null
echo " done."
cd $CURDIR

echo -n " - Creating flash files and MD5s..."
# kernel.img
if [ -e $TMPDIR/uImage ]; then
  mkimage -A sh -T kernel -C gzip -a 0x84001000 -e 0x84002000 -n Linux-2.6.32.71_stm24_0217 -d $TMPDIR/uImage $OUTDIR/$OUTFILEK > /dev/null
fi
# rootfs.img
if [ -e $TMPDIR/root.pad ]; then
  cp $TMPDIR/root.pad $OUTDIR/$OUTFILER
fi

# Create MD5 files
# update.img
md5sum -b $OUTDIR/$OUTFILEU | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILEU.md5
# kernel.img
if [ -e $OUTDIR/$OUTFILEK ]; then
  md5sum -b $OUTDIR/$OUTFILEK | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILEK.md5
fi
# rootfs.img
if [ -e $OUTDIR/$OUTFILER ]; then
  md5sum -b $OUTDIR/$OUTFILER | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILER.md5
fi
echo " done."

echo -n " - Creating .ZIP output file..."
cd $OUTDIR
zip -j $OUTZIPFILE $OUTFILEU $OUTFILEU.md5 > /dev/null
if [ -e $OUTDIR/$OUTFILEK ]; then
  zip -ju $OUTZIPFILE $OUTFILEK $OUTFILEK.md5 > /dev/null
fi
if [ -e $OUTDIR/$OUTFILER ]; then
  zip -ju $OUTZIPFILE $OUTFILER $OUTFILER.md5 > /dev/null
fi
cd $CURDIR
echo " done."

if [ -e $OUTDIR/$OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " The receiver must be equipped with a Freebox bootloader with"
  echo " unmodified bootargs."
  echo
  echo " To flash the created image copy these two or three files:"
  echo " - kernel.img (absent if image only)"
  echo " - rootfs.img (absent if kernel only)"
  echo " - update.img"
  echo " to the root directory of a FAT32 formatted USB stick."
  echo
  echo " Insert the USB stick in the box's USB port on the back, and switch on"
  echo " the receiver by inserting the DC power plug while pressing and"
  echo " holding the power key on the frontpanel."
  echo " Release the button when the display shows PROG."
  echo " Flashing the image will then begin."
  echo -e "\033[00m"
fi

# Clean up
rm -f $TMPDIR/uImage
rm -f $TMPDIR/root.bin
rm -f $TMPDIR/root.sum
rm -f $TMPDIR/root.pad
rm -f $OUTDIR/update.txt

