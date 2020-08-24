/*
 * vhfDPSFunctions.m
 *
 * Copyright 1996-2000 by vhf computer GmbH
 * Author:  Georg Fleischmann
 *
 * created:  01.04.00
 * modified: 
 */

#import "vhfDPSFunctions.h"

#ifndef DPSOPENSTEP_H

void doUserPath( float *pts, int numPts, DPSUserPathOp *ops, int numOps, const void *bbox, DPSUserPathAction action )
{   int	i;

    PSnewpath();
    for( i=0; i<numOps; i++ )
    {
        switch( *ops )
	{
	    case dps_moveto:
	        //if( action == dps_ueofill )
		//    PSeofill();
	        PSmoveto(pts[0], pts[1]);
		pts += 2;
		break;
	    case dps_lineto:
	        PSlineto(pts[0], pts[1]);
		pts += 2;
		break;
	    case dps_arc:
	        PSarc(pts[0], pts[1], pts[2], pts[3], pts[4]);
		pts += 5;
		break;
	    case dps_arcn:
	        PSarcn(pts[0], pts[1], pts[2], pts[3], pts[4]);
		pts += 5;
		break;
	    case dps_curveto:
	        PScurveto(pts[0], pts[1], pts[2], pts[3], pts[4], pts[5]);
		pts += 6;
	}
	ops++;
    }
    if( action == dps_ustroke )
        PSstroke();
    else
        PSeofill();
}

#else

/* workaround for DPS bug.
 * we limit the amount of coords to ~10000 for stroke
 */
#define	DPS_OPS_LIMIT	990
void doUserPath( float *pts, int numPts, DPSUserPathOp *ops, int numOps, const void *bbox, DPSUserPathAction action )
{
    if( numPts <= 10000 || action != dps_ustroke )
        PSDoUserPath( pts, numPts, dps_float, ops, numOps, bbox, action );
    else
    {   long	opsOffset, opsNumber;
        long	coordsOffset, coordsNumber;
        int	moveIndex = 0;
        char	op = 0;

        /* scan ops and take relating coords */
        for( opsOffset=0, coordsOffset=0; opsOffset<numOps; opsOffset+=opsNumber, coordsOffset+=coordsNumber )
        {   BOOL	makeMove = NO, stop = NO;

            for( coordsNumber = 0, opsNumber = 0; opsOffset+opsNumber<numOps && !stop; )
            {
                switch(ops[opsOffset+opsNumber])
                {
                    case dps_moveto:	/* x, y */
                        if( opsNumber>DPS_OPS_LIMIT )
                        {   stop = YES;
                            break;
                        }
                    case dps_rmoveto:	/* x, y */
                    case dps_lineto:	/* x, y */
                        opsNumber++;
                        coordsNumber += 2;
                        break;
                    case dps_arc:	/* center x, center y, radius, start angle, end angle */
                    case dps_arcn:
                        opsNumber++;
                        coordsNumber += 5;
                        break;
                    case dps_curveto:	/* x1, y1, x2, y2, x3, y3 */
                        opsNumber++;
                        coordsNumber += 6;
                        break;
                    default:
                        NSLog(@"doUserPath (): unsopported DPS type!");
                        return;
                }
                if( opsNumber >= 1000 )
                {   makeMove = YES; break; }
            }
            PSDoUserPath(pts+coordsOffset, coordsNumber, dps_float, ops+opsOffset, opsNumber, bbox, action);
            PSWait();
            if( moveIndex )
            {
                ops[moveIndex] = op;
                moveIndex = 0;
            }
            if( makeMove )
            {   makeMove = NO;
                moveIndex = opsOffset+opsNumber-1;
                op = ops[moveIndex];
                ops[moveIndex] = dps_moveto;
                opsNumber --;
                coordsNumber -= 2;
            }
        }
    }
}

#endif
