/*
 *  dcttable.h
 *  ToyViewer
 *
 *  Created by OGIHARA Takeshi on Thu Jan 31 2002.
 *  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
 *
 */

#define  DCTMAXSIZE	20

typedef struct {
	float	r;
	unsigned char	b, a;
	unsigned char	thumb;
} DCT_ratioCell;

extern const DCT_ratioCell DCT_ratioTable[];

int DCT_TableIndex(int x, float ratio);
int DCT_TableIndexForThumb(float ratio);
