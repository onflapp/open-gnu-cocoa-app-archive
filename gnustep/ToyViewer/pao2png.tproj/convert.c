/*
	pao2png
		is based on tiff2png
		(C) 1996 by Willem van Schaik, Singapore

	Ver. 1.1   1997-11-23	For libpng 0.96 by Takeshi Ogihara
 */

#include  <stdio.h>
#include  <stdlib.h>
#include  "png.h"
#include  "pao2png.h"

static png_struct	*png_ptr;
static png_info		*info_ptr;
static png_color	palette[MAXCOLORS];
static int	colors = 0, transparent = -1, planes, depth;
static png_bytep	pool;
static png_bytepp	row_ptr;


void read_palette(FILE *fp, int cols, int transp)
{
	int i;

	colors = cols;	/* Palette */
	for (i = 0; i < colors; i++) {
		palette[i].red   = (png_byte)getc(fp);
		palette[i].green = (png_byte)getc(fp);
		palette[i].blue  = (png_byte)getc(fp);
	}
	if ((transparent = transp) > colors - 1 && i < MAXCOLORS) {
		colors++;
		palette[i].red   = 255;
		palette[i].green = 255;
		palette[i].blue  = 255;
	}
}


static int get_comment(char *comm, png_text *comm_pair)
{
	if (comm == NULL || *comm == 0 || comm_pair == NULL)
		return 0;
	while (*comm && (*comm == ' ' || *comm == ':')) comm++;
	if (*comm == 0)
		return 0;

	comm_pair[0].key = "Comment";
	comm_pair[0].text = comm;
	comm_pair[0].compression = PNG_TEXT_COMPRESSION_NONE;
	return 1;
}

void open_png(FILE *png, int cols, int rows, int mval, int pnum)
{
	int	color_type = 0; /* dummy: GRAY */
	void	*vp;
/* Bug of libpng, zlib, or compiler ... ???
   I can't do like:
	pool = (png_bytep)malloc(cols * rows * planes * sizeof(png_byte));
   After this, pool has "&pool" as its value... Why??
   The compiler is:
	NeXT Computer, Inc. version cc-478, gcc version 2.5.8
 */

	/* start PNG preparation */
	png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	info_ptr = png_create_info_struct(png_ptr);
	if (png_ptr == NULL || info_ptr == NULL) {
		fprintf(stderr, "Error: cannot allocate PNGLIB structures\n");
		exit(1);
	}

	if (pnum < 0 || pnum > 4) {
		fprintf(stderr, "Error: illegal format\n");
		exit(1);
	}
	if (pnum != 0) {
		planes = pnum;
		colors = 0;	/* Not Paletted Image */
	}else
		planes = 1;

	/* allocate space for png-image */
	vp = malloc(cols * rows * planes * sizeof(png_byte));
	pool = (png_bytep)vp;
	row_ptr = (png_bytepp)malloc(rows * sizeof(png_bytep));
	if (pool == NULL || row_ptr == NULL) {
		fprintf(stderr, "Error: cannot allocate memory block\n");
		exit(1);
	}

	if (setjmp(png_ptr->jmpbuf)) {
		close_png();
		fprintf (stderr, "Error: setjmp returns error condition\n");
		exit(1);
	}

	depth = (mval > 16) ? 8 : ((mval > 4) ? 4 : ((mval > 2) ? 2 : 1));
	if (verbose) {
		fprintf(stderr, " maxval = %d\n", mval);
		fprintf(stderr, " bit-depth = %d\n", depth);
		fprintf(stderr, " progressive = %s\n",
			(progressive != PNG_INTERLACE_NONE) ? "ON" : "OFF");
	}
	switch (pnum) {
	case 0:	/* Palette */
		if (verbose)
			fprintf(stderr, " color-type = paletted\n");
		color_type = PNG_COLOR_TYPE_PALETTE;
		break;
	case 1: /* Monochrome or Grayscale */
		if (verbose)
			fprintf(stderr, " color-type = grayscale(%d)\n", mval);
		color_type = PNG_COLOR_TYPE_GRAY;
		break;
	case 2: /* Monochrome or Grayscale with ALPHA */
		if (verbose)
		    fprintf(stderr,
		    	" color-type = grayscale(%d) + alpha\n", mval);
		color_type = PNG_COLOR_TYPE_GRAY_ALPHA;
		break;
	case 3: /* RGB 3 planes */
		if (verbose)
			fprintf(stderr, " color-type = truecolor\n");
		color_type = PNG_COLOR_TYPE_RGB;
		break;
	case 4: /* RGB 3 planes with ALPHA */
		if (verbose)
			fprintf(stderr, " color-type = truecolor + alpha\n");
		color_type = PNG_COLOR_TYPE_RGB_ALPHA;
		break;
	}

	png_init_io(png_ptr, png);
	png_set_IHDR(png_ptr, info_ptr, cols, rows, depth,
		color_type, progressive,
		PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);

	if (pnum == 0) { /* Palette */
		/* PLTE chunk */
		png_set_PLTE(png_ptr, info_ptr, palette, colors);
		if (transparent >= 0) {
			static png_byte buff[2];
			buff[0] = 0;	/* index of palette is 0 */
			png_set_tRNS(png_ptr, info_ptr, buff, 1, NULL);
		}
	}

	/* gAMA chunk */
	if (gamma_param != -1.0) {
		png_set_gAMA(png_ptr, info_ptr, gamma_param);
		if (verbose)
			fprintf(stderr, " gamma = %f\n", gamma_param);
	}
}

