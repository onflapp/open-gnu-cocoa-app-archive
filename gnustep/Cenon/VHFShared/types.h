/* types.h
 * vhf definitions
 *
 * Copyright (C) 1995-2013 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1995-09-06
 * modified: 2013-02-13 (define MAXFLOAT if not defined)
 *           2012-02-03 (V3Point, VLine use VFloat, VFloat = CGFloat)
 *           2012-01-20 (TOLERANCE_DEG added for angular comparisons)
 *           2008-02-23 (**PointMMToInternal() added)
 *
 * This file is part of the vhf Shared Library.
 *
 * This library is ee software; you can redistribute it and/or
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

#ifndef VHF_H_TYPES
#define VHF_H_TYPES

#include <Foundation/Foundation.h>	// NSPoint
#include <math.h>

#ifndef MAXFLOAT
#define MAXFLOAT	FLT_MAX
#endif

typedef struct _UPath   // DEPRECATED, do not used any more
{
    float 	*pts;
    int		num_pts;
    char	*ops;
    int		num_ops;
    int		maxElems;
} UPath;

/* 32 bit = float, 64 bit = double, VFloat is the same as CGFloat on Mac >= 10.5 or GNUstep */
#if    (defined(__APPLE__)            && defined(CGFLOAT_IS_DOUBLE) && CGFLOAT_IS_DOUBLE == 1) \
    || (defined(GNUSTEP_BASE_VERSION) && defined(CGFLOAT_IS_DBL)    && CGFLOAT_IS_DBL    == 1)
    typedef double VFloat;  // 64 bit
#   define VHF_IS_DOUBLE 1
#else
    typedef float  VFloat;  // 32 bit
#   define VHF_IS_DOUBLE 0
#endif

/* 3D point */
#ifndef V3Point
    typedef struct _V3Point
    {
        VFloat	x, y, z;
    }V3Point;

    static __inline__ V3Point V3MakePoint(VFloat x, VFloat y, VFloat z)
    {   V3Point	p;
        p.x = x; p.y = y; p.z = z;
        return p;
    }

    #define V3ZeroPoint()   V3MakePoint( 0.0, 0.0, 0.0 )
    #define SqrDistPoints3D(p1, p2) ( ((p1).x-(p2).x)*((p1).x-(p2).x) + \
                                      ((p1).y-(p2).y)*((p1).y-(p2).y) + \
                                      ((p1).z-(p2).z)*((p1).z-(p2).z) )
    #define V3PointInternalToMM(v3p) \
            V3MakePoint( InternalToMM((v3p).x), InternalToMM((v3p).y), InternalToMM((v3p).z) )
    #define V3PointMMToInternal(v3p) \
            V3MakePoint( MMToInternal((v3p).x), MMToInternal((v3p).y), MMToInternal((v3p).z) )
    #define NSPointInternalToMM(nsp) \
            NSMakePoint( InternalToMM((nsp).x), InternalToMM((nsp).y) )
    #define NSPointMMToInternal(nsp) \
            NSMakePoint( MMToInternal((nsp).x), MMToInternal((nsp).y) )
#endif

/* limits */
typedef struct _VHFLimits
{
    float	min, max;
} VHFLimits;
static __inline__ VHFLimits VHFMakeLimits(float min, float max)
{   VHFLimits	l;
    l.min = min; l.max = max;
    return l;
}

/* range */
typedef struct _VHFRange
{
    int	from, to;
} VHFRange;

/* line */
typedef struct _VHFLine
{
    NSPoint p0, p1;
} VHFLine;
static __inline__ VHFLine VHFMakeLine(VFloat x0, VFloat y0, VFloat x1, VFloat y1)
{   VHFLine	l;
    l.p0.x = x0; l.p0.y = y0; l.p1.x = x1; l.p1.y = y1;
    return l;
}
#define VHFZeroLine		VHFMakeLine (0.0, 0.0, 0.0, 0.0)

#define	Pi              3.14159265358979323846
#define SQRT2           1.41421356
#define FLOAT_TOL       0.00001			// the tolerance to compare floats
#define LARGE_COORD     99999.0			// large but not too large to square
#define LARGENEG_COORD  -99999.0		// large negative but not too large to square
#define MAXCOORD        3.40282347e+38f
#define MINCOORD        -1.17549435e+38f
#define IS_NAN(x)       ((x)!=(x))		// check for number = NAN
#ifndef MAXINT
    #define MAXINT      ((int)0x7fffffff)
#endif

