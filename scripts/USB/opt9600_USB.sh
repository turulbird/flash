#!/bin/bash
# -----------------------------------------------------------------------
#  This script creates the files needed to run Enigma2/Neutrino off an
#  USB stick for these Opticum/Orton receivers"
#  - HD 9600
#  - HD 9600 TS
#  - HD 9600 Mini
#  - HD 9600 Prima
#  - HD 9600 TS Prima
#
# Author: Schischu/Audioniek"
# Date: 26-12-2020"
#
# -----------------------------------------------------------------------
# Changes:
#
# -----------------------------------------------------------------------

# -----------------------------------------------------------------------
# It is assumed that an image was already built prior to executing this
#  script!"
# -----------------------------------------------------------------------
#

# Set up the variables
TMPDUMDIR=$TMPDIR/DUMMY
MKFSEXT3="mke2fs -t ext3"
MKCRC32=crc32

#OUTFILE="$BOXTYPE"_"$INAME""$IMAGE"_kernel_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".upd
#OUTFILETS="$BOXTYPE"_TS_"$INAME""$IMAGE"_kernel_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".upd
OUTZIPFILE="$HOST"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip
FLASDH_FILE="FALSE"

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
#cp $TMPKERNELDIR/uImage $OUTDIR/uImage
cp $TMPKERNELDIR/uImage $TMPROOTDIR/boot/uImage
echo " done."

#echo -n " - Checking kernel size..."
#SIZEK=`stat $TMPKERNELDIR/uImage -t --format %s`
#SIZEKD=`printf "%d" $SIZEK`
#SIZEKH=`printf "%08X" $SIZEK`
#KERNELSIZE=`printf "%x" $SIZEK`
#if [[ $SIZEKD > "4194304" ]]; then
#  echo
#  echo -e "\033[01;31m"
#  echo "-- ERROR! -------------------------------------------------------------"
#  echo
#  echo " KERNEL TOO BIG: 0x$SIZEKH instead of max. 0x00400000 bytes." > /dev/stderr
#  echo " Exiting..."
#  echo
#  echo "-----------------------------------------------------------------------"
#  echo -e "\033[00m"
#  exit
#else
#  echo " OK: $SIZEKD (0x$SIZEKH, max. 0x00400000) bytes."
#fi
#echo " done."

if [ "$FLASH_FILE"  == "TRUE" ]; then
  # Determine file size and CRC of kernel file
  echo -n " - Calculating CRC32..."
  KERNELCRC=`$MKCRC32 $TMPKERNELDIR/uImage`
  #KERNELCRCH=`printf "%08X" $KERNELCRC`
  echo " done ($KERNELCRC)."
  # Create .upd file header
  printf "\x00\x00\x00\x00\x00\x00\x10\x40" > $OUTDIR/$OUTFILE
  # add box identifier
  case $BOXTYPE in
    opt9600)
      printf "\x03\x06\x12\x07\x15\x67" >> $OUTDIR/$OUTFILE
      ;;
    opt9600mini)
      printf "\x07\x06\x14\x05\x15\x65" >> $OUTDIR/$OUTFILE
      ;;
    opt9600prima)
      printf "\x03\x06\x73\x07\x75\x67" >> $OUTDIR/$OUTFILE
      ;;
  esac
  #add version number
  printf "\x00\x10" >> $OUTDIR/$OUTFILE
  # add kernel length (litte endian)
  (echo $SIZEKH | awk '{print substr($0,length($0)-1,2)}') | xxd -r -p >> $OUTDIR/$OUTFILE
  (echo $SIZEKH | awk '{print substr($0,length($0)-3,2)}') | xxd -r -p >> $OUTDIR/$OUTFILE
  (echo $SIZEKH | awk '{print substr($0,length($0)-5,2)}') | xxd -r -p >> $OUTDIR/$OUTFILE
  (echo $SIZEKH | awk '{print substr($0,length($0)-7,2)}') | xxd -r -p >> $OUTDIR/$OUTFILE
  # add flash address
  printf "\x00\x00\x00\x00" >> $OUTDIR/$OUTFILE
  # add kernel crc (litte endian)
  echo $KERNELCRC | awk '{print substr($0,length($0)-1,2)}' | xxd -r -p >> $OUTDIR/$OUTFILE
   echo $KERNELCRC | awk '{print substr($0,length($0)-3,2)}' | xxd -r -p >> $OUTDIR/$OUTFILE
   echo $KERNELCRC | awk '{print substr($0,length($0)-5,2)}' | xxd -r -p >> $OUTDIR/$OUTFILE
   echo $KERNELCRC | awk '{print substr($0,length($0)-7,2)}' | xxd -r -p >> $OUTDIR/$OUTFILE
  # add filler
  printf "\xff\xff\xff\xff" >> $OUTDIR/$OUTFILE
  # add kernel binary
  cat $TMPKERNELDIR/uImage >> $OUTDIR/$OUTFILE

  # create separate .upd file for HD 9600 TS model if needed
  if [ "$BOXTYPE" == "opt9600" ]; then
    # Create .upd file header
    printf "\x00\x10\x00\x00\x00\x00\x10\x40" > $OUTDIR/$OUTFILETS
    # add box identifier
    printf "\x03\x06\x12\x07\x67\x55" >> $OUTDIR/$OUTFILETS
    #add version number
    printf "\x00\x10" >> $OUTDIR/$OUTFILETS
    # add kernel length (litte endian)
    echo $SIZEKH | awk '{print substr($0,length($0)-1,2)}' | xxd -r -p >> $OUTDIR/$OUTFILETS
    echo $SIZEKH | awk '{print substr($0,length($0)-3,2)}' | xxd -r -p >> $OUTDIR/$OUTFILETS
    echo $SIZEKH | awk '{print substr($0,length($0)-5,2)}' | xxd -r -p >> $OUTDIR/$OUTFILETS
    echo $SIZEKH | awk '{print substr($0,length($0)-7,2)}' | xxd -r -p >> $OUTDIR/$OUTFILETS
    # add flash address
    printf "\x00\x00\x00\x00" >> $OUTDIR/$OUTFILETS
    # add kernel crc (litte endian)
    echo $KERNELCRC | awk '{print substr($0,length($0)-1,2)}' | xxd -r -p >> $OUTDIR/$OUTFILETS
    echo $KERNELCRC | awk '{print substr($0,length($0)-3,2)}' | xxd -r -p >> $OUTDIR/$OUTFILETS
    echo $KERNELCRC | awk '{print substr($0,length($0)-5,2)}' | xxd -r -p >> $OUTDIR/$OUTFILETS
    echo $KERNELCRC | awk '{print substr($0,length($0)-7,2)}' | xxd -r -p >> $OUTDIR/$OUTFILETS
    # add filler
    printf "\xff\xff\xff\xff" >> $OUTDIR/$OUTFILETS
    # add kernel binary
    cat $TMPKERNELDIR/uImage >> $OUTDIR/$OUTFILETS
  fi
