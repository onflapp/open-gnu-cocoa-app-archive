/* VCurveFit.h - Objective-C Frontend for curve fitting code
 *
 * Author:   Georg Fleischmann
 *
 * created:  2011-04-05 (based on CurveFit.c from Graphics Gems)
 * modified: 2011-04-05
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by vhf interservice GmbH. Among other things, the
 * License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this program; see the file LICENSE. If not, write to vhf.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

/* Piecewise cubic fitting code
 *
 * An Algorithm for Automatically Fitting Digitized Curves
 * by Philip J. Schneider
 * from "Graphics Gems", Academic Press, 1990
 */

#include <Foundation/Foundation.h>
#include "VCurveFit.h"
#include "VLine.h"
#include "VCurve.h"
#include "VPolyLine.h"
//#include <stdio.h>
//#include <malloc.h>
#include <math.h>

/* 2d point */
typedef struct Point2Struct
{
	double x, y;
} Point2;
typedef Point2 Vector2;
typedef Point2 *BezierCurve;

/* Forward declarations */
void                FitCurve();
static	int         FitCubic();
static	double		*Reparameterize();
static	double		NewtonRaphsonRootFind();
static	Point2		BezierII();
static	double 		B0(double u), B1(double u), B2(double u), B3(double u);
static	Vector2		ComputeLeftTangent();
static	Vector2		ComputeRightTangent();
static	Vector2		ComputeCenterTangent();
static	double		ComputeMaxError();
static	double		*ChordLengthParameterize();
static	BezierCurve	GenerateBezier();
static	Vector2		V2AddII();
static	Vector2		V2ScaleIII(Vector2 v, double s);
static	Vector2		V2SubII();

#define RECURSION_LIMIT             200
#define ERR_NONE                    0
#define ERR_LAST_FIRST_INVERSION    -1
#define ERR_EXCESSIVE_RECURSION     -2


@interface VCurveFit(PrivateMethods)
@end

@implementation VCurveFit

+ (VCurveFit*)sharedInstance
{   static VCurveFit    *sharedInstance = nil;

    if (!sharedInstance)
        sharedInstance = [self new];
    return sharedInstance;
}

/* turn lines into optimized curves
 */
- (VPath*)fitGraphic:(VGraphic*)g maxError:(double)maxError
{   Point2  *pts = nil;
    int     i, nPts = 0;
    VPath   *path = nil;

    cList = [NSMutableArray array];

    /* Path: we expect a path with lines only ! */
    if ( [g isKindOfClass:[VPath class]] )
    {   NSArray *list = [(VPath*)g list];
        NSPoint p1 = NSZeroPoint;

        pts = NSZoneMalloc((NSZone *)[self zone], [list count] * 2 * sizeof(Point2));

        for ( i=0; i<[list count]; i++ )
        {   VLine   *line = [list objectAtIndex:i];
            NSPoint p0 = [line pointWithNum:0];

            /* new sub-path (new start is not connected to last end) */
            if ( nPts > 1 && Diff(p1.x, p0.x) + Diff(p1.y, p0.y) > 15*TOLERANCE )
            {
                pts[nPts++] = pts[0];           // close path
                FitCurve(pts, nPts, maxError);
                nPts = 0;
            }
            p1 = [line pointWithNum:MAXINT];    // end point of line for sub-path test

            pts[nPts].x = p0.x;
            pts[nPts].y = p0.y;
            nPts ++;
        }
        if ( nPts > 1 )
             FitCurve(pts, nPts, maxError);
    }
    /* PolyLine */
    else if ( [g isKindOfClass:[VPolyLine class]] )
    {
        // TODO: VCurveFit should handle VPolyLine
        NSLog(@"TODO, VCurveFit: PolyLines not implemented yet");
        cList = nil;
        return nil;
    }
    else
    {
        NSLog(@"VCurveFit doesn't handle this kind of graphics %@", g);
        cList = nil;
        return nil;
    }

    if ( pts )
    {   NSZoneFree((NSZone *)[self zone], pts);
        path = [VPath path];
        [path setList:cList];
        cList = nil;
    }
    return path;
}

- (NSMutableArray*)list
{
    return cList;
}

- (void)dealloc
{
    [super dealloc];
}

