/* MoveMatrix.h
 *
 * Copyright (C) 1993-2002 by vhf interservice GmbH
 * Author: T+T Hennerich, Georg Fleischmann
 *
 * Created:  1993-05-17
 * Modified: 2002-07-01
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

#ifndef VHF_H_MOVEMATRIX
#define VHF_H_MOVEMATRIX

@interface MoveMatrix: NSMatrix
{
    NSImage	*matrixCache;
    NSImage	*cellCache;
    id  	activeCell;	// Cell currently move using the Control key

    id  	delegate;
}

- (id)initCellClass:aCellClass;
- (void)calcCellSize;

- (NSCell*)makeCellAtRow:(int)row column:(int)col;

- (void)mouseDown:(NSEvent *)theEvent;
- (void)shuffleCell:(int)row to:(int)newRow;
- (void)drawRect:(NSRect)rect;

- (void)setupCache;
- (NSImage*)sizeCache:(NSImage*)cacheWindow to:(NSSize)windowSize;

- (void)setDelegate:(id)anObject;
- (id)delegate;

- (void)dealloc;

@end


@interface PossibleDelegate: NSObject
{}

- (void)matrixDidShuffleCellFrom:(int)row to:(int)newRow;

@end

#endif // VHF_H_MOVEMATRIX
