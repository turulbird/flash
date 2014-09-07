# "-----------------------------------------------------------------------"
# "This script creates flashable Neutrino images for Fortis receivers:"
# " - FS9000
# " - FS9200
# " - HS9510
# " with unmodified factory bootloader:
# " 1.19/1.21/1.23/1.25/1.54 or 2.19/2.21/2.23/2.25/2.54
#
# "Author: Schischu/Audioniek"
# "Date: 08-31-2014"
#
# " Note: this script requires fup 1.8.4 or later.
#
# "-----------------------------------------------------------------------"
# "It is assumed that a neutrino image was already built prior to"
# "executing this script!"
# "-----------------------------------------------------------------------"
#

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

# Set up the variables
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad
FUP=$TOOLSDIR/fup

OUTFILE="$BOXTYPE"_"$IMAGE"_flash_R$RESELLERID.ird
OUTZIPFILE="$HOST"_"$IMAGE"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION".zip

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

# mtd-layout after flashing:
#	.name   = "Boot_firmware",      //mtd0
#	.size   = 0x00300000,           // 3MB
#	.offset = 0x00000000
#
#	.name   = "kernel",             //mtd1
#	.size   = 0x00300000,           // 3MB
#	.offset = 0x00300000            // 3MB
#
#	.name   = "app_low_unusable",   //mtd2
#	.size   = 0x00500000,           // 5MB (squashfs)
#	.offset = 0x00600000            // 6MB
#
#	.name   = "app_high_sq",        //mtd3
#	.size   = 0x00020000,           // 128kB (squashfs dummy)
#	.offset = 0x00b00000            // 11MB
#
#	.name   = "ROOT_FS_sq",         //mtd4
#	.size   = 0x00020000,           // 128kB (squashfs dummy)
#	.offset = 0x01000000            // 16MB
#
#	.name   = "Device_sq",          //mtd5
#	.size   = 0x00020000,           // 128kB (squashfs dummy)
#	.offset = 0x01800000            // 24MB
#
#	.name   = "Config_unusable",    //mtd6
#	.size   = 0x00040000,           // 256kB
#	.offset = 0x01bc0000 
#
#	.name   = "app_high_real",      //mtd7
#	.size   = 0x004c0000,           // 5MB - 128kB squashfs - 128k checksum
#	.offset = 0x00b20000 
#
#	.name   = "ROOT_FS_real",       //mtd8
#	.size   = 0x007c0000,           // 8MB - 128kB squashfs - 128k checksum
#	.offset = 0x01020000 
#
#	.name   = "Device_real",        //mtd9
#	.size   = 0x002c0000,           // 3MB - 128kB squashfs - 128k checksum
#	.offset = 0x01820000 
#
#	.name   = "Config_real",        //mtd10
#	.size   = 0x000c0000,           // 768kB
#	.offset = 0x01b00000 
#
#	.name = "User",                 //mtd11
#	.size =   0x00400000,           // 4MB
#	.offset = 0x01c00000 
#
# mtd-layout after partition concatenating:
#	.name   = "Boot_firmware",      //mtd0
#	.size   = 0x00300000,           // 3MB
#	.offset = 0x00000000
#
#	.name   = "kernel",             //mtd1
#	.size   = 0x00300000,           // 3MB
#	.offset = 0x00300000            // 3MB
#
#	.name   = "old_app_lo",         //mtd2
#	.size   = 0x00500000,           // 5MB (app_lo_squashfs)
#	.offset = 0x00600000
#
#	.name   = "old_app_hi",         //mtd3
#	.size   = 0x00020000,           // 128kB (app_high_squashfs dummy)
#	.offset = 0x00b00000
#
#	.name   = "Real_ROOT",           //mtd4
#	.size   = 0x01460000,            // 20.375MB
#	.offset = 0x00b20000             // 11.125MB
#
#	.name   = "root_squash_dummy",   //mtd5
#	.size   = 0x0001fffe,            // 128kB, one word too small, forces read-only mount
#	.offset = 0x01f80000
#
#	.name   = "dev_squash_dummy",    //mtd6
#	.size   = 0x0001fffe,            // 128kB, one word too small, forces read-only mount
#	.offset = 0x01fa0000
#
#	.name   = "ConfigC",             //mtd7
#	.size   = 0x0003fffe,            // 256kB, one word too small, forces read-only mount
#	.offset = 0x01fc0000
#

echo -n " - Prepare kernel file..."
cp $TMPKERNELDIR/uImage $TMPDIR/uImage
echo " done."

echo -n " - Checking kernel size..."
SIZEK=`stat $TMPDIR/uImage -t --format %s`
SIZEKD=`printf "%d" $SIZEK`
SIZEKH=`printf "%08X" $SIZEK`
if [[ $SIZEKD < "1048577" ]]; then
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
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " KERNEL TOO BIG: 0x$SIZEKH instead of max. 0x00300000 bytes." > /dev/stderr
  echo " Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit
else
  echo " OK: $SIZEKD (0x$SIZEKH, max. 0x00300000) bytes."
fi

