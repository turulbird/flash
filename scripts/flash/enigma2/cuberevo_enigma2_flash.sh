#!/bin/bash
# "-----------------------------------------------------------------------"
# "This script should create flashable enigma2 images for CubeRevo"
# "receivers."
#
# "Author: Audioniek"
# "Date: 08-02-2019"
# "-----------------------------------------------------------------------"

echo -e "\033[01;31m"
echo "-- REMARK -------------------------------------------------------------"
echo
echo " Enigma2 cannot be run in flash memory on this receiver as it is quite" > /dev/stderr
echo " a bit larger than the 32 Mbyte flash memory available. Sorry..." > /dev/stderr
echo
echo " Exiting..."
echo
echo "-----------------------------------------------------------------------"
echo -e "\033[00m"

