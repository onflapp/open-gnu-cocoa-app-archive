#include  <stdio.h>
#include  <stdlib.h>
#include  "mag.h"

Bool eucflag = NO;	/* convert into EUC ? */

static void usage(const char *name)
{
	fprintf(stderr, "usage: %s [-e] magfile\n", name);
	fprintf(stderr, "    -e   Convert comment into EUC\n");
	exit(1);
}

int main(int argc, char *argv[])
{
	FILE *fp;
	magHeader *mh;
	long base;
	int ac, err;

	for (ac = 1; ac < argc; ac++) {
		if (argv[ac][0] != '-') break;
		switch (argv[ac][1]) {
		case 'e': eucflag = YES; break;
		case 'h':
		default: usage(argv[0]); break;
		}
	}
	if (ac >= argc) usage(argv[0]);

	if ((fp = fopen(argv[ac], "r")) == NULL)
		return Err_OPEN;

	if ((mh = loadMagHeader(fp, &base, &err)) == NULL) {
		fclose(fp);
		return err;
	}
	err = magDecode(fp, stdout, mh, base);

	free((void *)mh);
	fclose(fp);
	return err;
}
