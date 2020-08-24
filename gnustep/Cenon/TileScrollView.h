/*
 * TileScrollView.h
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author: Georg Fleischmann
 *
 * Created:  1993
 * Modified: 2012-08-13 (scaleFactor is VFloat now)
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

#ifndef VHF_H_TILESCROLLVIEW
#define VHF_H_TILESCROLLVIEW

#include <AppKit/AppKit.h>
#include <VHFShared/types.h>

@interface TileScrollView:NSScrollView
{
    id		box;
    id		resPopupListButton;
    id		document;
    VFloat	oldScaleFactor;
}

/* instance methods */
- initWithFrame:(NSRect)theFrame;
- (void)setDocument:docu;
- (void)zoomIn:sender;
- (void)zoomOut:sender;
- (void)magnify:sender;
- (void)magnifyRegion:(NSRect)region;
- (void)changeScale:sender;
- (float)scaleFactor;
- (void)tile;
- (void)setDocumentView:(NSView *)aView;

@end

@interface possibleDocument:NSObject
- (void)scale:(float)x :(float)y withCenter:(NSPoint)center;
- (void)setMagnify:(BOOL)flag;
@end

#endif // VHF_H_TILESCROLLVIEW
