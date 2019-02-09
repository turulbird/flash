#!/bin/bash
# "-----------------------------------------------------------------------"
# "This script creates flashable images for NOR flash receivers."
# "Author: Schischu, Oxygen-1, BPanther, TangoCash, Grabber66, Audioniek"
# "Last Change: 07-11-2014"
#
# "Changed for \"classic flash\" (no mini_fo) for UFS910 and add more"
# "receivers by BPanther, 13-Feb-2013."
# "Adapted to new flash environment by Audioniek, 11-07-2014."
# "UFS922 erase size corrected, 14-01-2015."
#
# "Supported receivers (autoselection) are:"
# " - Kathrein UFS910 (ufs910)"
# " - Kathrein UFS922 (ufs922)"
# " - Fortis HS9510 (octagon1008)"
# " - Fortis FS9000/9200 (fortis_hdbox)"
# " - Cuberevo MINI2 (cuberevo_mini2)"
# " - Cuberevo (cuberevo)"
# " - Cuberevo 2000HD (cuberevo_2000hd)"
# "-----------------------------------------------------------------------"
# "An image is assumed to have been built prior to calling this script!
# "-----------------------------------------------------------------------"
# ---------------------------------------------------------------------------
# Changes:
# 20170920 Audioniek   Fix syntax error in call of mksquashfs4.0.
# 20190206 Audioniek   Switch to mksquashfs4.2.
# 20190208 Audioniek   Add cuberevo_min; clarify flashing instructions.
#

# Set up the variables
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad
MKSQUASHFS4=$TOOLSDIR/mksquashfs4.2

OUTFILE=miniFLASH.img
OUTZIPFILE="$HOST"_"$IMAGE"_"P$PATCH"_"$GITVERSION"

# Define sizes of kernel, root, var and erase block
case "$BOXTYPE" in
  ufs910) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=0x00190000
    SIZE_ROOTH=0x00B40000
    SIZE_ROOTD=11796480
    SIZE_VARH=0x002F0000
    SIZE_VARD=3080192
    ERASE_SIZE=0x10000;;
  ufs922) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=0x001A0000
    SIZE_ROOTH=0x00B40000
    SIZE_ROOTD=11796480
    SIZE_VARH=0x002E0000
    SIZE_VARD=3014656
    ERASE_SIZE=0x10000;;
  fortis_hdbox) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=0x00200000
    SIZE_ROOTH=0x00C00000
    SIZE_ROOTD=12582912
    SIZE_VARH=0x011C0000
    SIZE_VARD=18612224
    ERASE_SIZE=0x20000;;
  octagon1008) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=0x00200000
    SIZE_ROOTH=0x00C00000
    SIZE_ROOTD=12582912
    SIZE_VARH=0x011C0000
    SIZE_VARD=18612224
    ERASE_SIZE=0x20000;;
  cuberevo_mini|cuberevo_mini2) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=0x00220000
    SIZE_ROOTH=0x01380000
    SIZE_ROOTD=20447232
    SIZE_VARH=0x00A00000
    SIZE_VARD=655360
    ERASE_SIZE=0x20000
    HWMODEL=0x00053000
    HWVERSION=0x00010000
    OUTFILE_OU=mtd234.img
    OUTFILE=usb_update.img;;
  cuberevo) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=0x00220000
    SIZE_ROOTH=0x01380000
    SIZE_ROOTD=20447232
    SIZE_VARH=0x00A00000
    SIZE_VARD=655360
    ERASE_SIZE=0x20000
    HWMODEL=0x00051100
    HWVERSION=0x00010001
    OUTFILE_OU=mtd234.img
    OUTFILE=usb_update.img;;
  cuberevo_2000hd) echo "Creating $IMAGE flash image for $BOXTYPE..."
    SIZE_KERNEL=0x00220000
    SIZE_ROOTH=0x01380000
    SIZE_ROOTD=20447232
    SIZE_VARH=0x00A00000
    SIZE_VARD=655360
    ERASE_SIZE=0x20000
    HWMODEL=0x00056000
    HWVERSION=0x00010000
    OUTFILE_OU=mtd234.img
    OUTFILE=usb_update.img;;
  cuberevo_3000hd) echo "Creating flash image for $BOXTYPE..."
    SIZE_KERNEL=0x220000
    SIZE_ROOTH=0x1380000
    SIZE_ROOTD=20447232
    SIZE_VARH=0xA00000
    SIZE_VARD=655360
    ERASE_SIZE=0x20000
    HWMODEL=0x00053000
    HWVERSION=0x00010000
    OUTFILE_OU=mtd234.img
    OUTFILE=usb_update.img;;
  *) echo "Unsupported receiver $BOXTYPE, assuming ufs910..."
    SIZE_KERNEL=0x00190000
    SIZE_ROOTH=0x00B40000
    SIZE_ROOTD=11796480
    SIZE_VARH=0x002F0000
    SIZE_VARD=3080192
    ERASE_SIZE=0x10000;;
esac

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

# --- ROOT ---
echo -n " - Create a squashfs 4.2 partition for root..."
#echo -e "\nMKSQUASHFS4 $TMPROOTDIR $CURDIR/mtd_root.bin -noappend -always-use-fragments -b 262144"
$MKSQUASHFS4 $TMPROOTDIR $TMPDIR/mtd_root.bin -noappend -comp gzip -always-use-fragments -b 262144 > /dev/null
#echo -e "\nPAD $SIZE_ROOT $TMPDIR/mtd_root.bin $TMPDIR/mtd_root.pad.bin"
$PAD $SIZE_ROOTH $TMPDIR/mtd_root.bin $TMPDIR/mtd_root.pad
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

