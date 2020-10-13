# ---------------------------------------------------------------------------
# This script creates flashable images for Fortis HS8200 receivers"
# Author: Schischu/Audioniek"
# Date: 07-05-2014"
#
# Note: for HS8200 with loader 6.00 (concatenated partitions version)
#
# ---------------------------------------------------------------------------
# "It is assumed that an image was already built prior to executing this"
# "script!"
# "-----------------------------------------------------------------------"
#
# If only the kernel is to be reflashed, the partitions 8, 7 and 1 are
# also reflashed (requirement of loader 6.XX). Partition 1 is flashed as
# the squashfs dummy only, leaving the enigma2 part of it untouched.
#

if [ "$BATCH_MODE" == "yes" ]; then
  IMAGE=
else
  echo "-- Output selection ---------------------------------------------------"
  echo
  echo " What would you like to flash?"
  echo "   1) The whole $IMAGE image"
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
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad
MKSQUASHFS=$TOOLSDIR/mksquashfs3.3
FUP=$TOOLSDIR/fup
#FUP1=$TOOLSDIR/fup183

OUTFILE="$BOXTYPE"_L600_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_R$RESELLERID.ird
OUTZIPFILE="$HOST"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip

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

# mtd-layout after flashing:
#	.name   = "Boot_firmware",  //mtd0
#	.size   = 0x00060000,       //384k
#	.offset = 0x00000000
#
#	.name   = "kernel",         //mtd1
#	.size   = 0x00320000,       //3.125M
#	.offset = 0x00060000        //384k (0.375M)
#
#	.name   = "ROOT_FS",        //mtd2
#	.size   = 0x00020000,       //128k (dummy)
#	.offset = 0x00380000        //3.5M
#
#	.name   = "Device",         //mtd3
#	.size   = 0x00020000,       //128k (dummy)
#	.offset = 0x003A0000        //3.625M
#
#	.name   = "APP",            //mtd4
#	.size   = 0x00020000,       //128k (dummy)
#	.offset = 0x003C0000        //3.75M
#
#	.name   = "Real_ROOT",      //mtd5
#	.size   = 0x01D00000,       //29Mbyte, 128k hole at 0x20E0000 is used for force flash
#	.offset = 0x003E0000        //3.875M
#
#	.name   = "Config",         //mtd6
#	.size   = 0x00100000,       //  1M
#	.offset = 0x02100000
#
#	.name   = "User",           //mtd7
#	.size   = 0x01E00000,       // 30M
#	.offset = 0x02200000
#
# mtd-layout after boot and partition concatenating:
#	.name   = "Boot_firmware",  //mtd0
#	.size   = 0x00060000,       //384k (0.375M)
#	.offset = 0x00000000
#
#	.name   = "Kernel",         //mtd1
#	.size   = 0x00320000,       //3.125M
#	.offset = 0x00060000        //0.375M
#
#	.name   = "Fake_ROOT",      //mdt2
#	.size   = 0x0001FFFE,       //128k (dummy) minus 1 word to force read only mount
#	.offset = 0x00380000        //  4M - 128k force flash hole - 128k Fake_APP - 128k Fake_DEV - 128k own size
#
#	.name   = "Fake_DEV",       //mtd3
#	.size   = 0x0001FFFE,       //128k (dummy) minus 1 word to force read only mount
#	.offset = 0x003A0000        //  4M - 128k force flash hole - 128k Fake_APP - 128k own size
#
#	.name   = "Fake_APP",       //mtd4
#	.size   = 0x0001FFFE,       //128k (squashfs dummy) minus 1 word to force read only mount
#	.offset = 0x003C0000        //  4M - 128k force flash hole - 128k own size
#
#	.name   = "Real_ROOT",      //mtd5
#	.size   = 0x03C00000,       // 60M
#	.offset = 0x003E0000        //  4M - 128k force flash hole

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
SIZEK=`stat $TMPDIR/uImage -t --format %s`
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
  export ERROR="yes"
  exit
