/* sub.c
 *	is based on pngtopnm(2.31) by A. Lehmann & W. van Schaik.
 */

#include <stdio.h>
#include <stdlib.h>
#include "png.h"
#include "png2pao.h"

void print_err(char *p)
{
	fprintf(stderr, "ERROR: %s\n", p);
	exit(1);
}


#define  TEXT_MAX_LEN	128
#define  TEXT_MAX_NUM	10

char *pickup_text(png_info *info_ptr)
{
	int i, k, key, tp, max;
	const char *p;
	short order[TEXT_MAX_NUM];
	static char buf[TEXT_MAX_LEN + 2];

	if (info_ptr->num_text == 0)
		return NULL;
	k = 0;
	if (info_ptr->num_text == 1
			&& strcmp(info_ptr->text[0].key, "Comment") == 0) {
		p = info_ptr->text[0].text;
		while ( *p && k < TEXT_MAX_LEN - 1 )
			buf[k++] = *p++;
		buf[k] = 0;
		return (k > 0) ? buf : NULL;
	}

	max = info_ptr->num_text;
	if (max > TEXT_MAX_NUM) max = TEXT_MAX_NUM;
	for (i = 0; i < max; i++) order[i] = i - 1;
	for (i = 0; i < info_ptr->num_text; i++)
		if (strcmp(info_ptr->text[i].key, "Title") == 0) {
			order[0] = i;
			if (i < TEXT_MAX_NUM-1) order[i+1] = -1;
			break;
		}
	for (i = 0; i < max; i++) {
		if ((tp = order[i]) < 0) continue;
		key = strlen(p = info_ptr->text[tp].key);
		if (k + key > TEXT_MAX_LEN - 4)
			break;
		if (k > 0) {
			buf[k++] = ';';
			buf[k++] = ' ';
		}
		while (*p)
			buf[k++] = *p++;
		buf[k++] = '=';
		p = info_ptr->text[tp].text;
		while (*p && k < TEXT_MAX_LEN - 1)
			buf[k++] = *p++;
	}
	buf[k] = 0;
	return buf;
}

void print_info(png_info *info_ptr)
{
	char *type_string;
	char *alpha_string;

	switch (info_ptr->color_type) {
	case PNG_COLOR_TYPE_GRAY:
		type_string = "gray";
		alpha_string = "";
		break;
	case PNG_COLOR_TYPE_GRAY_ALPHA:
		type_string = "gray";
		alpha_string = "+alpha";
		break;
	case PNG_COLOR_TYPE_PALETTE:
		type_string = "palette";
		alpha_string = "";
		break;
	case PNG_COLOR_TYPE_RGB:
		type_string = "truecolor";
		alpha_string = "";
		break;
	case PNG_COLOR_TYPE_RGB_ALPHA:
		type_string = "truecolor";
		alpha_string = "+alpha";
		break;
	default:
		type_string = "unknown";
		alpha_string = "";
		break;
	}
	if (info_ptr->valid & PNG_INFO_tRNS)
		alpha_string = "+transparency";

	fprintf(stderr, "reading a %d x %d image, %d bit%s %s%s",
		(int)(info_ptr->width), (int)(info_ptr->height),
		info_ptr->bit_depth, info_ptr->bit_depth>1 ? "s" : "",
		type_string, alpha_string);

	if (info_ptr->valid & PNG_INFO_gAMA)
		fprintf(stderr, ", image gamma = %4.2f", info_ptr->gamma);
	if (info_ptr->interlace_type)
		fprintf(stderr, ", Adam7 interlaced");
	fprintf(stderr, "\n");
}


png_byte **alloc_png_image(png_info *info_ptr)
	/* Alloc memory for PNG image.
	   png_image is an array of byte strings. */
{
	png_byte **png_image;
	int	y, linesize;

	png_image = (png_byte **)malloc(info_ptr->height * sizeof(png_byte*));
	if (png_image == NULL)
		return NULL;

	linesize = info_ptr->width;
	if (info_ptr->bit_depth == 16)
		linesize *= 2;
	if (info_ptr->color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
		linesize *= 2;
	else if (info_ptr->color_type == PNG_COLOR_TYPE_RGB)
		linesize *= 3;
	else if (info_ptr->color_type == PNG_COLOR_TYPE_RGB_ALPHA)
		linesize *= 4;

	for (y = 0 ; y < info_ptr->height ; y++) {
		png_image[y] = (png_byte *)malloc(linesize * sizeof(png_byte));
		if (png_image[y] == NULL)
			return NULL;
	}
	return png_image;
}


int is_palette_gray(png_info *info_ptr)
{
	int i;
	png_color *ccp;

	ccp = info_ptr->palette;
	for (i = 0; i < info_ptr->num_palette; i++, ccp++) {
		if (ccp->red != ccp->green || ccp->green != ccp->blue)
			return NO;
	}
	return YES;
}


  /* sBIT handling is a bit tricky. If we are extracting only the image, we
     can use the sBIT info for grayscale and color images, if the three
     values agree. If we extract the transparency/alpha mask, sBIT is
     irrelevant for trans and valid for alpha. If we mix both, the
     multiplication may result in values that require the normal bit depth,
     so we will use the sBIT info only for transparency, if we know that only
     solid and fully transparent is used */

int check_sbit(png_info *info_ptr, png_struct *png_ptr, int useback)
{
	int i, w, mval;

	if (useback) {
		if (info_ptr->color_type == PNG_COLOR_TYPE_RGB_ALPHA ||
		    info_ptr->color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
			return 0;
		if (info_ptr->color_type == PNG_COLOR_TYPE_PALETTE &&
				(info_ptr->valid & PNG_INFO_tRNS)) {
			png_bytep tr = info_ptr->trans;
			int trans_mix = YES;
			for (i = 0 ; i < info_ptr->num_trans ; i++)
				if (tr[i] != 0 && tr[i] != 255) {
					trans_mix = NO;
					break;
				}
			if (!trans_mix)
				return 0;	/* halftone trans */
		}
	} else if ((info_ptr->color_type == PNG_COLOR_TYPE_PALETTE ||
	     info_ptr->color_type == PNG_COLOR_TYPE_RGB ||
	     info_ptr->color_type == PNG_COLOR_TYPE_RGB_ALPHA) &&
	    (info_ptr->sig_bit.red != info_ptr->sig_bit.green ||
	     info_ptr->sig_bit.green != info_ptr->sig_bit.blue)) {
		fprintf(stderr,
			"WARN: different bit depths for color"
			"channels not supported.\n"
			"WARN: writing file with %dbit resolution.\n",
			info_ptr->bit_depth);
		return 0;
	}

	if (info_ptr->color_type == PNG_COLOR_TYPE_PALETTE) {
		w = 8 - info_ptr->sig_bit.red;
		for (i = 0; i < info_ptr->num_palette; i++) {
			info_ptr->palette[i].red   >>= w;
			info_ptr->palette[i].green >>= w;
			info_ptr->palette[i].blue  >>= w;
		}
   	} else
		png_set_shift(png_ptr, &(info_ptr->sig_bit));

	if (info_ptr->color_type == PNG_COLOR_TYPE_PALETTE ||
	    info_ptr->color_type == PNG_COLOR_TYPE_RGB ||
	    info_ptr->color_type == PNG_COLOR_TYPE_RGB_ALPHA)
		mval = (1L << info_ptr->sig_bit.red) - 1;
	else
		mval = (1L << info_ptr->sig_bit.gray) - 1;

	return mval;
}