@end


/*
 * n        degree (3)
 * curve    curve pts
 */
void OutputBezierCurve(int n, BezierCurve crv)
{   NSMutableArray  *list = [[VCurveFit sharedInstance] list];
    VCurve          *curve;
    NSPoint         p0, p1, p2, p3;

    p0.x = crv[0].x; p0.y = crv[0].y;
    p1.x = crv[1].x; p1.y = crv[1].y;
    p2.x = crv[2].x; p2.y = crv[2].y;
    p3.x = crv[3].x; p3.y = crv[3].y;
    curve = [VCurve curveWithPoints:p0 :p1 :p2 :p3];
    [list addObject:curve];
}

#if 0   // TESTMODE
/* main:
 * Example of how to use the curve-fitting code. Given an array
 * of points and a tolerance (squared error between points and 
 * fitted curve), the algorithm will generate a piecewise
 * cubic Bezier representation that approximates the points.
 * When a cubic is generated, the routine "OutputBezierCurve"
 * is called, which outputs the Bezier curve just created
 * (arguments are the degree and the control points, respectively).
 * Users will have to implement this function themselves 	
 * ascii output, etc. 
 */
main()
{   static Point2 d[7] = {      // Digitized points
	{ 0.0, 0.0 },
	{ 0.0, 0.5 },
	{ 1.1, 1.4 },
	{ 2.1, 1.6 },
	{ 3.2, 1.1 },
	{ 4.0, 0.2 },
	{ 4.0, 0.0 },
    };
    double	error = 4.0;        // Squared error

    FitCurve(d, 7, error);      // Fit the Bezier curves
}
#endif  // TESTMODE


/* Stuff from GGVec.c
 */
static double V2DistanceBetween2Points(Point2 a, Point2 b)
{   double dx = a.x - b.x;
    double dy = a.y - b.y;

    return(sqrt((dx*dx)+(dy*dy)));
}
/* returns squared length of input vector */	
static double V2SquaredLength(Vector2 *a)
{	return((a->x * a->x)+(a->y * a->y));
}
/* returns length of input vector */
static double V2Length(Vector2 *a)
{
	return(sqrt(V2SquaredLength(a)));
}
/* negates the input vector and returns it */
static Vector2 *V2Negate(Vector2 *v)
{
	v->x = -v->x;  v->y = -v->y;
	return(v);
}
/* scales the input vector to the new length and returns it */
static Vector2 *V2Scale(Vector2 *v, double newlen)
{   double len = V2Length(v);

	if (len != 0.0) { v->x *= newlen/len;   v->y *= newlen/len; }
	return(v);
}
/* return vector sum c = a+b */
static Vector2 *V2Add(Vector2 *a, Vector2 *b, Vector2 *c)
{
	c->x = a->x+b->x;  c->y = a->y+b->y;
	return(c);
}
/* return the dot product of vectors a and b */
static double V2Dot(Vector2 *a, Vector2 *b)
{
	return((a->x*b->x)+(a->y*b->y));
}
/* normalizes the input vector and returns it */
static Vector2 *V2Normalize(Vector2 *v)
{   double len = V2Length(v);

	if (len != 0.0) { v->x /= len;  v->y /= len; }
	return(v);
}


/* FitCurve - Fit a Bezier curve to a set of digitized points
 * d        Array of digitized points
 * nPts     Number of digitized points
 * error    User-defined error squared
 */
void FitCurve(Point2 *d, int nPts, double error)
{   Vector2	tHat1, tHat2;   // Unit tangent vectors at endpoints

    tHat1 = ComputeLeftTangent(d, 0);
    tHat2 = ComputeRightTangent(d, nPts - 1);
    FitCubic(d, 0, nPts - 1, tHat1, tHat2, error, 0);
}

/* FitCubic - Fit a Bezier curve to a (sub)set of digitized points
 * d            Array of digitized points
 * first, last  Indices of first and last pts in region
 * tHat1, tHat2 Unit tangent vectors at endpoints
 * error        User-defined error squared
 */
