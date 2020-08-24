/*
	pcx2pxo
		partially based on "pcxtoppm.c" by Michael Davidson (1990).

	ver.2.0  1997-08-25  for Full Color	by T.Ogihara
*/

#include  <stdio.h>
#include  "pcx.h"

int main(int argc, char *argv[])
{
	FILE *fp;
	pcxHeader *ph;
	int err;

	if (argc != 2) {
		fprintf(stderr, "usage: pcx2pxo pcxfile\n");
		return 1;
	}
	if ((fp = fopen(argv[1], "r")) == NULL)
		return 2;	/* Can't open */

	if ((ph = loadPcxHeader(fp, &err)) == NULL)
		return err;	/* Error */
	err = pcxGetImage(fp, stdout, ph);
	fclose(stdout);
	freePcxHeader(ph);
	return err;
}
