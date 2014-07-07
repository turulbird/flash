#!/bin/bash
# "-----------------------------------------------------------------------"
# "This script creates flashable images for NOR flash receivers."
# "Author: Schischu, Oxygen-1, BPanther, TangoCash, Grabber66, Audioniek"
# "Last Change: 07-03-2014"
#
# "Changed for \"classic flash\" (no mini_fo) for UFS910 and add more"
# "receivers by BPanther, 13-Feb-2013."
# "Adapted to new flash environment by Audioniek, 03-07-2014."
#
# "Supported receivers (autoselection) are:"
# "ufs910, ufs922, octagon1008, fortis_hdbox, cuberevo_mini2, cuberevo
# "and cuberevo_2000hd"
# "-----------------------------------------------------------------------"
# "An image is assumed to have been built prior to calling this script!
# "-----------------------------------------------------------------------"

# Set up the variables
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad
MKSQUASHFS4=$TOOLSDIR/mksquashfs4.0
FUP=$TOOLSDIR/fup

OUTFILE=miniFLASH.img
OUTZIPFILE="$HOST"_"$IMAGE"_"P$PATCH"_"$GITVERSION"

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

# Define sizes of kernel, root, var and erase block
case "$BOXTYPE" in
  ufs910) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=190000
    SIZE_ROOT=B40000
    SIZE_VAR=2F0000
    ERASE_SIZE=10000;;
  ufs922) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=1A0000
    SIZE_ROOT=B40000
    SIZE_VAR=2E0000
    ERASE_SIZE=10000;;
  fortis_hdbox) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=200000
    SIZE_ROOT=C00000
    SIZE_VAR=11C0000
    ERASE_SIZE=20000
    ;;
  octagon1008) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=200000
    SIZE_ROOT=C00000
    SIZE_VAR=11C0000
    ERASE_SIZE=20000
    ;;
  cuberevo_mini2) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=220000
    SIZE_ROOT=1380000
    SIZE_VAR=A00000
    ERASE_SIZE=20000
    HWMODEL=00053000
    HWVERSION=00010000
    OUTFILE_OU=$OUTDIR/mtd234.img
    OUTFILE=$OUTDIR/usb_update.img;;
  cuberevo) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=220000
    SIZE_ROOT=1380000
    SIZE_VAR=A00000
    ERASE_SIZE=20000
    HWMODEL=00051100
    HWVERSION=00010001
    OUTFILE_OU=$OUTDIR/mtd234.img
    OUTFILE=$OUTDIR/usb_update.img;;
  cuberevo_2000hd) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=220000
    SIZE_ROOT=1380000
    SIZE_VAR=A00000
    ERASE_SIZE=20000
    HWMODEL=00056000
    HWVERSION=00010000
    OUTFILE_OU=$OUTDIR/mtd234.img
    OUTFILE=$OUTDIR/usb_update.img;;
  *) echo "Creating $IMAGE flash image for <$BOXTYPE -> ufs910>..."
    SIZE_KERNEL=190000
    SIZE_ROOT=B40000
    SIZE_VAR=2F0000
    ERASE_SIZE=10000;;
esac

echo
echo " - Prepare kernel file..."
cp $TMPKERNELDIR/uImage $TMPDIR/uImage
$PAD $SIZE_KERNEL $TMPDIR/uImage $TMPDIR/mtd_kernel.pad.bin
echo " done."

echo " - Checking kernel size..."
SIZE=`stat $TMPDIR/uImage -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "%08X" $SIZE`
if [[ $SIZEH > "$SIZE_KERNEL" ]]; then
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " KERNEL TOO BIG. $SIZED (0x$SIZEH, max. 0x$SIZE_KERNEL)" > /dev/stderr
  echo
  echo " Press ENTER to exit..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  read
  exit
else
echo " OK: kernel is $SIZED (0x$SIZEH, max, 0x$SIZE_KERNEL) bytes."
fi

# --- ROOT ---
echo -n " - Create a squashfs 4.0 partition for root..."
#echo "MKSQUASHFS4 $TMPROOTDIR $CURDIR/mtd_root.bin -noappend -comp gzip -always-use-fragments -b 262144"
$MKSQUASHFS4 $TMPROOTDIR $TMPDIR/mtd_root.bin -noappend -comp gzip -always-use-fragments -b 262144 > /dev/null
#echo "PAD $SIZE_ROOT $TMPDIR/mtd_root.bin $TMPDIR/mtd_root.pad.bin"
$PAD $SIZE_ROOT $TMPDIR/mtd_root.bin $TMPDIR/mtd_root.pad.bin
echo " done."

echo -n " - Checking root size..."
SIZE=`stat $TMPDIR/mtd_root.bin -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "%08X" $SIZE`
if [[ $SIZEH > "$SIZE_ROOT" ]]; then
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " ROOT TOO BIG. $SIZED (0x$SIZEH, max. 0x$SIZE_ROOT)" > /dev/stderr
  echo
  echo " Press ENTER to exit..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  read
  exit
else
echo " OK: root is $SIZED (0x$SIZEH, max, 0x$SIZE_ROOT bytes)."
fi