static int FitCubic(Point2 *d, int first, int last, Vector2 tHat1, Vector2 tHat2, double error, int recursion_level)
{   BezierCurve bezCurve;           // Control points of fitted Bezier curve
    double      *u;                 // Parameter values for point
    double      *uPrime;            // Improved parameter values
    double      maxError;           // Maximum fitting error
    int         splitPoint;         // Point to split point set at
    int         nPts;               // Number of points in subset
    double      iterationError;     // Error below which you try iterating
    int         maxIterations = 4;  // Max times to try iterating
    Vector2     tHatCenter;         // Unit tangent vector at splitPoint
    int         i;
	int         subret;

	if (last < first)
	{
		// this seems to happen a lot
		// printf("failed assertion: %d >= %d\n", last, first);
		return ERR_LAST_FIRST_INVERSION;
	}
	if (recursion_level > RECURSION_LIMIT)
	{
		// sodas this sometimes... just put a coke in it
		// or finger the dyke or whatever
		printf("excessive recursion\n");
		return ERR_EXCESSIVE_RECURSION;
	}

    iterationError = error * error;
    nPts = last - first + 1;

    /*  Use heuristic if region only has two points in it */
    if (nPts == 2)
    {   double dist = V2DistanceBetween2Points(d[last], d[first]) / 3.0;

		bezCurve = (Point2 *)malloc(4 * sizeof(Point2));
		bezCurve[0] = d[first];
		bezCurve[3] = d[last];
		V2Add(&bezCurve[0], V2Scale(&tHat1, dist), &bezCurve[1]);
		V2Add(&bezCurve[3], V2Scale(&tHat2, dist), &bezCurve[2]);
		OutputBezierCurve(3, bezCurve);
		free((void *)bezCurve);
		return ERR_NONE;
    }

    /*  Parameterize points, and attempt to fit curve */
    u = ChordLengthParameterize(d, first, last);
    bezCurve = GenerateBezier(d, first, last, u, tHat1, tHat2);

    /*  Find max deviation of points to fitted curve */
    maxError = ComputeMaxError(d, first, last, bezCurve, u, &splitPoint);
    if (maxError < error)
    {
		OutputBezierCurve(3, bezCurve);
		free((void *)u);
		free((void *)bezCurve);
		return ERR_NONE;
    }


    /*  If error not too large, try some reparameterization  */
    /*  and iteration */
    if (maxError < iterationError)
    {
		for (i = 0; i < maxIterations; i++) {
	    	uPrime = Reparameterize(d, first, last, u, bezCurve);
	    	free((void *)bezCurve);
	    	bezCurve = GenerateBezier(d, first, last, uPrime, tHat1, tHat2);
	    	maxError = ComputeMaxError(d, first, last,
				       bezCurve, uPrime, &splitPoint);
	    	if (maxError < error)
            {
                OutputBezierCurve(3, bezCurve);
                free((void *)u);
                free((void *)bezCurve);
                free((void *)uPrime);
                return ERR_NONE;
            }
            free((void *)u);
            u = uPrime;
        }
    }

    /* Fitting failed -- split at max error point and fit recursively */
    free((void *)u);
    free((void *)bezCurve);
    tHatCenter = ComputeCenterTangent(d, splitPoint);
    subret = FitCubic(d, first, splitPoint, tHat1, tHatCenter, error, recursion_level + 1);
	if (subret < 0)
		return subret;
    V2Negate(&tHatCenter);
    return FitCubic(d, splitPoint, last, tHatCenter, tHat2, error, recursion_level + 1);
}


/* GenerateBezier
 * Use least-squares method to find Bezier control points for region.
 *
 * d            Array of digitized points
 * first, last  Indices defining region
 * uPrime       Parameter values for region
 * tHat1, tHat2 Unit tangents at endpoints
 */
