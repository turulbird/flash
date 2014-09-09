#!/bin/bash
clear
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "+"
echo "+  flash.sh"
echo "+"
echo "+ This script creates the file(s) you need to run the image built last"
echo "+ in the receiver's flash memory or from a USB stick."
echo "+"
echo "+ Author : Audioniek, based on previous work by schishu, bpanther"
echo "+          and others."
echo "+ Date   : 08-07-2014"
echo "+"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo
# ---------------------------------------------------------------------------
# Changes:
# 20140726 Audioniek   Setting own language on atevio7500 did not work; moved
#                      upward.
# 20140726 Audioniek   French added as third fixed language on atevio7500.
# 20140831 Audioniek   Neutrino flash for Fortis 1st generation receivers
#                      added.
# 20140906 Audioniek   Tangos neutrino added.
# 20140907 Audioniek   Neutrino flash for HS7110 & HS7810A receivers added.
# ---------------------------------------------------------------------------

#Set up some variables
export CURDIR=`pwd`
export BASEDIR=`cd .. && pwd`
export TUFSBOXDIR=$BASEDIR/tufsbox
export CDKDIR=$BASEDIR/cdk
export TFINSTALLERDIR=$CDKDIR/tfinstaller
export SCRIPTDIR=$CURDIR/scripts
export TOOLSDIR=$CURDIR/flash_tools
export TMPDIR=$CURDIR/tmp
export TMPROOTDIR=$TMPDIR/ROOT
export TMPVARDIR=$TMPDIR/VAR
export TMPKERNELDIR=$TMPDIR/KERNEL
export OUTDIR=$CURDIR/out

# Check if lastChoice exists (TODO/note: not a watertight guarantee that the build was completed)
if [ ! -e $CDKDIR/lastChoice ] || [ ! -d $TUFSBOXDIR/release ]; then
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
cp $CDKDIR/lastChoice ./lastChoice
sed -i 's/ --/\n&/g' ./lastChoice
sed -i 's/ --//g' ./lastChoice
if [ `grep -e "enable-enigma2" ./lastChoice` ]; then
  IMAGE=`grep -e "enable-enigma2" ./lastChoice | awk '{print substr($0,8,length($0)-7)}'`
elif [ `grep -e "enable-neutrino" ./lastChoice` ]; then
  IMAGE=`grep -e "enable-neutrino" ./lastChoice | awk '{print substr($0,8,length($0)-7)}'`
fi
export IMAGE

# Determine receiver type
export BOXTYPE=`grep -e "with-boxtype" ./lastChoice | awk '{print substr($0,14,length($0)-12)}'`

# Determine patch level and last part of linux version number
export PATCH=`grep -e "enable-p0" ./lastChoice | awk '{print substr($0,length($0)-2,length($0))}'`
FNAME="0$PATCH"_"$BOXTYPE"
cd $CDKDIR/Patches/build-$IMAGE
ls linux-sh4-2.6.32.??-$FNAME.config > $CURDIR/lastChoice
cd $CURDIR
export SUBVERS=`grep -e "linux-sh4-2.6.32." ./lastChoice | awk '{print substr($0,length($0)-(length("'$BOXTYPE'")+14),2)}'`
rm ./lastChoice

# Ask for output type (USB or flash)
echo "-- Output destination -------------------------------------------------"
echo
echo " Where would you like your $IMAGE image to run?"
echo "   1) on a USB stick"
echo "   2) in the receivers flash memory (*)"
read -p " Select target (1-2)? "
case "$REPLY" in
  1) export OUTTYPE="USB";;
  *) export OUTTYPE="flash";;
#  *) echo " Invalid Input! Exiting..."
#    echo
#    echo "-----------------------------------------------------------------------"
#    exit 2;;
esac

# Check if the receiver can accept an Enigma2 image in flash
if [ "$IMAGE" == "enigma2" ] && [ "$OUTTYPE" == "flash" ]; then
  case "$BOXTYPE" in
    fortis_hdbox|octagon1008|hs7110|hs7810a|ufs910|ufs922|cuberevo|cuberevo_mini2|cuberevo_2000hd)
      echo "-- Message ------------------------------------------------------------"
      echo
      echo " Sorry, Enigma2 requires more flash memory than available on your"
      echo " receiver $BOXTYPE."
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

# Determine GIT version 
if [ "$IMAGE" == "neutrino" ]; then
  if [ -d $BASEDIR/apps/libstb-hal-next ]; then
    HAL_REV=_HAL-rev`cd $BASEDIR/apps/libstb-hal-next && git log | grep "^commit" | wc -l`-next
  elif [ -d $BASEDIR/apps/libstb-hal-github ]; then
    HAL_REV=_HAL-rev`cd $BASEDIR/apps/libstb-hal-github && git log | grep "^commit" | wc -l`-github
  elif [ -d $BASEDIR/apps/libstb-hal-martii-github ]; then
    HAL_REV=_HAL-rev`cd $BASEDIR/apps/libstb-hal-martii-github && git log | grep "^commit" | wc -l`-martii-github
  else
    HAL_REV=_HAL-rev`cd $BASEDIR/apps/libstb-hal && git log | grep "^commit" | wc -l`
  fi

  if [ -d $BASEDIR/apps/neutrino-mp-next ]; then
    NMP_REV=_NMP-rev`cd $BASEDIR/apps/neutrino-mp-next && git log | grep "^commit" | wc -l`-next
  elif [ -d $BASEDIR/apps/neutrino-mp-github ]; then
    NMP_REV=_NMP-rev`cd $CURDIR/../../apps/neutrino-mp-github && git log | grep "^commit" | wc -l`-github
  elif [ -d $BASEDIR/apps/neutrino-mp-martii-github ]; then
    NMP_REV=_NMP-rev`cd $BASEDIR/apps/neutrino-mp-martii-github && git log | grep "^commit" | wc -l`-martii-github
  elif [ -d $BASEDIR/apps/neutrino-mp-tangos ]; then
    NMP_REV=_NMP-rev`cd $BASEDIR/apps/neutrino-mp-tangos && git log | grep "^commit" | wc -l`-tangos
  else
    NMP_REV=_NMP-rev`cd $BASEDIR/apps/neutrino-mp && git log | grep "^commit" | wc -l`
  fi
