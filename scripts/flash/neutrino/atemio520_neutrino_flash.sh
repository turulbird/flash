#!/bin/bash
# "-----------------------------------------------------------------------"
# " This script creates Neutrino .ird flash files for Crenova receiver:"
# " - Atemio AM 520 HD"
# " with unmodified factory i-boot bootloader 6.40."
#
# "Version for NAND flash, UBI file system."
#
# "Author: Schischu/Audioniek"
# "Date: 17-09-2021"
#
# "-----------------------------------------------------------------------"
# "It is assumed that a neutrino image was already built prior to"
# "executing this script!"
# "-----------------------------------------------------------------------"
#
# If only the kernel is to be reflashed, the partitions 8, 7 and 1 are
# also reflashed (requirement of loader 6.40). Partition 1 is flashed as
# the squashfs dummy only, leaving the neutrino part of it untouched.
#
# "-----------------------------------------------------------------------"
#
# Date     Who          Description
# 20210912 Audioniek    Initial version.
# 20211024 Audioniek    Pad root to maximum size.
# 20211101 Audioniek    Fix small problem with batch mode.
#
# -----------------------------------------------------------------------

if [ "$BATCH_MODE" == "yes" ]; then
  IMAGE=
else
  echo "-- Output selection ---------------------------------------------------"
  echo
  echo " What would you like to flash?"
  echo "   1) The whole $IMAGE image (*)"
  echo "   2) Only the kernel"
  read -p " Select flash target (1-2)? "
  case "$REPLY" in
    1) echo > /dev/null;;
    2) IMAGE="kernel";;
    *) echo > /dev/null;;
  esac
  echo "-----------------------------------------------------------------------"
  echo
fi

# Set up the variables
TMPDUMDIR=$TMPDIR/DUMMY
#MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
#SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad
MKSQUASHFS=$TOOLSDIR/mksquashfs3.3
MKFSUBIFS=$TUFSBOXDIR/host/bin/mkfs.ubifs
UBINIZE=$TUFSBOXDIR/host/bin/ubinize
FUP=$TOOLSDIR/fup

OUTFILE="$BOXTYPE"_"$IMAGE"_flash_R$RESELLERID.ird
OUTZIPFILE="$HOST"_"$IMAGE"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip

