/***********************************************************
	sjis2euc.c
	1995-04-14  by T.Ogihara
***********************************************************/
#define  iskanji(c)	(((c)>=0x81 && (c)<=0x9f) || ((c)>=0xe0 && (c)<=0xfc))
	/* シフトJIS 1バイト目 */
#define  iskanji2(c)	((c)>=0x40 && (c)<=0xfc && (c)!=0x7f)
	/* シフトJIS 2バイト目 */
#define  is8kana(c)	((c)>=0xa0 && (c)<0xe0)
	/* 半角カナ */
#define  XK		0x8e	/* EUC半角カナ */

static void conv(int *ph, int *pl)  /* シフトJISを EUCに */
{
	if (*ph <= 0x9F) {
		if (*pl < 0x9F)  *ph = (*ph << 1) - 0xE1;
		else             *ph = (*ph << 1) - 0xE0;
	} else {
		if (*pl < 0x9F)  *ph = (*ph << 1) - 0x161;
		else             *ph = (*ph << 1) - 0x160;
	}
	if      (*pl < 0x7F) *pl -= 0x1F;
	else if (*pl < 0x9F) *pl -= 0x20;
	else                 *pl -= 0x7E;
	*ph |= 0x80;
	*pl |= 0x80;
}

void sjis2euc(unsigned char *dst, const unsigned char *src)
{
	int c, d;

	for (c = *src; c; ) {
		if (c & 0x80) {
			if (is8kana(c))
				*dst++ = XK, *dst++ = c;
			else if (iskanji(c)) {
				d = *++src;
				if (iskanji2(d)) {
					conv(&c, &d);
					*dst++ = c, *dst++ = d;
				}else {
					*dst++ = c & 0x7f;
					c = d;
					continue; /* ERROR */
				}
			}else
				*dst++ = c & 0x7f;
		}else
			*dst++ = c;
		c = *++src;
	}
	*dst = 0;
}

#ifdef ALONE
#include <stdio.h>
main()
{
	unsigned char buf[256], dst[256];

	while(gets(buf)) {
		sjis2euc(dst, buf);
		puts(dst);
	}
}
#endif