else
  cp $TMPKERNELDIR/uImage $OUTDIR/uImage
fi

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
sudo mount -o loop $OUTDIR/root.img $TMPDUMDIR
# copy the image to it
sudo cp -r . $TMPDUMDIR
sudo rm -rf lost+found
if [ -d $TMPDUMDIR/lost+found ];then
  sudo rmdir --ignore-fail-on-non-empty $TMPDUMDIR/lost+found
fi
sudo umount $TMPDUMDIR
cd $CURDIR
echo " done."

echo -n " - Add bootmenu.lst file ..."
cp $TOOLSDIR/opt9600_bootmenu.lst $OUTDIR/bootmenu.lst
echo " done."

echo -n " - Creating MD5 checksums..."
if [ "$FLASH_FILE"  == "TRUE" ]; then
  md5sum -b $OUTDIR/$OUTFILE | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
  md5sum -b $OUTDIR/root.img | awk -F' ' '{print $1}' > $OUTDIR/root.img.md5
  if [ "$BOXTYPE" == "opt9600" ]; then
    md5sum -b $OUTDIR/$OUTFILETS | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILETS.md5
  fi
else
  md5sum -b $OUTDIR/uImage | awk -F' ' '{print $1}' > $OUTDIR/uImage.md5
  md5sum -b $OUTDIR/root.img | awk -F' ' '{print $1}' > $OUTDIR/root.img.md5
fi
echo " done."

echo -n " - Creating .ZIP output file..."
cd $OUTDIR
if [ "$FLASH_FILE"  == "TRUE" ]; then
  zip -j $OUTZIPFILE $OUTDIR/$OUTFILE root.img $OUTDIR/$OUTFILE.md5 root.img.md5 > /dev/null
  if [ "$BOXTYPE" == "opt9600" ]; then
    zip -j $OUTZIPFILE $OUTDIR/$OUTFILETS $OUTDIR/$OUTFILETS.md5 > /dev/null
  fi
else
  zip -j $OUTZIPFILE $OUTDIR/uImage $OUTDIR/root.img $OUTDIR/uImage.md5 $OUTDIR/root.img.md5 > /dev/null
fi
cd $CURDIR
echo " done."

if [ -e $OUTDIR/$OUTZIPFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " The receiver must be equipped with a Enigma2 bootloader that is"
  echo " is capable of running the image off an USB stick."
  echo
  if [ "$FLASH_FILE"  == "TRUE" ]; then
    echo " To run the image off an USB stick, copy the files *kernel*.upd and"
    echo " root.img to the root directory of a FAT32 formatted USB stick."
    echo
    echo " Insert the USB stick in any of the box's USB ports, and switch on"
    echo " the receiver while holding the power key on the frontpanel."
    echo " Release the power key when the display shows SCAN USB."
    echo
    echo " The kernel will then be flashed. After flashing is complete,"
    echo " leave the USB stick in the receiver and wait until the receiver"
    echo " restarts. It will then run the image off the USB stick."
    echo
    echo " NOTE: to revert to the factory firmware, follow the same procedure,"
    echo " with the USB stick holding a factory firmware .upd file"
  else
    echo " To run the image off an USB stick, copy the files bootmenu.lst,"
    echo " uImage and root.img to the root directory of a FAT32"
    echo " formatted USB stick."
    echo
    echo " Insert the USB stick in any of the box's USB ports, and switch on"
    echo " the receiver. It will then run the image off the USB stick."
  fi
  echo -e "\033[00m"
fi

# Clean up
rm -f $TMPKERNELDIR/uImage
rm -f $TMPROOTDIR/uImage

