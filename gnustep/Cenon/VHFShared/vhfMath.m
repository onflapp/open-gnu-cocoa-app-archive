/*
 * vhf_math.m
 *
 * Copyright (C) 1993-2003 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *           Martin Dietterle
 *
 * created:  1993-06-27
 * modified: 1996-03-18 2002-07-15
 *
 * This file is part of the vhf Shared Library.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by the vhf interservice GmbH. Among other things,
 * the License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this library; see the file LICENSE. If not, write to vhf.
 *
 * If you want to link this library to your proprietary software,
 * or for other uses which are not covered by the definitions
 * laid down in the vhf Public License, vhf also offers a proprietary
 * license scheme. See the vhf internet pages or ask for details.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#include <Foundation/Foundation.h>
#include <math.h>
#include <stdio.h>
#include "vhfMath.h"
#include "types.h"

static int svSortAndFilterValues(double *array, int cnt);


/* created:  xx.06.93
 * modified: 16.07.93 18.03.96
 *
 * purpose:	 solve a polynomial of 2nd degree
 *		 a*x^2 + b*x + c = 0
 * parameter:	 a, b, c
 *		 pSolutions (array of solutions)
 * return value: number of solutions
 */
int svPolynomial2( double a, double b, double c, double *pSolutions)
{	double	d;

    if ( a == 0.0)
        /* 1st degree
        */
    {
        /* 0. degree
        */
        if ( b == 0.0)
            return(0);

        *pSolutions = -c / b;
        return(1);
    }

    d = b*b - 4.0*a*c;

    /* 2nd degree
        */
    if ( d > 0.0)
    {	double	sqrtD = sqrt(d);

        *pSolutions     = (-b+sqrtD) / (2.0*a);
        *(pSolutions+1) = (-b-sqrtD) / (2.0*a);
        return(svSortAndFilterValues( pSolutions, 2));
    }

    /* one solution
        */
    if ( d >= -0.0000001)
    {
        *pSolutions = (-b)/(2.0*a);
        return(1);
    }

    /* no real solution
        */
    return(0);
}

/* created:			xx.06.93
 * modified:		16.07.93 20.08.93 08.09.93
 *
 * purpose:			solve a polynomial of 3rd degree
 *					a*x^3 + b*x^2 + c*x + d = 0
 * parameter:		a, b, c, d
 *					pSolutions (array of solutions)
 * return value:	number of solutions
 */
int svPolynomial3( double a, double b, double c, double d, double *pSolutions)
{   double	x1, x, start[3], extremas[2];
    int		n, i, cnt=0, startCnt, extremaCnt;
    double	y=0, y1=0;	/* y, y' */

    if (a == 0.0)
        return( svPolynomial2( b, c, d, pSolutions));

    /* we know that this function has up to 3 solutions
        * we also know that these solutions are to the left and right of the extremas
        * 1. we get the extremas of the function and build some starting points for the
        *    Newton schema
        * 2. then we start the Newton schema with these values and collect the solutions
        */
    /* search the extremas to get the starting points
        * 3ax^2 + 2bx + c = 0
        */
    if (!(extremaCnt = svExtrema3(a, b, c, extremas)))
    {	start[0] = 0.5;
        startCnt = 1;
    }
    else if (extremaCnt == 1)
    {	start[0] = extremas[0] - 0.5;
        start[1] = extremas[0] + 0.5;
        startCnt = 2;
    }
    else
    {	start[0] = Min(extremas[0], extremas[1]) - 0.5;	/* left to 1st extrema */
        start[1] = (extremas[0] + extremas[1]) / 2.0;	/* between the two extremas */
        start[2] = Max(extremas[0], extremas[1]) + 0.5; /* right to 2nd extrema */
        startCnt = 3;
    }

    /* search the solutions using the Newton algorithm
     * y  = ax^3 + bx^2 + cx + d
     * y' = 3ax^2 + 2bx +c
     *
     * x(n+1) = x(n) - y / y'	for n = 1, 2, 3, 4, ...
     * if Abs(x(n+1) x(n)) < E	then y = x(n)
     */
    for (n=0; n<startCnt; n++)
    {
        x1 = start[n];
        x = x1 + 1.0;
        for (i=1; i<100 && Diff(x1, x)>0.000000001; i++)
        {
            x = x1;
            y  = a*x*x*x + b*x*x + c*x + d;
            y1 = 3.0*a*x*x + 2.0*b*x + c;
            /* when (y * y'') / (y' * y') becomes grater 1 then we have no approximation!
                */
            if (i>3 && (y * (6.0*a*x + 2.0*b)) / (y1*y1) > 1.0)	/* no solution */
                break;
            x1 = x - y / y1;
        }
        if (Diff(x1, x)>0.000000001 || Abs(y)>0.01)
            continue;

        /* each solution only once
        */
        for (i=0; i<cnt; i++)
            if (Diff(x1, pSolutions[i]) <= 0.000000001)
                break;
        if (i>=cnt)
            pSolutions[cnt++] = x1;
    }

    return cnt;
}

