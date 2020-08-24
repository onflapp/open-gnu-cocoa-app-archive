/* png2pao.c
 *	is based on pngtopnm(2.31) by A. Lehmann & W. van Schaik.
 *	Ver. 1.1   1997-11-23	For libpng 0.96 by Takeshi Ogihara
 *	Ver. 1.2   1997-12-21	convert to also PXO
 */

/*
** pngtopnm.c -
** read a Portable Network Graphics file and produce a portable anymap
**
** Copyright (C) 1995,1996 by Alexander Lehmann <alex@hal.rhein-main.de>
**                        and Willem van Schaik <gwillem@ntuvax.ntu.ac.sg>
**
** version 2.31 - July 1996
**
** Permission to use, copy, modify, and distribute this software and its
** documentation for any purpose and without fee is hereby granted, provided
** that the above copyright notice appear in all copies and that both that
** copyright notice and this permission notice appear in supporting
** documentation.  This software is provided "as is" without express or
** implied warranty.
**
** modeled after giftopnm by David Koblas and
** with lots of bits pasted from pnglib.txt by Guy Eric Schalnat
*/

/* pnglib forgot gamma correction for palette images, so we do it ourselves */

#include <stdio.h>
#include <stdlib.h>
#include "png.h"
#include "png2pao.h"


/* Local Data */
enum paoformat { pNONE, pPGM, pPPM, pPXO, aPGM, aPPM, aPXO };

static png_uint_16 maxval;
static png_uint_16 bgr, bgg, bgb; /* background colors */
static int gray_palette = NO;
static int has_alpha = NO;

#define PNG_TRANS	0
#define PNG_OPAQUE	maxval
#define INVERT_ALPHA(a)	(maxval - (a))

#define get_png_val(p) _get_png_val (&(p), info_ptr->bit_depth)

static png_uint_16 _get_png_val(png_byte **pp, int bit_depth)
{
	png_uint_16 c = 0;

	if (bit_depth == 16)
		c = (*((*pp)++)) << 8;
	return (c | (*((*pp)++)));
}

static void store_cpixel(png_uint_16 r, png_uint_16 g, png_uint_16 b, png_uint_16 a)
{
	if (!has_alpha) {
		if (a == PNG_TRANS) {
			r = bgr;
			g = bgg;
			b = bgb;
		}else if (a != PNG_OPAQUE) {
			double alp = (double)a / maxval;  /* PNG_TRANS = 0 */
			double bck = 1.0 - alp;
			r = r * alp + bck * bgr;
			g = g * alp + bck * bgg;
			b = b * alp + bck * bgb;
		}
	}
	putchar(r);
	putchar(g);
	putchar(b);
	if (has_alpha)
		putchar(a);
}

static void store_gpixel(png_uint_16 g, png_uint_16 a)
{
	if (!has_alpha) {
		if (a == PNG_TRANS)
			g = bgg;
		else if (a != PNG_OPAQUE) {
			double alp = (double)a / maxval;  /* PNG_TRANS = maxval */
			g = g * alp + (1.0 - alp) * bgg;
		}
	}
	putchar(g);
	if (has_alpha)
		putchar(a);
}

static int set_background(png_info *info_ptr)
  /* didn't manage to get pnglib to work (bugs?) concerning background */
  /* processing, therefore we do our own using bgr, bgg and bgb        */
{
    if (info_ptr->valid & PNG_INFO_bKGD) {
	switch (info_ptr->color_type) {
	case PNG_COLOR_TYPE_GRAY:
	case PNG_COLOR_TYPE_GRAY_ALPHA:
		bgr = bgg = bgb = info_ptr->background.gray;
		break;
	case PNG_COLOR_TYPE_PALETTE:
		bgr = info_ptr->palette[info_ptr->background.index].red;
		bgg = info_ptr->palette[info_ptr->background.index].green;
		bgb = info_ptr->palette[info_ptr->background.index].blue;
		break;
	case PNG_COLOR_TYPE_RGB:
	case PNG_COLOR_TYPE_RGB_ALPHA:
		bgr = info_ptr->background.red;
		bgg = info_ptr->background.green;
		bgb = info_ptr->background.blue;
		break;
	}
	return YES;
    }
    bgr = bgg = bgb = 0;
    return NO;
}


static enum paoformat get_paoformat(png_info *info_ptr)
{
	enum paoformat ptype = pNONE;
	int trans = !useBackground && (info_ptr->valid & PNG_INFO_tRNS);

