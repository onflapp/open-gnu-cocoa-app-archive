/*
 * vhfDPSFunctions.h
 *
 * Copyright 2000-2001 by vhf computer GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-04-01
 * modified: 2001-10-20
 */

#import <AppKit/AppKit.h>
#import "types.h"

/* GNUstep
 */
#ifndef PSPATHOPS_H	// should have been defined in AppKit.h - psops.h
//#   import "PSOperators.h"
//#   import <DPS/dpsclient.h>
//#   import <DPS/dpsXuserpath.h>

    /* Constants for constructing operator array parameter of DPSDoUserPath. */
    typedef unsigned char DPSUserPathOp;
    enum {
        dps_setbbox = 0,
        dps_moveto,
        dps_rmoveto,
        dps_lineto,
        dps_rlineto,
        dps_curveto,
        dps_rcurveto,
        dps_arc,
        dps_arcn,
        dps_arct,
        dps_closepath,
        dps_ucache
    };

    /* Constants for the action of DPSDoUserPath */
    typedef enum _DPSUserPathAction {
        dps_uappend = 176,
        dps_ufill = 179,
        dps_ueofill = 178,
        dps_ustroke = 183,
        dps_ustrokepath = 364,
        dps_inufill = 93,
        dps_inueofill = 92,
        dps_inustroke = 312,
        dps_def = 51,
        dps_put = 120
    } DPSUserPathAction;

#    define NSDPSContext		NSGraphicsContext
#    define VHFIsDrawingToScreen()	[[NSGraphicsContext currentContext] isDrawingToScreen]

#    define PSWait()			{ [[NSGraphicsContext currentContext] flush], [[NSGraphicsContext currentContext] wait]; }

/* OpenStep
 */
#else

#    import <AppKit/psops.h>
#    define VHFIsDrawingToScreen()	[[NSDPSContext currentContext] isDrawingToScreen]

#endif

void doUserPath( float *coords, int numCoords, DPSUserPathOp *ops, int numOps, const void *bbox, DPSUserPathAction action );
