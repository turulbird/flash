#!/bin/bash
# ----------------------------------------------------------------------
# This script prepares the root of a neutrino image intended to run from
# or on a USB stick pending further processing.
#
# Author: Audioniek, based on previous work by schishu and bpanther"
# Date: 08-03-2014"
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
  if [ -e $TMPROOTDIR/var/etc/init.d/makedev ]; then
    $TMPROOTDIR/var/etc/init.d/makedev start > /dev/null 2> /dev/null
  else
    $TMPROOTDIR/etc/init.d/makedev start > /dev/null 2> /dev/null
  fi
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
  hs8200)
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
  hl101)
    common
    ;;
  spark|spark7162)
    common
    ;;
  ufc960|ufs910|ufs922)
    find $RELEASEDIR -mindepth 1 -maxdepth 1 -exec cp -at$TMPROOTDIR -- {} +

    if [ ! -e $TMPROOTDIR/dev/mtd0 ]; then
      echo -n " Creating devices..."
      cd $TMPROOTDIR/dev/
      if [ -e $TMPROOTDIR/var/etc/init.d/makedev ]; then
        $TMPROOTDIR/var/etc/init.d/makedev start >/dev/null 2>/dev/null
      else
        $TMPROOTDIR/etc/init.d/makedev start >/dev/null 2>/dev/null
      fi
      cd - > /dev/null
      echo " done."
    fi

    echo -n " Add init_mini_fo..."
    mkdir $TMPROOTDIR/root_rw
    mkdir $TMPROOTDIR/storage
    cp ../common/init_mini_fo $TMPROOTDIR/sbin/
    chmod 777 $TMPROOTDIR/sbin/init_mini_fo
    echo " done."

    echo -n " Adapt /etc/fstab..."
    sed -i 's|/dev/sda.*||g' $TMPROOTDIR/etc/fstab
    #echo "/dev/mtdblock4	/var	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
    echo " done."

    echo -n " Move kernel..."
    mv $TMPROOTDIR/boot/uImage $TMPKERNELDIR/uImage
    echo " done."

    # --- STORAGE FOR MINI_FO ---
    mkdir $TMPSTORAGEDIR/root_ro
    ;;
  ufs912|ufs913)
    common

    echo -n " Fill firmware directory..."
    mv $TMPROOTDIR/boot/audio.elf $TMPFWDIR/audio.elf
    mv $TMPROOTDIR/boot/video.elf $TMPFWDIR/video.elf

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
  vip1_v1|vip1_v2|vip2)
    common
    ;;
  vitamin_hd5000)
    common
    ;;
  *)
    echo "Receiver $BOXTYPE not supported."
    echo
    ;;
esac

