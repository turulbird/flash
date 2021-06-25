#!/bin/bash
# ---------------------------------------------------------------------------
# This script prepares the root of an enigma2 image pending further
# processing.
#
# Author: Audioniek, based on previous work by schishu and bpanther"
#
# Date: 07-06-2014"
# ---------------------------------------------------------------------------
# Changes:
# 20140726: Audioniek   Removed: if gstreamer found, /usr/lib/libav* was
#                       deleted.
# 20140726: Audioniek   French added as third fixed language on hs8200.
# 20140914: Audioniek   Retain all languages option added on hs8200.
# 20141015: Audioniek   Fortis 4th generation receivers added.
# 20170310: Audioniek   Setting TMPFWDIR moved to flash.sh.
# 20191214: Audioniek   Fixed potential problem in making devs.
# 20191214: Audioniek   Add fortis dp2010.
# 20200609: Audioniek   dp6010 -> fx6010.
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
    TARGET=$BOXTYPE
    export TARGET
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

# Prepare enigma2 root according to box type
case $BOXTYPE in
  adb_box|hs8200)
    common
    if [[ ! "$OWNLANG" == "all" ]]; then
      echo -n " Stripping root..."
      # Language support: remove everything but English, French, German and own language
      mv $TMPROOTDIR/usr/local/share/enigma2/po $TMPROOTDIR/usr/local/share/enigma2/po.old
      mkdir $TMPROOTDIR/usr/local/share/enigma2/po
      for i in en de fr $OWNLANG
      do
        cp -r $TMPROOTDIR/usr/local/share/enigma2/po.old/$i $TMPROOTDIR/usr/local/share/enigma2/po
      done
      rm -rf $TMPROOTDIR/usr/local/share/enigma2/po.old

      mv $TMPROOTDIR/usr/local/share/enigma2/countries $TMPROOTDIR/usr/local/share/enigma2/countries.old
      mkdir $TMPROOTDIR/usr/local/share/enigma2/countries
      cp -r $TMPROOTDIR/usr/local/share/enigma2/countries.old/missing.* $TMPROOTDIR/usr/local/share/enigma2/countries
      for i in en de fr $OWNLANG
      do
        cp -r $TMPROOTDIR/usr/local/share/enigma2/countries.old/$i.* $TMPROOTDIR/usr/local/share/enigma2/countries
      done
      rm -rf $TMPROOTDIR/usr/local/share/enigma2/countries.old
      # Update /usr/lib/enigma2/python/Components/Language.py
      # First remove all language lines from it
      sed -i -e '/\t\tself.addLanguage(/d' $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.py
      # Add en, fr and ge
      sed -i "s/country!/&\n\t\tself.addLanguage(\"Deutsch\",     \"de\", \"DE\", \"ISO-8859-15\")\n\t\tself.addLanguage(\"Français\",     \"fr\", \"FR\", \"ISO-8859-15\")\n\t\tself.addLanguage(\"English\",     \"en\", \"EN\", \"ISO-8859-15\")/g" $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.py
      # Add own language if given
      if [[ ! "$OWNLANG" == "" ]]; then
        sed -i 's/("English",     "en", "EN", \"ISO-8859-15\")/&\n\t\tself.addLanguage(\"Your own\",    \"'$OWNLANG'", \"'$OWNCOUNTRY'\", \"ISO-8859-15\")/g' $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.py
      fi

      rm $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.pyo
      # Compile Language.py
      python -O -m py_compile $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.py
    fi

    #remove all .py-files
    find $TMPROOTDIR/usr/lib/python2.7/ -name "*.py" -exec rm -f {} \;
    find $TMPROOTDIR/usr/lib/enigma2/python/Components/ -name "*.py" -exec rm -f {} \;
    find $TMPROOTDIR/usr/lib/enigma2/python/Screens/ -name "*.py" -exec rm -f {} \;
    echo " done."
    ;;
  hs7110|hs7119|hs7810a|hs7819|dp2010|dp7000|dp7001|dp7050|ep8000|epp8000|fx6010|gpv8000)
# for loader 6.XX/7.XX/8.XX
    common;;
  spark|spark7162)
    common;;
  fs9000|hs9510|ufs910|cuberevo|cuberevo_mini2|cuberevo_2000hd)