fi
if [[ $SIZEKD > "3276799" ]]; then
  echo
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " KERNEL TOO BIG: 0x$SIZEKH instead of max. 0x0031FFFF bytes." > /dev/stderr
  echo " Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  export ERROR="yes"
  exit
else
  echo " OK: $SIZEKD (0x$SIZEKH, max. 0x0031FFFF) bytes."
fi

echo -n " - Adjusting fake root partition size..."
# Note: fake root size is adjusted so that the type 7 partition is always flashed at 0x3A0000.
# This in turn will always flash the real root starting at 0x3E0000 (0x3C0000 + squashfs dummy)
# Determine fake root size
if [[ $SIZEKD < "3276800" ]] && [[ $SIZEKD > "3145728" ]]; then
  FAKESIZE="196385"
else
  FAKESIZE="999" #used to flag illegal kernel size
fi
if [[ $SIZEKD < "3145728" ]] && [[ $SIZEKD > "3014656" ]]; then
  FAKESIZE="196385"
fi
if [[ $SIZEKD < "3014656" ]] && [[ $SIZEKD > "2883584" ]]; then
  FAKESIZE="327455"
fi
if [[ $SIZEKD < "2883584" ]] && [[ $SIZEKD > "2752512" ]]; then
  FAKESIZE="458527"
fi
if [[ $SIZEKD < "2752512" ]] && [[ $SIZEKD > "2621440" ]]; then
  FAKESIZE="589599"
fi
if [[ $SIZEKD < "2621440" ]] && [[ $SIZEKD > "2490368" ]]; then
  FAKESIZE="720670"
fi
if [[ $SIZEKD < "2490368" ]] && [[ $SIZEKD > "2359296" ]]; then
  FAKESIZE="851741"
fi
if [[ $SIZEKD < "2359296" ]] && [[ $SIZEKD > "2228224" ]]; then
  FAKESIZE="982810"
fi
if [[ $SIZEKD < "2228224" ]] && [[ $SIZEKD > "2097152" ]]; then
  FAKESIZE="1113881"
fi
if [[ $SIZEKD < "2097152" ]] && [[ $SIZEKD > "1966080" ]]; then
  FAKESIZE="1244953"
fi
if [[ $SIZEKD < "1966080" ]] && [[ $SIZEKD > "1835008" ]]; then
  FAKESIZE="1376025"
fi
if [[ $SIZEKD < "1835008" ]] && [[ $SIZEKD > "1703936" ]]; then
  FAKESIZE="1507097"
fi
if [[ $SIZEKD < "1703936" ]] && [[ $SIZEKD > "1572864" ]]; then
  FAKESIZE="1638169"
fi
if [[ $SIZEKD < "1572864" ]] && [[ $SIZEKD > "1441792" ]]; then
  FAKESIZE="1769241"
fi
if [[ $SIZEKD < "1441792" ]] && [[ $SIZEKD > "1310720" ]]; then
  FAKESIZE="1900314"
fi
if [[ $SIZEKD < "1310720" ]] && [[ $SIZEKD > "1179650" ]]; then
  FAKESIZE="2031386"
fi
if [[ $SIZEKD < "1179648" ]] && [[ $SIZEKD > "1048576" ]]; then
  FAKESIZE="2162458"
fi
if [[ "$FAKESIZE" == "999" ]]; then
  echo -e "\033[01;31m"
  echo "-- PROBLEM! -----------------------------------------------------------"
  echo
  echo -e "\033[01;31m"
  echo " This kernel cannot be flashed, due to its size being" > /dev/stderr
  echo " an exact multiple of 0x20000. This is a limitation of" > /dev/stderr
  echo " bootloader 6.00." > /dev/stderr
  echo " Rebuild the kernel by changing the configuration." > /dev/stderr
  echo
  echo " Exiting..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  export ERROR="yes"
  exit
fi
echo " done."

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