static BezierCurve  GenerateBezier(Point2 *d, int first, int last, double *uPrime, Vector2 tHat1, Vector2 tHat2)
{   int         i;
    const int 	nPts = last - first + 1;    // Number of pts in sub-curve
    Vector2     A[nPts][2];         // Precomputed rhs for eqn
    double      C[2][2];			// Matrix C
    double      X[2];               // Matrix X
    double      det_C0_C1,          // Determinants of matrices
                det_C0_X,
                det_X_C1;
    double      alpha_l,            // Alpha values, left and right
                alpha_r;
    Vector2 	tmp;                // Utility variable
    BezierCurve bezCurve;           // RETURN bezier curve ctl pts

    bezCurve = (Point2 *)malloc(4 * sizeof(Point2));

    /* Compute the A's	*/
    for (i = 0; i < nPts; i++)
    {	Vector2		v1, v2;

		v1 = tHat1;
		v2 = tHat2;
		V2Scale(&v1, B1(uPrime[i]));
		V2Scale(&v2, B2(uPrime[i]));
		A[i][0] = v1;
		A[i][1] = v2;
    }

    /* Create the C and X matrices	*/
    C[0][0] = 0.0;
    C[0][1] = 0.0;
    C[1][0] = 0.0;
    C[1][1] = 0.0;
    X[0]    = 0.0;
    X[1]    = 0.0;

    for (i = 0; i < nPts; i++)
    {
        C[0][0] += V2Dot(&A[i][0], &A[i][0]);
		C[0][1] += V2Dot(&A[i][0], &A[i][1]);
/*      C[1][0] += V2Dot(&A[i][0], &A[i][1]);*/	
		C[1][0] = C[0][1];
		C[1][1] += V2Dot(&A[i][1], &A[i][1]);

		tmp = V2SubII(d[first + i],
	        V2AddII(
	          V2ScaleIII(d[first], B0(uPrime[i])),
		    	V2AddII(
		      		V2ScaleIII(d[first], B1(uPrime[i])),
		        			V2AddII(
	                  		V2ScaleIII(d[last], B2(uPrime[i])),
	                    		V2ScaleIII(d[last], B3(uPrime[i]))))));

        X[0] += V2Dot(&A[i][0], &tmp);
        X[1] += V2Dot(&A[i][1], &tmp);
    }

    /* Compute the determinants of C and X	*/
    det_C0_C1 = C[0][0] * C[1][1] - C[1][0] * C[0][1];
    det_C0_X  = C[0][0] * X[1]    - C[1][0] * X[0];
    det_X_C1  = X[0]    * C[1][1] - X[1]    * C[0][1];

    /* Finally, derive alpha values	*/
    if (det_C0_C1 == 0.0) {
		det_C0_C1 = (C[0][0] * C[1][1]) * 10e-12;
    }
    alpha_l = det_X_C1 / det_C0_C1;
    alpha_r = det_C0_X / det_C0_C1;

    /*  If alpha negative, use the Wu/Barsky heuristic (see text) */
	/* (if alpha is 0, you get coincident control points that lead to
	 * divide by zero in any subsequent NewtonRaphsonRootFind() call. */
    if (alpha_l < 1.0e-6 || alpha_r < 1.0e-6)
    {	double	dist = V2DistanceBetween2Points(d[last], d[first]) / 3.0;

        bezCurve[0] = d[first];
		bezCurve[3] = d[last];
		V2Add(&bezCurve[0], V2Scale(&tHat1, dist), &bezCurve[1]);
		V2Add(&bezCurve[3], V2Scale(&tHat2, dist), &bezCurve[2]);
		return (bezCurve);
    }

#if 0   // alternative code
    /* Finally, derive alpha values	*/
    alpha_l = (det_C0_C1 == 0) ? 0.0 : det_X_C1 / det_C0_C1;
    alpha_r = (det_C0_C1 == 0) ? 0.0 : det_C0_X / det_C0_C1;

    /* If alpha negative, use the Wu/Barsky heuristic (see text) */
    /* (if alpha is 0, you get coincident control points that lead to
     * divide by zero in any subsequent NewtonRaphsonRootFind() call. */
    double segLength = V2DistanceBetween2Points(d[last], d[first]);
    double epsilon = 1.0e-6 * segLength;
    if (alpha_l < epsilon || alpha_r < epsilon)
    {
		/* fall back on standard (probably inaccurate) formula, 
         and subdivide further if needed. */
		double dist = segLength / 3.0;

		bezCurve[0] = d[first];
		bezCurve[3] = d[last];
		V2Add(&bezCurve[0], V2Scale(&tHat1, dist), &bezCurve[1]);
		V2Add(&bezCurve[3], V2Scale(&tHat2, dist), &bezCurve[2]);
		return (bezCurve);
    }
#endif

    /*  First and last control points of the Bezier curve are */
    /*  positioned exactly at the first and last data points */
    /*  Control points 1 and 2 are positioned an alpha distance out */
    /*  on the tangent vectors, left and right, respectively */
    bezCurve[0] = d[first];
    bezCurve[3] = d[last];
    V2Add(&bezCurve[0], V2Scale(&tHat1, alpha_l), &bezCurve[1]);
    V2Add(&bezCurve[3], V2Scale(&tHat2, alpha_r), &bezCurve[2]);
    return (bezCurve);
}