/* created:  15.07.93
 * modified: 16.07.93
 *
 * purpose:  calculate extrema of a function (2nd degree)
 *		a*x^2 + b*x + c
 *		2*a*x + b = 0
 * parameter:	a, b
 *		pSolutions (array of solutions)
 * return value: number of solutions (1)
 */
int svExtrema2( double a, double b, double *pSolutions)
{
    /* y' = 2ax + b
    */
    *pSolutions = (-b) / (2*a);

    return 1;
}

/* created:  15.07.93
 * modified: 16.07.93
 *
 * purpose:	calculate extrema of a function (3rd degree)
 *		a*x^3 + b*x^2 + c*x + d
 *		3ax^2 + 2bx + c = 0
 * parameter:	a, b, c
 *		pSolutions (array of solutions)
 * return value: number of solutions
 */
int svExtrema3( double a, double b, double c, double *pSolutions)
{
    if (a == 0.0)
        return( svExtrema2( b, c, pSolutions));

    /* y' = 3ax^2 + 2bx + c = 0
    */
    return svPolynomial2(3.0*a, 2.0*b, c, pSolutions);
}

/* created:  xx.06.93
 * modified: 14.03.96
 *
 * purpose: solve an equation of 3rd degree (Cramer)
 * example:
 *		2x1 -   x2 + 2x3 =  2
 *		 x1 + 10x2 - 3x3 =  5
 *		-x1 +   x2 +  x3 = -3
 *
 * 2 -1  2			  2 -1  2			  2  2  2			  2 -1  2
 * D =	 1 10 -3 = 46	D1 =  5 10 -3 = 92	D2 =  1  5 -3 = 0	D3 =  1 10  5 = -46
 * -1  1  1			 -3  1  1			 -1 -3  1			 -1  1 -3
 *
 * parameter:		m (matrix) [y][x]
 *			0 1 2
 *			1
 *			2
 *			aIn
 *			aOut (solutions)
 * literature:		Bruecken zur Mathematik, ISBN 824549, Band 2, page 29, page 36
 * return value:	YES on success
 */
char solveEquation3(double m[3][3], double aIn[3], double aOut[3])
{   double	d, d1, d2, d3;

    d =   m[0][0]*(m[1][1]*m[2][2] - m[1][2]*m[2][1]) - m[0][1]*(m[1][0]*m[2][2] - m[2][0]*m[1][2])
        + m[0][2]*(m[1][0]*m[2][1] - m[1][1]*m[2][0]);
    if (d == 0)
        return 0;

    d1 = aIn[0]*(m[1][1]*m[2][2] - m[1][2]*m[2][1]) - m[0][1]*(aIn[1]*m[2][2] - aIn[2]*m[1][2])
        + m[0][2]*(aIn[1]*m[2][1] - m[1][1]* aIn[2]);
    d2 = m[0][0]*(aIn[1]*m[2][2] - m[1][2]* aIn[2]) - aIn[0]*(m[1][0]*m[2][2] - m[2][0]*m[1][2])
        + m[0][2]*(m[1][0]* aIn[2] - aIn[1]*m[2][0]);
    d3 = m[0][0]*(m[1][1]* aIn[2] - aIn[1]*m[2][1]) - m[0][1]*(m[1][0]*aIn[2] - m[2][0]*aIn[1])
        +  aIn[0]*(m[1][0]*m[2][1] - m[1][1]*m[2][0]);

    aOut[0] = d1/d;
    aOut[1] = d2/d;
    aOut[2] = d3/d;

    return 1;
}