# Fortis needs TDT maxiboot or similar loader
    common

    echo -n " Moving var directory..."
    mv $TMPROOTDIR/var/* $TMPVARDIR/
    echo " done."

    echo -n " Creating mini-rcS and inittab..."
    rm -Rf $TMPROOTDIR/etc
    mkdir -p $TMPROOTDIR/etc/init.d
    echo "#!/bin/sh" > $TMPROOTDIR/etc/init.d/rcS
    echo "mount -n -t proc proc /proc" >> $TMPROOTDIR/etc/init.d/rcS
    if [ "$HOST" == "cuberevo-mini" -o "$HOST" == "cuberevo-mini2" -o "$HOST" == "cuberevo" -o "$HOST" == "cuberevo-2000hd" ]; then
      echo "mount -t jffs2 -o rw,noatime,nodiratime /dev/mtdblock4 /var" >> $TMPROOTDIR/etc/init.d/rcS
    else
      echo "mount -t jffs2 -o rw,noatime,nodiratime /dev/mtdblock3 /var" >> $TMPROOTDIR/etc/init.d/rcS
    fi
    echo "mount --bind /var/etc /etc" >> $TMPROOTDIR/etc/init.d/rcS
    echo "/etc/init.d/rcS" >> $TMPROOTDIR/etc/init.d/rcS
    chmod 755 $TMPROOTDIR/etc/init.d/rcS
    cp -f $TMPVARDIR/etc/inittab $TMPROOTDIR/etc
    echo " done."
    ;;
  ufs922)
    common
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
  ufs912|ufs913)
    common
    if [[ ! "$OWNLANG" == "all" && "$BOXTYPE" == "ufs913" ]]; then
      echo -n " Stripping root..."
      # Language support: remove everything but English, French, German and own language
      mv $TMPROOTDIR/usr/local/share/enigma2/po $TMPROOTDIR/usr/local/share/enigma2/po.old
      mkdir $TMPROOTDIR/usr/local/share/enigma2/po
      for i in en de fr $OWNLANG
      do
        cp -r $TMPROOTDIR/usr/local/share/enigma2/po.old/$i $TMPROOTDIR/usr/local/share/enigma2/po
      done
      rm -rf $TMPROOTDIR/usr/local/share/enigma2/po.old

      mv $TMPROOTDIR/usr/local/share/enigma2/countries $TMPROOTDIR/usr/local/share/enigma2/countries.old
      mkdir $TMPROOTDIR/usr/local/share/enigma2/countries
      cp -r $TMPROOTDIR/usr/local/share/enigma2/countries.old/missing.* $TMPROOTDIR/usr/local/share/enigma2/countries
      for i in en de fr $OWNLANG
      do
        cp -r $TMPROOTDIR/usr/local/share/enigma2/countries.old/$i.* $TMPROOTDIR/usr/local/share/enigma2/countries
      done
      rm -rf $TMPROOTDIR/usr/local/share/enigma2/countries.old
      # Update /usr/lib/enigma2/python/Components/Language.py
      # First remove all language lines from it
      sed -i -e '/\t\tself.addLanguage(/d' $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.py
      # Add en, fr and ge
      sed -i "s/country!/&\n\t\tself.addLanguage(\"Deutsch\",     \"de\", \"DE\", \"ISO-8859-15\")\n\t\tself.addLanguage(\"Français\",     \"fr\", \"FR\", \"ISO-8859-15\")\n\t\tself.addLanguage(\"English\",     \"en\", \"EN\", \"ISO-8859-15\")/g" $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.py
      # Add own language if given
      if [[ ! "$OWNLANG" == "" ]]; then
        sed -i 's/("English",     "en", "EN", \"ISO-8859-15\")/&\n\t\tself.addLanguage(\"Your own\",    \"'$OWNLANG'", \"'$OWNCOUNTRY'\", \"ISO-8859-15\")/g' $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.py
      fi

      rm $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.pyo
      # Compile Language.py
      python -O -m py_compile $TMPROOTDIR/usr/lib/enigma2/python/Components/Language.py

#      #remove all .py-files
#      find $TMPROOTDIR/usr/lib/python2.7/ -name "*.py" -exec rm -f {} \;
#      find $TMPROOTDIR/usr/lib/enigma2/python/Components/ -name "*.py" -exec rm -f {} \;
#      find $TMPROOTDIR/usr/lib/enigma2/python/Screens/ -name "*.py" -exec rm -f {} \;
      echo " done."
    fi

    echo -n " Moving firmwares..."
    if [ -e $TMPFWDIR ]; then
      rm -rf $TMPFWDIR/*
    elif [ ! -d $TMPFWDIR ]; then
      mkdir $TMPFWDIR
    fi
    mv $TMPROOTDIR/boot/*.elf $TMPFWDIR
    echo " done."

    if [ -e $TMPROOTDIR/boot/bootlogo.mvi ]; then
      mv $TMPROOTDIR/boot/bootlogo.mvi $TMPROOTDIR/etc/bootlogo.mvi
    fi
    sed -i "s/\/boot\/bootlogo.mvi/\/etc\/bootlogo.mvi/g" $TMPROOTDIR/etc/init.d/rcS

    rm -f $TMPROOTDIR/boot/*

    echo -n " Adapting /etc/fstab..."
    if [ "$BOXTYPE" == "ufs912" ]; then
       echo "/dev/mtdblock3	/boot	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
       #echo "/dev/mtdblock5	/root	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
    else
       echo "/dev/mtdblock8	/boot	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
       #echo "/dev/mtdblock10	/root	jffs2	defaults	0	0" >> $TMPROOTDIR/etc/fstab
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
        $TMPROOTDIR/var/etc/init.d/makedev start > /dev/null 2> /dev/null
      else
        $TMPROOTDIR/etc/init.d/makedev start > /dev/null 2> /dev/null
      fi
      cd - > /dev/null
      echo " done."
    fi;;
  *)
    common;;
esac
