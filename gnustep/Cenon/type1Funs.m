/* type1Funs.c
 * Functions helping with type 1 fonts
 *
 * Copyright (C) 1995-2008 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1995-07-30
 * Modified: 2008-02-06
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

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <VHFShared/types.h>
#include "type1Funs.h"

/* encrypt / decrypt
 */
#define C1 52845
#define C2 22719
unsigned short r;
unsigned char encryptByte(unsigned char plain)
{   unsigned char	cipher;

    cipher = (plain ^ (r>>8));
    r = (cipher+r) * C1 + C2;
    return cipher;
}

unsigned char decryptByte(unsigned char cipher)
{   unsigned char plain;

    plain = (cipher ^ (r>>8));
    r = (cipher+r) * C1 + C2;
    return plain;
}

unsigned char *decryptCharString(unsigned char *string, int len)
{   int			i;
    unsigned char	*str;

    if ( !(str = malloc((len-4)*sizeof(Proc))) )  // -4
    {	printf("FontWizard, /CharStrings: Out of Memory\n");
        return 0;
    }
    r = 4330;
    for (i=0; i<len; i++)
    {	unsigned char	v;

        v = decryptByte(string[i]);
        if (i>=4)
            str[i-4] = v;
    }

    return str;
}

unsigned char *encryptCharString(unsigned char *string, int len)
{   int	i;

    r = 4330;
    string[0] = 'v';
    string[1] = 'h';
    string[2] = 'f';
    string[3] = '2';
    for (i=0; i<len; i++)
        string[i] = encryptByte(string[i]);

    return string;
}

unsigned char *encryptEexec(unsigned char *string, int len)
{   unsigned char	*encryptedData, *ep, *cp, *end;

    r = 55665;
    if ( !(encryptedData = malloc(len*2)) )
    {	printf("FontWizard, eexec encryption: Out of Memory\n");
        return 0;
    }
    cp = string;
    ep = encryptedData;	/* this is the destination */
    for (end=string+len; cp < end; cp++, ep+=2)
    {	unsigned char	u = encryptByte(*cp);

        sprintf((char*)ep, "%x", u);
        if (u<0x10)
        {   *(ep+1) = *ep;
            *ep = '0';
        }
    }

    return encryptedData;
}

unsigned char *decryptEexec(const unsigned char *string, int srcLen, int *desLen)
{   unsigned char	*decryptedData, *dp;
    const char		*cp, *end;
    int			i, mode = 0;

    for (i=0; i<10;i++)
        if (strcspn((char*)string+i, "0123456789ABCDEFabcdef \t\r\n"))
            mode = 1;	/* dos */

    r = 55665;
    if ( !(decryptedData = malloc(srcLen/2)) )
    {	printf("FontWizard, eexec decryption: Out of Memory\n");
        return 0;
    }
    cp = (const char*)string;
    dp = decryptedData;	/* this is the destination */

    for (end=(const char*)string+srcLen; cp < end; dp++)
    {	char		str[3];
        unsigned char	uc;
        char		endp[10];

        if (!mode)
        {
            cp += strspn(cp, "\r\n\t ");	// skip space

            str[0] = *cp++;
            str[1] = *cp++;
            str[2] = 0;

            uc = (unsigned char)strtol(str, (char**)&endp, 16);
        }
        else
        {
            uc = (unsigned char)*cp++;
        }
        *dp = decryptByte(uc);
    }
    *desLen = dp - decryptedData;

    return decryptedData;
}

/* charstring encoding / decoding
 */
unsigned char *decodeNumber(unsigned char *str, int *value)
{   int	v = (int)*str;

    if (v >= 32)
    {
        if (v <= 246)
        {   *value = v - 139;
            return str+1;
        }
        if (v >= 247 && v <= 250)
        {   int	w = (int)*(str+1);

            *value = ((v - 247) * 256) + w + 108;
            return str+2;
        }
        if (v >= 251 && v <= 254)
        {   int	w = (int)*(str+1);

            *value = 0-((v - 251) * 256) - w - 108;
            return str+2;
        }
        if (v == 255)
        {   int	v;

            v =  (int)*(str+1)*(int)0x1000000;
            v += (int)*(str+2)*(int)0x10000;
            v += (int)*(str+3)*(int)0x100;
            v += (int)*(str+4);
            *value = v;
            return str+5;
        }
    }

    return str;
}

