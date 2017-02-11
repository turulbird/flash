#!/bin/bash
clear
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "+"
echo "+  flash.sh"
echo "+"
echo "+ This script creates the file(s) you need to run the image built last"
echo "+ in the receiver's flash memory, the internal hard disk or from a USB"
echo "+ stick."
echo "+"
echo "+ Author : Audioniek, based on previous work by schishu, bpanther"
echo "+          and others."
echo "+ Date   : 11-02-2017"
echo "+"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo
# ---------------------------------------------------------------------------
# Changes:
# 20140726 Audioniek   Setting own language on atevio7500 did not work; moved
#                      upward.
# 20140726 Audioniek   French added as third fixed language on atevio7500.
# 20140831 Audioniek   Neutrino flash for Fortis 1st generation receivers
#                      added (requires latest fup).
# 20140906 Audioniek   Tangos neutrino added.
# 20140907 Audioniek   Neutrino flash for HS7110 & HS7810A receivers added.
# 20140912 Audioniek   Flash for HS7119 & HS7819 receivers added.
# 20140914 Audioniek   Corrected some typos, add all languages option for
#                      atevio7500.
# 20141015 Audioniek   Fortis 4th generation receivers added.
# 20141208 Audioniek   Bug fixed with Fortis dp6010.
# 20150806 Audioniek   Tvheadend added.
# 20150911 Audioniek   Exit when building Topfield installer fails.
# 20160416 Audioniek   ./lastChoice handling adapted to handle E2..
#                      environment variables.
# 20160512 Audioniek   Check for E2 in flash for hs7420 was missing.
# 20161126 Audioniek   Adapted to work with cdk_new as well.
# 20161205 Audioniek   Fixed tfinstaller with cdk_new.
# 20161216 Audioniek   Skip output type selection if built with cdk_new
#                      and destination already set.
# 20161216 Audioniek   Enable USB for Fortis 2G receivers with 32MB of flash.
# 20161217 Audioniek   Enable USB for Fortis 3G receivers.
# 20170207 Audioniek   Improved check on existence of a flashable image.
# 20170211 Audioniek   Support for buildsystem added.
# ---------------------------------------------------------------------------

#Set up some variables
export CURDIR=`pwd`
export BASEDIR=`cd .. && pwd`
export TUFSBOXDIR=$BASEDIR/tufsbox
#Determine which cdk was used to build
if [ -e ../cdk/lastChoice ]; then
  BUILTFROM="cdk"
  CDKDIR=$BASEDIR/cdk
elif [ -e ../cdk_new/config ]; then
  BUILTFROM="cdk_new"
  CDKDIR=$BASEDIR/cdk_new
else
  BUILTFROM="buildsystem"
  CDKDIR=$BASEDIR
fi
export CDKDIR
export FLASHDIR=$BASEDIR/flash
export SCRIPTDIR=$FLASHDIR/scripts
export TOOLSDIR=$FLASHDIR/flash_tools
export TMPDIR=$FLASHDIR/tmp
export TMPROOTDIR=$TMPDIR/ROOT
export TMPVARDIR=$TMPDIR/VAR
export TMPKERNELDIR=$TMPDIR/KERNEL
export OUTDIR=$FLASHDIR/out
export TFINSTALLERDIR=$CDKDIR/tfinstaller

# Check if an image was actually built
# built from cdk: lastChoice, ./deps/build_complete and release directory should exist
# built from cdk_new or buidlsystem  config, ./deps/build_complete and release directory should exist
if ([ "$BUILTFROM" == "cdk" ]  && [ ! -e $CDKDIR/lastChoice ] \
|| (([ "$BUILTFROM" == "cdk_new" ] || [ "$BUILTFROM" == "buildsystem" ]) && [ ! -e $CDKDIR/config ]) \
|| [ ! -e $CDKDIR/.deps/build_complete ] \
|| [ ! -d $BASEDIR/tufsbox/release ]); then
  echo "-- PROBLEM! -----------------------------------------------------------"
  echo
  echo " Please build an image first. Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  exit
fi

if [ `id -u` != 0 ]; then
  echo
  echo "-- PROBLEM! -----------------------------------------------------------"
  echo
  echo " You are not running this script with fakeroot."
  echo " Try it again with \"fakeroot ./flash.sh\"."
  echo
  echo " Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  exit
