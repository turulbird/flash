#!/bin/bash
# ----------------------------------------------------------------------
# This script prepares the root of an enigma2 image intended to run from
# or on a USB stick pending further processing.
#
# Author: Audioniek, based on previous work by schishu and bpanther"
# Date: 08-07-2014"
#
# ---------------------------------------------------------------------------
# Changes:
# 20140708 Audioniek   Initial version
# 20200116 Audioniek   Added Fortis 4G receivers

RELEASEDIR=$1

common() {
  echo -n " Copying release image..."
  find $RELEASEDIR -mindepth 1 -maxdepth 1 -exec cp -at$TMPROOTDIR -- {} +
  echo " done."

  echo -n " Creating devices..."
  cd $TMPROOTDIR/dev/
  $TMPROOTDIR/etc/init.d/makedev start > /dev/null 2> /dev/null
  cd - > /dev/null
  echo " done."

  echo -n " Move kernel..."
  mv $TMPROOTDIR/boot/uImage $TMPKERNELDIR/uImage
  echo " done."
}

#echo "-----------------------------------------------------------------------"
#echo
case $BOXTYPE in
  adb_box)
    common
    ;;
  atevio7500)
    common
    ;;
  fortis_hdbox|octagon1008)
    common
    ;;
  hs7110|hs7119|hs7420|hs7429|hs7810a|hs7819)
    common
    ;;
  dp2010|dp6010|dp7000|dp7001|dp7050|ep8000|epp8000|gpv8000)
    common
    ;;
  cuberevo|cuberevo_mini|cuberevo_mini2|cuberevo_250hd)
    common
    ;;
  spark|spark7162)
    common
    ;;
  ufc960|ufs910|ufs922)
    common

#    mkdir $TMPROOTDIR/root_rw
#    mkdir $TMPROOTDIR/storage
#    cp ./flash_tools/init_mini_fo $TMPROOTDIR/sbin/
#    chmod 777 $TMPROOTDIR/sbin/init_mini_fo

#    # --- STORAGE FOR MINI_FO ---
#    mkdir $TMPROOTDIR/root_ro
    ;;
  ufs912|ufs913)
    common

    echo -n " Fill firmware directory..."
    mv $TMPROOTDIR/boot/audio.elf $TMPFWDIR/audio.elf
    mv $TMPROOTDIR/boot/video.elf $TMPFWDIR/video.elf

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
  vitamin_hd5000)
    common
    ;;
  *)
    echo "Receiver $BOXTYPE not supported."
    echo
    ;;
esac