int encodeNumber(int value, unsigned char *charString)
{   int			v;
    unsigned char	*str = charString;

    if (value >= -107 && value <= 107)
    {
        str[0] = (unsigned char)(value + 139);
        str[1] = 0;
        return 1;
    }
    if (value >= 108 && value <= 1131)
    {
        str[0] = (unsigned char)((value-108)/256+247);
        str[1] = (unsigned char)((value-108)%256);
        str[2] = 0;
        return 2;
    }
    if (value >= -1131 && value <= -108)
    {
        str[0] = (unsigned char)((0-(value+108))/256+251);
        str[1] = (unsigned char)((0-(value+108))%256);
        str[2] = 0;
        return 2;
    }

    str[0] = 255;
    str[1] = (unsigned char)(value / 0x1000000);
    v = value % 0x1000000;
    str[2] = (unsigned char)(v / 0x10000);
    v = v % 0x10000;
    str[3] = (unsigned char)(v / 0x100);
    v = v % 0x100;
    str[4] = (unsigned char)v;
    str[5] = 0;
    return 5;
}

/* allocates a string with a copy of cp until the next separator
 */
char *getName(const char *cp)
{   char	*str;
    int		len;
    
//   str = NXUniqueStringWithLength(cp, strcspn(cp, SEPARATORS));

    len = strcspn(cp, SEPARATORS);

    if ( !(str = malloc(len*sizeof(char)+1)) )
    {	printf("FontWizard, getName(): Out of memory\n");
        return 0;
    }
    // cp++; getName()+1
    strncpy(str, cp, len);
    str[len] = 0;
    cp += len;

    return (char*)str;
}

/* allocates a string with a copy of cp from '(' until the next ')'
 */
char *getString(const char *cp)
{   char	*str;
    int		len, i;

    cp += strcspn(cp, "()\n\r");	// goto '('
    if (*cp != '(')
    {	printf("FontWizard, getString(): unexpected character; '(' expected\n");
        return 0;
    }
    cp++;
    for (i=1, len=0; i; len++)	/* for nested () */
    {
        len += strcspn(cp+len, "()\n\r");	// goto next '(' or ')'
        if (*(cp+len) == '(')
            i++;
        else if (*(cp+len) == ')')
            i--;
        else
            break;
    }
    len --;

    str = malloc(len+1);
    strncpy(str, cp, len);
    str[len] = 0;

    return (char*)str;
}

int getInt(const char *cp)
{   char	*endp[10];

    return (int)strtol(cp, (char**)&endp, 10);
}

BOOL getBool(const char *cp)
{
	cp += strspn(cp, " \t");	/* goto data */
	return (strncmp(cp, "false", strlen("false")) ? YES : NO);
}

char *getArray(char *cp, float array[])
{	int	i;

    cp += strcspn(cp, "[{}]\n\r")+1;	// goto '['
    cp += strspn(cp, " \t");	// goto next digits
    for (i=0; 1; i++)
    {
        if (strcspn(cp, "-.0123456789"))	// not a digit -> we are wrong
        {	printf("FontWizard, getArray(): unexpected character; digit expected!\n");
            return cp;
        }
        array[i] = (float)atof(cp);
        cp += strspn(cp, "-.0123456789");	// goto end of digits
        cp += strspn(cp, " \t");	// skip space
        if (*cp == ']' || *cp == '}')	// ready
           return cp+1;
    }

    return cp;
}

char *getOtherSubrs(char *cp)
{   int		len, i;
    char	*str;

    cp += strspn(cp, SEPARATORS);	// goto '['
    if (*cp != '[')
        cp += strcspn(cp, "[");	// goto '['
    if (*cp != '[')
    {	printf("FontWizard, getOtherSubrs(): unexpected character; '[' expected.\n");
        return 0;
    }
    for (i=1, len=1; i; len++)	// include nested []
    {
        len += strcspn(cp+len, "[]");	// goto next '[' or ']'
        if (*(cp+len) == '[')
            i++;
        else if (*(cp+len) == ']')
            i--;
        else
            break;
    }

    if ( !(str = malloc(len*sizeof(char)+1)) )
    {	printf("FontWizard, getOtherSubrs(): Out of memory\n");
        return 0;
    }

    strncpy(str, cp, len);
    str[len] = 0;

    return str;
}