# --- VAR ---
echo -n " - Create a jffs2 partition for var..."
#echo "MKFSJFFS2 -qUf -p$SIZE_VAR -e$ERASE_SIZE -r $TMPVARDIR -o $TMPDIR/mtd_var.bin"
$MKFSJFFS2 -qUf -p$SIZE_VAR -e$ERASE_SIZE -r $TMPVARDIR -o $TMPDIR/mtd_var.bin
#echo "SUMTOOL -p -e $ERASE_SIZE -i $TMPDIR/mtd_var.bin -o $TMPDIR/mtd_var.sum.bin"
$SUMTOOL -p -e $ERASE_SIZE -i $TMPDIR/mtd_var.bin -o $TMPDIR/mtd_var.sum
$PAD $SIZE_VARH $TMPDIR/mtd_var.sum $TMPDIR/mtd_var.pad
echo " done."

echo -n " - Checking var size..."
SIZE=`stat $TMPDIR/mtd_var.sum -t --format %s`
SIZED=`printf "%d" $SIZE`
SIZEH=`printf "0x%08X" $SIZE`
if [[ $SIZEH > "$SIZE_VARH" ]]; then
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " VAR TOO BIG: $SIZED ($SIZEH, max. $SIZE_VARH) bytes." > /dev/stderr
  echo
  echo " Press ENTER to exit..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  read
  exit
else
echo " OK: $SIZED ($SIZEH, max. $SIZE_VARH) bytes."
fi

# Merge all parts together
cd $OUTDIR
echo -n " - Create output file(s) and MD5..."
if [ "$BOXTYPE" == "cuberevo_mini2" -o "$BOXTYPE" == "cuberevo" -o "$BOXTYPE" == "cuberevo-2000hd" ]; then
  cat $TMPDIR/mtd_kernel.pad > out_tmp.img
  cat $TMPDIR/mtd_root.pad >> out_tmp.img
  cat $TMPDIR/mtd_var.pad >> out_tmp.img
  cp out_tmp.img $OUTFILE_OU
  md5sum -b $OUTFILE_OU | awk -F' ' '{print $1}' > $OUTFILE_OU.md5
  cat $TOOLSDIR/mtd1.img out_tmp.img > out_tmp1.img
  $TOOLSDIR/mkdnimg -make usbimg -vendor_id 0x00444753 -product_id 0x6c6f6f6b -hw_model $HWMODEL -hw_version $HWVERSION -start_addr 0xa0040000 -erase_size 0x01fc0000 -image_name all_noboot -input out_tmp1.img -output $OUTFILE
  rm -f out_tmp.img
  rm -f out_tmp1.img
else
  cat $TMPDIR/mtd_kernel.pad > $OUTFILE
  cat $TMPDIR/mtd_root.pad >> $OUTFILE
  cat $TMPDIR/mtd_var.pad >> $OUTFILE
fi
echo " done."

# Create MD5 file
md5sum -b $OUTFILE | awk -F' ' '{print $1}' > $OUTFILE.md5

echo -n " - Creating .ZIP output file..."
if [ "$BOXTYPE" == "cuberevo_mini2" -o "$BOXTYPE" == "cuberevo" -o "$BOXTYPE" == "cuberevo-2000hd" ]; then
  zip -j $OUTZIPFILE.zip $OUTFILE $OUTFILE.md5 $OUTFILE_OU $OUTFILE_OU.md5 > /dev/null
  rm -f $OUTFILE_OU
  rm -f $OUTFILE_OU.md5
else
  zip -j $OUTZIPFILE.zip $OUTFILE $OUTFILE.md5 > /dev/null
fi
echo " done."

if [ -e $OUTFILE ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  case "$BOXTYPE" in
    ufs910|ufs922)
      echo
      echo " The receiver must be equipped with a TDTmaxiboot boot loader,"
      echo " or a boot loader with compatible capabilities."
      echo
      echo " To flash the created image copy the file miniFLASH.img"
      echo " to the root (/) of your FAT32 formatted USB stick."
      echo " Insert the USB stick in the/a USB port on the receiver."
      echo
      echo " To start the flashing process press RECORD for 10 sec on your"
      echo " remote control while the receiver is starting.";;
    cuberevo|cuberevo_mini|cuberevo_mini2|cuberevo_2000hd)
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
      echo " key to reboot the receiver and run the software just flashed.";;
    fortis_hdbox|octagon1008)
      echo
      echo " The receiver must be equipped with a TDTmaxiboot boot loader,"
      echo " or a boot loader with compatible capabilities."
      echo
      echo " You have to flash the file $OUTFILE using the AAF Recovery Tool"
      echo " (ART) program. For further info, see the instructions of ART.";;
  esac
  echo -e "\033[00m"
fi
cd - > /dev/null

# Clean up
rm -f $CURDIR/uImage
rm -f $CURDIR/mtd_kernel.pad
rm -f $CURDIR/mtd_root.bin
rm -f $CURDIR/mtd_root.pad
rm -f $CURDIR/mtd_var.bin
rm -f $CURDIR/mtd_var.sum
rm -f $CURDIR/mtd_var.pad

