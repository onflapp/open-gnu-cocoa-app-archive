#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
//#include <libc.h> //Linux only

#include "mag.h"
#include "sjis2euc.h"

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


static void copy_comm(char *comm, char *memo)
{
	int i, k, n;
	char *p;

	if (memo == NULL || *memo == 0) return;
	if (!eucflag) { /* SJIS　のまま */
		strcpy(comm, memo);
		return;
	}
	n = strlen(memo);
	p = (char *)malloc(2 * n + 4);	/* コメントが半角カタカナの場合、 */
	sjis2euc(p, memo);		/* 文字数が最大で２倍に増える  */
	p[n+1] = p[n+2] = 0;	/* sentinel */
	for (i = 0, k = 0; i < MAX_COMMENT-2 && p[k]; ) {
		if (p[k] == ' ') {
			for (n = 0; p[++k] == ' '; n++) ;
			comm[i++] = ' ';
			if (n) comm[i++] = ' ';
		}else if (p[k] & 0x80) {
			comm[i++] = p[k++];
			comm[i++] = p[k++];
		}else
			comm[i++] = p[k++];
	}
	comm[i] = 0;
	free((void *)p);
}

static magHeader *get_header(FILE *fp) /* ファイルからヘッダ情報を読む。 */
{
	int cc, x1, x2, y1, y2;
	magHeader *mh;

	mh = (magHeader *)malloc(sizeof(magHeader));
	(void)fseek(fp, 3L, SEEK_CUR);
	cc = getc(fp);
	mh->is256c = (cc & 0x80) ? YES : NO;
	mh->isDouble = (cc & 0x01) ? YES : NO;
	x1 = get_short(fp);
	y1 = get_short(fp);
	x2 = get_short(fp);
	y2 = get_short(fp);
	if (x1 < 0 || x2 >= MaxImageSize || y1 < 0 || y2 >= MaxImageSize)
		mh->xbitwidth = mh->yheight = mh->xbytewidth = 0;
	else {
		mh->xbitwidth = x2 - x1 + 1;
		mh->yheight = y2 - y1 + 1;
		mh->xbytewidth = (x2 >> 3) - (x1 >> 3) + 1;
	}
	mh->flagAoffset = get_long(fp);
	mh->flagBoffset = get_long(fp);
	mh->flagBsize = get_long(fp);
	mh->pixeloffset = get_long(fp);
	mh->pixelsize = get_long(fp);
	return mh;
}

void freeMagHeader(magHeader *mh)
{
	if (mh) free((void *)mh);
}

magHeader *loadMagHeader(FILE *fp, long *base, int *errcode)
/* ファイルからヘッダ情報を読む。
   エラーが起きた場合は NULLが返り、errcodeにその理由が入る。
   ファイルポインタはパレット情報の先頭を指して返る。 */
{
	char	typestr[10];
	long	size, w;
	int	i, cc;
	unsigned char	*mm;
	struct stat	sbuf;
	magHeader	*mh;

	*errcode = 0;
	fstat(fileno(fp), &sbuf);
	size = sbuf.st_size;
	for (i=0; i<8; i++)
		typestr[i] = getc(fp);
	typestr[8] = 0;
	if (strcmp(typestr, "MAKI02  ") != 0) {
		*errcode = Err_FORMAT;
		return NULL;
	}
	for (i=8; (cc=getc(fp)) != 0x1a; i++)
		if (cc == EOF) {
			*errcode = Err_SHORT;
			return NULL;
		}
	mm = (unsigned char *)malloc(i-6);
	(void)fseek(fp, 8L, SEEK_SET);
	for (i=0; (cc=getc(fp)) != 0x1a; i++)
		mm[i] = cc;
	mm[i++] = 0;
	if ((*base = i + 8) + sizeof_magHeader >= size) {
		*errcode = Err_SHORT;
		return NULL;
	}
	mh = get_header(fp);
	copy_comm(mh->memo, mm);
	free((void *)mm);
	if (mh->xbitwidth <= 0) {
		freeMagHeader(mh);
		*errcode = Err_ILLG;
		return NULL;
	}
	if ((w = *base + mh->pixeloffset + mh->pixelsize) > size)
	/* データ欠損。多少は見逃す。 */
		if (w - size > 8) {
			freeMagHeader(mh);
			*errcode = Err_SHORT;
			return NULL;
		}
	return mh;
}
