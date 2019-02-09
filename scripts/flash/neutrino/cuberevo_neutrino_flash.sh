#!/bin/bash
# "-----------------------------------------------------------------------"
# "This script creates flashable images for Cuberevo receivers."
# "Author: Schischu, Oxygen-1, BPanther, TangoCash, Grabber66, Audioniek"
# "Last Change: 08-02-2019"
#
# "Supported receivers (autoselection) are:"
# " - Cuberevo Mini (cuberevo_mini, untested)"
# " - Cuberevo Mini II (cuberevo_mini2)"
# " - Cuberevo (cuberevo, untested)"
# " - Cuberevo 2000HD (cuberevo_2000hd, untested)"
# " - Cuberevo 3000HD (cuberevo_3000hd, untested)"
# "-----------------------------------------------------------------------"
# "An image is assumed to have been built prior to calling this script!
# "-----------------------------------------------------------------------"
# Changes:
#

# Set up the variables
TMPDUMDIR=$TMPDIR/DUMMY
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad
MKSQUASHFS4=$TOOLSDIR/mksquashfs4.2
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2

OUTFILE=usb_update.img
OUTFILE_OU=mtd234.img
OUTZIPFILE="$HOST"_"$INAME""$IMAGE"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION"

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

# Define sizes of kernel, root, var and erase block
case "$BOXTYPE" in
  cuberevo_mini|cuberevo_mini2) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=0x00220000
    SIZE_ROOTH=0x01D80000
    SIZE_ROOTD=30932992
    ERASE_SIZE=0x20000
    HWMODEL=0x00053000
    HWVERSION=0x00010000;;
  cuberevo) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=0x00220000
    SIZE_ROOTH=0x01D800000
    SIZE_ROOTD=30932992
    ERASE_SIZE=0x20000
    HWMODEL=0x00051100
    HWVERSION=0x00010001;;
  cuberevo_2000hd) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=0x00220000
    SIZE_ROOTH=0x01D80000
    SIZE_ROOTD=30932992
    ERASE_SIZE=0x20000
    HWMODEL=0x00056000
    HWVERSION=0x00010000;;
  cuberevo_3000hd) echo "Creating flash image for $BOXTYPE..."
    SIZE_KERNEL=0x220000
    SIZE_ROOTH=0x1D80000
    SIZE_ROOTD=30932992
    ERASE_SIZE=0x20000
    HWMODEL=0x00053000
    HWVERSION=0x00010000;;
  *) echo "Unsupported receiver $BOXTYPE, assuming cuberevo_mini2..."
    SIZE_KERNEL=0x00220000
    SIZE_ROOTH=0x01D80000
    SIZE_ROOTD=30932992
    ERASE_SIZE=0x20000
    HWMODEL=0x00053000
    HWVERSION=0x00010000;;
esac

# mtd-layout after flashing:
#
#		.name       = "nor.boot",           // mtd0, read only
#		.offset     = 0x00000000,
#		.size       = 0x00040000 (256k or 0.25M)
#
#		.name       = "nor.config_welcome", // mtd1 bootargs
#		.offset     = 0x00040000 (256k or 0.25M)
#		.size       = 0x00020000 (128k or 0.125M)
#
#		.name       = "nor.kernel",         // mtd2
#		.offset     = 0x00060000 (384k or 0.375M)
#		.size       = 0x00220000 (2.125M)
#
#		.name       = "nor.root",           // mtd3 squashfs
#		.offset     = 0x00280000 (2.5M)
#		.size       = 0x01380000 (19.5M)
#
#		.name       = "nor.var",            // mtd4 jffs
#		.offset     = 0x01600000 (22M)
#		.size       = 0x00a00000 (10M)
#
#	/* partitions for upgrade */
#		.name       = "nor.mtd2_mtd3",      // mtd5 kernel + root
#		.offset     = 0x00060000 (384k or 0.375M)
#		.size       = 0x00220000 + 0x01380000 = 0x015a0000 (21.625M)
#
#		.name       = "nor.mtd2_mtd3_mtd4", // mtd6 kernel + root + var
#		.offset     = 0x00060000 (384k or 0.375M)
#		.size       = 0x00220000 + 0x01380000 + 0x00a00000 = 0x01fa0000 (31.625M)
#
#		.name       = "nor.full",           // mtd7 bootargs + kernel + root + var ("all_noboot")
#		.offset     = 0x00040000 (256k or 0.25M)
#		.size       = 0x02000000 - 0x00040000 = 0x01fc0000 (31.75M)
#
#		.name       = "nor.all",            // mtd8 everything, read only
#		.offset     = 0,
#		.size       = 0x02000000 (32M)
#
# mtd-layout after partition concatenating:
#
#		.name       = "nor.boot",           // mtd0, read only
#		.offset     = 0x00000000,
#		.size       = 0x00040000 (256k)
#
#		.name       = "nor.config_welcome", // mtd1 bootargs
#		.offset     = 0x00040000 (256k)
#		.size       = 0x00020000 (128k)
#
#		.name       = "nor.kernel",         // mtd2
#		.offset     = 0x00060000 (384k)
#		.size       = 0x00220000 (2.2M)
#
#		.name       = "nor.dummy",          // mtd3, dummy squashfs
#		.offset     = 0x00280000 (2.5M)
#		.size       = 0x00020000,           // 1 sector (128k)
#
#		.name       = "nor.new_root",       // mtd4, jffs
#		.offset     = 0x002a0000 (2.625M)
#		.size       = 0x01D60000 (29.375M)
#
#	/* partitions for upgrade */
#
#		.name       = "nor.mtd2_mtd3",      // mtd5 kernel + dummy_root (kernel only)
#		.offset     = 0x00060000 (384k)
#		.size       = 0x00220000 + 0x00020000 = 0x00240000 (2.25M)
#
#		.name       = "nor.mtd2_mtd3_mtd4",  // mtd6 kernel + dummy_root + root
#		.offset     = 0x00060000 (384k)
#		.size       = 0x00220000 + 0x1380000 + 0x00a00000 = 0x01fa0000 (31.625M)
#
#		.name       = "nor.full",           // mtd7 bootargs + kernel + dummy_root + root ("all_noboot")
#		.offset     = 0x00040000 (256k)
#		.size       = 0x02000000 - 0x00040000 = 0x01fc0000 (31.75M)
#
#		.name       = "nor.all",            // mtd8 everything, read only
#		.offset     = 0,
#		.size       = 0x02000000 (32M)
#

