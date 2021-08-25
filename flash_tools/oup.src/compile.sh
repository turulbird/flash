#!/bin/bash

if [  -e oup ]; then
  rm oup
fi

if [  -e oup.exe ]; then
  rm oup.exe
fi

g++ -o oup oup.c crc32.c

if [  -e oup ]; then
  strip --strip-unneeded oup
fi