echo -n " - Creating dummy dev squashfs 3.3 partition (Fake_DEV)..."
echo "#!/bin/bash" > $TMPDUMDIR/dummy
echo "This is a dummy DEV squashfs partition." >> $TMPDUMDIR/dummy
chmod 755 $TMPDUMDIR/dummy > /dev/null
$MKSQUASHFS $TMPDUMDIR $TMPDIR/mtd_fakedev.bin -nopad -le > /dev/null
# Sign partition
$FUP -s $TMPDIR/mtd_fakedev.bin > /dev/null
echo " done."

if [ "$IMAGE" == "kernel" ]; then
  echo -n " - Creating dummy root..."
  cat $TMPDIR/mtd_fakedev.bin.signed > $TMPDIR/mtd_root.1.signed
  echo " done."
else
  echo -n " - Preparing real root..."
  # Create a jffs2 partition for the complete root
  $MKFSJFFS2 -qUfl -e 0x20000 -r $TMPROOTDIR -o $TMPDIR/mtd_root.bin
  $SUMTOOL -p -l -e 0x20000 -i $TMPDIR/mtd_root.bin -o $TMPDIR/mtd_root.sum > /dev/null
  # Padding the root up maximum size is required to force JFFS2 to find
  # only erased flash blocks after the root on the initial kernel run.
  $PAD 0x3C00000 $TMPDIR/mtd_root.sum $TMPDIR/mtd_root.pad
  echo " done."

  echo -n " - Checking root size..."
  SIZE=`stat $TMPDIR/mtd_root.bin -t --format %s`
  SIZEH=`printf "%08X" $SIZE`
  SIZED=`printf "%d" $SIZE`
  MAXSIZE=62914560
  CHECKSIZE=$(( SIZED > MAXSIZE ))
  if [ "$CHECKSIZE" == "1" ]; then
    echo -e "\033[01;31m"
    echo "-- ERROR! -------------------------------------------------------------"
    echo
    echo " ROOT TOO BIG: 0x$SIZEH instead of 0x03C00000 bytes." > /dev/stderr
    echo
    echo " Exiting..."
    echo "-----------------------------------------------------------------------"
    echo -e "\033[00m"
    export ERROR="yes"
    exit
  else
    echo " OK: $SIZED (0x$SIZEH, max. 0x3C00000) bytes."
  fi

  if [ ! -e $TOOLSDIR/dummy.squash.signed.padded ]; then
    echo -n " - Generating dummy squashfs file...  "
    cd $TOOLSDIR
    $TOOLSDIR/fup -d
    cd $FLASHDIR
    echo " done."
  fi
  echo " - Split root into flash parts"
  # Root part one size is 0x1D00000, partition type 1 (Fake_APP, extending into Real_ROOT)
  dd if=$TMPDIR/mtd_root.pad of=$TMPDIR/mtd_root.1.bin bs=65536 skip=0 count=464 2> /dev/null
  # Sign partition by preceding it with a squashfs dummy (will be flashed at 0x3C0000,
  # real root starts at 0x3E0000)
  echo -n "   + Part one: app partition...       "
  cat $TOOLSDIR/dummy.squash.signed.padded > $TMPDIR/mtd_root.1.signed
  cat $TMPDIR/mtd_root.1.bin >> $TMPDIR/mtd_root.1.signed
  # Add some bytes to enforce flashing (will expand the file to 0x1D40000 bytes when flashed)
  echo "Added to force flashing this partition." >> $TMPDIR/mtd_root.1.signed
  echo " done."

  echo -n "   + Part two: config partition...    "
  # Root part two, size 0x100000, partition type 2 (Config 0)
  dd if=$TMPDIR/mtd_root.pad of=$TMPDIR/mtd_config.bin bs=65536 skip=464 count=16 2> /dev/null
  echo " done."

  echo -n "   + Part three: user partition...    "
  # Root part three, max. size 0x1E00000, partition type 9 (User)
  dd if=$TMPDIR/mtd_root.pad of=$TMPDIR/mtd_user.bin bs=65536 skip=480 count=480 2> /dev/null
  echo " done."