echo
echo -n " - Prepare kernel file..."
cp $TMPKERNELDIR/uImage $TMPDIR/uImage
$PAD $SIZE_KERNEL $TMPDIR/uImage $TMPDIR/mtd_kernel.pad
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

# --- Dummy ROOT ---
echo -n " - Create a squashfs 4.2 partition for dummy root..."
echo "This is a dummy file to fool the bootloader." > $TMPDUMDIR/dummy.txt
$MKSQUASHFS4 $TMPDUMDIR $TMPDIR/mtd_dummy_root.bin -noappend -comp gzip -always-use-fragments -b 131072 > /dev/null
$PAD 0x20000 $TMPDIR/mtd_dummy_root.bin $TMPDIR/mtd_dummy_root.pad
echo " done."

# --- Real ROOT ---
echo -n " - Create a jffs partition for real root..."
# Create a jffs2 partition for the complete root
$MKFSJFFS2 -qUfl -e 0x20000 -r $TMPROOTDIR -o $TMPDIR/mtd_root.bin
$SUMTOOL -p -l -e 0x20000 -i $TMPDIR/mtd_root.bin -o $TMPDIR/mtd_root.sum > /dev/null
# Padding the root up maximum size is required to force JFFS2 to find
# only erased flash blocks after the root on the initial kernel run.
$PAD 0x1D60000 $TMPDIR/mtd_root.sum $TMPDIR/mtd_root.pad
echo " done."

echo -n " - Checking root size..."
SIZE=`stat $TMPDIR/mtd_root.bin -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "0x%08X" $SIZE`
if [[ $SIZED > "$SIZE_ROOTD" ]]; then
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " ROOT TOO BIG: $SIZED ($SIZEH, max. $SIZE_ROOTH) bytes." > /dev/stderr
  echo
  echo " Press ENTER to exit..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  read
  exit
else
  echo " OK: $SIZED ($SIZEH, max. $SIZE_ROOTH) bytes."
fi

# Merge all parts together
cd $OUTDIR
echo -n " - Create output file(s) and MD5..."
#if [ "$BOXTYPE" == "cuberevo_mini2" -o "$BOXTYPE" == "cuberevo" -o "$BOXTYPE" == "cuberevo-2000hd" ]; then
  cat $TMPDIR/mtd_kernel.pad > out_tmp.img
  cat $TMPDIR/mtd_dummy_root.pad >> out_tmp.img
  cat $TMPDIR/mtd_root.pad >> out_tmp.img
  cp out_tmp.img $OUTFILE_OU
  md5sum -b $OUTFILE_OU | awk -F' ' '{print $1}' > $OUTFILE_OU.md5
  cat $TOOLSDIR/mtd1.img out_tmp.img > out_tmp1.img
  $TOOLSDIR/mkdnimg -make usbimg -vendor_id 0x00444753 -product_id 0x6c6f6f6b -hw_model $HWMODEL -hw_version $HWVERSION -start_addr 0xa0040000 -erase_size 0x01fc0000 -image_name all_noboot -input out_tmp1.img -output $OUTFILE
  rm -f out_tmp.img
  rm -f out_tmp1.img
echo " done."

# Create MD5 file
md5sum -b $OUTFILE | awk -F' ' '{print $1}' > $OUTFILE.md5

echo -n " - Creating .ZIP output file..."
zip -j $OUTZIPFILE.zip $OUTFILE $OUTFILE.md5 $OUTFILE_OU $OUTFILE_OU.md5 > /dev/null
rm -f $OUTFILE_OU
rm -f $OUTFILE_OU.md5
echo " done."

if [ -e $OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo " To flash the created image, copy the file usb_update.img"
  echo " to the root (/) of your FAT32 formatted USB stick."
  echo " Insert the USB stick in the/a USB port on the receiver."
  echo
  echo " To start the flashing process switch off the receiver with"
  echo " the power switch on the back. Press and hold the POWER key"
  echo " on the frontpanel and switch the receiver back on with the"
  echo " power switch on the back. Keep holding the POWER key down"
  echo " and wait until the display shows USB UPGRADE."
  echo
  echo " Then release the POWER key; flashing will start."
  echo " It is finished when the display shows DONE. Press the POWER"
  echo " key to reboot the receiver and run the software just flashed."
  echo -e "\033[00m"
fi

# Clean up
rm -f $TMPDIR/uImage
rm -f $TMPDIR/mtd_kernel.pad
rm -f $TMPDIR/mtd_dummy_root.bin
rm -f $TMPDIR/mtd_dummy_root.pad
rm -f $TMPDIR/mtd_root.bin
rm -f $TMPDIR/mtd_root.sum
rm -f $TMPDIR/mtd_root.pad
rm -f $TMPDIR/mtd_var.bin

