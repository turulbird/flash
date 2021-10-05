/*****************************************************************************
 * Name :   oup (Opticum update program)                                     *
 *                                                                           *
 *          Management program for Opticum .upd flash files for HD 9600      *
 *          series models:                                                   *
 *          HD 9600          (STx7109, DVB-S(2) only)                        *
 *          HD TS 9600       (STx7109, DVB-S(2) + DVB-T                      *
 *          HD 9600 PRIMA    (STx7105, DVB-S(2) only)                        *
 *          HD 9600 TS PRIMA (STx7105, DVB-S(2) + DVB-T)                     *
 *          HD 9600 MINI     (STx7111, DVB-S(2) only)                        *
 *          HD X550          (STx7100, DVB-S(2) only, not tested)            *
 *          HD X560          (STx7100, DVB-S(2) only, not supported yet)     *
 *                                                                           *
 * Author:  Audioniek                                                        *
 *                                                                           *
 * This program is free software; you can redistribute it and/or modify      *
 * it under the terms of the GNU General Public License as published by      *
 * the Free Software Foundation; either version 2 of the License, or         *
 * (at your option) any later version.                                       *
 *                                                                           *
 * This program is distributed in the hope that it will be useful,           *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of            *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             *
 * GNU General Public License for more details.                              *
 *                                                                           *
 * You should have received a copy of the GNU General Public License         *
 * along with this program; if not, write to the Free Software               *
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA *
 *                                                                           *
 *****************************************************************************
 *
 * File format of .upd:
 * Header (length: 32 / 0x20 bytes)
 *      S        TS       Prima      Mini     Description
 *
 * 0x00 00000000 00000000 00000000   00000000 File type
 * 0x04 40100000 40100000 40100000   40100000 Header identifier
 * 0x08 07120603 07520603 07730603   05140607 Receiver identifier (big endian)
 * 0x0c 1567     5567     7567       1565     Hardware version (big endian)
 * 0x0e 2430     2430     2c40       2750     Version (3rd nibble: major, 1st byte: minor, big endian) 
 * 0x10 0034a8ad 0034f131 003da786   95457c2f Length of binary  (big endian)
 * 0x14 00000000 00000000 00000000   00000000 Reserved? (used as flash offset)
 * 0x18 c96b7058 163d96cf 2677b660   e2f5de11 CRC32 over binary (big endian)
 * 0x1c ffffffff ffffffff ffffffff   ffffffff Filler?
 * 0x20 [binary payload]
 *
 * File format of .cha:
 * Header (length: 32 / 0x20 bytes)
 *      S        TS       Prima      Mini     Description
 *
 * 0x00 01000000 01000000 01000000   01000000 File type
 * 0x04 00000000 00000000 00000000   00000000 Header identifier
 * 0x08 07120603 07520603 07730603   05140607 Receiver identifier (big endian)
 * 0x0c 8490     8490     8490       8490     Hardware version (big endian)
 * 0x0e 3201     3201     3201       3201     Version (3rd nibble: major, 1st byte: minor, big endian) 
 * 0x10 0034a8ad 0034f131 003da786   95457c2f Length of binary (big endian)
 * 0x14 00000000 00000000 00000000   00000000 Reserved?
 * 0x18 c96b7058 163d96cf 2677b660   e2f5de11 CRC32 over binary  (big endian)
 * 0x1c 01000000 01000000 01000000   01000000 Filler?
 * 0x20 [binary payload]
 *
 * Receiver identifiers
 * 07120603  9600HD
 * 07520603  9600HD TS
 * 07730603  9600HD Prima
 * 07730603  9600HD TS Prima
 * 05140607  9600HD Mini
 * 05120601  HD X550
 * unknown   HD X560
 *
 ****************************************************************************/
#ifndef __UPD_MAKE_H__
#define __UPD_MAKE_H__

#define FILE_TYPE_FLASH            0x00000000
#define FILE_TYPE_CHANNEL_LIST     0x00000001
#define HEADER_TYPE_FLASH          0x40100000
#define HEADER_TYPE_CHANNEL_LIST   0x00000000
#define FLAGS_FLASH                0xffffffff
#define FLAGS_CHANNEL_LIST         0x00000001

#define MODEL_CODE_9600HD          0x07120603
#define MODEL_CODE_9600HDTS        0x07520603
#define MODEL_CODE_9600HD_PRIMA    0x07730603  // note: S and TS models use same code
#define MODEL_CODE_9600HD_PRIMA_TS MODEL_CODE_9600HD_PRIMA
#define MODEL_CODE_9600HD_MINI     0x05140607
#define MODEL_CODE_HD_X550         0x05120601

#define HW_CODE_9600HD             0x6715
#define HW_CODE_9600HDTS           0x6755
#define HW_CODE_9600HD_PRIMA       0x6775  // note: S and TS models use same code
#define HW_CODE_9600HD_PRIMA_TS    HW_CODE_9600HD_PRIMA
#define HW_CODE_9600HD_MINI        0x6515
#define HW_CODE_HD_X550            0x6515
#define HW_CODE_CHANNEL_LIST       0x9084

#define SW_CODE_CHANNEL_LIST       0x3201

struct tHeader
{
	uint32_t file_type;
	uint32_t header_id;
	uint32_t model_code;
	uint8_t hw_version_major;
	uint8_t hw_version_minor;
	uint8_t sw_version_major;
	uint8_t sw_version_minor;
	uint32_t length;  // caution: stored big endian
	uint32_t start_addr;  // caution: always 0 in factory .upd files
	uint32_t crc32;  // caution: stored big endian
	uint32_t flag;  // flash: 0xffffffff, channel list 0x01000000
};

/************************************************************
 *
 * Simple table defining model_code -> model name
 *
 * (This table is almost certainly not complete).
 *
 */
struct model_name
{
	uint32_t model_code;
	uint32_t hw_version;
	const char *model_name;
} opt9600hdNames[] =
{
	{ MODEL_CODE_9600HD, HW_CODE_9600HD, "Opticum/Orton HD 9600" },
	{ MODEL_CODE_9600HDTS, HW_CODE_9600HDTS, "Opticum/Orton HD TS 9600" },
	{ MODEL_CODE_9600HD_PRIMA, HW_CODE_9600HD_PRIMA, "Opticum/Orton HD (TS) 9600 PRIMA" },
	{ MODEL_CODE_9600HD_MINI, HW_CODE_9600HD_MINI, "Opticum/Orton HD 9600 MINI" },
	{ MODEL_CODE_HD_X550, HW_CODE_HD_X550, "Opticum HD X550" },
	{ 0, 0x100, "Unknown model" }
};
	
#endif  // __UPD_MAKE_H__
// vim:ts=4

