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
echo "+ Date   : 08-12-2019"
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
# 20170310 Audioniek   Support for Kathrein UFS912 improved/debugged.
# 20170922 Audioniek   Support for Kathrein UFS910 Neutrino USB added.
# 20171223 Audioniek   Support for Tvheadend built by buildsystem added.
# 20180114 Audioniek   Handle tfinstaller built from buildsystem.
# 20190113 Audioniek   Add batch mode.
# 20190208 Audioniek   Flash layout changed for Neutrino on CubeRevo's.
# 20190326 Audioniek   All CubeRevo USB changed to make_tar_gz.
# 20190518 Audioniek   Add vitamin_hd5000.
# 20190530 Audioniek   Add adb_box.
# 20190828 Audioniek   adb_box also strips languages on flash.
# 20191103 Audioniek   Rename Patches directory to patches.
# 20191208 Audioniek   Add Fortis DP2010.
# 20191214 Audioniek   Fix Linux version display.
# ---------------------------------------------------------------------------

# Set up some variables
export CURDIR=`pwd`
export BASEDIR=`cd .. && pwd`
export TUFSBOXDIR=$BASEDIR/tufsbox
CDKDIR=$BASEDIR
export CDKDIR
export FLASHDIR=$BASEDIR/flash
export SCRIPTDIR=$FLASHDIR/scripts
export TOOLSDIR=$FLASHDIR/flash_tools
export TMPDIR=$FLASHDIR/tmp
export TMPROOTDIR=$TMPDIR/ROOT
export TMPVARDIR=$TMPDIR/VAR
export TMPFWDIR=$TMPDIR/FW
export TMPKERNELDIR=$TMPDIR/KERNEL
export OUTDIR=$FLASHDIR/out
export TFINSTALLERDIR=$CDKDIR/tfinstaller

# Check if an image was actually built
# built from buildsystem:  config, ./deps/build_complete and release directory should exist
if [ ! -e $CDKDIR/config ] \
|| [ ! -e $CDKDIR/.deps/build_complete ] \
|| [ ! -d $BASEDIR/tufsbox/release ]; then
  echo "-- PROBLEM! -----------------------------------------------------------"
  echo
  echo " Please build an image first. Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  export ERROR="yes"
  exit
fi

if [ `id -u` != 0 ]; then
  echo
  echo "-- PROBLEM! -----------------------------------------------------------"
  echo
  echo " You are not running this script with sudo or fakeroot."
  echo " Try it again with \"sudo $0\" in case of an USB image."
  echo " For a flash image \"fakeroot $0\" will do fine."
  echo
  echo " Exiting..."
  echo
  echo "-----------------------------------------------------------------------"
  export ERROR="yes"
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