fi

# Create/cleanup work directory structure
if [ -e $TMPDIR ]; then
  rm -rf $TMPDIR/*
elif [ ! -d $TMPDIR ]; then
  mkdir $TMPDIR
fi

if [ -e $TMPROOTDIR ]; then
  rm -rf $TMPROOTDIR/*
elif [ ! -d $TMPROOTDIR ]; then
  mkdir -p $TMPROOTDIR
fi

if [ -e $TMPVARDIR ]; then
  rm -rf $TMPVARDIR/*
elif [ ! -d $TMPVARDIR ]; then
  mkdir -p $TMPVARDIR
fi

if [ -e $TMPKERNELDIR ]; then
  rm -rf $TMPKERNELDIR/*
elif [ ! -d $TMPKERNELDIR ]; then
  mkdir -p $TMPKERNELDIR
fi

if [ -e $OUTDIR ]; then
  rm -rf $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

# Determine which image has been built last
if [ "$BUILTFROM" == "cdk" ]; then
  cp $CDKDIR/lastChoice $FLASHDIR/lastChoice
  sed -i 's/ --/\n&/g' $FLASHDIR/lastChoice
  sed -i 's/ --//g' $FLASHDIR/lastChoice
  sed -i 's/ E2/\n&E2/g' $FLASHDIR/lastChoice
  sed -i 's/ E2//g' $FLASHDIR/lastChoice
  if [ `grep -e "enable-enigma2" $FLASHDIR/lastChoice` ]; then
    IMAGE=`grep -e "enable-enigma2" $FLASHDIR/lastChoice | awk '{print substr($0,8,length($0)-7)}'`
    IMAGEN="Enigma2"
  elif [ `grep -e "enable-neutrino" $FLASHDIR/lastChoice` ]; then
    IMAGE=`grep -e "enable-neutrino" $FLASHDIR/lastChoice | awk '{print substr($0,8,length($0)-7)}'`
    IMAGEN="Neutrino"
  elif [ `grep -e "enable-tvheadend" $FLASHDIR/lastChoice` ]; then
    IMAGE=`grep -e "enable-tvheadend" $FLASHDIR/lastChoice | awk '{print substr($0,8,length($0)-7)}'`
    IMAGEN="Tvheadend"
  fi
else
  cp $CDKDIR/config $FLASHDIR/config
  if [ `grep -e "IMAGE=enigma2" $FLASHDIR/config` ]; then
    IMAGE=enigma2
    IMAGEN="Enigma2"
  elif [ `grep -e "IMAGE=neutrino" $FLASHDIR/config` ]; then
    IMAGE=neutrino
    IMAGEN="Neutrino"
  fi
fi
export IMAGE
export IMAGEN

# Determine receiver type
if [ "$BUILTFROM" == "cdk" ]; then
  export BOXTYPE=`grep -e "with-boxtype" $FLASHDIR/lastChoice | awk '{print substr($0,14,length($0)-12)}'`
else
  export BOXTYPE=`grep -e "BOXTYPE" $FLASHDIR/config | awk '{print substr($0,9,length($0)-7)}'`
fi

# Determine patch level and last part of linux version number
if [ "$BUILTFROM" == "cdk" ]; then
  export PATCH=`grep -e "enable-p0" ./lastChoice | awk '{print substr($0,length($0)-2,length($0))}'`
  rm ./lastChoice
else
  export PATCH=`grep -e "KERNEL=p0" ./config | awk '{print substr($0,length($0)-2,length($0))}'`
fi
FNAME="0$PATCH"_"$BOXTYPE"
if [ "$IMAGE" == "tvheadend" ]; then
  cd $CDKDIR/Patches/build-neutrino
else
  cd $CDKDIR/Patches/build-$IMAGE
fi
ls linux-sh4-2.6.32.??_$FNAME.config > $FLASHDIR/lastconfig
cd $CURDIR
export SUBVERS=`grep -e "linux-sh4-2.6.32." $FLASHDIR/lastconfig | awk '{print substr($0,length($0)-(length("'$BOXTYPE'")+14),2)}'`
rm $FLASHDIR/lastconfig

# Determine/ask for output type (USB or flash)
if ([ "$BUILTFROM" == "cdk_new" ] || [ "$BUILTFROM" == "buildsystem" ]) && [ `grep -e "DESTINATION=USB" $FLASHDIR/config` ]; then
  export OUTTYPE="USB"
  rm $FLASHDIR/config
else
  echo "-- Output destination -------------------------------------------------"
  echo
  echo " Where would you like your $IMAGEN image to run?"
  echo "   1) on a USB stick"
  echo "   2) in the receivers flash memory (*)"
  read -p " Select target (1-2)? "
  case "$REPLY" in
    1) export OUTTYPE="USB";;
    *) export OUTTYPE="flash";;
  esac
fi
# Check if the receiver can accept an Enigma2 image in flash
if [ "$IMAGE" == "enigma2" ] && [ "$OUTTYPE" == "flash" ]; then
  case "$BOXTYPE" in
    fortis_hdbox|octagon1008|hs7110|hs7420|hs7810a|ufs910|ufs922|cuberevo|cuberevo_mini2|cuberevo_2000hd)
      echo
      echo "-- Message ------------------------------------------------------------"
      echo
      echo " Sorry, Enigma2 requires more flash memory than available on your"
      echo " $BOXTYPE receiver."
      echo
      echo " Consider running Enigma2 from a USB stick or building Neutrino."
      echo
      echo " Exiting..."      
      echo "-----------------------------------------------------------------------"
      exit;;
  esac
fi

# Check if the required flash tool programs are there; if not, compile them
$SCRIPTDIR/create_flash_tools.sh $TOOLSDIR

# Determine receiver host name
if [ -f $TMPROOTDIR/etc/hostname ]; then
  HOST=`cat $TMPROOTDIR/etc/hostname`
elif [ -f $TMPROOTDIR/var/etc/hostname ]; then
  HOST=`cat $TMPROOTDIR/var/etc/hostname`
else
  HOST=$BOXTYPE
fi
export HOST

# Determine Neutrino GIT version 
if [ "$IMAGE" == "neutrino" ]; then
  if [ -d $BASEDIR/source/libstb-hal-next ]; then
    HAL_REV=_HAL-rev`cd $BASEDIR/source/libstb-hal-next && git log | grep "^commit" | wc -l`-next
  elif [ -d $BASEDIR/source/libstb-hal-cst-next ]; then
    HAL_REV=_HAL-rev`cd $BASEDIR/source/libstb-hal-cst-next && git log | grep "^commit" | wc -l`-github
  elif [ -d $BASEDIR/source/libstb-hal-github ]; then
    HAL_REV=_HAL-rev`cd $BASEDIR/source/libstb-hal-github && git log | grep "^commit" | wc -l`-github
  elif [ -d $BASEDIR/source/libstb-hal-martii-github ]; then
    HAL_REV=_HAL-rev`cd $BASEDIR/source/libstb-hal-martii-github && git log | grep "^commit" | wc -l`-martii-github
  elif [ -d $BASEDIR/source/libstb-hal ]; then
    HAL_REV=_HAL-rev`cd $BASEDIR/source/libstb-hal && git log | grep "^commit" | wc -l`
  else
    HAL_REV=_HAL-revXXX
  fi

  if [ -d $BASEDIR/source/neutrino-mp-next ]; then
    NMP_REV=_NMP-rev`cd $BASEDIR/source/neutrino-mp-next && git log | grep "^commit" | wc -l`-next
  elif [ -d $BASEDIR/source/neutrino-mp-github ]; then
    NMP_REV=_NMP-rev`cd $CURDIR/../../source/neutrino-mp-github && git log | grep "^commit" | wc -l`-github
  elif [ -d $BASEDIR/source/neutrino-mp-martii-github ]; then
    NMP_REV=_NMP-rev`cd $BASEDIR/source/neutrino-mp-martii-github && git log | grep "^commit" | wc -l`-martii-github
  elif [ -d $BASEDIR/source/neutrino-mp-tangos ]; then
    NMP_REV=_NMP-rev`cd $BASEDIR/source/neutrino-mp-tangos && git log | grep "^commit" | wc -l`-tangos
  elif [ -d $BASEDIR/source/neutrino-mp ]; then
    NMP_REV=_NMP-rev`cd $BASEDIR/source/neutrino-mp && git log | grep "^commit" | wc -l`
  else
    NMP_REV=_NMP-revXXX
  fi
fi
export GITVERSION=CDK-rev`(cd $CDKDIR && git log | grep "^commit" | wc -l)`"$HAL_REV""$NMP_REV"

# Build tfinstaller if not done yet
TFINSTALL="present"
if [ $BOXTYPE == "tf7700" ]; then
  if [ "$BUILTFROM" == "cdk" ]; then
    TFINSTALL="not built"
    if [ ! -e $TFINSTALLERDIR/uImage ] || [ ! -e $CDKDIR/.deps/uboot_tf7700 ] || [ ! -e $CDKDIR/.deps/tfkernel.do_compile ]; then
      echo
      echo "-- Create Topfield installer-------------------------------------------"
      echo
      $SCRIPTDIR/tfinstaller.sh $TFINSTALLERDIR
      if [ ! -e $TFINSTALLERDIR/uImage ] || [ ! -e $TFINSTALLERDIR/Enigma_Installer.tfd ] || [ ! -e $TFINSTALLERDIR/u-boot.ftfd ]; then
        echo -e "\033[01;31m"
        echo "-- ERROR! -------------------------------------------------------------"
        echo
        echo " Building the Topfield installer failed !!!"
        echo
        echo " Exiting..."
        echo "-----------------------------------------------------------------------"
        echo -e "\033[00m"
        exit 2
      else
        TFINSTALL="built"
      fi
#    else
#      if [ ! -e $TFINSTALLERDIR/uImage ] || [ ! -e $TFINSTALLERDIR/Enigma_Installer.tfd ] || [ ! -e $TFINSTALLERDIR/tfpacker ]; then
#        echo -e "\033[01;31m"
#        echo "-- ERROR! -------------------------------------------------------------"
#        echo
#        echo " Building the Topfield installer has not been done yet."
#        echo
#        echo " Build an image first and then run this script again to build"
#        echo " the Topfield installer."
#        echo
#        echo " Exiting..."
#        echo "-----------------------------------------------------------------------"
#        echo -e "\033[00m"
#        exit 2
    fi
  fi
fi

# All is OK so far, display summary
clear
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "+"
echo "+  Summary"
echo "+  ======="
echo "+"
echo "+  Receiver           : $BOXTYPE"
if [ $BOXTYPE == "tf7700" ]; then
  echo "+  Topfield installer : $TFINSTALL"
fi
echo "+  Linux version      : linux-sh4-2.6.32-$SUBVERS"
echo "+  Kernel patch level : P0$PATCH"
echo "+  Image              : $IMAGEN"
echo "+  Built from         : $BUILTFROM"
echo "+  Will run in/on     : $OUTTYPE"
echo "+"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo

# Prepare root
echo "-- Prepare root -------------------------------------------------------"
echo
echo " Prepare $IMAGEN root for $BOXTYPE."
echo
if [ "$BOXTYPE" == "atevio7500" ] && [ "$OUTTYPE" == "flash" ] && [ "$IMAGE" == "enigma2" ]; then
  # The root will be optionally stripped of all language support except de (German), fr (French)
  # and en (English) because the flash space is rather limited on this receiver.
  # A fourth language can be specified here in ISO code (suggestion is your own language,
  # two lower case letters). To leave all languages in, specify 'all' here:
  export OWNLANG=nl
  # and the country to go with it (ISO code, two uppercase letters, often the same letters
  # as the language; in case of OWNLANG=all it is ignored):
  export OWNCOUNTRY=NL
fi
$SCRIPTDIR/$OUTTYPE/prepare_root_"$IMAGE"_"$OUTTYPE".sh $TUFSBOXDIR/release
echo
echo " Root preparation completed."
echo

# Check .elf file sizes
if [ $IMAGEN == "Enigma2" ]; then
  AUDIOELFSIZE=`stat -c %s $TUFSBOXDIR/release/boot/audio.elf`
  VIDEOELFSIZE=`stat -c %s $TUFSBOXDIR/release/boot/video.elf`
elif [ $IMAGEN == "Neutrino" ] || [ $IMAGEN == "Tvheadend" ]; then
  AUDIOELFSIZE=`stat -c %s $TUFSBOXDIR/release/lib/firmware/audio.elf`
  VIDEOELFSIZE=`stat -c %s $TUFSBOXDIR/release/lib/firmware/video.elf`
fi
if [ "$AUDIOELFSIZE" == "" ] || [ "$VIDEOELFSIZE" == "" ] || [ "$AUDIOELFSIZE" == "0" ] || [ "$VIDEOELFSIZE" == "0" ]; then
echo -e "\033[01;31m"
echo "-- ERROR! -------------------------------------------------------------"
echo
  if [ "$AUDIOELFSIZE" == "" ]; then
    echo " !!! ERROR: File audio.elf is missing !!!"
  fi
  if [ "$AUDIOELFSIZE" == "0" ]; then
    echo " !!! ERROR: File size of audio.elf is zero !!!"
  fi
  if [ "$VIDEOELFSIZE" == "" ]; then
    echo " !!! ERROR: File video.elf is missing !!!"
  fi
  if [ "$VIDEOELFSIZE" == "0" ]; then
    echo " !!! ERROR: File size of video.elf is zero !!!"
  fi
  echo
  echo " Make sure that you use the correct .elf files in the"
  echo " directory $CDKDIR/root/boot."
  echo
  echo " Exiting..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit 2
fi

# Check if the devs have been made
if [ ! -e $TMPROOTDIR/dev/mtd0 ]; then
  echo -e "\033[01;31m"
  echo "-- ERROR! -------------------------------------------------------------"
  echo
  echo " !!! ERROR: DEVS ARE MISSING !!!"
  echo " APPARENTLY MAKEDEV IN prepare_root.sh FAILED."
  echo
  echo " Exiting..."
  echo "-----------------------------------------------------------------------"
  echo -e "\033[00m"
  exit 2
fi

# Build output files, depending on receiver type, image type and output type
echo "-- Create output file(s) ----------------------------------------------"
echo
echo " Build $IMAGEN output file(s) for $BOXTYPE running in/on $OUTTYPE."
echo

if [ "$OUTTYPE" == "flash" ]; then
# Handle Fortis resellerID
case $BOXTYPE in
  atevio7500|fortis_hdbox|octagon1008|hs7110|hs7420|hs7810a|hs7119|hs7429|hs7819|dp7000|dp6010|dp7001|epp8000)
    RESELLERID=$1
    if [[ "$RESELLERID" == "" ]]; then
      case $BOXTYPE in
        atevio7500)
          RESELLERID=230200A0
          FORTISBOX="Octagon SF1028P HD Noblence";;
        fortis_hdbox)
          RESELLERID=20020000
          FORTISBOX="Octagon SF1018P HD Alliance";;
        octagon1008)
          RESELLERID=20020300
          FORTISBOX="Octagon SF1008P HD Intelligence";;
        hs7110)
          RESELLERID=250202A0
          FORTISBOX="Octagon SF918 SE+ HD Difference";;
        hs7420)
          RESELLERID=250203A0
          FORTISBOX="Octagon SF1008P SE+ HD Intelligence";;
        hs7810a)
          RESELLERID=250200A0
          FORTISBOX="Octagon SF1008 SE+ HD Intelligence";;
        hs7119)
          RESELLERID=270200A0
          FORTISBOX="Octagon SF918G SE+ HD Difference";;
        hs7429)
          RESELLERID=270130A0
          FORTISBOX="Octagon SF1008G+ SE+ HD Intelligence";;
        hs7819)
          RESELLERID=270220A0
          FORTISBOX="Octagon SF1008G SE+ HD Intelligence";;
        dp6010)
          RESELLERID=29060000
          FORTISBOX="Rebox RE-2220HD S-PVR";;
        dp7000|dp7001)
          RESELLERID=29060100
          FORTISBOX="Rebox RE-4220HD S-PVR";;
        epp8000)
          RESELLERID=2A020000
          FORTISBOX="Rebox RE-8220HD S-PVR";;
      esac
      echo " No resellerID specified, using default $RESELLERID"
      echo " (equals $FORTISBOX)."
      echo
      echo " Note: other resellerID may be specified as arg1"
      echo " on the command line:"
      echo " $0 [resellerID]"
      echo
      echo " Optional resellerID must either be 4 or 8 hex characters".
    else
      echo " Using resellerID $RESELLERID."
    fi
    echo
    export RESELLERID
    if [ ! -e $TOOLSDIR/dummy.squash.signed.padded ]; then
      cd $TOOLSDIR
      ./fup > /dev/null
      cd $CURDIR
    fi
esac

  case $BOXTYPE in
    atevio7500)
      $SCRIPTDIR/$OUTTYPE/"$BOXTYPE"_"$OUTTYPE".sh
      unset RESELLERID
      if [ "$IMAGE" == "enigma2" ]; then
        unset OWNLANG
        unset OWNCOUNTRY
      fi;;
    cuberevo|cuberevo_mini2|cuberevo_2000hd|ufs910|ufs922)
      $SCRIPTDIR/$OUTTYPE/$IMAGE/"nor"_"$IMAGE"_"$OUTTYPE".sh;;
    fortis_hdbox|octagon1008)
      $SCRIPTDIR/$OUTTYPE/$IMAGE/"fortis_1G"_"$IMAGE"_"$OUTTYPE".sh
      unset RESELLERID;;
    hs7420|hs7110|hs7810a)
      $SCRIPTDIR/$OUTTYPE/$IMAGE/"fortis_2G"_"$IMAGE"_"$OUTTYPE".sh
      unset RESELLERID;;
    hs7429|hs7119|hs7819)
      $SCRIPTDIR/$OUTTYPE/"fortis_3G"_"$OUTTYPE".sh
      unset RESELLERID;;
    dp6010|dp7000|dp7001|epp8000)
      $SCRIPTDIR/$OUTTYPE/"fortis_4G"_"$OUTTYPE".sh
      unset RESELLERID;;
    spark|spark7162)
      $SCRIPTDIR/$OUTTYPE/"spark"_"$OUTTYPE".sh;;
    tf7700)
      $SCRIPTDIR/$OUTTYPE/"tf7700"_"$OUTTYPE".sh;;
    ufc960)
      $SCRIPTDIR/$OUTTYPE/$IMAGE/"ufc960"_"$OUTTYPE"_"$IMAGE".sh;;
    ufs912|ufs913)
      $SCRIPTDIR/$OUTTYPE/"$BOXTYPE"_"$OUTTYPE".sh;;
    *)
      echo " Sorry, there is no $OUTTYPE support for receiver $BOXTYPE available."
      echo
      echo " Exiting..."
      echo "-----------------------------------------------------------------------"
      exit 2;;
  esac
else #USB
  case $BOXTYPE in
    atevio7500)
      $SCRIPTDIR/$OUTTYPE/"$BOXTYPE"_"$OUTTYPE".sh;;
    fortis_hdbox|octagon1008)
      $SCRIPTDIR/$OUTTYPE/make_tar_gz.sh;;
    hs7420|hs7110|hs7810a|hs7429|hs7119|hs7819)
      $SCRIPTDIR/$OUTTYPE/"fortis_23G"_"$OUTTYPE".sh;;
    ufs910|ufs912|ufs922|ufc960)
      $SCRIPTDIR/$OUTTYPE/make_tar_gz.sh;;
    *)
      echo " Sorry, there is no $OUTTYPE support for receiver $BOXTYPE available."
      echo
      echo " Exiting..."
      echo "-----------------------------------------------------------------------"
      exit 2;;
  esac
fi
echo

# Wrap up
cd $CURDIR
echo "-- Result -------------------------------------------------------------"
echo
echo " Output file(s) created in $OUTDIR:"
echo
ls -ohg $OUTDIR > ./dirlist
cat ./dirlist
rm ./dirlist
echo
echo "-- Finished -----------------------------------------------------------"

# Clean up variables
unset CURDIR
unset BASEDIR
unset TUFSBOXDIR
unset TFINSTALLERDIR
unset CDKDIR
unset SCRIPTDIR
unset TOOLSDIR
unset TMPDIR
unset TMPROOTDIR
unset TMPKERNELDIR
unset TMPVARDIR
unset OUTDIR
unset PATCH
unset IMAGE
unset IMAGEN
unset OUTTYPE
unset HOST
unset GITVERSION

if [ -e dummy.squash.signed.padded ]; then
  rm -f dummy.squash.signed.padded
fi