/* Reparameterize:
 * Given set of points and their parameterization, try to find
 * a better parameterization.
 *
 * d            Array of digitized points
 * first, last  Indices defining region
 * u            Current parameter values
 * bezCurve     Current fitted curve
 */
static double *Reparameterize(Point2 *d, int first, int last, double *u, BezierCurve bezCurve)
{   int 	nPts = last-first+1;	
    int 	i;
    double	*uPrime;                // New parameter values

    uPrime = (double *)malloc(nPts * sizeof(double));
    for (i = first; i <= last; i++)
    {
		uPrime[i-first] = NewtonRaphsonRootFind(bezCurve, d[i], u[i-
					first]);
    }
    return (uPrime);
}


/* NewtonRaphsonRootFind
 * Use Newton-Raphson iteration to find better root.
 * Q    Current fitted curve
 * P    Digitized point
 * u    Parameter value for "P"
 */
static double NewtonRaphsonRootFind(BezierCurve Q, Point2 P, double u)
{   double 		numerator, denominator;
    Point2 		Q1[3], Q2[2];       // Q' and Q''
    Point2		Q_u, Q1_u, Q2_u;    // u evaluated at Q, Q', & Q''
    double 		uPrime;             // Improved u
    int 		i;

    /* Compute Q(u)	*/
    Q_u = BezierII(3, Q, u);

    /* Generate control vertices for Q'	*/
    for (i = 0; i <= 2; i++)
    {
		Q1[i].x = (Q[i+1].x - Q[i].x) * 3.0;
		Q1[i].y = (Q[i+1].y - Q[i].y) * 3.0;
    }

    /* Generate control vertices for Q'' */
    for (i = 0; i <= 1; i++)
    {
		Q2[i].x = (Q1[i+1].x - Q1[i].x) * 2.0;
		Q2[i].y = (Q1[i+1].y - Q1[i].y) * 2.0;
    }

    /* Compute Q'(u) and Q''(u)	*/
    Q1_u = BezierII(2, Q1, u);
    Q2_u = BezierII(1, Q2, u);

    /* Compute f(u)/f'(u) */
    numerator = (Q_u.x - P.x) * (Q1_u.x) + (Q_u.y - P.y) * (Q1_u.y);
    denominator = (Q1_u.x) * (Q1_u.x) + (Q1_u.y) * (Q1_u.y) +
		      	  (Q_u.x - P.x) * (Q2_u.x) + (Q_u.y - P.y) * (Q2_u.y);
    if (denominator == 0.0f) return u;

    /* u = u - f(u)/f'(u) */
    uPrime = u - (numerator/denominator);
    return (uPrime);
}

	
		       
/* Bezier
 * Evaluate a Bezier curve at a particular parameter value
 *
 * degree   The degree of the bezier curve
 * V        Array of control points
 * t        Parametric value to find point for
 */
static Point2 BezierII(int degree, Point2 *V, double t)
{   int 	i, j;		
    Point2 	Q;      // Point on curve at parameter t
    Point2 	*Vtemp; // Local copy of control points

    /* Copy array	*/
    Vtemp = (Point2 *)malloc((unsigned)((degree+1) 
				* sizeof (Point2)));
    for (i = 0; i <= degree; i++)
		Vtemp[i] = V[i];

    /* Triangle computation	*/
    for (i = 1; i <= degree; i++)
    {	
		for (j = 0; j <= degree-i; j++)
        {
	    	Vtemp[j].x = (1.0 - t) * Vtemp[j].x + t * Vtemp[j+1].x;
	    	Vtemp[j].y = (1.0 - t) * Vtemp[j].y + t * Vtemp[j+1].y;
		}
    }

    Q = Vtemp[0];
    free((void *)Vtemp);
    return Q;
}