/* created:  04.04.96
 * modified: 
 *
 * purpose: solve an equation of n'th degree (Gauss)
 * example:
 *		  a -  b +   5c =   12  *(-3)  *(-10)
 *		 3a - 8b -    c =    9
 *		10a + 5b -   2c =    1
 *
 *		  a -  b +   5c =   12
 *		    - 5b -  16c =  -27  *(3)
 *			 15a -  52b = -119
 *
 *		  a -  b +   5c =   12
 *			- 5b -  16c =  -27
 *				 - 100c = -200
 *
 *		c = 2, b = -1, a = 1
 *
 * parameter: m (matrix) [y][x]
 *		0 1 2
 *		1
 *		2
 *		aIn
 *		aOut (solutions)
 *		degree (up to 6)
 * literature:   Bruecken zur Mathematik, ISBN 824549, Band 2, page 44 ff
 * return value: YES on success
 */
#define ExchangeDoubleValues(v1, v2)	{ double v; v=v1; v1=v2; v2=v; }
/* [0 0 1] < [0 2 9] -> YES
 */
static char arrayIsLessThanArray(double *m, double *n, int cnt)
{   int	i;

    for ( i=0; i<cnt && !m[i]; i++ )
        if ( !m[i] && n[i] )
            return YES;
    return NO;
}
/* leading zeros must come later in matrix
 *
 * 1 5 2
 * 0 3 1
 * 0 0 9
 */
void sortMatrix(double m[6][6], double aIn[6], int cnt)
{   int	i, j, n;

    for ( i=0; i<cnt-1; i++ )
        for ( j=i+1; j<cnt; j++ )
            if ( arrayIsLessThanArray(m[i], m[j], cnt) )
                {	for (n=0; n<cnt; n++)
                    ExchangeDoubleValues(m[i][n], m[j][n]);
                ExchangeDoubleValues(aIn[i], aIn[j]);
                }
}
void eliminate(double *m1, double *m2, double aIn, int cnt, double mul)
{	int	i;

    for (i=0; i<cnt; i++)
        m2[i] = m2[i]+m1[i]*mul;
}
void printMatrix(double m[6][6], double aIn[6], int cnt)
{	int	x, y;

    for (y=0; y<cnt; y++)
    {	for (x=0; x<cnt; x++)
        printf("%.4f ", m[y][x]);
        printf("= %.4f", aIn[y]);
        printf("\n");
    }
    printf("\n");
}
char solveEquationN(double m[6][6], double aIn[6], double aOut[6], int cnt)
{	int		x, y, e;

    //printf("1:\n"); printMatrix(m, aIn, cnt);
    sortMatrix(m, aIn, cnt);

    //printf("2:\n"); printMatrix(m, aIn, cnt);
    for (x=0; x<cnt-1; x++)
    {	for (y=x+1; y<cnt; y++)
    {	double mul = -m[y][x]/m[x][x];

        if (mul)	/* eliminate leading zeros */
        {	for (e=x; e<cnt; e++)
            m[y][e] = m[y][e]+m[x][e]*mul;
            aIn[y] = aIn[y] + aIn[x]*mul;
        }
    }
        sortMatrix(m, aIn, cnt);
    }

    //printf("3:\n"); printMatrix(m, aIn, cnt);
    for (y=cnt-1; y>=0; y--)
    {	double sum = 0.0;
        for (x=cnt-1; x>y; x--)
            sum += m[y][x]*aOut[x];
        if (m[y][y] == 0.0)
        {   NSLog(@"vhfMath, - solveEquationN: Division by zero!");
            return 0;
        }
        aOut[y] = (aIn[y]-sum) / m[y][y];
    }

    return 1;
}

