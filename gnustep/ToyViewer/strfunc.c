#include  <stdio.h>
#include  <string.h>
//#include  <libc.h>
#include  <objc/objc.h>
#include  "strfunc.h"

char *str_dup(const char *src)
{
	char *dst;

	dst = (char *)malloc(strlen(src) + 1);
	strcpy(dst, src);
	return dst;
}


void str_lcat(char *p, const char *comm, int max)
{
	int i, limit;

	if (comm == NULL)
		return;
	limit = max - 1;
	for (i = 0; i < limit && *p; i++, p++) ;
	while(*comm && i < limit) {
		*p++ = *comm++;
		i++;
	}
	*p = 0;
}

const char *begin_comm(const char *comm, BOOL cont)
	/* Get begining of comment (... : comment) */
{
	if (comm == NULL)
		return NULL;
	while (*comm && *comm != ':')
		comm++;
	if (*comm == ':' && cont)
		while (*++comm == ' ') ;
	if (*comm == 0)
		return NULL;
	return comm;
}

void comment_copy(char *p, const char *comm)
{
	const char *q;

	if ((q = begin_comm(comm, NO)) == NULL)
		return;
	str_lcat(p, q, MAX_COMMENT);
}

const char *key_comm(const commonInfo *cinf)
{
	const char *pp = begin_comm(cinf->memo, NO);
	if (pp == NULL)
		return ": by ToyViewer";
	return pp;
}
