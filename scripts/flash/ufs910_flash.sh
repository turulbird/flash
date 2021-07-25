#!/bin/bash
# "-----------------------------------------------------------------------"
# "This script creates the files set required to run an image off a hard
#  disk (either USB of later built in) on a Kathrein UFS910."
# "Author: Audioniek"
# "Last Change: 11-07-2021"
#
# "-----------------------------------------------------------------------"
# "An image is assumed to have been built prior to calling this script!
# "-----------------------------------------------------------------------"
# ---------------------------------------------------------------------------
# Changes:
# 20210627 Audioniek   Initial version.
#

# Set up the variables
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad
MKSQUASHFS4=$TOOLSDIR/mksquashfs4.2

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

#
# Notes on output file miniFLASH.img
#
# The file is simply a complete memory image from
# 0xa0040000 to 0xa0ffffff, that is the entire NOR
# flash area excluding:
# the original bootloader    (mtd0) 0xa0000000 to 0xa001ffff
# the bootloader environment (mtd7) 0xa0020000 to 0xa002ffff (with miniUboot)
# the miniUboot loader       (mtd8) 0xa0030000 to 0xa003ffff
#
# It is only accepted if it file length is exactly 0xfc0000 or 
# 16515072 bytes.
#
# This means that if you want to flash the (update)kernel only,
# the original Kathrein emergency root is overwritten, needlessly
# destroying an easy way to convert back to original.
# As the purpose in this case is to flash the (update) kernel
# only, it is padded with 0xff up to the mtd5 boundary, then the
# original mtd5 image is added, and the result is padded again
# with 0xff up to the desired file length.
#
OUTFILE=miniFLASH.img
OUTZIPFILE="$HOST"_"$IMAGE"_"P$PATCH"_"$GITVERSION"

# Define sizes of kernel, root, var and erase block
case "$BOXTYPE" in
  ufs910)
    echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=0x00220000
    SIZE_UKERNEL=0x00AA0000
    SIZE_OFILED=0x00FC0000;;
  *)
    echo "Unsupported receiver $BOXTYPE, assuming ufs910..."
    SIZE_KERNEL=0x00220000
    SIZE_UKERNEL=0x00AA0000
    SIZE_OFILED=0x00FC0000;;
esac

echo
echo -n " - Prepare kernel file..."
cp $TMPKERNELDIR/uImage $TMPDIR/uImage
$PAD $SIZE_KERNEL $TMPDIR/uImage $TMPDIR/uImage.pad
echo " done."

echo -n " - Checking kernel size..."
SIZE=`stat $TMPDIR/uImage -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "0x%08X" $SIZE`
if [[ $SIZEH > "$SIZE_KERNEL" ]]; then
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " KERNEL TOO BIG. $SIZED ($SIZEH, max. $SIZE_KERNEL) bytes." > /dev/stderr
  echo
  echo " Press ENTER to exit..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  read
  exit
else
echo " OK: $SIZED ($SIZEH, max. $SIZE_KERNEL) bytes."
fi

echo -n " - Prepare update kernel file..."
cp $BASEDIR/ufsinstaller/uImage $TMPFWDIR/uImage
$PAD $SIZE_UKERNEL $TMPFWDIR/uImage $TMPFWDIR/uImage.pad
echo " done."

echo -n " - Checking update kernel size..."
SIZE=`stat $TMPFWDIR/uImage -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "0x%08X" $SIZE`
if [[ $SIZEH > "$SIZE_UKERNEL" ]]; then
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " UPDATE KERNEL TOO BIG. $SIZED ($SIZEH, max. $SIZE_KERNEL) bytes." > /dev/stderr
  echo
  echo " Press ENTER to exit..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  read
  exit
else
echo " OK: $SIZED ($SIZEH, max. $SIZE_UKERNEL) bytes."
fi


# --- ROOT ---
echo -n " - Create tar.gz file for root..."
cd $TMPROOTDIR
tar -cvzf $OUTDIR/rootfs.tar.gz * > /dev/null
cd - > /dev/null
echo " done."
echo

# Create the output file structure
echo "-- Creating Flash/USB files set ---------------------------------------"
echo
echo -n " Copy the kernel..."
cd $OUTDIR/kathrein/$BOXTYPE
cp $TMPDIR/uImage.pad ./uImage
echo " done."
cd $OUTDIR
echo -n " Copy the update kernel..."
cat $TOOLSDIR/ufs910_mtd5.img >> $TMPFWDIR/uImage.pad
$PAD $SIZE_OFILED $TMPFWDIR/uImage.pad $TMPFWDIR/uImage.img
cp $TMPFWDIR/uImage.img $OUTDIR/$OUTFILE
echo " done."

echo -n " Copy Image_Installer.ini..."
cp $BASEDIR/ufsinstaller/Image_Installer.ini $OUTDIR/Image_Installer.ini
echo " done."
echo -n " Create MD5 checksums..."
md5sum -b $OUTFILE | awk -F' ' '{print $1}' > $OUTFILE.md5
md5sum -b Image_Installer.ini | awk -F' ' '{print $1}' > Image_Installer.ini.md5
cd $OUTDIR/kathrein/$BOXTYPE
md5sum -b uImage | awk -F' ' '{print $1}' > uImage.md5
echo " done."
cd $OUTDIR

echo -n " Creating .ZIP output file..."
zip -r -q $OUTZIPFILE *
echo " done."

if [ -e $OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  case "$BOXTYPE" in
    ufs910)
      echo
      echo " The receiver must be in its factory state with miniUboot"
      echo " and its default bootargs installed."
      echo
      echo " Unpack the .zip file to a convenient place on your computer."
      echo
      echo " Prepare the USB stick to be used for installing the image as follows:"
      echo " 1. Format the stick with a FAT32 file system. Do not use features"
      echo "    like quick format or similar."
      echo " 2. Only copy the file miniFLASH.img from the convenient place to"
      echo "    the root directory the freshly formatted stick."
      echo " 3. The copy the remaining files ad directories of the file set"
      echo "    this time omitting the file miniFLASH.img."
      echo " The purpose of all this is that the USB must have the entry for the"
      echo " file miniFLASH.img in its first directory entry, other wise the"
      echo " miniUboot flasher cannot find it."
      echo
      echo " The stick should now have a directory /kathrein with a"
      echo " subdirectory $BOXTYPE in it. The stick should hold the"
      echo " following files:"
      echo " - directory kathrein/$BOXTYPE:"
      echo "   - uImage"
      echo " - Image_Installer.ini"
      echo " - rootfs.tar.gz"
      echo " - miniFLASH.img"
      echo
      echo " Insert the USB stick in the front USB port on the receiver."
      echo
      echo " To start the flashing process press RECORD for 10 sec on your"
      echo " remote control while the receiver is starting. Hold the RECORD key"
      echo " until the front panal display shows 'miniFLASH search'."
      echo " The installation will finish automatically when no errors occur"
      echo " and the image will be started for the first time after the"
      echo " process is complete. The full installation involves two restarts."
      ;;
  esac
  echo -e "\033[00m"
fi
cd - > /dev/null

# Clean up
rm -f $CURDIR/uImage
rm -f $CURDIR/kernel.pad
rm -f $CURDIR/kernel.img