void close_png(void)
{
	png_destroy_write_struct(&png_ptr,  (png_infopp)NULL);
	free((void *)pool);
	free((void *)row_ptr);
}

void write_png(FILE *fp, char *comm)
{
	int trflag = 0, npix, total;
	int i, w;
	png_bytep	pp;
	unsigned char tmap[256];
	static png_text	comm_pair[2];
	static const unsigned char elmtwo[4] = { 0, 0x55, 0xaa, 0xff };
	static const unsigned char elmfour[16] = {
		0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
		0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff };

	if (colors > 0 && transparent > 0) {
		png_color temp;
		trflag = 1;
		for (i = 0; i < 256; i++) tmap[i] = i;
		tmap[0] = transparent;	/* index of palette is 0 */
		tmap[transparent] = 0;
		temp = palette[0];
		palette[0] = palette[transparent];
		palette[transparent] = temp;
	}

	png_write_info(png_ptr, info_ptr);
	png_set_packing(png_ptr);

	npix = planes * info_ptr->width;
	total = npix * info_ptr->height;
	pp = pool;
	for (i = 0; i < info_ptr->height; i++) {
		row_ptr[i] = pp;
		pp += npix;
	}
	pp = pool;
	if (trflag) {
		for (i = 0; i < total; i++)
			*pp++ = tmap[ getc(fp) & 0xff ];
	}else if (colors > 0 /* palette index */ || depth == 8) {
		/* depth == 8  or  paletted without trans */
		/* or paletted with trans index 0 */
		for (i = 0; i < total; i++)
			*pp++ = getc(fp);
	}else
		switch (depth) {
		case 1:
			for (i = 0; i < total; i++)
				*pp++ = getc(fp) ? 0xff : 0;
			break;
		case 2:
			for (i = 0; i < total; i++)
				*pp++ = elmtwo[getc(fp) & 0x03];
			break;
		case 4:
			for (i = 0; i < total; i++)
				*pp++ = elmfour[getc(fp) & 0x0f];
			break;
		}
	png_write_image(png_ptr, row_ptr);

	/* Comments */
	if ((w = get_comment(comm, comm_pair)) > 0) {
		png_set_text(png_ptr, info_ptr, comm_pair, w);
		if (verbose) {
			for (i = 0; i < w; i++)
				fprintf(stderr, " %s = %s\n",
					comm_pair[i].key, comm_pair[i].text);
		}
	}
	png_write_end(png_ptr, info_ptr);
}
