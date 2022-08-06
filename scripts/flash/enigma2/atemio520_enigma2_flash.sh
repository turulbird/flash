#!/bin/bash
# "-----------------------------------------------------------------------"
# " This script creates Enigma2 .ird flash files for Crenova receiver:"
# " - Atemio AM 520 HD
# " with unmodified factory i-boot bootloader 6.40.
#
# This version generates an image using JFFS2 in NAND flash.
#
# "Author: Schischu/Audioniek"
# "Date: 28-06-2022"
#
# "-----------------------------------------------------------------------"
# "It is assumed that an image was already built prior to"
# "executing this script!"
# "-----------------------------------------------------------------------"
#
# If only the kernel is to be reflashed, partition 7 is also reflashed
# (requirement of loader 6.40).
# "-----------------------------------------------------------------------"
#
# Date     Who          Description
# 20210912 Audioniek    Initial version.
# 20220806 Audioniek    Indicate default choice differently.
#
# -----------------------------------------------------------------------

echo "-- Output selection ---------------------------------------------------"
echo
echo " What would you like to flash?"
echo "   1*) The whole $IMAGE image"
echo "   2)  Only the kernel"
read -p " Select flash target (1-2)? "
case "$REPLY" in
#  1) echo > /dev/null;;
  2) IMAGE="kernel";;
#  *) echo > /dev/null;;
esac
echo "-----------------------------------------------------------------------"
echo

# Set up the variables
TMPDUMDIR=$TMPDIR/DUMMY
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad
MKSQUASHFS=$TOOLSDIR/mksquashfs3.3
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

#
# Note on flash order on Atemio AM 520 HD:
#
# The order of flashing in NAND is
# 1. if present: type 0 (loader, mtd0)
# 2. type 6 (kernel, mtd7)
# 3. type 7 (dev, mtd8, fake root))
# 4. type 8 (root, mtd9, real root)
# 5. if present,type 9 (user, mtd10)
#
# mtd-layout in NAND:
#	.name   = "NAND KERNEL",     // mtd7 (partition type 6)
#	.size   = 0x00300000,        // 3.0 Mbyte
#	.offset = 0
#
#	.name   = "NAND FAKE_ROOT",  // mtd8 (flashable using type 7)
#	.size   = 0x0001FFFE,        // 128 kbyte
#	.offset = 0x00300000         // 3 Mbyte
#
#	.name   = "NAND ROOT",       // mtd9 (flashable using type 8)
#	.size   = 0x08000000,        // 128 Mbyte
#	.offset = 0x00320000         // 3,125 Mbyte
#
#	.name   = "NAND USER",       // mtd10 (partition type 9)
#	.size   = 0x07CE0000,        // 4.0 Mbyte
#	.offset = 0x08320000         // 124,875 Mbyte
#
#	.name   = "NAND SWAP",       // mtd11
#	.size   = MTDPART_SIZ_FULL,  // 256 Mbyte
#	.offset = 0x10000000         // 256 Mbyte
#
#	.name   = "NAND FULL",       // mtd12
#	.size   = MTDPART_SIZ_FULL,
#	.offset = 0x300000
#

echo -n " - Preparing kernel file..."
# Note: padding the kernel to set start offset of type 7 (fake root) does not work;
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
# Note: The type 7 partition is always flashed directly following the kernel
# at the address the iBoot loader expects it based on the partition size of
# the kernel. The type 7 partition will at least occupy one erase block.
# Because the kernel can vary in size up to 3 Mbyte, the fake root squashfs
# partition preceeding the real rootfs must be adjusted in size in such a way
# that the real rootfs is always flashed at offset 0x320000.
# The dummy app squashfs is filled with one file filled with random bytes (to
# limit # compressing as much as possible).
# The overhead of the squashfs dummy is about 228 bytes.
# It is desirable that the squashfs dummy ends about in the middle of an erase
# block. This will achieve that the resizing during flashing has the greatest
# chance of resulting in the desired flash offset for the real rootfs at
# offset 0x320000.
#
# The actual kernel will end at offset (kernel offset plus $SIZEKD). The
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
#          = 0x320000 - 0x60000 - $SIZEKD - 228 - 0x20000 / 2
#          = 3276800 - 393216 - $SIZEKD - 228 - 65536
#          = 2883356 - $SIZEKD - 65536.
#
FAKESIZEN=$(expr 2817820 - $SIZEKD)

