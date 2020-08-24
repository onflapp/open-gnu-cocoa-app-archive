#include  "common.h"

char *str_dup(const char *src);
void str_lcat(char *, const char *, int);
const char *begin_comm(const char *, BOOL);
void comment_copy(char *, const char *);
const char *key_comm(const commonInfo *);

#define  comm_cat(mem, s)	str_lcat(mem, s, MAX_COMMENT)
