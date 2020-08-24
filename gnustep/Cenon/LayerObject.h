/* LayerObject.h
 * Object managing a single layer and its attributes
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * Created:  1996-03-07
 * Modified: 2012-01-25 (-setInvisible:, -invisible, invisible)
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

#ifndef VHF_H_LAYEROBJECT
#define VHF_H_LAYEROBJECT

#include "GraphicObjects.subproj/PerformanceMap.h"

/* FIXME: CAM (should go to a sub class header) */
#define OUTPUT_STEPMAX 100
typedef struct
{
    float	step[OUTPUT_STEPMAX];
    int		count;
} OutputSteps;

typedef enum
{
    CUT_INSIDE    = 0,  // correct to inside
    CUT_OUTSIDE   = 1,  // correct to outside
    CUT_NOSIDE    = 2,  // no correction
    CUT_PICKOUT   = 3,  // engraving with pick-out
    CUT_ISOLATION = 4,	// calculate isolation of PCB
    CUT_BLOWUP    = 5,	// calculate blow up   of PCB
    CUT_RUBOUT    = 6	// calculate rubout    of PCB
} CAMCutType;

/* the layer ids shouldn't be changed, they are saved to the document !
 * FIXME: we should save the name of the layer types (not integer code)
 */
typedef enum
{
    /* General layer types */
    LAYER_STANDARD   = 0,	// standard layer
    LAYER_PASSIVE    = 1,	// passive layer, not editable, calculated automatically (CAM)
    LAYER_CLIPPING   = 2,	// layer with regions used for clipping (CAM)
    LAYER_LEVELING   = 3,	// layer with elements defining an area for leveling (CAM)
    LAYER_FITTING    = 4,	// a layer with two marks for flipping the working piece (CAM)
    LAYER_PAGE       = 5,	// page in multi page document

    /* Templates */
    LAYER_TEMPLATE   = 10,	// general template for all layers and pages
    LAYER_TEMPLATE_1 = 11,	// template for odd pages
    LAYER_TEMPLATE_2 = 12,	// template for even pages

    /* CAM (FIXME: needs to go to CAM module) */
    LAYER_CAMERA     = 50	// layer with markers defining target net for camera gauging (CAM)
} LayerType;

@interface LayerObject: NSObject
{
    NSString        *string;            // the name of the layer
    PerformanceMap  *performanceMap;    // grid for faster access of objects on layer
    NSMutableArray  *list;              // the graphic list
    int             tag;                // tag for layers with special purpose
    NSColor         *color;             // the color of this layer
    int             state;              // if we have to display this layer
    BOOL            editable;           // whether we are editable
    int             type;               // type of layer: LAYER_STANDARD, LAYER_PASSIVE, ...
    int             uniqueId;           // a unique id of the layer used with multi layer groups
    BOOL            likeOtherLayers;    // YES = share parameters with other layers of state YES
    BOOL            useForTile;         // whether layer is used for duplicates
    BOOL            dirty;              // YES when changed
    BOOL            invisible;          // whether this is a drawable layer

    NSMutableDictionary *layerDict;     // dictionary to store additional stuff for the layer

    /* TODO: CAM (move to a sub class) */
    int             toolIndex;          // the index of the tool
    NSString        *toolString;        // the name of the tool
    BOOL            filled;             // whether we are filled
    BOOL            mirrored;           // whether we are mirrored
    int             side;               // whether to cut inside, outside or on the line
    float           flatness;
    float           fillOverlap;        // (0.0 - 1.0) 0 = no overlap
    float           fillDirection;      // (0.0 - 360.0)
    BOOL            removeLoops;        // whether we have to remove garbage (loops) from contour
    BOOL            revertDirection;    // whether we revert the direction (ccw/cw)
    float           dippingDepth;       // the dippingDepth [mm]
    float           approachAngle;      // the approach angle for dipping, 0 - 89 [deg]
    BOOL            stepwise;           // weather stepwise cutting is active
    int             numSteps;           // number of middle steps
    float           step[3];            // first, step width, final step [mm]
    OutputSteps     calcSteps;          // calculated steps [mm]
    float           settle;             // [mm]
    BOOL            settleBefore;       // settlement before last step z
    int             levelingX, levelingY;   // number of test points for leveling */
    BOOL            inlay;

