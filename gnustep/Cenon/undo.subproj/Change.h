/* Change.h
 *
 * Copyright (C) 1993-2002 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *
 * created:  1993 based on the Draw example files
 * modified: 2002-07-15
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

#ifndef VHF_H_CHANGE
#define VHF_H_CHANGE

@class ChangeManager;

@interface Change : NSObject
{
    struct {
	unsigned int disabled: 1;	/* YES if disable message receieved */
	unsigned int hasBeenDone: 1;	/* YES if done or redone */
	unsigned int changeInProgress: 1; /* YES after startChange 
					     but before endChange */
	unsigned int padding: 29;
    } _changeFlags;
   ChangeManager *_changeManager;
}

/* Methods called directly by your code */

- (id)init;				/* start with [super init] if overriding */
- (BOOL)startChange;			/* DO NOT override */
- (BOOL)startChangeIn:aView;		/* DO NOT override */
- (BOOL)endChange;			/* DO NOT override */
- (ChangeManager *)changeManager;	/* DO NOT override */

/* Methods called by ChangeManager or by your code */

- (void)disable;			/* DO NOT override */
- (BOOL)disabled;		/* DO NOT override */
- (BOOL)hasBeenDone;		/* DO NOT override */
- (BOOL)changeInProgress;	/* DO NOT override */
- (NSString *)changeName;	/* override at will */

/* Methods called by ChangeManager */
/* DO NOT call directly */

- (void)saveBeforeChange;		/* override at will */
- (void)saveAfterChange;		/* override at will */
- (void)undoChange;			/* end with [super undoChange] if overriding */
- (void)redoChange;			/* end with [super redoChange] if overriding */
- (BOOL)subsumeChange:change;	/* override at will */
- (BOOL)incorporateChange:change;/* override at will */
- (void)finishChange;			/* override at will */

@end

#endif // VHF_H_CHANGE
