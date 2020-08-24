#include  <stdio.h>
//#include  <libc.h> //Linux only
#include  "pcx.h"

static int optimalBits(unsigned char *pattern, int num)
/* How many bits are needed to represent given patterns */
{
	int i, x;

	if (num > 16) return 8;
	if (num == 1) { /* 1 bit; only one color */
		if (pattern[0] || pattern[0xff]) return 1;
	}else if (num == 2) { /* 1 bit */
		if (pattern[0] && pattern[0xff]) return 1;
	}
	if (num <= 4) { /* 2 bits */
		for (i = 1; i <= 0xfe; i++)
			if (pattern[i] && (i != 0x55 && i != 0xaa))
				goto BIT4;
		return 2;
	}
BIT4:	/* num <= 16 -- 4 bits */
	for (i = 1; i <= 0xfe; i++)
		if (pattern[i]
			&& ((x = i & 0x0f) != 0 && x != 0x0f && x != i >> 4))
				return 8;
	return 4;
}

int howManyBits(paltype *pal, int n)
/* How many bits are needed to display colors of the palette ? */
{
	int i, c, num;
	unsigned char *p, buf[256];

	for (i = 0; i < 256; i++) buf[i] = 0;
	num = 0;
	for (i = 0; i < n; i++) {
	    p = pal[i];
	    for (c = 0; c < 3; c++)
		if (buf[p[c]] == 0) {
			buf[p[c]] = 1;
			if (++num > 16) return 8;
		}
	}
	return optimalBits(buf, num);
}

Boolean isGray(paltype *pal, int n)
/* Is Gray-scaled all colors of the palette ? */
{
	int i;
	unsigned char *p;

	if (pal == NULL)
		return NO;
	for (i = 0; i < n; i++) {
		p = pal[i];
		if (p[0] != p[1] || p[1] != p[2])
			return NO;
	}
	return YES;
}
