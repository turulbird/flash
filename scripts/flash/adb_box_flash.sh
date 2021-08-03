#!/bin/bash
# "-----------------------------------------------------------------------"
# " This script creates flashable images for these receivers:"
# " - ADB ITI-5800S (BSKA and BSLA models) and
# " - ADB ITI-5800SX (BXZB and BZZB models),
# " with Freebox or compatible bootloader set to NAND"
#
# "Author: Schischu/Audioniek"
# "Date: 05-30-2019"   Last change 10-05-2019
#
# "-----------------------------------------------------------------------"
# "It is assumed that an image was already built prior to executing this"
# "script!"
# "-----------------------------------------------------------------------"
#
# Date     Who          Description
# 20190717 Audioniek    Fix several errors.
# 20190721 Audioniek    Fix rootsfs size check.
# 20190907 Audioniek    Switch to UBI for rootfs.
# 20190908 Audioniek    Fix cleaning up.
# 20191003 Audioniek    Moved rootfs check forward before running
#                       ubinize.
# 20191005 Audioniek    Fix rootfs CRC32, improve update text, remove
#                       script flow error.
# 20210803 Audioniek    Created separate zip file with wireless drivers
#                       when built with WLAN.
#
# -----------------------------------------------------------------------

#

# Set up the variables
MKFSUBIFS=$TUFSBOXDIR/host/bin/mkfs.ubifs
UBINIZE=$TUFSBOXDIR/host/bin/ubinize
MKIMAGE=$TUFSBOXDIR/host/bin/mkimage
MKCRC32=crc32
OUTFILEK=kernel.img
OUTFILER=rootfs.img
OUTFILEU=update.img
OUTFILEU2=update
OUTZIPFILE="$HOST"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip
OUTZIPWFILE="$HOST"_USB_WLAN_drivers_"$GITVERSION".zip

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

# Check if built with WLAN. If so, remove the USB WLAN drivers
# from the root and place them in a separate zip file.
if [ `grep -e "wlandriver" $FLASHDIR/config` ]; then
  echo -n " - Creating .ZIP file with USB WLAN drivers..."
  for i in 8712u.ko 8188eu.ko 8192cu.ko 8192du.ko 8192eu.ko mt7601Usta.ko rt2870sta.ko rt3070sta.ko rt5370sta.ko;
  do
    md5sum -b $TMPROOTDIR/lib/modules/$i | awk -F' ' '{print $1}' > $TMPFWDIR/$i.md5
    zip -Tmu $OUTDIR/$OUTZIPWFILE $TMPROOTDIR/lib/modules/$i > /dev/null
    zip -Tju $OUTDIR/$OUTZIPWFILE $TMPFWDIR/$i.md5 > /dev/null
  done
  echo " done."
fi

if [ ! "$FIMAGE" == "image" ]; then
  echo -n " - Preparing kernel file..."
  cp $TMPKERNELDIR/uImage $TMPDIR
  echo " done."
  echo -n " - Calculating CRC32..."
  KERNELCRC=`$MKCRC32 $TMPKERNELDIR/uImage`
  echo " done ($KERNELCRC)."

  echo -n " - Checking kernel size..."
  SIZEK=`stat $TMPKERNELDIR/uImage -t --format %s`
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
fi

