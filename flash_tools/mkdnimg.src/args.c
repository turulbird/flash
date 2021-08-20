/************************************************************************
 *
 * mkdnimg - args part
 *
 * Program to create flash files for DGStation receivers
 *
 * Copyright (C) DGSTATION
 *
 *
 * Tuners are directkly connected to the I2C bus, not through
 * the STV0900 I2C gate.
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
#include <stdlib.h>

#include "args.h"

#define print(fmt,arg...) fprintf(stderr, fmt, ##arg)
#define debug_Error print

extern struct Arg_Desc __start_argument_struct;
extern struct Arg_Desc __stop_argument_struct;

struct Arg_Desc *argd;
int argd_num;

int analize_args(int argc, char **argv)
{
	int ret = 0;
	int a;
	int b;
	int cmplen;

	argd = &__start_argument_struct;
	argd_num = &__stop_argument_struct - &__start_argument_struct;

	//debug( "argd     0x%08x\n", (int)argd );
	//debug( "argd_num %d\n", argd_num );

	for(a = 1; a < argc; a++)
	{
		char *arg = *(argv + a);

		/* skip first two '-' */
		if (arg[0] == '-')
		{
			arg ++;
		}
		if (arg[0] == '-')
		{
			arg ++;
		}
		for (b = 0; b < argd_num; b++)
		{
			cmplen = strlen(argd[b].what_to_get);

			if (strncmp(argd[b].what_to_get, arg, cmplen) == 0)
			{
				if (argd[b].type == AT_STRING)
				{
					if (strlen(&arg[cmplen]) > 0)
					{
						if (arg[cmplen] == '=')
						{
							*(char**)argd[b].to_get = &arg[cmplen + 1];
							break;
						}
						else
						{
							*(char**)argd[b].to_get = &arg[cmplen];
							break;
						}
					}
					else if (a + 1 < argc)
					{
						a++;
						*(char**)argd[b].to_get = *(argv + a);
						break;
					}
					else
					{
						debug_Error("More arguments are required.\n");
						return -1;
					}
				}
				else if (argd[b].type == AT_BOOLEAN)
				{
					if (strlen(arg) == cmplen)
					{
						*(int*)argd[b].to_get = 1;
						break;
					}
				}
				else if (argd[b].type == AT_INT)
				{
					if (strlen(&arg[cmplen]) > 0)
					{
						if (arg[cmplen] == '=')
						{
							*(int*)argd[b].to_get = strtol(&arg[cmplen + 1], NULL, 0);
							break;
						}
						else
						{
							*(int*)argd[b].to_get = strtol(&arg[cmplen], NULL, 0);
							break;
						}
					}
					else if (a + 1 < argc)
					{
						a++;
						*(int*)argd[b].to_get = strtol(*(argv + a), NULL, 0);
						break;
					}
					else
					{
						debug_Error("More arguments are required.\n" );
						return -1;
					}
				}
				else if (argd[b].type == AT_UINT)
				{
					if (strlen(&arg[cmplen]) > 0)
					{
						if (arg[cmplen] == '=')
						{
							*(int*)argd[b].to_get = strtoul(&arg[cmplen + 1], NULL, 0);
							break;
						}
						else
						{
							*(int*)argd[b].to_get = strtoul(&arg[cmplen], NULL, 0);
							break;
						}
					}
					else if(a + 1 < argc)
					{
						a++;
						*(int*)argd[b].to_get = strtoul(*(argv + a), NULL, 0);
						break;
					}
					else
					{
						debug_Error("More arguments are required.\n");
						return -1;
					}
				}
				else
				{
					debug_Error("Unknown type of argument.\n" );
					return -1;
				}
			}
		}
		if (b == argd_num)
		{
			debug_Error( "Unknown argument.\"%s\"\n", arg );
			ret = -1;
			break;
		}
	}
	return ret;
}

void print_value(void)
{
	int a;

	print("argument        type    value\n");

	for (a = 0; a < argd_num; a++)
	{
		print("%-16s", argd[a].what_to_get);
		switch (argd[a].type)
		{
			case AT_STRING:
			{
				print("STRING  \"%s\"\n", *(char**)argd[a].to_get);
				break;
			}
			case AT_BOOLEAN:
			{
				print("BOOLEAN %d\n", *(int*)argd[a].to_get);
				break;
			}
			case AT_INT:
			{
				print("INT     %d\n", *(int*)argd[a].to_get);
				break;
			}
			case AT_UINT:
			{
				print("UINT    0x%08x\n", *(int*)argd[a].to_get);
				break;
			}
			default:
			{
				print("Unknown... possible bug...\n");
				break;
			}
		}
	}
}
// vim:ts=4