# Determine fake app size
if [[ $SIZEKD < "3145729" ]] && [[ $SIZEKD > "3014656" ]]; then # < 0x2E0000, > 0x2C00000, kernel ends at 0x300000 
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
if [[ "$FAKESIZE" == "999" ]]; then
  echo -e "\033[01;31m"
  echo "-- PROBLEM! -----------------------------------------------------------"
  echo
  echo -e "\033[01;31m"
  echo " This kernel cannot be flashed, due to its size being" > /dev/stderr
  echo " an exact multiple of 0x20000. This is a limitation of" > /dev/stderr
  echo " bootloader 6.40." > /dev/stderr
  echo " Rebuild the kernel by changing the configuration." > /dev/stderr
  echo
  echo " Exiting..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
fi
echo " done."
#echo "FAKESIZE = $FAKESIZE, new FAKESIZE = $FAKESIZEN"

if [ ! -e $TOOLSDIR/seedfile ]; then
  echo
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
  echo -n " - Preparing real root..."
  # Create a jffs2 partition for the complete root
  $MKFSJFFS2 -qUfl -e 0x20000 -r $TMPROOTDIR -o $TMPDIR/mtd_root.bin
  $SUMTOOL -p -l -e 0x20000 -i $TMPDIR/mtd_root.bin -o $TMPDIR/mtd_root.sum > /dev/null
  # Padding the root up maximum size is required to force JFFS2 to find
  # only erased flash blocks after the root on the initial kernel run.
  $PAD 0x8000000 $TMPDIR/mtd_root.sum $TMPDIR/mtd_root.pad
  echo " done."

  echo -n " - Checking root size..."
  SIZE=`stat $TMPDIR/mtd_root.bin -t --format %s`
  SIZEH=`printf "%08X" $SIZE`
  SIZED=`printf "%d" $SIZE`
  SIZEDS=$(expr $SIZED / 16)
  SIZEMAX=8388608
  SIZEMAXH=8000000
  if [[ $SIZEDS > $SIZEMAX ]]; then
    echo -e "\033[01;31m"
    echo "-- ERROR! -------------------------------------------------------------"
    echo
    echo " ROOT TOO BIG: 0x$SIZEH instead of 0x0$SIZEMAXH bytes." > /dev/stderr
    echo
    echo " Exiting..."
    echo "-----------------------------------------------------------------------"
    echo -e "\033[00m"
    exit
  else
    echo " OK: $SIZED (0x$SIZEH, max. 0x0$SIZEMAXH) bytes."
  fi
fi

echo -n " - Creating .IRD flash file and MD5..."
if [ "$IMAGE" == "kernel" ]; then
  $FUP -c $OUTDIR/$OUTFILE \
       -6 $TMPDIR/uImage \
       -7 $TMPDIR/mtd_fakeroot.bin.signed
else
  if [ -e $TMPDIR/mtd_user.bin ]; then
    $FUP -c $OUTDIR/$OUTFILE \
         -6 $TMPDIR/uImage \
         -7 $TMPDIR/mtd_fakeroot.bin.signed \
         -8 $TMPDIR/mtd_root.pad \
         -9 $TMPDIR/mtd_user.bin
  else
    $FUP -c $OUTDIR/$OUTFILE \
         -6 $TMPDIR/uImage \
         -7 $TMPDIR/mtd_fakeroot.bin.signed \
         -8 $TMPDIR/mtd_root.pad
  fi
fi
# Set reseller ID
$FUP -r $OUTDIR/$OUTFILE $RESELLERID
# Set SW version to 2.10.00 to force flashing to NAND flash
$FUP -n $OUTDIR/$OUTFILE 21000
# Create MD5 file
md5sum -b $OUTDIR/$OUTFILE | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
echo " done."

echo -n " - Creating .ZIP output file..."
cd $OUTDIR
zip -j $OUTZIPFILE $OUTFILE $OUTFILE.md5 > /dev/null
cd $CURDIR
echo " done."

if [ -e $OUTDIR/$OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " The receiver must be equipped with the standard iBoot bootloader used"
  echo " for TitanNit with unmodified bootargs."
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
rm -f $TMPDIR/uImage
rm -f $TMPDIR/mtd_fakeroot.bin
rm -f $TMPDIR/mtd_fakeroot.bin.signed
rm -f $TMPDIR/mtd_root.bin
rm -f $TMPDIR/mtd_root.sum
rm -f $TMPDIR/mtd_root.pad
if [ -e $TMPDIR/mtd_user.bin ]; then
  rm -f $TMPDIR/mtd_user.bin
fi
if [ -e $FLASHDIR/dummy.squash.signed.padded ]; then
  rm $FLASHDIR/dummy.squash.signed.padded
fi
