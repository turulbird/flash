#!/bin/bash
# ----------------------------------------------------------------------
# This script prepares the root of a neutrino image pending further
# processing.
#
# Author: Audioniek, based on previous work by schishu and bpanther"
# Date: 07-02-2014"

RELEASEDIR=$1

common() {
  echo -n " Copying release image..."
  cp -a $RELEASEDIR/* $TMPROOTDIR
  echo " done."

  echo -n " Creating devices..."
  cd $TMPROOTDIR/dev/
  $TMPROOTDIR/var/etc/init.d/makedev start 2> /dev/null
  cd - > /dev/null
  echo " done."

  echo -n " Move kernel..."
  mv $TMPROOTDIR/boot/uImage $TMPKERNELDIR/uImage
  echo " done."
}

# Prepare neutrino root according to box type
case $BOXTYPE in
  atevio7500|hs7110|hs7810a)
    common;;
  fortis_hdbox|octagon1008)
    common;;
    # To be able to flash with the original loader, the image has to be split:
    # mtd3 (app_high, 5 Mbyte - 128kbyte): 
    # mtd4 (root, 8 Mbyte - 128kbyte)    :
    # mtd5 (dev, 3 Mbyte - 128kbyte)     : var
    # mtd6 (config, 1 Mbyte)             : boot (bootscreen)
    # mtd7 (user, 4 Mbyte)               : boot (without bootscreen))
  spark|spark7162)
    common;;
  ufc960)
    find $RELEASEDIR -mindepth 1 -maxdepth 1 -exec cp -at$TMPROOTDIR -- {} +

    echo -n " Creating devices..."
    cd $TMPROOTDIR/dev/
    $TMPROOTDIR/etc/init.d/makedev start
    cd - > /dev/null
    echo " done."

    echo -n " Set up init_mini_fo..."
    mkdir $TMPROOTDIR/root_rw
    mkdir $TMPROOTDIR/storage
    cp $TOOLSDIR/init_mini_fo $TMPROOTDIR/sbin/
    chmod 777 $TMPROOTDIR/sbin/init_mini_fo

    # --- STORAGE FOR MINI_FO ---
    mkdir $TMPSTORAGEDIR/root_ro
    #mv    $TMPROOTDIR/var $TMPSTORAGEDIR/
    echo " done."

    echo -n " Adapt fstab..."
    sed -i 's|/dev/sda.*||g' $TMPROOTDIR/etc/fstab
    #echo "/dev/mtdblock4	/var	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
    echo " done."

    echo -n " Move kernel..."
    mv $TMPROOTDIR/boot/uImage $TMPKERNELDIR/uImage
    echo " done."
    ;;
esac
