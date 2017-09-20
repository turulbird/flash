#!/bin/bash
# ----------------------------------------------------------------------
# This script prepares the root of an enigma2 image pending further
# processing.
#
# Author: Audioniek, based on previous work by schishu and bpanther"
# Date: 08-03-2014"

#echo "-----------------------------------------------------------------------"
#echo

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

case $BOXTYPE in
  atevio7500)
    common
    ;;
  fortis_hdbox|octagon1008)
    common
    # Move kernel back
    mv $TMPKERNELDIR/uImage $TMPROOTDIR/boot/uImage;;
  hs7119|hs7819)
    common;;
  spark|spark7162)
    common;;
  ufc960)
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
  *)
    echo "Receiver $BOXTYPE not supported."
    echo
    ;;
esac

