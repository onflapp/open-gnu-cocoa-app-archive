#include <stdio.h>
//#include <libc.h> // Linux only
#include "bmp.h"

/* extern */
int verbose = 0;

static void usage(void)
{
	fprintf(stderr, "pxo2bmp (2000-03-25)\n");
	fprintf(stderr, "Usage: pxo2bmp [-v] [pxo_file]\n");
	fprintf(stderr, "\t-i\tInterlace\n");
	fprintf(stderr, "\t-v\tVerbose\n");
}

int main(int argc, char **argv)
{
	FILE	*fp;
	int	ac;
	commonInfo *cinf;

	for (ac = 1; ac < argc && argv[ac][0] == '-'; ac++) {
		switch (argv[ac][1]) {
		case 'v':
			verbose = 1;	break;
		case 'h':
			usage();
			return 1;
		default:
			fprintf(stderr, 
				"Warning: Unknown option: %s\n", argv[ac]);
			break;
		}
	}
	if (ac >= argc)
		fp = stdin;
	else {
		if ((fp = fopen(argv[ac], "r")) == NULL) {
			fprintf(stderr, "ERROR: Can't open %s\n", argv[ac]);
			return 1;
		}
	}
	cinf = pxoread(fp);
	if (cinf->palette)
		saveBmpWithPalette(stdout, cinf);
	else if (cinf->bits == 1)
		saveBmpFromPBM(stdout, cinf);
	else
		saveBmpbmap(stdout, cinf);
	freePxoInfo(cinf);
	(void)fclose(fp);
	return 0;
}
