#!/bin/bash
# "-----------------------------------------------------------------------"
# "This script can be used to customize the creation of flashable images"
# "for NOR flash receivers."
# "Author: Schischu, Oxygen-1, BPanther, TangoCash, Grabber66, Audioniek"
# "Last Change: 07-12-2014"
#
# Available # ed environment variables are:
#  CURDIR         The directory the origination flash script was called from;
#  BASEDIR        The base directory of the current build environment;
#  TUFSBOXDIR     The tufsbox folder of the current build environment;
#  CDKDIR         The cdk folder of the current build environment;
#  SCRIPTDIR      The folder the basic scripts are in;
#  TOOLSDIR       The folder holding the flashtools pad, fup, mup, mksquashfs and others;
#  TMPDIR         The temporary work folder (filled by prepare_root.sh)
#  TMPROOTDIR     $TMPDIR/ROOT
#  TMPVARDIR      $TMPDIR/VAR
#  TMPKERNELDIR   $TMPDIR/KERNEL
#  OUTDIR         The folder where the output will be written ($CURDIR/out);
#  BOXTYPE        The receiver model, as supplied by make.sh in the build environment;
#  OUTTYPE        Image type to make: flash or USB;
#  HOST           The contents of hostname of the target receiver
#  GITVERSION     String holding the GIT-version numbers
#  SUBVERS        Last part of the linux version number (precede with 'linux-sh4-2.6.32.' to get the whole version string).

# Set up the variables (adapt as you see fit)
MKFSJFFS2=$TUFSBOXDIR/host/bin/mkfs.jffs2
SUMTOOL=$TUFSBOXDIR/host/bin/sumtool
PAD=$TOOLSDIR/pad
MKSQUASHFS3=$TOOLSDIR/mksquashfs3.3
MKSQUASHFS4=$TOOLSDIR/mksquashfs4.0

# Do your customizations here

