/* LocalizableStringsForGraphicsUndo.h
 *
 * Copyright (C) 1996-2011 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1996
 * modified: 2011-05-28 (EXCLUDE_OP added, NAME_OP -> LABEL_OP)
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

#ifndef VHF_H_LOCALIZABLESTRINGSFORGRAPHICSUNDO
#define VHF_H_LOCALIZABLESTRINGSFORGRAPHICSUNDO

#include <Foundation/Foundation.h>

/* Localization strings for the graphics undo subproject */

#define ALIGN_OP NSLocalizedStringFromTable(@"Align", @"Operations", "The operation of aligning some graphical entities together.")
#define ANGLE_OP NSLocalizedStringFromTable(@"Angle", @"Operations", "The operation of setting the angles of a graphical element (arc).")
#define ASPECT_OP NSLocalizedStringFromTable(@"Natural Size", @"Operations", "The operation of returning a graphical entity to its natural aspect ratio, e.g., an oval becomes a circle, a rectangle becomes a square.")
#define BRING_TO_FRONT_OP NSLocalizedStringFromTable(@"Bring to Front", @"Operations", "The operation of bringing a graphical entity or group of graphical entities to the front of all other graphical entities.")
#define COLOR_OP NSLocalizedStringFromTable(@"Color", @"Operations", "The operation of changing the color of a line segment.")
#define CONTOUR_OP NSLocalizedStringFromTable(@"Contour", @"Operations", "The operation of building the contour of graphical entities.")
#define CUT_OP NSLocalizedStringFromTable(@"Cut", @"Operations", "The operation of cutting some graphical entities out of the document and putting them on the Pasteboard.")
#define DELETE_OP NSLocalizedStringFromTable(@"Delete", @"Operations", "The operation of pressing the delete key to remove the selected graphical entites or text from the document entirely.")
#define DIMENSION_OP NSLocalizedStringFromTable(@"Dimensions", @"Operations", "The operation of changing the dimensions of a graphical entity by typing numbers into text fields for the width and height.")
#define END_EDITING_OP NSLocalizedStringFromTable(@"Editing", @"Operations", "The operation of ending the editing process and proceding onto some other operation.")
#define EXCLUDE_OP NSLocalizedStringFromTable(@"Exclude/Include", @"Operations", "The operation of excluding and including all selected graphics so that they are not processed.")
#define FILL_OP NSLocalizedStringFromTable(@"Fill", @"Operations", "The operation of filling a graphical entity's interior with a gray or color.")
#define GRID_OP NSLocalizedStringFromTable(@"Grid Change", @"Operations", "The operation of changing the spacing or color of the grid.")
#define GROUP_OP NSLocalizedStringFromTable(@"Group", @"Operations", "The operation of grouping a bunch of graphical entities together.")
#define JOIN_OP NSLocalizedStringFromTable(@"Join", @"Operations", "The operation of joining a bunch of graphical entities together.")
#define LINEWIDTH_OP NSLocalizedStringFromTable(@"Line Width", @"Operations", "The operation of changing the width of a line segment.")
#define LENGTH_OP NSLocalizedStringFromTable(@"Length", @"Operations", "The operation of changing the length of a ghraphic object.")
#define LOCK_OP NSLocalizedStringFromTable(@"Lock/Unlock", @"Operations", "The operation of locking and unlocking all selected graphics so that they can't be edited in anyway until they are unlocked.")
#define MOVE_OP NSLocalizedStringFromTable(@"Move", @"Operations", "The operation of moving a graphical entity.")
#define MOVEPOINT_OP NSLocalizedStringFromTable(@"Move vertex", @"Operations", "The operation of moving a verticex.")
#define ADDPOINT_OP NSLocalizedStringFromTable(@"Add vertex", @"Operations", "The operation of adding a vertices.")
#define REMOVEPOINT_OP NSLocalizedStringFromTable(@"Remove vertex", @"Operations", "The operation of removing a vertices.")
#define MIX_OP NSLocalizedStringFromTable(@"Mix", @"Operations", "The operation of mixing some graphical entities together.")
#define MIRROR_OP NSLocalizedStringFromTable(@"Mirror", @"Operations", "The operation of mirroring a graphical entity.")
#define LABEL_OP NSLocalizedStringFromTable(@"Rename", @"Operations", "The operation of renaming a graphical entity.")
#define NEW_CHANGE_OP NSLocalizedStringFromTable(@"New %@", @"Operations", "The operation of creating a new graphical entity by dragging the mouse.  The %@ is one of Rectangle, Circle, etc.")
#define PUNCH_OP NSLocalizedStringFromTable(@"Punch", @"Operations", "The operation of punching graphical entities from others.")
#define PASTE_OP NSLocalizedStringFromTable(@"Paste", @"Operations", "The operation of getting something from the Pasteboard and inserting into the document.")
#define RADIUS_OP NSLocalizedStringFromTable(@"Radius", @"Operations", "The operation of setting the radius of a graphical element.")
#define RESIZE_OP NSLocalizedStringFromTable(@"Resize", @"Operations", "The operation of changing the size of a graphical entity by dragging a corner of it with the mouse.")
#define ROTATE_OP NSLocalizedStringFromTable(@"Rotate", @"Operations", "The operation of rotating a graphical entity.")
#define SCALE_OP NSLocalizedStringFromTable(@"Scale", @"Operations", "The operation of scaling a graphical entity.")
#define SEND_TO_BACK_OP NSLocalizedStringFromTable(@"Send To Back", @"Operations", "The operation of sending all the selected graphical entities to the back of (behind) all other graphical entities.")
#define SPLIT_OP NSLocalizedStringFromTable(@"Split", @"Operations", "The operation of spliotting a path.")
#define START_EDITING_OP NSLocalizedStringFromTable(@"Begin Editing", @"Operations", "The operation of starting to edit some text.")
#define UNGROUP_OP NSLocalizedStringFromTable(@"Ungroup", @"Operations", "The operation of ungroup a bunch of graphical entities that are grouped together into a single graphical entity.")
#define STEPWIDTH_OP NSLocalizedStringFromTable(@"Step Width", @"Operations", "The operation of changing the stepwidth of a graduate or radial filling.")
#define RADIALCENTER_OP NSLocalizedStringFromTable(@"Radial Center", @"Operations", "The operation of changing the radial center of a radial filling.")

#endif // VHF_H_LOCALIZABLESTRINGSFORGRAPHICSUNDO
