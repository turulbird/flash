#!/bin/bash
# ----------------------------------------------------------------------
# This script prepares the root of a Tvheadend image intended to run
# from or on a USB stick pending further processing.
#
# Author: Audioniek, based on previous work by schishu and bpanther"
# Date: 08-28-2014"

# ---------------------------------------------------------------------------
# Changes:
# 
# 20150810 Audioniek   Tvheadend added, based on enigma2 version.
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

  echo -n " Move kernel..."
  mv $TMPROOTDIR/boot/uImage $TMPKERNELDIR/uImage
  echo " done."
}

#echo "-----------------------------------------------------------------------"
#echo
case $BOXTYPE in
  atevio7500)
    common
    ;;
  fortis_hdbox|octagon1008)
    common
    # Move kernel back
    mv $TMPKERNELDIR/uImage $TMPROOTDIR/boot/uImage
    ;;
  hs7110|hs7119|hs7810a|hs7819)
    common
    ;;
  [spark|spark7162])
    common
    ;;
  ufc960|ufs910)
    common
#    find $RELEASEDIR -mindepth 1 -maxdepth 1 -exec cp -at$TMPROOTDIR -- {} +

#    echo -n " Creating devices..."
#    cd $TMPROOTDIR/dev/
#    $TMPROOTDIR/etc/init.d/makedev start > /dev/null 2> /dev/null
#    cd - > /dev/null
#    echo " done."

    mkdir $TMPROOTDIR/root_rw
    mkdir $TMPROOTDIR/storage
    cp ../common/init_mini_fo $TMPROOTDIR/sbin/
    chmod 777 $TMPROOTDIR/sbin/init_mini_fo

#    echo -n "Moving kernel..."
#    mv $TMPROOTDIR/boot/uImage $TMPKERNELDIR/uImage
#    echo " done."

    # --- STORAGE FOR MINI_FO ---
!!    mkdir $TMPSTORAGEDIR/root_ro
    echo " done."
    ;;
  [ufs912|ufs913])
    common

    echo -n "Fill firmware directory..."
    mv $TMPROOTDIR/lib/firmware/audio.elf $TMPFWDIR/audio.elf
    mv $TMPROOTDIR/lib/firmware/video.elf $TMPFWDIR/video.elf

    mv $TMPROOTDIR/boot/bootlogo.mvi $TMPROOTDIR/etc/bootlogo.mvi
    sed -i "s/\/boot\/bootlogo.mvi/\/etc\/bootlogo.mvi/g" $TMPROOTDIR/etc/init.d/rcS

    rm -f $TMPROOTDIR/boot/*

    if [ "$BOXTYPE" == "ufs912" ];then
       echo "/dev/mtdblock3	/boot	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
       #echo "/dev/mtdblock5	/root	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
    else
       echo "/dev/mtdblock8	/boot	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
       #echo "/dev/mtdblock10	/root	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
    fi
    echo " done."
    ;;
  *)
    echo "Receiver $BOXTYPE not supported."
    echo
    ;;
esac
