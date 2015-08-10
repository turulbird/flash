#!/bin/bash
# ---------------------------------------------------------------------------
# This script prepares the root of a Tvheadend image pending further
# processing.
#
# Author: Audioniek, based on previous work by schishu and bpanther"
# Date: 06-08-2015"
# ---------------------------------------------------------------------------
# Changes:
#
# ---------------------------------------------------------------------------

RELEASEDIR=$1

common() {
  echo -n " Copying release image..."
  find $RELEASEDIR -mindepth 1 -maxdepth 1 -exec cp -at$TMPROOTDIR -- {} +
  echo " done."

  if [ ! -e $TMPROOTDIR/dev/mtd0 ]; then
    echo -n " Creating devices..."
    cd $TMPROOTDIR/dev/
    if [ -e $TMPROOTDIR/var/etc/init.d/makedev ]; then
      $TMPROOTDIR/var/etc/init.d/makedev start > /dev/null 2> /dev/null
    else
      $TMPROOTDIR/etc/init.d/makedev start > /dev/null 2> /dev/null
    fi
    cd - > /dev/null
    echo " done."
  fi

  echo -n " Moving kernel..."
  mv $TMPROOTDIR/boot/uImage $TMPKERNELDIR/uImage
  echo " done."
}

# Prepare Tvheadend root according to box type
case $BOXTYPE in
  atevio7500)
# for loader 6.00
    common;;
  fortis_hdbox|octagon1008)
    common;;
  hs7110|hs7119|hs7810a|hs7819|dp6010|dp7000|dp7001|epp8000)
# for loader 6.XX/7.XX/8.XX
    common;;
  spark|spark7162)
    common;;
  ufs912|ufs913)
# TODO: test!
    common
    export TMPFWDIR=$TMPDIR/FW
    if [ -e $TMPFWDIR ]; then
      rm -rf $TMPFWDIR/*
    elif [ ! -d $TMPFWDIR ]; then
      mkdir $TMPFWDIR
    fi

    echo -n "Filling firmware directory..."
    mv $TMPROOTDIR/lib/firmware/audio.elf $TMPFWDIR/audio.elf
    mv $TMPROOTDIR/lib/firmware/video.elf $TMPFWDIR/video.elf

    rm -f $TMPROOTDIR/boot/*

    if [ "$BOXTYPE" == "ufs912" ]; then
       echo "/dev/mtdblock3	/boot	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
       #echo "/dev/mtdblock5	/root	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
    elif [ "$BOXTYPE" == "ufs913" ]; then
       echo "/dev/mtdblock8	/boot	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
       #echo "/dev/mtdblock10	/root	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
    fi
    echo " done."
    ;;
  *)
    common;;
esac
