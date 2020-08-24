/*
	pao2png
		coded by Takeshi Ogihara
	-----------------------------------------------
	pao2png  Ver. 1.1  1997-12-26  by T.Ogihara
	pao2png  Ver. 1.2  2002-01-25  by T.Ogihara
 */

#include  <stdio.h>
#include  <stdlib.h>
#include  "/usr/include/png.h"
#include  "pao2png.h"

int verbose = NO;
int progressive = PNG_INTERLACE_NONE;
float gamma_param = -1.0;


static void print_usage(char *path)
{
	int b, x;

	for (b = 0, x = 0; path[x]; x++)
		if (path[x] == '/') b = x + 1;
	fprintf(stderr,
		"Usage: %s [-v] [-g value] [-p] [input-file]\n", &path[b]);
	exit(1);
}


int main(int argc, char *argv[])
{
	int argn;

	for (argn = 1; argn < argc; argn++) {
		if (argv[argn][0] != '-' || argv[argn][1] == '\0')
			break;
		switch (argv[argn][1]) {
		case 'g':	/* gamma */
			if (++argn < argc)
				sscanf(argv[argn], "%f", &gamma_param);
			else
				print_usage(argv[0]);
			break;
		case 'p':	/* progressive */
			progressive = PNG_INTERLACE_ADAM7;
			break;
		case 'v':	/* verbose */
			verbose = YES;
			break;
		default:
			print_usage(argv[0]);
			break;
		}
	}
	if (argn != argc && argv[argn][0] != '-') {
		if (freopen(argv[argn], "r", stdin) == NULL) {
			fprintf(stderr, "ERROR: Can't open: %s\n", argv[argn]);
			return 1;
		}
		++argn;
	}
	if (argn != argc)
		print_usage(argv[0]);

	paoread(stdin, stdout);

	return 0;
}