fi
export GITVERSION=CDK-rev`(cd $CDKDIR && git log | grep "^commit" | wc -l)`"$HAL_REV""$NMP_REV"

# Build tfinstaller if not done yet
if [ $BOXTYPE == "tf7700" ]; then
  if [ ! -e $TFINSTALLERDIR/uImage ] || [ ! -e $CDKDIR/.deps/uboot_tf7700 ]; then
    echo "-- Create Topfield installer-------------------------------------------"
    echo
    $SCRIPTDIR/tfinstaller.sh
    echo
    echo " Topfield installer built."
    echo
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
echo "+  Linux version      : linux-sh4-2.6.32-$SUBVERS"
echo "+  Kernel patch level : $PATCH"
echo "+  Image              : $IMAGE"
echo "+  Will run in/on     : $OUTTYPE"
echo "+"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo

# Prepare root
echo "-- Prepare root -------------------------------------------------------"
echo
echo " Prepare $IMAGE root for $BOXTYPE."
echo
if [ "$BOXTYPE" == "atevio7500" ] && [ "$OUTTYPE" == "flash" ] && [ "$IMAGE" == "enigma2" ]; then
  # The root will be stripped of all language support except de (German), fr (French) and
  # en (English) because the flash space is rather limited on this receiver.
  # A fourth language can be specified here in ISO code (suggestion is your own language,
  # two lower case letters):
  export OWNLANG=nl
  # and the country to go with it (ISO code, two uppercase letters, often the same letters
  # as the language):
 export OWNCOUNTRY=NL
fi
$SCRIPTDIR/$OUTTYPE/prepare_root_"$IMAGE"_"$OUTTYPE".sh $TUFSBOXDIR/release
echo
echo " Root preparation completed."
echo

# Check .elf file sizes
if [ $IMAGE == "enigma2" ]; then
  AUDIOELFSIZE=`stat -c %s $TUFSBOXDIR/release/boot/audio.elf`
VIDEOELFSIZE=`stat -c %s $TUFSBOXDIR/release/boot/video.elf`
elif [ $IMAGE == "neutrino" ]; then
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
  echo " Make sure that you use correct .elf files in the"
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
echo " Build $IMAGE output file(s) for $BOXTYPE running in/on $OUTTYPE."
echo

if [ "$OUTTYPE" == "flash" ]; then
# Handle common Fortis flash stuff
case $BOXTYPE in
  atevio7500|fortis_hdbox|octagon1008|hs7110|hs7810a|hs7119|hs7819)
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
          FORTISBOX="Octagon SF918SE+ HD Difference";;
        hs7810a)
          RESELLERID=250200A0
          FORTISBOX="Octagon SF1008SE+ HD Intelligence";;
        hs7119)
          RESELLERID=270200A0
          FORTISBOX="Octagon SF918GSE+ HD Difference";;
        hs7819)
          RESELLERID=270220A0
          FORTISBOX="Octagon SF1008GSE+ HD Intelligence";;
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
      if [ "$IMAGE" == "enigma2" ]; then
        # The root will be stripped of all language support except de (German) and en (English)
        # because the flash space is rather limited on this receiver.
        # A third language can be specified here in ISO code (suggestion is your own language,
        # two lower case letters):
        export OWNLANG=nl
        # and the country to go with it (ISO code, two uppercase letters, often the same letters
        # as the language):
        export OWNCOUNTRY=NL
      fi
      $SCRIPTDIR/$OUTTYPE/"$BOXTYPE"_"$OUTTYPE".sh
      unset RESELLERID
      unset OWNLANG
      unset OWNCOUNTRY;;
#    fortis_hdbox|octagon1008|ufs910|ufs922|cuberevo|cuberevo_mini2|cuberevo_2000hd)
    ufs910|ufs922|cuberevo|cuberevo_mini2|cuberevo_2000hd)
      $SCRIPTDIR/$OUTTYPE/$IMAGE/"nor"_"$IMAGE"_"$OUTTYPE".sh;;
    fortis_hdbox|octagon1008)
      $SCRIPTDIR/$OUTTYPE/$IMAGE/"fortis_1G"_"$IMAGE"_"$OUTTYPE".sh
      unset RESELLERID;;
    hs7110|hs7810a)
      $SCRIPTDIR/$OUTTYPE/$IMAGE/"fortis_2G"_"$IMAGE"_"$OUTTYPE".sh
      unset RESELLERID;;
#    hs7119|hs7819)
#      $SCRIPTDIR/$OUTTYPE/$IMAGE/"fortis_3G"_"$IMAGE"_"$OUTTYPE".sh
#      unset RESELLERID;;
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
    fortis_hdbox|octagon1008)
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
unset OUTTYPE
unset HOST
unset GITVERSION

if [ -e dummy.squash.signed.padded ]; then
  rm -f dummy.squash.signed.padded
fi