/*
 *  B0, B1, B2, B3 :
 *	Bezier multipliers
 */
static double B0(double u)
{   double tmp = 1.0 - u;
    return (tmp * tmp * tmp);
}

static double B1(double u)
{   double tmp = 1.0 - u;
    return (3 * u * (tmp * tmp));
}

static double B2(double u)
{   double tmp = 1.0 - u;
    return (3 * u * u * tmp);
}

static double B3(double u)
{
    return (u * u * u);
}


/* ComputeLeftTangent, ComputeRightTangent, ComputeCenterTangent :
 * Approximate unit tangents at endpoints and "center" of digitized curve
 * d    Digitized points
 * end  Index to "left" end of region
 */
static Vector2 ComputeLeftTangent(Point2 *d, int end)
{   Vector2	tHat1;

    tHat1 = V2SubII(d[end+1], d[end]);
    tHat1 = *V2Normalize(&tHat1);
    return tHat1;
}

/*
 * d        Digitized points
 * end      Index to "right" end of region
 */
static Vector2 ComputeRightTangent(Point2 *d, int end)
{   Vector2	tHat2;

    tHat2 = V2SubII(d[end-1], d[end]);
    tHat2 = *V2Normalize(&tHat2);
    return tHat2;
}

/*
 * d        Digitized points
 * center   Index to point inside region
 */
static Vector2 ComputeCenterTangent(Point2 *d, int center)
{   Vector2 V1, V2, tHatCenter;

    V1 = V2SubII(d[center-1], d[center]);
    V2 = V2SubII(d[center], d[center+1]);
    tHatCenter.x = (V1.x + V2.x)/2.0;
    tHatCenter.y = (V1.y + V2.y)/2.0;
    tHatCenter = *V2Normalize(&tHatCenter);
    return tHatCenter;
}


/* ChordLengthParameterize
 * Assign parameter values to digitized points using relative distances between points.
 * d            Array of digitized points
 * first, last  Indices defining region
 */
static double *ChordLengthParameterize(Point2 *d, int first, int last)
{   int		i;	
    double	*u;     // Parameterization

    u = (double *)malloc((unsigned)(last-first+1) * sizeof(double));

    u[0] = 0.0;
    for (i = first+1; i <= last; i++)
    {
		u[i-first] = u[i-first-1] + V2DistanceBetween2Points(d[i], d[i-1]);
    }

    for (i = first + 1; i <= last; i++)
    {
		u[i-first] = u[i-first] / u[last-first];
    }

    return(u);
}


/* ComputeMaxError
 * Find the maximum squared distance of digitized points to fitted curve.
 * d            Array of digitized points
 * first, last  Indices defining region
 * bezCurve     Fitted Bezier curve
 * u            Parameterization of points
 * splitPoint   Point of maximum error
 */
static double ComputeMaxError(Point2 *d, int first, int last, BezierCurve bezCurve, double *u, int *splitPoint)
{   int		i;
    double	maxDist;    //  Maximum error
    double	dist;		//  Current error
    Point2	P;			//  Point on curve
    Vector2	v;			//  Vector from point to curve

    *splitPoint = (last - first + 1)/2;
    maxDist = 0.0;
    for (i = first + 1; i < last; i++)
    {
		P = BezierII(3, bezCurve, u[i-first]);
		v = V2SubII(P, d[i]);
		dist = V2SquaredLength(&v);
		if (dist >= maxDist)
        {
	    	maxDist = dist;
	    	*splitPoint = i;
		}
    }
    return (maxDist);
}
static Vector2 V2AddII(Vector2 a, Vector2 b)
{   Vector2	c;

    c.x = a.x + b.x;  c.y = a.y + b.y;
    return (c);
}
static Vector2 V2ScaleIII(Vector2 v, double s)
{   Vector2 result;

    result.x = v.x * s; result.y = v.y * s;
    return (result);
}

static Vector2 V2SubII(Vector2 a, Vector2 b)
{   Vector2	c;

    c.x = a.x - b.x; c.y = a.y - b.y;
    return (c);
}
