#!/bin/bash
# "-----------------------------------------------------------------------"
# "This script creates the Topfield installer."
#
# "Author: Audioniek, based on previous work by person(s) unknown."
# "Date: 07-12-2014"
#
# "Do not run this script witch sudo. fakeroot is OK."

echo -n " Remove previous Topfield installer..."
rm -f $TFINSTALLERDIR/uImage
rm -f $TFINSTALLERDIR/Enigma_Installer.tfd
rm -f $TFINSTALLERDIR/tfpacker
rm -f $CDKDIR/.deps/uboot_tf7700
echo " done."

cd $CDKDIR
make uboot_tf7700
make tfinstaller/u-boot.ftfd
make -C tfinstaller 2> /dev/null