if [ ! "$FIMAGE" == "kernel" ]; then
  echo -n " - Preparing UBIFS root file system..."
  # The ADB ITI5800S(X) is equipped with an STM NAND512W3A NAND flash memory,
  # having the following properties:
  # - Page size: 512 bytes -> Minimum I/O size = 512 bytes => -m 512
  # - Subpage size = 256 bytes
  # - Block size: 16 kbytes or 16384 bytes
  # - Total number of blocks = 512 Mbit / 8 / 16384 (blocksize) = 4096
  # Logical erase block size (LEB) is physical erase block size (16384) minus -m parameter => -e 15872
  #
  # Receiver specifics:
  # The rootfs mtd has a size of 60 Mib
  # Number of erase blocks is partition size / physical eraseblock size: 60Mib / 16384 => -c 3840
  # The kernel supports a zlib compressed ubifs => -x zlib
  # Enigma2 is run as root => -U (changes ownership of all files to root)
  $MKFSUBIFS -d $TMPROOTDIR -m 512 -e 15872 -c 3840 -x zlib -U -o $TMPDIR/root.ubi
  echo " done."

  if [ -e $TMPDIR/root.ubi ]; then
    echo -n " - Checking root size..."
    SIZE=`stat $TMPDIR/root.ubi -t --format %s`
    SIZEH=`printf "%08X" $SIZE`
    SIZED=`printf "%d" $SIZE`
    SIZEDS=$(expr $SIZED / 16)
    SIZEMAX=3759680  # 60154880 / 16 (see below)
    SIZEMAXH=395E400  # 60154880 in hex (see below)
    ROOTSIZE=`printf "%x" $SIZE`
    if [[ $SIZEDS > $SIZEMAX ]]; then
      echo
      echo -e "\033[01;31m"
      echo "-- ERROR! -------------------------------------------------------------"
      echo
      echo " ROOTFS TOO BIG: 0x$SIZEH instead of max. 0x0$SIZEMAXH bytes." > /dev/stderr
      echo " Exiting..."
      echo
      echo "-----------------------------------------------------------------------"
      echo -e "\033[00m"
      exit
    else
      echo " OK: $SIZED (0x$SIZEH, max. 0x0$SIZEMAXH) bytes."
    fi
  else
    echo -e "\033[01;31m"
    echo "-- ERROR! -------------------------------------------------------------"
    echo
    echo " mkfs.ubifs failed: root.ubi not created." > /dev/stderr
    echo " Exiting..."
    echo
    echo "-----------------------------------------------------------------------"
    echo -e "\033[00m"
    exit
  fi

  echo -n " - Creating ubinize ini file..."
  # Create ubi.ini
  echo "[ubi-rootfs]" > $TMPDIR/ubi.ini
  echo "mode=ubi" >> $TMPDIR/ubi.ini
  echo "image=$TMPDIR/root.ubi" >> $TMPDIR/ubi.ini
  echo "vol_id=0" >> $TMPDIR/ubi.ini
  # UBI needs a few free erase blocks for bad PEB handling, say 50, so:
  # Net available for data: Number of (blocks in partition - 50 ) x LEB size => 3790 x 15872 = 60154880 bytes
  echo "vol_size=60154880" >> $TMPDIR/ubi.ini
  echo "vol_type=dynamic" >> $TMPDIR/ubi.ini
  # The kernel startup line uses the volume label rootfs
  echo "vol_name=rootfs" >> $TMPDIR/ubi.ini
  # Allow UBI to dynamically resize the volume
  echo "vol_flags=autoresize" >> $TMPDIR/ubi.ini
  echo "vol_alignment=1" >> $TMPDIR/ubi.ini
  echo " done."

  echo -n " - Creating UBI root image..."
  # UBInize the UBI partition of the rootfs
  # Physical eraseblock size is 16384 => -p 16KiB
  # Subpage size is 256 bytes => -s 256
  # UBI version number to put to EC headers = 1 => -x 1
  $UBINIZE -o $TMPDIR/root.ubin -p 16KiB -m 512 -s 256 -x 1 $TMPDIR/ubi.ini
  if [ ! -e $TMPDIR/root.ubin ]; then
      echo -e "\033[01;31m"
      echo "-- ERROR! -------------------------------------------------------------"
      echo
      echo " ubinize failed: root.ubin not created." > /dev/stderr
      echo " Exiting..."
      echo
      echo "-----------------------------------------------------------------------"
      echo -e "\033[00m"
      exit
  fi
  echo " done."

  echo -n " - Calculating CRC32..."
  ROOTCRC=`$MKCRC32 $TMPDIR/root.ubin`
  echo " done ($ROOTCRC)."
# note: root.ubin is not converted to an u-boot image

  # get root.ubin file length to use in update script building
  USIZE=`stat $TMPDIR/root.ubin -t --format %s`
  USIZEH=`printf "%08x" $USIZE`  # get length of root.ubin in hex
fi

