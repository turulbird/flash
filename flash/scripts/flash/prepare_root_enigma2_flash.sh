#!/bin/bash
# ----------------------------------------------------------------------
# This script prepares the root of an enigma2 image pending further
# processing.
#
# Author: Audioniek, based on previous work by schishu and bpanther"
# Date: 07-06-2014"

RELEASEDIR=$1

common() {
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
  fi

  echo -n " Move kernel..."
  mv $TMPROOTDIR/boot/uImage $TMPKERNELDIR/uImage
  echo " done."
}

# Prepare enigma2 root according to box type
case $BOXTYPE in
  atevio7500)
    common
    echo -n " Strip Root..."
    # Language support: remove everything but English, German and own language
    mv $TMPROOTDIR/usr/local/share/enigma2/po $TMPROOTDIR/usr/local/share/enigma2/po.old
    mkdir $TMPROOTDIR/usr/local/share/enigma2/po
    cp -r $TMPROOTDIR/usr/local/share/enigma2/po.old/en $TMPROOTDIR/usr/local/share/enigma2/po
    cp -r $TMPROOTDIR/usr/local/share/enigma2/po.old/de $TMPROOTDIR/usr/local/share/enigma2/po
    # Add own language if given
    if [[ ! "$OWNLANG" == "" ]]; then
    cp -r $TMPROOTDIR/usr/local/share/enigma2/po.old/$OWNLANG $TMPROOTDIR/usr/local/share/enigma2/po
    fi
    sudo rm -rf $TMPROOTDIR/usr/local/share/enigma2/po.old

    mv $TMPROOTDIR/usr/local/share/enigma2/countries $TMPROOTDIR/usr/local/share/enigma2/countries.old
    mkdir $TMPROOTDIR/usr/local/share/enigma2/countries
    cp -r $TMPROOTDIR/usr/local/share/enigma2/countries.old/missing.* $TMPROOTDIR/usr/local/share/enigma2/countries
    cp -r $TMPROOTDIR/usr/local/share/enigma2/countries.old/en.* $TMPROOTDIR/usr/local/share/enigma2/countries
    cp -r $TMPROOTDIR/usr/local/share/enigma2/countries.old/de.* $TMPROOTDIR/usr/local/share/enigma2/countries
    if [[ ! "$OWNLANG" == "" ]]; then
      cp -r $TMPROOTDIR/usr/local/share/enigma2/countries.old/$OWNLANG.* $TMPROOTDIR/usr/local/share/enigma2/countries
    fi
    sudo rm -rf $TMPROOTDIR/usr/local/share/enigma2/countries.old
    # Update /usr/lib/enigma2/python/Components/Language.py
    # First remove all language lines from it
    sed -i -e '/\t\tself.addLanguage(/d' $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.py
    # Add en and ge
    sed -i "s/country!/&\n\t\tself.addLanguage(\"Deutsch\",     \"de\", \"DE\")\n\t\tself.addLanguage(\"English\",     \"en\", \"EN\")/g" $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.py
    # Add own language if given
    if [[ ! "$OWNLANG" == "" ]]; then
      sed -i 's/("English",     "en", "EN")/&\n\t\tself.addLanguage(\"Your own\",    \"'$OWNLANG'", \"'$OWNCOUNTRY'\")/g' $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.py
    fi
    rm $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.pyo
    # Compile Language.py
    python -O -m py_compile $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.py

    if [ -d $TMPROOTDIR/usr/lib/gstreamer-0.10 ]; then
      rm -f $TMPROOTDIR/usr/lib/libav*
    fi
    #remove all .py-files
    find $TMPROOTDIR/usr/lib/python2.7/ -name "*.py" -exec rm -f {} \;
    find $TMPROOTDIR/usr/lib/enigma2/python/Components/ -name "*.py" -exec rm -f {} \;
    find $TMPROOTDIR/usr/lib/enigma2/python/Screens/ -name "*.py" -exec rm -f {} \;
    echo " done."
    ;;
  hs7110|hs7119|hs7810a|hs7819)
# for loader 6.X0/7.X0
    common;;
  spark|spark7162)
    common;;
  fortis_hdbox|octagon1008|ufs910|ufs922|cuberevo|cuberevo_mini2|cuberevo_2000hd)
    common

    echo -n " Move var directory..."
    mv $TMPROOTDIR/var/* $TMPVARDIR/
    echo " done."

    echo -n " Create mini-rcS and inittab..."
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

    echo -n " Set up init_mini_fo..."
    mkdir $TMPROOTDIR/root_rw
    mkdir $TMPROOTDIR/storage
    cp $TOOLSDIR/init_mini_fo $TMPROOTDIR/sbin/
    chmod 777 $TMPROOTDIR/sbin/init_mini_fo
    # --- STORAGE FOR MINI_FO ---
    mkdir $TMPVARDIR/root_ro
    echo " done."

#    echo -n " Move var directory..."
#    mv $TMPROOTDIR/var $TMPVARDIR/
#    echo " done."

    echo -n " Adapt var/etc/fstab..."
    sed -i 's|/dev/sda.*||g' $TMPROOTDIR/var/etc/fstab
    #echo "/dev/mtdblock4	/var	jffs2	defaults	0	0" >> $TMPROOTDIR/var/etc/fstab
    echo " done."
    ;;
  ufs912|ufs913)
    common
    export TMPFWDIR=$TMPDIR/FW
    if [ -e $TMPFWDIR ]; then
      rm -rf $TMPFWDIR/*
    elif [ ! -d $TMPFWDIR ]; then
      mkdir $TMPFWDIR
    fi

    echo -n "Fill firmware directory..."
    mv $TMPROOTDIR/boot/audio.elf $TMPFWDIR/audio.elf
    mv $TMPROOTDIR/boot/video.elf $TMPFWDIR/video.elf

    mv $TMPROOTDIR/boot/bootlogo.mvi $TMPROOTDIR/etc/bootlogo.mvi
    sed -i "s/\/boot\/bootlogo.mvi/\/etc\/bootlogo.mvi/g" $TMPROOTDIR/etc/init.d/rcS

    rm -f $TMPROOTDIR/boot/*

    if [ "$BOXTYPE" == "ufs912" ]; then
       echo "/dev/mtdblock3	/boot	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
       #echo "/dev/mtdblock5	/root	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
    elif [ "$BOXTYPE" == "ufs913" ]; then
       echo "/dev/mtdblock8	/boot	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
       #echo "/dev/mtdblock10	/root	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
    elif [ "$BOXTYPE" == "hs7810a" ]; then
      echo "/dev/mtdblock2	/boot	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
      #echo "/dev/mtdblock5	/root	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
    fi
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
  *)
    common;;
esac

