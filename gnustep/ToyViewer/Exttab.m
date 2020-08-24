#import  "Exttab.h"
#import  "NSStringAppended.h"
#import  <stdio.h>
#import  <string.h>
#import  "strfunc.h"

/*
Format:

<extension> <path_of_command> <args> ...

One of args must be '$', which is replaced by the image file.
If the first character of path is '~', it is extended to the home
directory. If '@', it is extended to the application directory.

Example...
jpg	/usr/local/bin/djpeg $
g3	/usr/local/pbmplus/g3topbm -reversebits $
qwe	~/bin/qwe2ppm $ -
*/

#define  MAXCOMM	512

static NSString *homeDir, *appDir;

/* Note: If method "fileSystemRepresentation" returns EUC or UTF8 Unicode,
   this routine would work well.  In case of Shift JIS, however, it will fail.
   Because second bytes of Shift JIS can have zero-MSB. */

static char *get_comm(const char *buf, int *a)
{
	int i, j, n, len;
	char tmp[MAXCOMM + 128], *q;
	const char *p;

	if ((len = strlen(buf)) < 3)
		return NULL;
	for (i = j = n = 0; i < len && buf[i]; ) {
		while (buf[i] && buf[i] <= ' ') i++;
		if (buf[i] > ' ') {
			if (++n == 2) { /* path */
				if (buf[i] == '~')
					p = [homeDir fileSystemRepresentation];
				else if (buf[i] == '@')
					p = [appDir fileSystemRepresentation];
				else p = NULL;
				if (p) {
					i++;
					while (*p)
						tmp[j++] = *p++;
				}
			}
			while (buf[i] > ' ')
				tmp[j++] = buf[i++];
			tmp[j++] = 0;
		}
	}
	*a = n;
	tmp[j++] = 0;	/* double NULL */
	q = (char *)malloc(j);
	for (i = 0; i < j; i++)
		q[i] = tmp[i];
	return q;
}


@implementation Exttab

+ (void)setHome:(NSString *)home andPath:(NSString *)path
{
	homeDir = [home retain];
	appDir = [path retain];
}

- (id)init
{
	[super init];
	entry = 0;
	table = NULL;
	args = NULL;
	return self;
}

- (int)readExtData:(NSString *)filename
{
	FILE *fp;
	char buf[MAXCOMM];
	char **tab, *p;
	int *a;
	int count, newentry;

	if ((fp = fopen([filename fileSystemRepresentation], "r")) == NULL)
		return 0;
	for (count = 0; fgets(buf, MAXCOMM, fp); )
		if (buf[0] >= ' ' && buf[0] != '#') count++;
	if (count == 0) {
		fclose(fp);
		return 0;
	}
	rewind(fp);
	newentry = entry + count + 1;
	tab = (char **)malloc(sizeof(char *) * newentry);
	a = (int *)malloc(sizeof(int) * newentry);
	for (count = 0; fgets(buf, MAXCOMM, fp); ) {
		if (! (buf[0] >= ' ' && buf[0] != '#'))
			continue;
		if ((p = get_comm(buf, &a[count])) != NULL)
			tab[count++] = p;
	}
	if (count == 0) {
		free((void *)tab);
		free((void *)a);
		fclose(fp);
		return 0;
	}
	if (entry > 0) {
		int x, k = count;
		for (x = 0; table[x]; x++) {
			tab[k] = table[x];
			a[k] = args[x];
			k++;
		}
		free((void *)table);
		free((void *)args);
		entry = k;
	}else
		entry = count;
	tab[entry] = NULL;
	table = tab;
	args = a;
	return count;
}

- (char **)table
{
	return table;
}

- (int)entry
{
	return entry;
}

- (const char **)execListAlloc: (const char *)type with: (NSString *)filename
{
	int i, n;
	const char **list, *p;

	if (table == NULL)
		return NULL;
	for (n = 0;  ; n++) {
		if (table[n] == NULL) return NULL;
		if (strcmp(table[n], type) == 0)
			break;
	}
	list = (const char **)malloc(sizeof(char *) * (args[n] + 1));
	for (i = 1, p = table[n];  ; i++) {
		while (*p) p++;
		if (*++p == 0) { /* double NULL */
			list[i] = NULL;
			break;
		}
		list[i] = (*p == '$') ? [filename fileSystemRepresentation] : p;
	}
	p = list[0] = list[1];
	while (*p) {
		if (*p++ == '/')
			list[1] = p;
	}
	return list;
}

@end

#ifdef TEST_ALONE
main()
{
	id tab;
	int i, n;
	const char **ex;
	static char *sample[] = { "jpg", "g3", "none", NULL };

	tab = [[Exttab alloc] init];
	[tab readExtData:@"./test1"];
	[tab readExtData:@"./test2"];
	for (n = 0; sample[n]; n++) {
		ex = [tab execListAlloc: sample[n] with: @"ImageFile"];
		if (ex == NULL) {
			printf("Error\n");
			continue;
		}
		for (i = 0; ex[i]; i++)
			printf("(%s) ", ex[i]);
		putchar('\n');
		free((void *)ex);
	}
}
#endif