    /* CAM output */
    NSArray         *webList;           // used to reach web list when creating output
    int             tileCount;          // used to reach tile count when creating output
    id              clipObject;         // used to reach clip object when creating output
}

+ layerObject;
+ layerObjectWithFrame:(NSRect)bRect;
- init;
- initWithFrame:(NSRect)bRect;

- (void)createPerformanceMapWithFrame:(NSRect)rect;
- (PerformanceMap*)performanceMap;
- (void)setList:(NSMutableArray*)aList;
- (NSMutableArray*)list;
- (void)insertObject:(id)obj atIndex:(unsigned)ix;
- (void)addObject:(id)obj;
- (void)addObjectWithoutCheck:(id)obj;
- (void)addObjectsFromArray:(NSArray*)array;
- (void)updateObject:(VGraphic*)g;
- (void)removeAllObjects;
- (void)removeObject:(id)obj;
- (void)draw:(NSRect)rect inView:(id)view;

- (BOOL)isFillable;
- (BOOL)hasDip;             // TODO: move to CAM module
- (BOOL)isPassive;          // LAYER_PASSIVE
- (BOOL)fastSideSelection;

- (void)setString:(NSString *)aString;
- (NSString*)string;

- (void)setTag:(int)newTag;
- (int)tag;

- (void)setColor:(NSColor *)aColor;
- (NSColor *)color;

- (void)setState:(int)flag;
- (int)state;

- (void)setInvisible:(int)flag;
- (int)invisible;

- (void)setEditable:(BOOL)flag;
- (BOOL)editable;

- (void)setDirty:(BOOL)flag calculate:(BOOL)cflag;
- (void)setDirty:(BOOL)flag;
- (BOOL)dirty;

- (int)type;
- (void)setType:(int)newType;

- (int)uniqueId;
- (void)setUniqueId:(int)newId;

- (BOOL)useForTile;
- (void)setUseForTile:(BOOL)flag;
- (void)setTileCount:(int)c;
- (int)tileCount;

- (BOOL)likeOtherLayers;
- (void)setLikeOtherLayers:(BOOL)flag;


/* CAM (should go to a sub class or category) */
- (void)setToolIndex:(int)aTool;
- (int)toolIndex;
- (void)setToolString:(NSString*)theToolString;
- (NSString*)toolString;

- (void)setFilled:(BOOL)flag;
- (BOOL)filled;

- (void)setMirrored:(BOOL)flag;
- (BOOL)mirrored;

- (void)setInlay:(BOOL)flag;
- (BOOL)inlay;

- (void)setSide:(int)s;
- (int)side;

- (float)flatness;
- (void)setFlatness:(float)v;

- (float)fillOverlap;
- (void)setFillOverlap:(float)v;
- (float)fillDirection;
- (void)setFillDirection:(float)v;

- (void)setDippingDepth:(float)d;
- (float)dippingDepth;

- (void)setApproachAngle:(float)angle;
- (float)approachAngle;

- (void)setStepwise:(BOOL)flag;
- (BOOL)stepwise;
- (void)setFirstStep:(float)step;
- (void)setStepHeight:(float)height;
- (float)stepHeight;
- (void)setNumSteps:(int)n;
- (int)numSteps;
- (void)setFinalStep:(float)step;
- (float)stepWithNum:(int)n;
- (OutputSteps)steps;
- (OutputSteps)stepsForDip:(float)dip;

- (void)setSettle:(float)value;
- (float)settle;
- (void)setSettleBefore:(BOOL)flag;
- (BOOL)settleBefore;

- (BOOL)removeLoops;
- (void)setRemoveLoops:(BOOL)flag;

- (BOOL)revertDirection;
- (void)setRevertDirection:(BOOL)flag;

- (void)setLevelingPointsX:(int)x y:(int)y;
- (int)levelingPointsX;
- (int)levelingPointsY;

/* CAM output, used to reach web list when creating output */
- (void)setWebList:(NSArray*)array;
- (NSArray*)webList;
- (void)setClipObject:obj;
- clipObject;


/* archiving */
- (void)dealloc;

- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;

@end

#endif // VHF_H_LAYEROBJECT
