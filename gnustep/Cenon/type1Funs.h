/* fontFuns.h
 * Functions helping with type 1 fonts
 *
 * Copyright (C) 1995-2005 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1995-07-30
 * Modified: 2002-07-07
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by vhf interservice GmbH. Among other things, the
 * License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this program; see the file LICENSE. If not, write to vhf.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#ifndef VHF_H_TYPE1FUNS
#define VHF_H_TYPE1FUNS

/* for interpreter
 */
#define SEPARATORS	" \t\n\r"
#define NEWLINE		"\n\r"

typedef unsigned char Proc;

unsigned char encryptByte(unsigned char plain);
unsigned char decryptByte(unsigned char cipher);
unsigned char *decryptCharString(unsigned char *string, int len);
unsigned char *encryptCharString(unsigned char *string, int len);
unsigned char *encryptEexec(unsigned char *string, int len);
unsigned char *decryptEexec(const unsigned char *string, int srcLen, int *desLen);
unsigned char *decodeNumber(unsigned char *str, int *value);
int encodeNumber(int value, unsigned char *charString);
char *getName(const char *cp);
char *getString(const char *cp);
int getInt(const char *cp);
BOOL getBool(const char *cp);
char *getArray(char *cp, float array[]);
char *getOtherSubrs(char *cp);

#endif // VHF_H_TYPE1FUNS
