#include  <stdio.h>
//#include  <libc.h> //Linux only
#include  <objc/objc.h>
#include  "common.h"

int get_short(FILE *fp)
{
	int c = getc(fp);
	return ((getc(fp) << 8) | c);
}

long get_long(FILE *fp)
{
	long c = get_short(fp);
	return ((get_short(fp) << 16) | c);
}

void put_short(int k, FILE *fp)
{
	putc(k & 0xff, fp);
	putc((k >> 8) & 0xff, fp);
}

void put_long(long k, FILE *fp)
{
	put_short(k & 0xffff, fp);
	put_short((k >> 16) & 0xffff, fp);
}

int byte_Length(int bits, int width) // namespace pb  GNUstep
{
	switch (bits) {
	case 1: return ((width + 7) >> 3);
	case 2: return ((width + 3) >> 2);
	case 4: return ((width + 1) >> 1);
	case 8:
	default:
	  break;
	}
	return width;
}