	switch (info_ptr->color_type) {
	case PNG_COLOR_TYPE_GRAY:
		ptype = trans ? aPGM : pPGM;
		break;
	case PNG_COLOR_TYPE_GRAY_ALPHA:
		ptype = aPGM;
		break;
	case PNG_COLOR_TYPE_PALETTE:
		gray_palette = is_palette_gray(info_ptr);
		if (gray_palette)
			ptype = trans ? aPGM : pPGM;
		else if (info_ptr->num_palette <= 256 && usePXO)
			ptype = trans ? aPXO : pPXO;
		else
			ptype = trans ? aPPM : pPPM;
		break;
	case PNG_COLOR_TYPE_RGB:
		ptype = trans ? aPPM : pPPM;
		break;
        case PNG_COLOR_TYPE_RGB_ALPHA:
		ptype = aPPM;
		break;
	default:
		print_err("unknown PNG color type");
		break;
	}
	return ptype;
}


static void init_ppm(png_info *info_ptr, enum paoformat pao_type, char *comm)
{
	const char *tp;

	if (pao_type == pPGM)		tp = "P5";
	else if (pao_type == pPPM)	tp = "P6";
	else if (pao_type == pPXO || pao_type == aPXO)	tp = "PX";
	else				tp = "PA";
	printf("%s\n", tp);
	if (comm || info_ptr->interlace_type) {
		putchar('#');
		if (pao_type == pPXO || pao_type == aPXO)
			printf(" Palette");
		if (info_ptr->interlace_type)
			printf(" Interlace");
	/***	if (pao_type == aPGM || pao_type == aPPM || pao_type == aPXO)
			printf(" Alpha");	***/
		if (comm && *comm)
			printf(" : %s", comm);
		putchar('\n');
	}
	printf("%d %d\n", (int)(info_ptr->width), (int)(info_ptr->height));
	has_alpha = NO;
	if (pao_type == aPXO)
		printf("%d 1 %d\n", info_ptr->num_palette - 1,
			info_ptr->num_trans + 255);
	else if (pao_type == pPXO)
		printf("%d 0\n", info_ptr->num_palette - 1);
	else { /* PPM or PAO */
		printf("%d\n", (1 << info_ptr->bit_depth) - 1);
		if (pao_type == aPGM || pao_type == aPPM) { /* PAO */
			has_alpha = YES;
			if (pao_type == aPGM)
				printf("2\n");
			else /* if (pao_type == aPPM) */
				printf("4\n");
		}
	}
}


static void write_pixels(png_info *info_ptr, png_byte **png_image, enum paoformat pao_type)
{
	png_byte *png_pixel;
	int x, y;
	png_uint_16 c, c2, c3, a;
	png_colorp	pal;
	int trans = (info_ptr->valid & PNG_INFO_tRNS);

	switch (info_ptr->color_type) {
	case PNG_COLOR_TYPE_GRAY:
	    for (y = 0 ; y < info_ptr->height ; y++) {
		png_pixel = png_image[y];
		for (x = 0 ; x < info_ptr->width ; x++) {
			c = get_png_val(png_pixel);
			a = (trans && c == info_ptr->trans_values.gray) ?
				PNG_TRANS : PNG_OPAQUE;
			store_gpixel(c, a);
		}
	    }
	    break;

	case PNG_COLOR_TYPE_GRAY_ALPHA:
	    for (y = 0 ; y < info_ptr->height ; y++) {
		png_pixel = png_image[y];
		for (x = 0 ; x < info_ptr->width ; x++) {
			c = get_png_val(png_pixel);
			a = get_png_val(png_pixel);
			store_gpixel(c, a);
		}
	    }
	    break;

	case PNG_COLOR_TYPE_PALETTE:
	    pal = info_ptr->palette;
	    if (pao_type == aPXO || pao_type == pPXO) {
		int	i;
		for (i = 0; i < info_ptr->num_palette; i++) {
		    putchar(pal[i].red);
		    putchar(pal[i].green);
		    putchar(pal[i].blue);
		}
		for (y = 0 ; y < info_ptr->height ; y++) {
		    png_pixel = png_image[y];
		    for (x = 0 ; x < info_ptr->width ; x++) {
			c = get_png_val(png_pixel);
			putchar(c);
		    }
		}
	    }else if (gray_palette) {
		for (y = 0 ; y < info_ptr->height ; y++) {
		    png_pixel = png_image[y];
		    for (x = 0 ; x < info_ptr->width ; x++) {
			    c = get_png_val(png_pixel);
			    a = (trans && c < info_ptr->num_trans)
				    ? info_ptr->trans[c] : PNG_OPAQUE;
			    store_gpixel(pal[c].red, a);
		    }
		}
	    }else {
		for (y = 0 ; y < info_ptr->height ; y++) {
		    png_pixel = png_image[y];
		    for (x = 0 ; x < info_ptr->width ; x++) {
			    c = get_png_val(png_pixel);
			    a = (trans && c < info_ptr->num_trans)
				    ? info_ptr->trans[c] : PNG_OPAQUE;
			    store_cpixel(pal[c].red, pal[c].green, pal[c].blue, a);
		    }
		}
	    }
	    break;

	case PNG_COLOR_TYPE_RGB:
	    for (y = 0 ; y < info_ptr->height ; y++) {
		png_pixel = png_image[y];
		for (x = 0 ; x < info_ptr->width ; x++) {
			c = get_png_val(png_pixel);
			c2 = get_png_val(png_pixel);
			c3 = get_png_val(png_pixel);
			a = (trans &&
			    c  == info_ptr->trans_values.red &&
			    c2 == info_ptr->trans_values.green &&
			    c3 == info_ptr->trans_values.blue)
			    ? PNG_TRANS : PNG_OPAQUE;
			store_cpixel(c, c2, c3, a);
		}
	    }
	    break;

        case PNG_COLOR_TYPE_RGB_ALPHA:
	    for (y = 0 ; y < info_ptr->height ; y++) {
		png_pixel = png_image[y];
		for (x = 0 ; x < info_ptr->width ; x++) {
			c = get_png_val(png_pixel);
			c2 = get_png_val(png_pixel);
			c3 = get_png_val(png_pixel);
			a = get_png_val(png_pixel);
			store_cpixel(c, c2, c3, a);
		}
	    }
	    break;

	default:
/*	    print_err("unknown PNG color type"); */
	    break;
	}
}


