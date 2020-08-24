/*
 * This is the DCT module, which implements Discrete Cosine Transform.
 * This code is based on the work of M. Nelson.
*/

#import  <stdio.h>
#import  <stdlib.h>
#import  <math.h>
#import  "DCTscaler.h"

@implementation DCTscaler

static void makeDCTmatrix(int sz, DCTmat C, DCTmat Ct)
{
	int	i, j;
	double	w1, w2;
	double pi = atan( 1.0 ) * 4.0;

	for (i = 0; i < DCTMAXSIZE; i++)
		for (j = 0; j < DCTMAXSIZE; j++)
			C[ i ][ j ] = Ct[ i ][ j ] = 0.0;

	w1 = 1.0 / sqrt( (double) sz );
	for (j = 0; j < sz; j++)
		C[ 0 ][ j ] = Ct[ j ][ 0 ] = w1;
	w1 = sqrt(2.0 / sz);
	w2 = 2.0 * sz;
	for (i = 1; i < sz; i++) {
		for (j = 0; j < sz; j++) {
			C[ i ][ j ] = Ct[ j ][ i ]
				= w1 * cos(pi * (2*j+1) * i / (w2));
		}
	}
}

- (id)init:(int)bsize :(int)asize	/*  bsize / asize  */
{
	[super init];
	if (asize <= 0 || bsize <= 0
		|| asize > 16 || bsize > 16 || asize == bsize)
		return nil;
	aSize = asize;
	bSize = bsize;
	makeDCTmatrix(aSize, Ca, Cat);
	makeDCTmatrix(bSize, Cb, Cbt);
	return self;
}

/*
 * The Forward DCT routine implements the matrix function:
 *
 *                     DCT = C * pixels * Ct
 *** LOCAL METHOD */

- (void) forwardDCT:(DCTmat)output from:(PIXmat)input
{
	DCTmat	temp;
	double	w;
	int i, j, k;

	for (i = 0; i < DCTMAXSIZE; i++)
		for (j = 0; j < DCTMAXSIZE; j++)
			output[ i ][ j ] = 0.0;
/*  MatrixMultiply( temp, input, Ct ); */
	for (i = 0; i < aSize; i++) {
	    for (j = 0; j < aSize; j++) {
		w = 0.0;
		for (k = 0; k < aSize; k++)
			w += ((int)input[ i ][ k ] - 128) * Cat[ k ][ j ];
		temp[ i ][ j ] = w;
	    }
	}

/*  MatrixMultiply( output, C, temp ); */
	for (i = 0; i < aSize; i++) {
	    for (j = 0; j < aSize; j++) {
		w = 0.0;
		for (k = 0; k < aSize; k++)
			w += Ca[ i ][ k ] * temp[ k ][ j ];
		output[ i ][ j ] = w;
	    }
	}
}

/*
 * The Inverse DCT routine implements the matrix function:
 *
 *                     pixels = C * DCT * Ct
 *** LOCAL METHOD */

- (void) inverseDCT:(PIXmat)output from:(DCTmat)input
{
	DCTmat	temp;
	double	w;
	int	i, j ,k;

/*  MatrixMultiply( temp, input, C ); */
	for (i = 0; i < bSize; i++) {
	    for (j = 0; j < bSize; j++) {
		w = 0.0;
		for (k = 0; k < bSize; k++)
			w += input[ i ][ k ] * Cb[ k ][ j ];
		temp[ i ][ j ] = w;
	    }
	}

/*  MatrixMultiply( output, Ct, temp ); */
	for (i = 0; i < bSize; i++) {
	    for (j = 0; j < bSize; j++) {
		w = 128.5;
		for (k = 0; k < bSize; k++)
		    w += Cbt[ i ][ k ] * temp[ k ][ j ];
		if (w <= 0)
		    output[ i ][ j ] = 0;
		else if (w > 255)
		    output[ i ][ j ] = 255;
		else
		    output[ i ][ j ] = (unsigned char)w;
	    }
	}
}

- (void)DCTrescale:(PIXmat)dst from:(PIXmat)src
{
	DCTmat	work;
	double	t;
	int	i, j;

	[self forwardDCT:work from:src];
	t = (double)bSize / (double)aSize;
	for (i = 0; i < bSize; i++)
		for (j = 0; j < bSize; j++)
			work[i][j] *= t;
	[self inverseDCT:dst from:work];
}

@end