# TODO: integrate uboot
echo -n " - Creating update.img file..."
cd $TMPDIR
echo "if crc32; then" > update.txt
  echo >> update.txt
  if [ -e uImage ]; then
    echo "vfd L--1" >> update.txt
    echo >> update.txt
    echo "if fatload usb 0:1 84010000 kernel.img; then" >> update.txt
    echo -e "\techo checking CRC32" >> update.txt
    echo -e "\tvfd C--1" >> update.txt
    echo -e "\tif crc32 -v 84010000 $KERNELSIZE $KERNELCRC,; then" >> update.txt
    echo -e "\t\tvfd S--1" >> update.txt
    echo -e "\t\tnand unlock 3c00000 400000" >> update.txt
    echo -e "\t\tnand erase 3c00000 400000" >> update.txt
    echo -e "\t\tnand write.i 84010000 3c00000 $KERNELSIZE" >> update.txt
    echo -e "\t\techo checking CRC32" >> update.txt
    echo -e "\t\tvfd C--1" >> update.txt
    echo -e "\t\tnand read.i 84010000 3c00000 $KERNELSIZE" >> update.txt
    echo -e "\t\tif crc32 -v 84010000 $KERNELSIZE $KERNELCRC,; then" >> update.txt
    echo -e "\t\t\techo CRC32 OK" >> update.txt
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
  fi
  if [ -e root.ubin ]; then
    echo "vfd L--2" >> update.txt
    echo "if fatload usb 0:1 84010000 rootfs.img; then" >> update.txt
    echo -e "\techo checking CRC32" >> update.txt
    echo -e "\tvfd C--2" >> update.txt
    echo -e "\tif crc32 -v 84010000 $USIZEH $ROOTCRC,; then" >> update.txt
    echo -e "\t\tvfd S--2" >> update.txt
    echo -e "\t\techo CRC32 OK" >> update.txt
    echo -e "\t\tnand unlock 0 3c00000" >> update.txt
    echo -e "\t\tnand erase 0 3c00000" >> update.txt
    echo -e "\t\tnand write.jffs2 84010000 0 $USIZEH" >> update.txt
    echo -e "\techo checking CRC32" >> update.txt
    echo -e "\t\tvfd C--2" >> update.txt
    echo -e "\t\tnand read.jffs2 84010000 0 $USIZEH" >> update.txt
    echo -e "\t\tif crc32 -v 84010000 $USIZEH $ROOTCRC,; then" >> update.txt
    echo -e "\t\t\techo CRC32 OK" >> update.txt
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
  fi
  echo >> update.txt
  echo "else" >> update.txt
  echo >> update.txt
  echo 'echo "Loader has no crc32 option; do not check CRC32"' >> update.txt
  echo >> update.txt
  if [ -e uImage ]; then
    echo "vfd L--1" >> update.txt
    echo "if fatload usb 0:1 84010000 kernel.img; then" >> update.txt
    echo -e "\tvfd S--1" >> update.txt
    echo -e "\tnand unlock 3c00000 400000" >> update.txt
    echo -e "\tnand erase 3c00000 400000" >> update.txt
    echo -e "\tnand write.i 84010000 3c00000 $KERNELSIZE" >> update.txt
    echo "else" >> update.txt
    echo -e "\tvfd LE-1" >> update.txt
    echo -e "\tstop" >> update.txt
    echo "fi" >> update.txt
    echo >> update.txt
  fi
  if [ -e root.ubin ]; then
    echo "vfd L--2" >> update.txt
    echo "if fatload usb 0:1 84010000 rootfs.img; then" >> update.txt
    echo -e "\tvfd S--2" >> update.txt
    echo -e "\tnand unlock 0 3c00000" >> update.txt
    echo -e "\tnand erase 0 3c00000" >> update.txt
    echo -e "\tnand write.jffs2 84010000 0 $USIZEH" >> update.txt
    echo "else" >> update.txt
    echo -e "\tvfd LE-2" >> update.txt
    echo -e "\tstop" >> update.txt
    echo "fi" >> update.txt
    echo >> update.txt
  fi
echo "fi" >> update.txt
echo "vfd -OK-" >> update.txt
echo 'echo "Rebooting in 5 seconds..."' >> update.txt
echo "sleep 5" >> update.txt
echo "reset" >> update.txt
echo >> update.txt
echo " done."

