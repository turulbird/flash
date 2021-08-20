/************************************************************************
 *
 * mkdnimg - main part
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
#include <string.h>

#include "common.h"
#include "args.h"
#include "main.h"
#include "mkusbimg.h"
#include "mkserialimg.h"

#define VERSION "1.0"
#define DATE "20-08-2021"

static const char *make = "";
int debug = 0;
const char *infile = "";
const char *outfile = "";

define_main_argument(debug, AT_BOOLEAN, &debug);
define_main_argument(make, AT_STRING, &make);
define_main_argument(infile, AT_STRING, &infile);
define_main_argument(input, AT_STRING, &infile);
define_main_argument(outfile, AT_STRING, &outfile);
define_main_argument(output, AT_STRING, &outfile);

int main(int argc, char *argv[])
{
	int ret = 0;

	printf("\nmkdnimg - Version %s (%s)\n", VERSION, DATE);
	if (analize_args(argc, argv ))
	{
		printf("Usage:\n");
		printf("\n");
		printf("mkdnimg [-debug] -make usbimg|usbimg_old|serialimg -vendor_id (int) -product_id (int) -hw_model (int) -hw_version (int) -start_addr (flash start address) -erase_size (size to erase) -image_name (name) -input (input file name) -output (output file name)");
		printf("\n");
		printf("All arguments apart from -debug are mandatory.\n\n");
		return -1;
	}
	if (!strcmp("usbimg", make))
	{
		ret = mkusbimg();
	}
	else if (!strcmp("usbimg_old", make))
	{
		ret = mkusbimg_old();
	}
	else if (!strcmp("serialimg", make))
	{
		ret = mkserialimg();
	}
	else
	{
		errprintf("Unknown option for -make given (must be usbimg, usbimg_old or serialimg)\n");
	}
	return ret;
}
// vim:ts=4