fi

echo -n " - Creating .IRD flash file and MD5..."
if [ "$IMAGE" == "kernel" ]; then
  $FUP -c $OUTDIR/$OUTFILE \
       -6 $TMPDIR/uImage \
       -8 $TMPDIR/mtd_fakeroot.bin.signed \
       -7 $TMPDIR/mtd_fakedev.bin.signed \
       -1 $TMPDIR/mtd_root.1.signed
  $FUP1 -c $OUTDIR/$OUTFILE"d" \
        -6 $TMPDIR/uImage \
        -8 $TMPDIR/mtd_fakeroot.bin.signed \
        -7 $TMPDIR/mtd_fakedev.bin.signed \
        -1 $TMPDIR/mtd_root.1.signed
else
  $FUP -c $OUTDIR/$OUTFILE \
       -6 $TMPDIR/uImage \
       -8 $TMPDIR/mtd_fakeroot.bin.signed \
       -7 $TMPDIR/mtd_fakedev.bin.signed \
       -1 $TMPDIR/mtd_root.1.signed \
       -2 $TMPDIR/mtd_config.bin \
       -9 $TMPDIR/mtd_user.bin
  $FUP1 -c $OUTDIR/$OUTFILE"d" \
        -6 $TMPDIR/uImage \
        -8 $TMPDIR/mtd_fakeroot.bin.signed \
        -7 $TMPDIR/mtd_fakedev.bin.signed \
        -1 $TMPDIR/mtd_root.1.signed \
        -2 $TMPDIR/mtd_config.bin \
        -9 $TMPDIR/mtd_user.bin
fi
# Set reseller ID
$FUP -r $OUTDIR/$OUTFILE $RESELLERID
#$FUP1 -r $OUTDIR/$OUTFILE"d" $RESELLERID
# Create MD5 file
md5sum -b $OUTDIR/$OUTFILE | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
echo " done."

echo -n " - Creating .ZIP output file...       "
cd $OUTDIR
zip -j $OUTZIPFILE $OUTFILE $OUTFILE.md5 > /dev/null
cd $CURDIR
echo " done."

if [ -e $OUTDIR/$OUTFILE ] && [ ! "$BATCH_MODE" == "yes" ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " The receiver must be equipped with a standard Fortis bootloader 6.00"
  echo " with unmodified bootargs."
  echo
  echo " To flash the created image copy the .ird file to the root directory"
  echo " of a FAT32 formatted USB stick."
  echo
  echo " Insert the USB stick in any of the box's USB ports, and switch on"
  echo " the receiver using the mains switch while pressing and holding the"
  echo " channel up key on the frontpanel. Release the button when the display"
  echo " shows SCAN USB."
  echo " Flashing the image will then begin."
  echo
  echo " NOTE: On Octagon SF1028P and Icecrypt STC6000 only, use"
  echo " volume up (->) instead of channel up."
  echo -e "\033[00m"
fi

# Clean up
rm -f $TMPDIR/uImage
rm -f $TMPDIR/mtd_fakeroot.bin
rm -f $TMPDIR/mtd_fakeroot.bin.signed
rm -f $TMPDIR/mtd_fakedev.bin
rm -f $TMPDIR/mtd_fakedev.bin.signed
rm -f $TMPDIR/mtd_root.bin
rm -f $TMPDIR/mtd_root.sum
rm -f $TMPDIR/mtd_root.pad
rm -f $TMPDIR/mtd_root.1.bin
rm -f $TMPDIR/mtd_root.1.signed
rm -f $TMPDIR/mtd_config.bin
rm -f $TMPDIR/mtd_user.bin
if [ -e $TOOLSDIR/dummy.squash.signed.padded ]; then
  rm $TOOLSDIR/dummy.squash.signed.padded
fi
