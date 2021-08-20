/************************************************************************
 *
 * mkdnimg - mkserialimg part
 *
 * Program to create flash files for DGStation receivers
 *
 * Copyright (C) DGSTATION
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 ************************************************************************/
#include <stdio.h>

#include "common.h"
#include "mkserialimg.h"
#include "crc32.h"
#include "main.h"
#include "args.h"
#include <string.h>
#include <arpa/inet.h>

static const char *model_name = "";

define_main_argument(model_name, AT_STRING, &model_name);

int mkserialimg(void)
{
//	struct _serial_image_header header;
	struct DataHeader header;
	FILE *ifd;
	FILE *ofd;
	int filesize;
	int a;
	unsigned int readed;
	unsigned int crc;
	unsigned char buf[1024];
	int ret = 0;

	if (strlen(model_name) > 30)
	{
		errprintf( "Model name is too long; max.length is 30.\n" );
		return -1;
	}

	/*
	 * print verbose message.
	 */
	dprintf( "input file     : %s\n", infile );
	dprintf( "output file    : %s\n", outfile );
	dprintf( "model_name     : \"%s\"\n", model_name );

	/*
	 * open input file and output file.
	 */
	ifd = fopen(infile, "rb");
	if (ifd == NULL)
	{
		errprintf("Error opening input file %s.\n", infile);
		return -1;
	}
	ofd = fopen(outfile, "wb");
	if (ofd == NULL)
	{
		errprintf("Error opening output file %s.\n", outfile);
		fclose(ofd);
		return -1;
	}

	/*
	 * get input filesize.
	 */
	fseek(ifd, 0, SEEK_END);
	filesize = ftell(ifd);
	fseek(ifd, 0, SEEK_SET);
	filesize = (filesize + 1023) & ~1023;

	dprintf("data_size      : 0x%08x(%d)\n", filesize, filesize);

	memset(&header, 0x00, sizeof(header));
	header.valid = 0x01;
	memcpy(header.model_name, model_name, strlen(model_name));
	header.p_or_d = 0x01;
	header.da = 0xff;
	header.f_or_e = 0xff;
	header.size = htonl(filesize);
	header.dummy = 0xff;
	memset(buf, 0xff, 64);
	memcpy(buf, &header, sizeof(header));

	if (fwrite(buf, 1, 64, ofd ) != 64)
	{
		errprintf( "Write error.\n" );
		ret = -1;
		goto terminate;
	}
	for (a = 0; a < filesize; a += 1024)
	{
		readed = fread(buf, 1, 1024, ifd);
		if (readed == 0)
		{
			ret = -1;
			errprintf("Read error.\n");
			goto terminate;
		}
		if (readed != 1024)
		{
			dprintf("readed %d\n", (int)readed);
			memset(&buf[readed], 0, 1024 - readed);
		}
		readed = fwrite(buf, 1, 1024, ofd);
		if (readed != 1024)
		{
			ret = -1;
			errprintf( "Write error.\n" );
			goto terminate;
		}
	}

terminate:
	fclose(ifd);
	fclose(ofd);
	return ret;
}
// vim:ts=4
