# ---------------------------------------------------------------------------
# "This script creates a USB-image for Fortis HS8200 receivers in a .tar.gz
# archive."
#
# Author: Schischu/Audioniek"
# Date: 08-28-2014"
#
# Note: Receiver requires a changed bootloader to run the image created.
#
# ---------------------------------------------------------------------------
# "It is assumed that an image was already built prior to executing this"
# "script!"
# "-----------------------------------------------------------------------"

# Set up the variables
TMPDUMDIR=$TMPDIR/DUMMY
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad
MKSQUASHFS=$TOOLSDIR/mksquashfs3.3
FUP=$TOOLSDIR/fup

OUTFILE="$BOXTYPE"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"$GITVERSION"
OUTZIPFILE="$BOXTYPE"_"$INAME""$IMAGE"_"$MEDIAFW"_"$OUTTYPE"_"P$PATCH"_"$GITVERSION.zip"

if [ -e $OUTDIR ]; then
  rm -f $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

cd $OUTDIR
echo "-- Creating tar.gz output file ----------------------------------------"
echo
echo -n " Move kernel back..."
mv $TMPKERNELDIR/uImage $TMPROOTDIR/boot/uImage
echo " done."
echo -n " Compressing release image..."
cd $TMPROOTDIR
tar -zcf $OUTDIR/$OUTFILE.tar.gz * > /dev/null 2> /dev/null
echo " done."
echo -n " - Creating MD5 checksum..."
md5sum -b $OUTDIR/$OUTFILE.tar.gz | awk -F' ' '{print $1}' > $OUTDIR/$OUTFILE.md5
echo " done."
echo -n " Pack everything in a zip..."
zip -j $OUTDIR/$OUTFILE.zip *
echo " done."
cd $CURDIR

if [ -e $OUTDIR/$OUTFILE.tar.gz ]; then
  echo -e "\033[01;32m"
  echo "-- Instructions -------------------------------------------------------"
  echo
  echo " To be supplied in a future release."
  echo -e "\033[00m"
fi

