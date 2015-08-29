#!/bin/bash
# ---------------------------------------------------------------------------
# This script prepares the root of a Tvheadend image pending further
# processing.
#
# Author: Audioniek, based on previous work by schishu and bpanther"
# Date: 28-08-2015"
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
  fortis_hdbox|octagon1008|atevio7500|hs7110|hs7810a|hs7119|hs7819|dp6010|dp7000|dp7001|epp8000)
    common;;
  spark|spark7162)
    common;;
  ufs910|ufs922|cuberevo|cuberevo_mini2|cuberevo_2000hd)
    common

    echo -n " Moving var directory..."
    mv $TMPROOTDIR/var/* $TMPVARDIR/
    echo " done."

    echo -n " Creating mini-rcS and inittab..."
    rm -f $TMPROOTDIR/etc
    mkdir -p $TMPROOTDIR/etc/init.d
    echo "#!/bin/sh" > $TMPROOTDIR/etc/init.d/rcS
    echo "mount -n -t proc proc /proc" >> $TMPROOTDIR/etc/init.d/rcS
    if [ "$HOST" == "cuberevo-mini2" -o "$HOST" == "cuberevo" -o "$HOST" == "cuberevo-2000hd" ]; then
      echo "mount -t jffs2 -o rw,noatime,nodiratime /dev/mtdblock4 /var" >> $TMPROOTDIR/etc/init.d/rcS
    else
      echo "mount -t jffs2 -o rw,noatime,nodiratime /dev/mtdblock3 /var" >> $TMPROOTDIR/etc/init.d/rcS
    fi
    echo "mount --bind /var/etc /etc" >> $TMPROOTDIR/etc/init.d/rcS
    echo "/etc/init.d/rcS &" >> $TMPROOTDIR/etc/init.d/rcS
    chmod 755 $TMPROOTDIR/etc/init.d/rcS
    cp -f $TMPVARDIR/etc/inittab $TMPROOTDIR/etc
    echo " done."
    ;;
  ufc960)
    common

    echo -n " Setting up init_mini_fo..."
    mkdir $TMPROOTDIR/root_rw
    mkdir $TMPROOTDIR/storage
    cp $TOOLSDIR/init_mini_fo $TMPROOTDIR/sbin/
    chmod 777 $TMPROOTDIR/sbin/init_mini_fo
    # --- STORAGE FOR MINI_FO ---
    mkdir $TMPVARDIR/root_ro
    echo " done."

#    echo -n " Moving var directory..."
#    mv $TMPROOTDIR/var $TMPVARDIR/
#    echo " done."

    echo -n " Adapting var/etc/fstab..."
    sed -i 's|/dev/sda.*||g' $TMPROOTDIR/var/etc/fstab
    #echo "/dev/mtdblock4	/var	jffs2	defaults	0	0" >> $TMPROOTDIR/var/etc/fstab
    echo " done."
    ;;
  tf7700)
    echo -n " Copying release image..."
    find $RELEASEDIR -mindepth 1 -maxdepth 1 -exec cp -at$TMPROOTDIR -- {} +
    echo " done."

    if [ ! -e $TMPROOTDIR/dev/mtd0 ]; then
      echo -n " Creating devices..."
      cd $TMPROOTDIR/dev/
      if [ -e $TMPROOTDIR/var/etc/init.d/makedev ]; then
        $TMPROOTDIR/var/etc/init.d/makedev start 2>/dev/null
      else
        $TMPROOTDIR/etc/init.d/makedev start 2>/dev/null
      fi
      cd - > /dev/null
      echo " done."
    fi;;
  ufs912|ufs913)
    common
    cp $RELEASEDIR/.version $TMPROOTDIR
    rm -fr $TMPROOTDIR/boot

 export TMPFWDIR=$TMPDIR/FW
    if [ -e $TMPFWDIR ]; then
      rm -rf $TMPFWDIR/*
    elif [ ! -d $TMPFWDIR ]; then
      mkdir $TMPFWDIR
    fi

   echo -n " Moving firmwares..."
    mv $TMPROOTDIR/lib/firmware/* $TMPVARDIR
    echo " done."

    if [ -e $TMPROOTDIR/var/etc/fstab ]; then
      echo -n " Adapting var/etc/fstab..."
      if [ "$BOXTYPE" == "ufs912" ]; then
         echo "/dev/mtdblock3	/lib/firmware	jffs2	defaults	0	0" >> $TMPROOTDIR/var/etc/fstab
         #echo "/dev/mtdblock5	/swap	jffs2	defaults	0	0" >> $TMPROOTDIR/var/etc/fstab
      else
        echo "/dev/mtdblock8	/lib/firmware	jffs2	defaults	0	0" >> $TMPROOTDIR/var/etc/fstab
        #echo "/dev/mtdblock10	/swap	jffs2	defaults	0	0" >> $TMPROOTDIR/var/etc/fstab
      fi
    else
      if [ "$BOXTYPE" == "ufs912" ]; then
        echo -n " Adapting etc/fstab..."
        echo "/dev/mtdblock3	/lib/firmware	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
        #echo "/dev/mtdblock5	/swap	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
      else
        echo "/dev/mtdblock8	/lib/firmware	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
        #echo "/dev/mtdblock10	/swap	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
      fi
    fi
    echo " done.";;
esac