if [ "$IMAGE" != "kernel" ]; then
  echo -n " - Prepare root..."
  # Create a jffs2 partition for the complete root
  $MKFSJFFS2 -qUfl -e 0x20000 -r $TMPROOTDIR -o $TMPDIR/mtd_root.bin
  $SUMTOOL -p -l -e 0x20000 -i $TMPDIR/mtd_root.bin -o $TMPDIR/mtd_root.sum > /dev/null
  # Padding the root up maximum size is required to force JFFS2 to find
  # only erased flash blocks after the root on the initial kernel run.
  $PAD 0x1400000 $TMPDIR/mtd_root.sum $TMPDIR/mtd_root.pad
  echo " done."

  echo -n " - Checking root size..."
  SIZE=`stat $TMPDIR/mtd_root.bin -t --format %s`
  SIZEH=`printf "%08X" $SIZE`
  SIZED=`printf "%d" $SIZE`
  if [[ $SIZED > "20971520" ]]; then
    echo -e "\033[01;31m"
    echo "-- ERROR! -------------------------------------------------------------"
    echo
    echo " ROOT TOO BIG: 0x$SIZEH instead of 0x01400000 bytes." > /dev/stderr
    echo
    echo " Exiting..."
    echo "-----------------------------------------------------------------------"
    echo -e "\033[00m"
    exit
  else
    echo " OK: $SIZED (0x$SIZEH, max. 0x1400000) bytes."
  fi

  echo " - Split root into flash parts"
  echo -n "   + Part one  : app partition...     "
  # Root part one size is 0x4C0000, partition type 1 (app_high_real)
  dd if=$TMPDIR/mtd_root.pad of=$TMPDIR/mtd_root.1.bin bs=65536 skip=0 count=76 2> /dev/null
  echo " done."

  echo -n "   + Part two  : root partition...    "
  # Root part two, size 0x7C0000, partition type 8 (ROOT_FS_sq)
  dd if=$TMPDIR/mtd_root.pad of=$TMPDIR/mtd_root.8.bin bs=65536 skip=76 count=124 2> /dev/null
  echo " done."

  echo -n "   + Part three: dev partition...     "
  # Root part three, size 0x2C0000, partition type 7 (Device_sq)
  dd if=$TMPDIR/mtd_root.pad of=$TMPDIR/mtd_root.7.bin bs=65536 skip=200 count=44 2> /dev/null
  echo " done."

  echo -n "   + Part four : config0 partition... "
  # Root part four, size 0x40000, partition type 2 (Config0, will be flashed at 0x01B00000)
  dd if=$TMPDIR/mtd_root.pad of=$TMPDIR/mtd_config0.bin bs=65536 skip=244 count=4 2> /dev/null
  echo " done."

  echo -n "   + Part five : config4 partition... "
  # Root part five, size 0x40000, partition type 3 (Config4, will be flashed at 0x01B40000)
  dd if=$TMPDIR/mtd_root.pad of=$TMPDIR/mtd_config4.bin bs=65536 skip=248 count=4 2> /dev/null
  echo " done."

  echo -n "   + Part six  : config8 partition... "
  # Root part six, size 0x20000, partition type 4 (Config8, will be flashed at 0x01B80000)
  dd if=$TMPDIR/mtd_root.pad of=$TMPDIR/mtd_config8.bin bs=65536 skip=252 count=2 2> /dev/null
  echo " done."

  echo -n "   + Part seven: configA partition... "
  # Root part seven, size 0x20000, partition type 5 (ConfigA, will be flashed at 0x01BA0000)
  dd if=$TMPDIR/mtd_root.pad of=$TMPDIR/mtd_configA.bin bs=65536 skip=254 count=2 2> /dev/null
  echo " done."

  echo -n "   + Part eight: user partition...    "
  # Root part eight, max. size 0x00400000, partition type 9 (User, will be flashed at 0x01C00000)
  dd if=$TMPDIR/mtd_root.pad of=$TMPDIR/mtd_root.9.bin bs=65536 skip=256 count=64 2> /dev/null
  echo " done."
fi

echo -n " - Creating .IRD flash file and MD5..."
cd $TOOLSDIR
if [ "$IMAGE" == "kernel" ]; then
  $FUP -c $OUTDIR/$OUTFILE -6 $TMPDIR/uImage
else
  $FUP -ce $OUTDIR/$OUTFILE \
       -1G \
       -1 $TMPDIR/mtd_root.1.bin \
       -2 $TMPDIR/mtd_config0.bin \
       -3 $TMPDIR/mtd_config4.bin \
       -4 $TMPDIR/mtd_config8.bin \
       -5 $TMPDIR/mtd_configA.bin \
       -6 $TMPDIR/uImage \
       -7 $TMPDIR/mtd_root.7.bin \
       -8 $TMPDIR/mtd_root.8.bin \
       -9 $TMPDIR/mtd_root.9.bin
fi
# Set reseller ID
$FUP -r $OUTDIR/$OUTFILE $RESELLERID
cd $CURDIR
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
  echo " The receiver must be equipped with a standard Fortis bootloader:"
  echo "  - FS9000/9200 : 1.19, 1.21, 1.23 or 1.54"
  echo "  - HS9510      : 2.19, 2.21, 2.23 or 2.54"
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
  echo -e "\033[00m"
fi

# Clean up
rm -f $TMPDIR/uImage
rm -f $TMPDIR/mtd_root.bin
rm -f $TMPDIR/mtd_root.sum
rm -f $TMPDIR/mtd_root.pad
rm -f $TMPDIR/mtd_root.1.bin
rm -f $TMPDIR/mtd_root.1.signed
rm -f $TMPDIR/mtd_root.7.bin
rm -f $TMPDIR/mtd_root.7.signed
rm -f $TMPDIR/mtd_root.8.bin
rm -f $TMPDIR/mtd_root.8.signed
rm -f $TMPDIR/mtd_config0.bin
rm -f $TMPDIR/mtd_config4.bin
rm -f $TMPDIR/mtd_config8.bin
rm -f $TMPDIR/mtd_configA.bin
rm -f $TMPDIR/mtd_root.9.bin