echo -n " - Creating update file..."
echo "if crc32 1000 1010; then" > update2.txt
  echo >> update2.txt
  if [ -e uImage ]; then
    echo -e '\tdisplay "READ kernel" U1-L;' >> update2.txt
    echo -e '\tif fatload usb 0:1 84010000 kernel.img; then' >> update2.txt
    echo -e "\t\techo checking CRC32;" >> update2.txt
    echo -e '\t\tdisplay "CHECK CRC32" U1-C;' >> update2.txt
    echo -e "\t\tif crc32 -v 84010000 $KERNELSIZE $KERNELCRC,; then" >> update2.txt
    echo -e "\t\t\techo CRC32 OK" >> update2.txt
    echo -e '\t\t\tdisplay "ERASE Flash" U1-E;' >> update2.txt
    echo -e '\t\t\tnand unlock 3c00000 400000;' >> update2.txt
    echo -e '\t\t\tnand erase 3c00000 400000;' >> update2.txt
    echo -e '\t\t\tdisplay "FLASH kernel" U1-F;' >> update2.txt
    echo -e "\t\t\tnand write.i 84010000 3c00000 $KERNELSIZE;" >> update2.txt
    echo -e "\t\t\techo checking CRC32;" >> update2.txt
    echo -e '\t\t\tdisplay "CHECK kernel" U1-C;' >> update2.txt
    echo -e "\t\t\tnand read.jffs2 84010000 3c00000 $KERNELSIZE;" >> update2.txt
    echo -e "\t\t\tif crc32 -v 84010000 $KERNELSIZE $KERNELCRC,; then" >> update2.txt
    echo -e "\t\t\t\techo CRC32 OK;" >> update2.txt
    echo -e "\t\t\telse" >> update2.txt
    echo -e '\t\t\t\tdisplay "CRC32 error" U1Er;' >> update2.txt
    echo -e "\t\t\t\texit;" >> update2.txt
    echo -e "\t\t\tfi;" >> update2.txt
    echo -e "\t\telse" >> update2.txt
    echo -e '\t\t\tdisplay "CRC32 error" U1Er;' >> update2.txt
    echo -e "\t\t\texit;" >> update2.txt
    echo -e "\t\tfi;" >> update2.txt
    echo -e '\telse' >> update2.txt
    echo -e '\t\tdisplay "ERROR kernel" U1Er;' >> update2.txt
    echo -e '\t\texit;' >> update2.txt
    echo -e '\tfi;' >> update2.txt
  fi
  if [ -e root.ubin ]; then
    echo -e '\tdisplay "READ rootfs" U2-L;' >> update2.txt
    echo -e '\tif fatload usb 0:1 84010000 rootfs.img; then' >> update2.txt
    echo -e "\t\techo checking CRC32;" >> update2.txt
    echo -e '\t\tdisplay "CHECK CRC32" U2-C;' >> update2.txt
    echo -e "\t\tif crc32 -v 84010000 $USIZEH $ROOTCRC,; then" >> update2.txt
    echo -e '\t\t\tdisplay "ERASE Flash" U2-E;' >> update2.txt
    echo -e "\t\t\tnand unlock 0 3c00000;" >> update2.txt
    echo -e "\t\t\tnand erase 0 3c00000;" >> update2.txt
    echo -e '\t\t\tdisplay "FLASH rootfs" U2-F;' >> update2.txt
    echo -e "\t\t\tnand write.jffs2 84010000 0 $USIZEH" >> update2.txt
    echo -e "\t\t\techo checking CRC32;" >> update2.txt
    echo -e '\t\t\tdisplay "CHECK rootfs" U2-C;' >> update2.txt
    echo -e "\t\t\tnand read.jffs2 84010000 0 $USIZEH" >> update2.txt
    echo -e "\t\t\tif crc32 -v 84010000 $USIZEH $ROOTCRC,; then" >> update2.txt
    echo -e "\t\t\t\techo CRC32 OK;" >> update2.txt
    echo -e "\t\t\telse" >> update2.txt
    echo -e '\t\t\t\tdisplay "CRC32 error" U2Er;' >> update2.txt
    echo -e "\t\t\t\texit;" >> update2.txt
    echo -e "\t\t\tfi;" >> update2.txt
    echo -e "\t\telse" >> update2.txt
    echo -e '\t\t\tdisplay "CRC32 error" U2Er;' >> update2.txt
    echo -e "\t\t\texit;" >> update2.txt
    echo -e "\t\tfi;" >> update2.txt
    echo -e "\telse" >> update2.txt
    echo -e '\t\tdisplay "ERROR rootfs" U2Er;' >> update2.txt
    echo -e '\t\texit;' >> update2.txt
    echo -e "\tfi;" >> update2.txt
  fi
  echo >> update2.txt
