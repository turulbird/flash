#!/bin/bash

if [  -e mkdnimg ]; then
  rm mkdnimg
fi

if [  -e mkdnimg.exe ]; then
  rm mkdnimg.exe
fi

gcc -o mkdnimg main.c args.c mkusbimg.c crc32.c mkserialimg.c

if [  -e mkdnimg ]; then
  strip --strip-unneeded mkdnimg
fi

