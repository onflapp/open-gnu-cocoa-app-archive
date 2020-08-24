/*
 * fastMath.c
 *
 * Copyright 1995-2000 by vhf computer GmbH
 * Author:   Georg Fleischmann
 *
 * created:  10.12.95
 * modified: 
 *
 */

#include <stdlib.h>
#include <math.h>

#include "types.h"
#include "fastMath.h"

/* select usage of fast or precise functions
 * 1 = fast (default)
 */
static int fast = 1;
void setFast(int flag)
{
    fast = flag;
}


/* atan
 */
static unsigned short *atanTab;
#define	FASTATANSIZE 2000
unsigned short *buildFastAtanTab(void)
{   int	i;

    if( !(atanTab = malloc((FASTATANSIZE+1)*sizeof(short))) )
        return NULL;
    for( i=0; i<=FASTATANSIZE; i++ )
        atanTab[i] = (unsigned short)(RadToDeg(atan((double)i/(double)FASTATANSIZE))*1000.0);
    return atanTab;
}
double fastAtan(double v)
{
    if(!fast)
        return RadToDeg(atan(v));

    if(!atanTab)
        buildFastAtanTab();
#if 0
    static test = 0;
    if(!test)
    {	double	f, s;

        test = 1;
        f = fastAtan(v);
        s = RadToDeg(atan(v));
        if(fabs(f-s)>0.01)
            printf("atan, v:%f f:%f s:%f\n", v, f, s);
        test = 0;
        return f;
    }
#endif

    if(v < 0.0)
    {	if(v < -1.0)
        return -(90.0 - (double)atanTab[(int)(1.0/-v*FASTATANSIZE)]/1000.0);
        return -(double)atanTab[(int)(-v*FASTATANSIZE)]/1000.0;
    }
    if(v > 1.0)
        return 90.0 - (double)atanTab[(int)(1.0/v*FASTATANSIZE)]/1000.0;
    return (double)atanTab[(int)(v*FASTATANSIZE)]/1000.0;
}


/* sin, cos
 */
#define	FASTSINSIZE 1800
#define	FASTSINDIV (FASTSINSIZE/90.0)
static short *sinTab;

/* table from 0 to 90 degree
 */
unsigned short *buildFastSinTab(void)
{   int	i;

    if( !(sinTab = malloc((FASTSINSIZE+1)*sizeof(short))) )
        return NULL;
    for( i=0; i<=FASTSINSIZE; i++ )
        sinTab[i] = (short)(sin(DegToRad((double)i/FASTSINDIV))*1000.0);
    return sinTab;
}
double fastSin(double a)
{
    if(!fast)
        return sin(DegToRad(a));

    if(!sinTab)
        buildFastSinTab();
#if 0
    static int test = 0;
    if(!test)
    {	double	f, s;

        test = 1;
        f = fastSin(a);
        s = sin(DegToRad(a));
        if(fabs(f-s)>0.01)
            printf("sin, a:%f f:%f s:%f\n", a, f, s);
        test = 0;
        return f;
    }
#endif

    while(a >= 360.0)	/* limit 360 degree */
        a -= 360.0;
    while(a <= -360.0)	/* limit -360 degree */
        a += 360.0;
    if(a > 180.0)	/* angle between -180 and + 180 degree */
        a = a - 360.0;
    if(a > 90.0)	/* upper/left quadrant = upper/right quadrant */
        a = 180 - a;
    else if(a < -90.0)	/* lower/left quadrant = lower/right quadrant */
        a = -180 - a;

    if(a >= 0)
        return (double)sinTab[(int)(a*FASTSINDIV)]/1000.0;
    return -(double)sinTab[(int)(-a*FASTSINDIV)]/1000.0;
}

double fastCos(double a)
{
    if(!fast)
        return cos(DegToRad(a));
    return fastSin(90.0 - a);
}