if [ -e $TMPFWDIR ]; then
  rm -rf $TMPFWDIR/*
elif [ ! -d $TMPFWDIR ]; then
  mkdir -p $TMPFWDIR
fi

if [ -e $OUTDIR ]; then
  rm -rf $OUTDIR/*
elif [ ! -d $OUTDIR ]; then
  mkdir -p $OUTDIR
fi

# Evaluate -b / --batchmode command line parameter
set="$@"
for i in $set;
do
  if [ $"$i" == -b ] || [ $"$i" == --batchmode ]; then
    shift
    BATCH_MODE="yes"
    break
  fi
done
export BATCH_MODE

# Set image name
if [ "$BATCH_MODE" == "yes" ]; then
  INAME=Audioniek
  INAME="$INAME"_
else
  INAME=
fi
export INAME

# Determine which image has been built last
cp $CDKDIR/config $FLASHDIR/config
if [ `grep -e "IMAGE=enigma2" $FLASHDIR/config` ]; then
  IMAGE=enigma2
  IMAGEN="Enigma2"
elif [ `grep -e "IMAGE=neutrino" $FLASHDIR/config` ]; then
  IMAGE=neutrino
  IMAGEN="Neutrino"
elif [ `grep -e "IMAGE=tvheadend" $FLASHDIR/config` ]; then
  IMAGE=tvheadend
  IMAGEN="Tvheadend"
fi
export IMAGE
export IMAGEN

# Determine receiver type
export BOXTYPE=`grep -e "BOXTYPE" $FLASHDIR/config | awk '{print substr($0,9)}'`

# Determine media framework
MFW=`grep -e "MEDIAFW=" $FLASHDIR/config | awk '{print substr($0,9)}'`
if [ "$MFW" == "gstreamer" ]; then
  MEDIAFW=gst
elif [ "$MFW" == "eplayer3" ]; then
  MEDIAFW=epl3
elif [ "$MFW" == "gst-eplayer3" ]; then
  MEDIAFW=gst-epl3
elif [ "$MFW" == "gst-eplayer3-dual" ]; then
  MEDIAFW=dual
else
  MEDIAFW=builtin
fi
export MEDIAFW

# Determine patch level and last part of linux version number
export PATCH=`grep -e "KERNEL_STM=p0" ./config | awk '{print substr($0,length($0)-2,length($0))}'`
FNAME="0$PATCH"_"$BOXTYPE"
if [ "$IMAGE" == "tvheadend" ]; then
  cd $CDKDIR/patches/build-neutrino
else
  cd $CDKDIR/patches/build-$IMAGE
fi
ls $CDKDIR/build_tmp > $FLASHDIR/lastconfig
cd $CURDIR
export SUBVERS=`grep -e "linux-sh4-2.6.32." $FLASHDIR/lastconfig | awk '{print substr($0,length($0)-12,2)}'`
rm $FLASHDIR/lastconfig

# Determine/ask for output type (USB or flash)
if [ "$BATCH_MODE" == "yes" ]; then
  if [ `grep -e "DESTINATION=USB" $FLASHDIR/config` ]; then
    export OUTTYPE="USB"
  else
    export OUTTYPE="flash"
  fi
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
if [ "$IMAGE" == "enigma2" ] && [ "$OUTTYPE" == "flash" ] && [ ! "$BATCH_MODE" == "yes" ]; then
  case "$BOXTYPE" in
    fortis_hdbox|octagon1008|hs7110|hs7420|hs7810a|ufs910|ufs922|cuberevo|cuberevo_mini2|cuberevo_250hd|cuberevo_2000hd|cuberevo_3000hd|cuberevo_9500hd)
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
      export ERROR="yes"
      exit;;
  esac
fi

# Check if there is support for the receiver combined with imagetype
if [ "$IMAGE" == "enigma2" ] && [ "$OUTTYPE" == "USB" ]; then
  case "$BOXTYPE" in
    spark|spark7162|ufs913)
      echo
      echo "-- Message ----------------------------------------------------------------"
      echo
      echo " Currently there is no enigma2-USB support for your receiver $BOXTYPE."
      echo
      echo " Sorry."
      echo
      echo " Exiting..."
      echo "---------------------------------------------------------------------------"
      export ERROR="yes"
      exit;;
    *)
      ;;
  esac
elif [ "$IMAGE" == "neutrino" ] && [ "$OUTTYPE" == "USB" ]; then
  case "$BOXTYPE" in
    atevio7500|fortis_hdbox|octagon1008|hs7119|hs7819|spark|spark7162|ufc960|ufs910)
      ;;
    *)
      echo
      echo "-- Message ----------------------------------------------------------------"
      echo
      echo " Currently there is no Neutrino-USB support for your receiver $BOXTYPE."
      echo
      echo " Sorry."
      echo
      echo " Exiting..."
      echo "---------------------------------------------------------------------------"
      export ERROR="yes"
      exit;
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
  if [ -d $BASEDIR/build_source/libstb-hal-ddt ]; then
    HAL_REV=_HAL-rev`cd $BASEDIR/build_source/libstb-hal-ddt && git log | grep "^commit" | wc -l`
  elif [ -d $BASEDIR/build_source/libstb-hal-github ]; then
    HAL_REV=_HAL-rev`cd $BASEDIR/build_source/libstb-hal-github && git log | grep "^commit" | wc -l`
  elif [ -d $BASEDIR/build_source/libstb-hal-martii-github ]; then
    HAL_REV=_HAL-rev`cd $BASEDIR/build_source/libstb-hal-martii-github && git log | grep "^commit" | wc -l`
  elif [ -d $BASEDIR/build_source/libstb-hal-tangos ]; then
    HAL_REV=_HAL-rev`cd $BASEDIR/build_source/libstb-hal-tangos && git log | grep "^commit" | wc -l`
  elif [ -d $BASEDIR/build_source/libstb-hal ]; then
    HAL_REV=_HAL-rev`cd $BASEDIR/build_source/libstb-hal && git log | grep "^commit" | wc -l`
  elif [ -d $BASEDIR/build_source/neutrino-hd2.git ]; then
    HAL_REV=
  else
    HAL_REV=_HAL-revXXX
  fi

  if [ -d $BASEDIR/build_source/neutrino-mp-ddt ]; then
    NMP_REV=_NMP-rev`cd $BASEDIR/build_source/neutrino-mp-ddt && git log | grep "^commit" | wc -l`-ddt
  elif [ -d $BASEDIR/build_source/neutrino-mp-github ]; then
    NMP_REV=_NMP-rev`cd $BASEDIR/build_source/neutrino-mp-github && git log | grep "^commit" | wc -l`-github
  elif [ -d $BASEDIR/build_source/neutrino-mp-martii-github ]; then
    NMP_REV=_NMP-rev`cd $BASEDIR/build_source/neutrino-mp-martii-github && git log | grep "^commit" | wc -l`-martii-github
  elif [ -d $BASEDIR/build_source/neutrino-mp-tangos ]; then
    NMP_REV=_NMP-rev`cd $BASEDIR/build_source/neutrino-mp-tangos && git log | grep "^commit" | wc -l`-tangos
  elif [ -d $BASEDIR/build_source/neutrino-mp ]; then
    NMP_REV=_NMP-rev`cd $BASEDIR/build_source/neutrino-mp && git log | grep "^commit" | wc -l`
  elif [ -d $BASEDIR/build_source/neutrino-hd2.git ]; then
    NMP_REV=_NMP-rev`cd $BASEDIR/build_source/neutrino-hd2.git && git log | grep "^commit" | wc -l`-hd2
  else
    NMP_REV=_NMP-revXXX
  fi
fi
export GITVERSION=CDK-rev`(cd $CDKDIR && git log | grep "^commit" | wc -l)`"$HAL_REV""$NMP_REV"

# Build tfinstaller if not done yet
TFINSTALL="present"
if [ $BOXTYPE == "tf7700" ]; then
    TFINSTALL="built"
fi

# All is OK so far, display summary
if [ ! "$BATCH_MODE" == "yes" ]; then
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
  echo "+  Linux version      : linux-sh4-2.6.32.$SUBVERS"
  echo "+  Kernel patch level : P0$PATCH"
  echo "+  Image              : $IMAGEN"
  echo "+  Will run in/on     : $OUTTYPE"
  echo "+"
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo
fi

# Prepare root
echo "-- Prepare root -------------------------------------------------------"
echo
echo " Prepare $IMAGEN root for $BOXTYPE."
echo
if [[ ( "$BOXTYPE" == "adb_box" || "$BOXTYPE" == "atevio7500" ) && "$OUTTYPE" == "flash" && "$IMAGE" == "enigma2" ]]; then
  # The root will be optionally stripped of all language support except de (German), fr (French)
  # and en (English) because the flash space is rather limited on these receivers.
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
  export ERROR="yes"
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
  atevio7500|fortis_hdbox|octagon1008|hs7110|hs7420|hs7810a|hs7119|hs7429|hs7819|dp2010|dp6010|dp7000|dp7001|epp8000)
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
        dp2010)
          RESELLERID=29090300
          FORTISBOX="Forever HD 3434 PVR Cardiff";;
        dp6010)
          RESELLERID=29060000
          FORTISBOX="Rebox RE-2220HD S-PVR";;
#        dp7000|dp7001)
        dp7001)
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
    adb_box)
      $SCRIPTDIR/$OUTTYPE/"$BOXTYPE"_"$OUTTYPE".sh;;
    atevio7500)
      $SCRIPTDIR/$OUTTYPE/"$BOXTYPE"_"$OUTTYPE".sh
      unset RESELLERID
      if [ "$IMAGE" == "enigma2" ]; then
        unset OWNLANG
        unset OWNCOUNTRY
      fi;;
    cuberevo|cuberevo_mini|cuberevo_mini2|cuberevo_250hd|cuberevo_2000hd|cuberevo_3000hd|cuberevo_9500hd)
      $SCRIPTDIR/$OUTTYPE/$IMAGE/"cuberevo"_"$IMAGE"_"$OUTTYPE".sh;;
    ufs910|ufs922)
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
    dp2010|dp6010|dp7000|dp7001|epp8000)
      $SCRIPTDIR/$OUTTYPE/"fortis_4G"_"$OUTTYPE".sh
      unset RESELLERID;;
    spark|spark7162)
      $SCRIPTDIR/$OUTTYPE/"spark"_"$OUTTYPE".sh;;
    tf7700)
      $SCRIPTDIR/$OUTTYPE/"$BOXTYPE"_"$OUTTYPE".sh;;
    ufc960)
      $SCRIPTDIR/$OUTTYPE/$IMAGE/"ufc960"_"$OUTTYPE"_"$IMAGE".sh;;
    ufs912|ufs913)
      $SCRIPTDIR/$OUTTYPE/"$BOXTYPE"_"$OUTTYPE".sh;;
    vitamin_hd5000)
      $SCRIPTDIR/$OUTTYPE/"vitamin_hd5000"_"$OUTTYPE".sh;;
    *)
      echo " Sorry, there is no $OUTTYPE support for receiver $BOXTYPE available."
      echo
      echo " Exiting..."
      echo "-----------------------------------------------------------------------"
      exit 2;;
  esac
else #USB
  case $BOXTYPE in
    adb_box)
#      $SCRIPTDIR/$OUTTYPE/"$BOXTYPE"_"$OUTTYPE".sh;;
      $SCRIPTDIR/$OUTTYPE/make_tar_gz.sh;;
    atevio7500|fortis_hdbox|octagon1008)
      $SCRIPTDIR/$OUTTYPE/make_tar_gz.sh;;
    hs7110|hs7420|hs7810a|hs7119|hs7429|hs7819)
      $SCRIPTDIR/$OUTTYPE/"fortis_23G"_"$OUTTYPE".sh;;
    cuberevo|cuberevo_mini|cuberevo_mini2|cuberevo_250hd|cuberevo_2000hd|cuberevo_3000hd|cuberevo_9500hd)
      $SCRIPTDIR/$OUTTYPE/make_tar_gz.sh;;
    ufs910|ufs912|ufs922|ufc960)
      $SCRIPTDIR/$OUTTYPE/make_tar_gz.sh;;
    vitamin_hd5000)
      $SCRIPTDIR/$OUTTYPE/"$BOXTYPE"_"$OUTTYPE".sh;;
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
unset BATCH_MODE
unset INAME
unset MEDIAFW

if [ -e dummy.squash.signed.padded ]; then
  rm -f dummy.squash.signed.padded
fi