echo "else" >> update2.txt
  echo >> update2.txt
  echo -e '\techo "No crc32 option found; do not check CRC32"' >> update2.txt
  echo >> update2.txt
  if [ -e uImage ]; then
    echo -e '\tdisplay "READ kernel" U1-L;' >> update2.txt
    echo -e "\tif fatload usb 0:1 84010000 kernel.img; then" >> update2.txt
    echo -e '\t\tdisplay "ERASE Flash" U1-C;' >> update2.txt
    echo -e "\t\tnand unlock 3c00000 400000;" >> update2.txt
    echo -e "\t\tnand erase 3c00000 400000;" >> update2.txt
    echo -e '\t\tdisplay "FLASH kernel" U1-F;' >> update2.txt
    echo -e '\t\tnand write.i 84010000 3c00000 $filesize;' >> update2.txt
    echo -e "\telse" >> update2.txt
    echo -e '\t\tdisplay "ERROR uImage" U1-E;' >> update2.txt
    echo -e "\t\texit;" >> update2.txt
    echo -e "\tfi;" >> update2.txt
  fi
  if [ -e root.ubin ]; then
    echo -e '\tdisplay "READ rootfs" U2-L;' >> update2.txt
    echo -e "\tif fatload usb 0:1 84010000 rootfs.img; then" >> update2.txt
    echo -e '\t\tdisplay "ERASE Flash" U2-C;' >> update2.txt
    echo -e "\t\tnand unlock 0 3c00000;" >> update2.txt
    echo -e "\t\tnand erase 0 3c00000;" >> update2.txt
    echo -e '\t\tdisplay "FLASH rootfs" U2-F;' >> update2.txt
    echo -e '\t\tnand write.jffs2 84010000 0 $filesize;' >> update2.txt
    echo -e "\telse" >> update2.txt
    echo -e '\t\tdisplay "ERROR rootfs.img" U2-E;' >> update2.txt
    echo -e "\t\texit;" >> update2.txt
    echo -e "\tfi;" >> update2.txt
  fi
echo "fi;" >> update2.txt
echo 'display "Update OK" -OK-;' >> update2.txt
echo 'echo "Rebooting in 5 seconds..."' >> update2.txt
echo "sleep 5" >> update2.txt
echo "reset" >> update2.txt
echo >> update2.txt
echo " done."
cd $CURDIR

echo -n " - Creating flash files and MD5s..."
# update.img
$MKIMAGE -T script -C none -n update -d $TMPDIR/update.txt $OUTDIR/$OUTFILEU > /dev/null
# update
$MKIMAGE -T script -C none -n update -d $TMPDIR/update2.txt $OUTDIR/$OUTFILEU2 > /dev/null
# kernel.img
if [ -e $TMPDIR/uImage ]; then
  cp $TMPDIR/uImage $OUTDIR/$OUTFILEK
fi
# rootfs.img
if [ -e $TMPDIR/root.ubin ]; then
  cp $TMPDIR/root.ubin $OUTDIR/$OUTFILER
fi

# Create MD5 files
# update.img
md5sum -b $OUTDIR/$OUTFILEU | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILEU.md5
# update
md5sum -b $OUTDIR/$OUTFILEU2 | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILEU2.md5
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
zip -ju $OUTZIPFILE $OUTFILEU2 $OUTFILEU2.md5 > /dev/null
if [ -e $OUTFILEK ]; then
  zip -ju $OUTZIPFILE $OUTFILEK $OUTFILEK.md5 > /dev/null
fi
if [ -e $OUTFILER ]; then
  zip -ju $OUTZIPFILE $OUTFILER $OUTFILER.md5 > /dev/null
fi
if [ -e $OUTZIPWFILE ]; then
  zip -ju $OUTZIPFILE $OUTZIPWFILE > /dev/null
fi
cd $CURDIR
echo " done."

if [ -e $OUTDIR/$OUTZIPFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " The receiver must be equipped with a Freebox or Freebox compatible"
  echo " bootloader (B4T, MAGUS) that can boot from NAND flash mtd0."
  echo
  echo " To flash the created image copy these three or four files:"
  echo " - kernel.img (absent if image only)"
  echo " - rootfs.img (absent if kernel only)"
  echo " - update"
  echo " - update.img"
  echo " to the root directory of a FAT32 formatted USB stick."
  echo
  echo " Insert the USB stick in the box's USB port on the back."
  echo
  echo " If the receiver is equipped with the Freebox loader (signon is"
  echo " 'boot' or 'uboot...'), switch on the receiver by inserting the"
  echo " DC power plug while pressing and holding the power key on the"
  echo " frontpanel. Release the button when the display shows PROG."
  echo " Flashing the image will then begin."
  echo
  echo " If the receiver is equipped with the B4T loader (signon is"
  echo " 'nBox'), switch on the receiver by inserting the DC"
  echo " power plug while pressing and holding the arrow up key on the"
  echo " frontpanel. Wait 5 seconds, then use the arrow up and down keys"
  echo " to select the option UPDT and press the OK button on the"
  echo " front panel."
  echo " Flashing the image will then begin."
  echo -e "\033[00m"
fi

# Clean up
rm -f $TMPDIR/uImage
rm -f $TMPDIR/root.ubi
rm -f $TMPDIR/root.ubin
rm -f $TMPDIR/ubi.ini
rm -f $TMPDIR/update.txt
rm -f $TMPDIR/update2.txt