# --- VAR ---
echo -n " - Create a jffs2 partition for var..."
#echo "MKFSJFFS2 -qUf -p$SIZE_VAR -e$ERASE_SIZE -r $TMPVARDIR -o $TMPDIR/mtd_var.bin"
$MKFSJFFS2 -qUf -p$SIZE_VAR -e$ERASE_SIZE -r $TMPVARDIR -o $TMPDIR/mtd_var.bin
#echo "SUMTOOL -p -e $ERASE_SIZE -i $TMPDIR/mtd_var.bin -o $TMPDIR/mtd_var.sum.bin"
$SUMTOOL -p -e $ERASE_SIZE -i $TMPDIR/mtd_var.bin -o $TMPDIR/mtd_var.sum.bin
#echo "$PAD $SIZE_VAR $TMPDIR/mtd_var.sum.bin $TMPDIR/mtd_var.sum.pad.bin"
$PAD $SIZE_VAR $TMPDIR/mtd_var.sum.bin $TMPDIR/mtd_var.sum.pad.bin
echo " done."

echo -n " - Checking var size..."
SIZE=`stat $TMPDIR/mtd_var.sum.bin -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "%08X" $SIZE`
if [[ $SIZEH > "$SIZE_VAR" ]]; then
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " VAR TOO BIG. $SIZED (0x$SIZEH, max. 0x$SIZE_VAR)" > /dev/stderr
  echo
  echo " Press ENTER to exit..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  read
  exit
else
echo " OK: var is $SIZED (0x$SIZEH, max, 0x$SIZE_VAR bytes)."
fi

# --- update.img ---
# Merge all parts together
echo -n "- Create output file(s) and MD5..."
if [ "$BOXTYPE" == "cuberevo_mini2" -o "$BOXTYPE" == "cuberevo" -o "$BOXTYPE" == "cuberevo-2000hd" ]; then
  cat $TMPDIR/mtd_kernel.pad.bin > $OUTDIR/out_tmp.img
  cat $TMPDIR/mtd_root.pad.bin >> $OUTDIR/out_tmp.img
  cat $TMPDIR/mtd_var.sum.pad.bin >> $OUTDIR/out_tmp.img
  cp $OUTDIR/out_tmp.img $OUTFILE_OU
  md5sum -b $OUTFILE_OU | awk -F' ' '{print $1}' > $OUTFILE_OU.md5
  cat $TOOLSDIR/mtd1.img $OUTDIR/out_tmp.img > $OUTDIR/out_tmp1.img
  $TOOLSDIR/mkdnimg -make usbimg -vendor_id 0x00444753 -product_id 0x6c6f6f6b -hw_model $HWMODEL -hw_version $HWVERSION -start_addr 0xa0040000 -erase_size 0x01fc0000 -image_name all_noboot -input $OUTDIR/out_tmp1.img -output $OUTFILE
  rm -f $OUTDIR/out_tmp.img
  rm -f $OUTDIR/out_tmp1.img
else
  cat $TMPDIR/mtd_kernel.pad.bin > $OUTFILE
  cat $TMPDIR/mtd_root.pad.bin >> $OUTFILE
  cat $TMPDIR/mtd_var.sum.pad.bin >> $OUTFILE
fi
echo " done."

# Create MD5 file
md5sum -b $OUTFILE | awk -F' ' '{print $1}' > $OUTFILE.md5

echo " - Creating .ZIP output file..."
if [ "$BOXTYPE" == "cuberevo_mini2" -o "$BOXTYPE" == "cuberevo" -o "$BOXTYPE" == "cuberevo-2000hd" ]; then
  zip -j $OUTZIPFILE.zip $OUTFILE $OUTFILE.md5 $OUTFILE_OU $OUTFILE_OU.md5
  rm -f $OUTFILE_OU
  rm -f $OUTFILE_OU.md5
else
  zip -j $OUTZIPFILE.zip $OUTFILE $OUTFILE.md5 > /dev/null
fi
echo " done."

if [ -e $OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  case "$BOXTYPE" in
    ufs910|ufs922)
      echo "To flash the created image copy the file miniFLASH.img"
      echo "to the root (/) of your FAT32 formatted USB stick."
      echo "Insert the USB stick in the/a USB port on the receiver."
      echo
      echo "To start the flashing process press RECORD for 10 sec on your"
      echo "remote control while the receiver is starting.";;
    cuberevo|cuberevo_mini2|cuberevo_2000hd)
      echo "To flash the created image rename the file miniFLASH.img to"
      echo "usb_update.img and copy it to the root (/) of your FAT32"
      echo "formatted USB stick."
      echo "Insert the USB stick in the/a USB port on the receiver."
      echo
      echo "To start the flashing process press POWER for 10 sec on your"
      echo "receiver front panel while it is starting."
  esac       
  echo -e "\033[00m"
fi

# Clean up
rm -f $CURDIR/uImage
rm -f $CURDIR/mtd_root.bin
rm -f $CURDIR/mtd_var.bin
rm -f $CURDIR/mtd_var.sum.bin
rm -f $CURDIR/mtd_kernel.pad.bin
rm -f $CURDIR/mtd_root.pad.bin
rm -f $CURDIR/mtd_var.sum.pad.bin

