/*
    ras2pxo  --- SUN Rasterfile --> PXO file
    Ver. 1.0   2001.05.12   By OGIHARA Takeshi
  ---------------------------
    Original ...
    SUNLBP  --- SUN rasterfile print out filter
    Ver. 1.0   1988-12-21  by T.Ogihara
    Ver. 1.5   1990-03-30   for LaserShot
*/

#include  <stdio.h>
#include  <string.h>
#include  "rasterfile.h"
#include  "ras2pxo.h"

static void usage(const char *toolname)
{
	fprintf(stderr, "ras2pxo (2001.05.12)\n");
	fprintf(stderr, "Usage: %s [-info] [--] [raster_file]\n", toolname);
	fprintf(stderr, "\t-info   display image information\n");
	fprintf(stderr, "\t--      shows that next arg is a filename\n");
}

static void displayInfo(const rasinfo *ras)
{
	static char *types[] = {
		"Raw pixrect OLD", "Raw pixrect", "Run-length compression"
	};
	static char *mtypes[] = {
		"NONE", "EQUAL_RGB", "RAW"
	};

	printf("SUN Rasterfile ");
	if (ras->ras_type > 2)
		printf("Type %d\n", ras->ras_type);
	else
		printf("%s\n", types[ras->ras_type]);
	printf("Size: %d x %d\n", ras->ras_width, ras->ras_height);
	printf("Depth: %d", ras->ras_depth);
	if (isGray(ras))
		printf(" (gray)");
	putchar('\n');
	printf("Length: %ld\n", ras->ras_length);
	printf("MapType: ");
	if (ras->ras_maptype > 2)
		printf("Unknown(%d)\n", ras->ras_maptype);
	else
		printf("%s\n", mtypes[ras->ras_maptype]);
	printf("MapLength: %d\n", ras->ras_maplength);
	if (ras->ras_maplength > 0) {
		int  num, i;
		const unsigned char *p;
		printf("Palette:\n");
		num = ras->ras_maplength / 3;
		for (i = 0; i < num; i++) {
			p = ras->palette[i];
			printf("%3d[%02x %02x %02x]", i, p[0], p[1], p[2]);
			if ((i & 0x03) == 0x03)
			    putchar('\n');
			else
			    printf("  ");
		}
	}
}

int main(int argc, char **argv)
{
	FILE *fp;
	rasinfo *ras = NULL;
	int	ac, err = 0;
	int	infoflag = 0;

	for (ac = 1; ac < argc && argv[ac][0] == '-'; ac++) {
		if (strncmp(&argv[ac][1], "info", 4) == 0)
			infoflag = 1;
		else if (argv[ac][1] == '-') {
			ac++;	/* Last Option */
			break;
		}else {
			if (argv[ac][1] != 'h')
				fprintf(stderr, 
				"Warning: Unknown option: %s\n", argv[ac]);
			usage(argv[0]);
			return 1;
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
	if ((ras = loadRasterHeader(fp, &err)) == NULL) {
		fprintf(stderr, "ERROR: Illegal format: %s\n", argv[ac]);
		(void)fclose(fp);
		return 1;
	}
	if (infoflag) {	/* Display info. of the image file */
		displayInfo(ras);
	}else {
		switch (ras->ras_depth) {
		case 1:
			err = raster_to_pbm(ras, fp, stdout);
			break;
		case 8:
			if (isGray(ras))
				err = raster_to_pgm(ras, fp, stdout);
			else
				err = raster_to_pxo(ras, fp, stdout);
			break;
		case 24:
			err = raster_to_ppm(ras, fp, stdout);
			break;
		default:
			fprintf(stderr,
				"ERROR: Unknown depth: %d\n", ras->ras_depth);
			err = 1;
			break;
		}
	}
	freeRasterHeader(ras);
	(void)fclose(fp);
	return err;
}