if [ -e $TMPDUMDIR ]; then
  rm -rf $TMPDUMDIR/*
elif [ ! -d $TMPDUMDIR ]; then
  mkdir -p $TMPDUMDIR
fi

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

echo -n " - Preparing kernel file..."
# Note: padding the kernel to set start offset of type 8 (root) does not work;
# boot loader always uses the actual kernel size (at offset 0x0c?) to find/check
# the root.
# CAUTION for a known problem: a kernel with a size that is an exact multiple
# 0x20000 bytes cannot be flashed, due to a bug in the loader.
# This condition is tested for in this script later on.
cp $TMPKERNELDIR/uImage $TMPDIR/uImage
echo " done."

echo -n " - Checking kernel size..."
SIZEK=`stat $TMPKERNELDIR/uImage -t --format %s`
SIZEKD=`printf "%d" $SIZEK`
SIZEKH=`printf "%08X" $SIZEK`
if [[ $SIZEKD < "1048577" ]]; then
  echo
  echo "-- REMARK -------------------------------------------------------------"
  echo
  echo -e "\033[01;31m"
  echo "Kernel is smaller than 1 Mbyte." > /dev/stderr
  echo "Are you sure this is correct?" > /dev/stderr
  echo "Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
fi
if [[ $SIZEKD > "3145728" ]]; then
  echo
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " KERNEL TOO BIG: 0x$SIZEKH instead of max. 0x002FFFFF bytes." > /dev/stderr
  echo " Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
else
  echo " OK: $SIZEKD (0x$SIZEKH, max. 0x002FFFFF) bytes."
fi

echo -n " - Adjusting fake root partition size..."
# Note: The type 8 partition is always flashed directly following the kernel
# at the address the i-boot loader expects it based on the partition size of
# the kernel. The type 8 partition will at least occupy one erase block.
# Because the kernel can vary in size up to 3 Mbyte, the fake root squashfs
# partition preceeding the real rootfs must be adjusted in size in such a way
# that the real rootfs is always flashed at offset 0x38000.
# The dummy app squashfs is filled with one file filled with random bytes (to
# limit # compressing as much as possible).
# The overhead of the squashfs dummy is about 228 bytes.
# It is desirable that the squashfs dummy ends about in the middle of an erase
# block. This will achieve that the resizing during flashing has the greatest
# chance of resulting in the desired flash offset for the real rootfs at
# offset 0x380000.
#
# The actual kernel will end at offset kernel offset plus $SIZEKD. The
# flashing process will round this up to the next erase block boundary
# automatically.
#
# The end address of the fake file in the dummy squashfs is:
# 1. The kernel end address (automatically rounded up to the next erase block
#    boundary)
# 2. The squashfs overhead (228 bytes)
# 3. Length of the file with random bytes within the squashfs
#
# The size of the fake file in the dummy squashfs is therefore approximately:
#
# FAKESIZE = desired offset - (kernel offset + $SIZEKD) - squashfs overhead - (erasesize / 2)
#          = 0x380000 - 0x60000 - $SIZEKD - 228 - 0x20000 / 2
#          = 3670016 - 393216 - $SIZEKD - 228 - 65536
#          = 3276572 - $SIZEKD - 65536.
#
FAKESIZEN=$(expr 3211036 - $SIZEKD)

# Determine fake root size
if [[ $SIZEKD < "3145729" ]] && [[ $SIZEKD > "3014656" ]]; then # < 0x2E0000, > 0x2C00000, kernel ends at 0x360000 
  FAKESIZE="65308"  # 0x010000 - 228
else
  FAKESIZE="999" #used to flag illegal kernel size
fi
if [[ $SIZEKD < "3014656" ]] && [[ $SIZEKD > "2883584" ]]; then # < 0x2E0000, > 0x2C00000
  FAKESIZE="196380"  # 0x030000 - 228
fi
if [[ $SIZEKD < "2883584" ]] && [[ $SIZEKD > "2752512" ]]; then # < 0x2C0000, > 0x2A00000
  FAKESIZE="327452"  # 0x050000 - 228
fi
if [[ $SIZEKD < "2752512" ]] && [[ $SIZEKD > "2621440" ]]; then # < 0x2A0000, > 0x2800000
  FAKESIZE="458524"  # 0x070000 - 228
fi
if [[ $SIZEKD < "2621440" ]] && [[ $SIZEKD > "2490368" ]]; then # < 0x280000, > 0x2600000
  FAKESIZE="589596"  # 0x090000 - 228
fi
if [[ $SIZEKD < "2490368" ]] && [[ $SIZEKD > "2359296" ]]; then # < 0x260000, > 0x2400000
  FAKESIZE="720668"  # 0x0B0000 - 228
fi
if [[ $SIZEKD < "2359296" ]] && [[ $SIZEKD > "2228224" ]]; then # < 0x240000, > 0x2200000
  FAKESIZE="851740"  # 0x0D0000 - 228
fi
if [[ $SIZEKD < "2228224" ]] && [[ $SIZEKD > "2097152" ]]; then # < 0x220000, > 0x2000000
  FAKESIZE="982812"  # 0x0F00000 - 228
fi
if [[ $SIZEKD < "2097152" ]] && [[ $SIZEKD > "1966080" ]]; then # < 0x200000, > 0x1E00000
  FAKESIZE="1113884"  # 0x110000 - 228
fi
if [[ $SIZEKD < "1966080" ]] && [[ $SIZEKD > "1835008" ]]; then # < 0x1E0000, > 0x1C00000
  FAKESIZE="1244956"  # 0x130000 - 228
fi
if [[ $SIZEKD < "1835008" ]] && [[ $SIZEKD > "1703936" ]]; then # < 0x1C0000, > 0x1A00000
  FAKESIZE="1376028"  # 0x150000 - 228
fi
if [[ $SIZEKD < "1703936" ]] && [[ $SIZEKD > "1572864" ]]; then # < 0x1A0000, > 0x1800000
  FAKESIZE="1507100"  # 0x170000 - 228
fi
if [[ $SIZEKD < "1572864" ]] && [[ $SIZEKD > "1441792" ]]; then # < 0x180000, > 0x1600000
  FAKESIZE="1638172"  # 0x190000 - 228
fi
if [[ $SIZEKD < "1441792" ]] && [[ $SIZEKD > "1310720" ]]; then # < 0x160000, > 0x1400000
  FAKESIZE="1769244"  # 0x1B0000 - 228
fi
if [[ $SIZEKD < "1310720" ]] && [[ $SIZEKD > "1179648" ]]; then # < 0x140000, > 0x1200000
  FAKESIZE="1900316"  # 0x1D0000 - 228
fi
if [[ $SIZEKD < "1179648" ]] && [[ $SIZEKD > "1048576" ]]; then # < 0x120000, > 0x1000000
  FAKESIZE="2031388"  # 0x1F0000 - 228
fi
#if [[ "$FAKESIZE" == "999" ]]; then
#  echo -e "\033[01;31m"
#  echo "-- PROBLEM! -----------------------------------------------------------"
#  echo
#  echo -e "\033[01;31m"
#  echo " This kernel cannot be flashed, due to its size being" > /dev/stderr
#  echo " an exact multiple of 0x20000. This is a limitation of" > /dev/stderr
#  echo " bootloader 6.40." > /dev/stderr
#  echo " Rebuild the kernel by changing the configuration." > /dev/stderr
#  echo
#  echo " Exiting..."
#  echo "-----------------------------------------------------------------------"
#  echo -e "\033[00m"
#  exit
#fi
echo " done."
#echo "FAKESIZE = $FAKESIZE, new FAKESIZE = $FAKESIZEN"

if [ ! -e $TOOLSDIR/seedfile ]; then
  echo -n " - Generating seedfile..."
  dd if=/dev/urandom count=3538943 bs=1 of=$TOOLSDIR/seedfile bs=1 skip=0 2> /dev/null
  echo " done."
fi

echo -n " - Creating dummy root squashfs 3.3 partition (Fake_ROOT)..."
dd if=$TOOLSDIR/seedfile of=$TMPDUMDIR/dummy bs=1 skip=0 count=$FAKESIZE 2> /dev/null
$MKSQUASHFS $TMPDUMDIR $TMPDIR/mtd_fakeroot.bin -nopad -le > /dev/null
# Sign partition
$FUP -s $TMPDIR/mtd_fakeroot.bin > /dev/null
echo " done."

if [ "$IMAGE" != "kernel" ]; then
  echo -n " - Preparing UBIFS root file system..."
  # Logical erase block size is physical erase block size (131072) minus -m parameter => -e 129024
  # Number of erase blocks is partition size / physical eraseblock size: 37Mib / 131072 => -c 296
  # Fortis bootloader expects a zlib compressed ubifs => -x zlib
  $MKFSUBIFS -d $TMPROOTDIR -m 2048 -e 129024 -c 296 -x zlib -U -o $TMPDIR/mtd_root.ubi 2> /dev/null
  echo " done."

  echo -n " - Creating ubinize ini file..."
  # Create ubi.ini
  echo "[ubi-rootfs]" > $TMPDIR/ubi.ini
  echo "mode=ubi" >> $TMPDIR/ubi.ini
  echo "image=$TMPDIR/mtd_root.ubi" >> $TMPDIR/ubi.ini
  echo "vol_id=0" >> $TMPDIR/ubi.ini
  # UBI needs a few free erase blocks for bad PEB handling, say 15, so:
  # Net available for data: (296 - 15) x 129024 = 36255744 bytes
  echo "vol_size=36255744" >> $TMPDIR/ubi.ini
  echo "vol_type=dynamic" >> $TMPDIR/ubi.ini
  # krnel patch uses the volume label rootfs
  echo "vol_name=rootfs" >> $TMPDIR/ubi.ini
  # Allow UBI to dynamically resize the volume
  echo "vol_flags=autoresize" >> $TMPDIR/ubi.ini
  echo "vol_alignment=1" >> $TMPDIR/ubi.ini
  echo " done."

  echo -n " - Creating UBI root image..."
  # UBInize the UBI partition of the rootfs
  # Physical eraseblock size is 131072 => -p 128KiB
  # Subpage size is 512 bytes => -s 512
  $UBINIZE -o $TMPDIR/mtd_root.ubin -p 128KiB -m 2048 -s 512 -x 1 $TMPDIR/ubi.ini 2> /dev/null
  $PAD 0x2500000 $TMPDIR/mtd_root.ubin $TMPDIR/mtd_root.pad
  echo " done."

  echo -n " - Checking root size..."
  SIZE=`stat $TMPDIR/mtd_root.ubin -t --format %s`
  SIZEH=`printf "%08X" $SIZE`
  SIZED=`printf "%d" $SIZE`
  if [[ $SIZED > "36255744" ]]; then
    echo -e "\033[01;31m"
    echo "-- ERROR! -------------------------------------------------------------"
    echo
    echo " ROOT TOO BIG: 0x$SIZEH instead of 0x022937FF bytes." > /dev/stderr
    echo
    echo " Exiting..."
    echo "-----------------------------------------------------------------------"
    echo -e "\033[00m"
    exit
  else
    echo " OK: $SIZED (0x$SIZEH, max. 0x022937FF) bytes."
  fi
fi

echo -n " - Creating .IRD flash file and MD5..."
if [ "$IMAGE" == "kernel" ]; then
  $FUP -c $OUTDIR/$OUTFILE \
       -6 $TMPDIR/uImage \
       -7 $TMPDIR/mtd_fakeroot.bin
else
  $FUP -c $OUTDIR/$OUTFILE \
       -6 $TMPDIR/uImage \
       -7 $TMPDIR/mtd_fakeroot.bin \
       -8 $TMPDIR/mtd_root.pad
fi
# Set reseller ID
$FUP -r $OUTDIR/$OUTFILE $RESELLERID
# Set version number to enforce flashing to NAND
$FUP -n $OUTDIR/$OUTFILE 10000
# Create MD5 file
md5sum -b $OUTDIR/$OUTFILE | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
echo " done."

echo -n " - Creating .ZIP output file...       "

cd $OUTDIR
zip -j $OUTZIPFILE $OUTFILE $OUTFILE.md5 > /dev/null
cd $CURDIR
echo " done."

if [ -e $OUTDIR/$OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " The receiver must be equipped with the standard i-boot bootloader"
  echo " used for Titanit with unmodified bootargs."
  echo
  echo " To flash the created image copy the .ird file to the root directory"
  echo " of a FAT32 formatted USB stick."
  echo
  echo " Insert the USB stick in any of the box's USB ports, and switch on"
  echo " the receiver using the power switch on the back while pressing and"
  echo " holding the power key on the frontpanel."
  echo " Release the button when the display shows 'SrcH', or when you see"
  echo " activity on the USB stick."
  echo " Flashing the image will then begin."
  echo -e "\033[00m"
fi

# Clean up
#rm -f $TMPDIR/uImage
#rm -f $TMPDIR/mtd_fakeroot.bin
#rm -f $TMPDIR/mtd_fakeroot.bin.signed
#rm -f $TMPDIR/mtd_fakedev.bin
#rm -f $TMPDIR/mtd_fakedev.bin.signed
#rm -f $TMPDIR/mtd_root.bin
#rm -f $TMPDIR/mtd_root.sum
#rm -f $TMPDIR/mtd_root.pad
#rm -f $TMPDIR/mtd_root.1.bin
#rm -f $TMPDIR/mtd_root.1.signed
#rm -f $TMPDIR/mtd_config.bin
#rm -f $TMPDIR/mtd_user.bin
if [ -e $TOOLSDIR/dummy.squash.signed.padded ]; then
  rm $TOOLSDIR/dummy.squash.signed.padded
fi