/* leading zeros must come later in matrix
 *
 * 1 5 2
 * 0 3 1
 * 0 0 9
 */
void sortMatrixXY(double m[10][10], double *aIn, int yCnt, int xCnt)
{   int	i, j, n;

    for ( i=0; i<yCnt-1; i++ )
        for ( j=i+1; j<yCnt; j++ )
            if ( arrayIsLessThanArray(m[i], m[j], xCnt) )
            {	for (n=0; n<xCnt; n++)
                ExchangeDoubleValues(m[i][n], m[j][n]);
                ExchangeDoubleValues(aIn[i], aIn[j]);
            }
}
void printMatrixXY(double m[10][10], double *aIn, int yCnt, int xCnt)
{	int	x, y;

    for (y=0; y<yCnt; y++)
    {	for (x=0; x<xCnt; x++)
        printf("%.4f ", m[y][x]);
        printf("= %.4f", aIn[y]);
        printf("\n");
    }
    printf("\n");
}
char solveEquationNM(double m[10][10], double *aIn, double *aOut, int yCnt, int xCnt)
{	int		x, y, e;

    //printf("1:\n"); printMatrixXY(m, aIn, yCnt, xCnt);
    sortMatrixXY(m, aIn, yCnt, xCnt);

    //printf("2:\n"); printMatrixXY(m, aIn, yCnt, xCnt);
    for (x=0; x<xCnt-1; x++)
    {	for (y=x+1; y<yCnt; y++)
    {	double mul = -m[y][x]/m[x][x];

        if (mul)	/* eliminate leading zeros */
        {	for (e=x; e<xCnt; e++)
            m[y][e] = m[y][e]+m[x][e]*mul;
            aIn[y] = aIn[y] + aIn[x]*mul;
        }
    }
        sortMatrixXY(m, aIn, yCnt, xCnt);
    }

    //printf("3:\n"); printMatrixXY(m, aIn, yCnt, xCnt);

    /* approximate the 1st value from all additional entries
        */
    aOut[xCnt-1] = 0.0;
    for (y=yCnt-1, e=0; y>=xCnt-1; y--)
    {
        if (!m[y][xCnt-1])
            continue;
        aOut[xCnt-1] += aIn[y] / m[y][xCnt-1];
        e++;
    }
    aOut[xCnt-1] = aOut[xCnt-1] / e;

    for (y=xCnt-2; y>=0; y--)
    {	double sum = 0.0;
        for (x=xCnt-1; x>y; x--)
            sum += m[y][x]*aOut[x];
        if (m[y][y] == 0.0)
        {   NSLog(@"vhfMath, - solveEquationN: Division by zero!");
            return 0;
        }
        aOut[y] = (aIn[y]-sum) / m[y][y];
    }

    return 1;
}

/* created:  xx.06.93
 * modified: 11.07.93 20.08.93
 *
 * purpose:  sort values in 'array' upwards and filter multiple values
 *		we have a limit of 100 elements!!
 * parameter: array
 *		cnt (number of values)
 * return value: new number of values
 */
int svSortAndFilterValues(double *array, int cnt)
{   double	sort[100], last = MINCOORD;
    int		n1, n2, cntNeu = 0;

    for ( n1=0; n1<cnt; n1++ )
    {	double	min=MAXCOORD, *p1;

        for ( p1=array, n2=0; n2<cnt; n2++, p1++ )
        {	if ( *p1<min && *p1>last )
            min = *p1;
        }
        last = sort[n1] = min;
        if ( min < MAXCOORD )
            cntNeu++;
    }

    memcpy( array, sort, cntNeu* sizeof(double) );

    return(cntNeu);
}
