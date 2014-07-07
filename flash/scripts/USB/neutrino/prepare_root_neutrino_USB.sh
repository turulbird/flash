#!/bin/bash
# ----------------------------------------------------------------------
# This script prepares the root of an enigma2 image pending further
# processing.
#
# Author: Audioniek, based on previous work by schishu and bpanther"
# Date: 06-29-2014"

CURDIR=$1
RELEASEDIR=$2
TMPROOTDIR=$3
TMPSTORAGEDIR=$4
TMPKERNELDIR=$5
$BOXTYPE=$6

#echo "-----------------------------------------------------------------------"
#echo
case $BOXTYPE in
  atevio7500)
    ;;
  [spark | spark7162])
    cp -a $RELEASEDIR/* $TMPROOTDIR

    cd $TMPROOTDIR/dev/
    $TMPROOTDIR/etc/init.d/makedev start
    cd - > /dev/null

    # --- BOOT ---
    mv $TMPROOTDIR/boot/uImage $TMPKERNELDIR/uImage
    ;;
  ufc960)
    find $RELEASEDIR -mindepth 1 -maxdepth 1 -exec cp -at$TMPROOTDIR -- {} +

    cd $TMPROOTDIR/dev/
    $TMPROOTDIR/etc/init.d/makedev start
    cd - > /dev/null

    mkdir $TMPROOTDIR/root_rw
    mkdir $TMPROOTDIR/storage
    cp ../common/init_mini_fo $TMPROOTDIR/sbin/
    chmod 777 $TMPROOTDIR/sbin/init_mini_fo

    sed -i 's|/dev/sda.*||g' $TMPROOTDIR/etc/fstab
    #echo "/dev/mtdblock4	/var	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab

    # --- BOOT ---
    mv $TMPROOTDIR/boot/uImage $TMPKERNELDIR/uImage

    # --- STORAGE FOR MINI_FO ---
    mkdir $TMPSTORAGEDIR/root_ro
    #mv    $TMPROOTDIR/var $TMPSTORAGEDIR/
    ;;
esac
