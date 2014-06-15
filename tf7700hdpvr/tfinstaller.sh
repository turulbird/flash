#!/bin/bash
if [ `id -u` = 0 ]; then
	echo "Do not run this script as root. Try it again without su/sudo command."
	echo "Bye Bye..."
	exit
fi

CURDIR=`pwd`
BASEDIR=$CURDIR/../..

TUFSBOXDIR=$BASEDIR/tufsbox
CDKDIR=$BASEDIR/cdk
TFINSTALLERDIR=$CDKDIR/tfinstaller

cd $CDKDIR
make uboot_tf7700
make tfinstaller/u-boot.ftfd
make tfpacker
make -C tfinstaller

echo "Finished, now you could run tf7700hdpvr.sh"