void convertpng(FILE *ifp)
{
	png_struct *png_ptr;
	png_info *info_ptr;
	png_byte **png_image;
	png_color_8p sig_bit;
	char *comm;
	enum paoformat	pao_type = pNONE;

	/* Alloc info blocks used generally by pnglib */
	png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if (png_ptr == NULL)
		print_err("Cannot allocate PNGLIB structures");
	info_ptr = png_create_info_struct(png_ptr);
	if (info_ptr == NULL)
		print_err("Cannot allocate PNGLIB structures");

	/* Emergency Exit */
	if (setjmp(png_ptr->jmpbuf)) {
		png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
		print_err("setjmp returns error condition");
	}

	/* Initialize */
	png_init_io(png_ptr, ifp);
	png_read_info(png_ptr, info_ptr);
	if (verbose)
		print_info(info_ptr);

	/* Alloc memory for PNG image */
	if ((png_image = alloc_png_image(info_ptr)) == NULL)
		print_err("couldn't alloc space for image");

	if (info_ptr->bit_depth < 8) {
		png_set_packing(png_ptr);
		if (png_get_sBIT(png_ptr, info_ptr, &sig_bit))
			png_set_shift(png_ptr, sig_bit);
	}else if (info_ptr->bit_depth == 16)
		png_set_strip_16(png_ptr);

	maxval = (info_ptr->color_type == PNG_COLOR_TYPE_PALETTE)
		? 255 : ((1L << info_ptr->bit_depth) - 1);

	if (useBackground)
		useBackground = set_background(info_ptr);

	if (info_ptr->valid & PNG_INFO_sBIT) {
		int w = check_sbit(info_ptr, png_ptr, useBackground);
		if (w) maxval = w;
	}

	if (displaygamma != -1.0) {
		if (info_ptr->valid & PNG_INFO_gAMA) {
			png_set_gamma(png_ptr, displaygamma, info_ptr->gamma);
			if (verbose)
				fprintf(stderr, "image gamma is %4.2f,"
					"converted for display gamma of %4.2f",
					info_ptr->gamma, displaygamma);
		} else {
			png_set_gamma(png_ptr, displaygamma, 1.0);
			if (verbose)
				fprintf(stderr, "image gamma assumed 1.0,"
					"converted for display gamma of %4.2f",
					displaygamma);
		}
	}

	png_read_image(png_ptr, png_image);
	png_read_end(png_ptr, info_ptr);

	comm = pickup_text(info_ptr);

	if (info_ptr->valid & PNG_INFO_pHYs) {
		float r;
		r = (float)info_ptr->x_pixels_per_unit
			/ info_ptr->y_pixels_per_unit;
		if (r != 1.0)
			fprintf(stderr, "WARN: Non-square pixels(%4.2f)\n", r);
	}

	pao_type = get_paoformat(info_ptr);
	init_ppm(info_ptr, pao_type, comm);
	write_pixels(info_ptr, png_image, pao_type);

	png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
}