#define FitAngle(a)         (((a)<0.0) ? ((a)+360.0) : (((a)>=360.0) ? ((a)-360.0) : (a)))
#define	Min(a,b)            (((a)<(b)) ? (a) : (b))		// return the smaller value
#define	Max(a,b)            (((a)>(b)) ? (a) : (b))		// returns the larger value
#define Limit(a,min,max)    Max(min, Min(a, max))
#define Limit1(a,l1,l2)     Max( Min(l1,l2), Min(a, Max(l1,l2)) )
#define	Diff(a,b)           (((a)>(b)) ? (a)-(b) : (b)-(a))	// returns the difference of the values
#define	Abs(a)              (((a)>=0) ? (a) : -(a))
#define	Sqr(a)              ((a)*(a))
#define DiffPoint(p1, p2)   ( Diff((p1).x, (p2).x) + Diff((p1).y, (p2).y) )	// difference of points
#define LineMiddlePoint(p1, p2, p)  { (p).x = Diff((p1).x, (p2).x)/2.0 + Min((p1).x, (p2).x); \
                                      (p).y = Diff((p1).y, (p2).y)/2.0 + Min((p1).y, (p2).y); }	// deprecated !
#define CenterPoint(p1, p2)     NSMakePoint( Diff((p1).x, (p2).x)/2.0 + Min((p1).x, (p2).x), \
                                             Diff((p1).y, (p2).y)/2.0 + Min((p1).y, (p2).y) )
#define CenterPoint3D(p1, p2)   V3MakePoint( Diff((p1).x, (p2).x)/2.0 + Min((p1).x, (p2).x), \
                                             Diff((p1).y, (p2).y)/2.0 + Min((p1).y, (p2).y), \
                                             Diff((p1).z, (p2).z)/2.0 + Min((p1).z, (p2).z) )
/* this one works with width/height == 0 */
#define VHFUnionRect(r1, r2)    NSMakeRect( Min((r1).origin.x, (r2).origin.x), \
                                            Min((r1).origin.y, (r2).origin.y), \
    Max((r1).origin.x+(r1).size.width,  (r2).origin.x+(r2).size.width)  - Min((r1).origin.x, (r2).origin.x), \
    Max((r1).origin.y+(r1).size.height, (r2).origin.y+(r2).size.height) - Min((r1).origin.y, (r2).origin.y) )

#define ExchangeInts(i1, i2)    { int _i; _i=(i1); (i1)=(i2); (i2)=_i; }
#define ExchangeFloats(f1, f2)  { float _f; _f=(f1); (f1)=(f2); (f2)=_f; }
#define ExchangePoints(p1, p2)  { NSPoint _p; _p=(p1); (p1)=(p2); (p2)=_p; }

#define ScaleValue(v, c, f)     (((v)-(c))*(f) + (c))
#define Even(v)                 (((v)%2) ? 0 : 1)
#define EnlargedRect(r, v)      NSMakeRect( (r).origin.x-(v), (r).origin.y-(v), \
                                            (r).size.width+2.0*(v), (r).size.height+2.0*(v) )

#define MMToInternal(v)         ((v)*72.0/25.4)	/* convert mm to internal unit */
#define InternalToMM(v)         ((v)*25.4/72.0)	/* convert internal unit to mm */
#define RectInternalToMM(r)     NSMakeRect( InternalToMM((r).origin.x),   InternalToMM((r).origin.y), \
                                            InternalToMM((r).size.width), InternalToMM((r).size.height) )
#define InchToMM(v)             ((v)/25.4)	/* convert inch to mm */
#define	PT                      1.0
#define INCH                    72.0
#define MM                      (INCH/25.4)

#define Sin(a)      sin(DegToRad(a))
#define Asin(a)     RadToDeg(asin(a))
#define Cos(a)      cos(DegToRad(a))
#define Acos(a)     RadToDeg(acos(a))
#define Tan(a)      tan(DegToRad(a))
#define Atan(a)     RadToDeg(atan(a))
#define Cot(a)      1.0/(Tan(a))
#define Acot(a)     Atan(1.0/(a))
#define DegToRad(a) ((a)*Pi/180.0)	// changes degree to rad
#define RadToDeg(a) ((a)*180.0/Pi)	// changes rad to degree

#define TOLERANCE       0.001       // tolerance for coordinates
#define TOLERANCE_DEG   0.0036      // tolerance for angles in degree (1/10000 deg)

typedef enum { LinkOnly = -1, DontLink = 0, Link = 1 } LinkType;

#ifndef BYTE
    #define BYTE    signed char     // Signed byte
    #define UBYTE   unsigned char   // Unsigned byte

    #ifdef NeXT
    #define WORD    short           // Signed word (16 bits)
    #define UWORD   unsigned short  // Unsigned word
    #else
    #define WORD    int             // Signed word (16 bits)
    #define UWORD   unsigned int    // Unsigned word
    #endif

    #define LONG    long            // Signed long (32 bits)
    #define ULONG   unsigned long   // Unsigned long

    #define BOOLEAN WORD            // 2 valued (true/false)

    #define FLOAT   float           // Single precision float
    #define DOUBLE  double          // Double precision float
#endif

#endif	// VHF_H_TYPES
