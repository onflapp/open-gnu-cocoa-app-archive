/* VText.h
 * 2-D Text object
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:  Georg Fleischmann
 *
 * created:  1996-02-15
 * modified: 2010-07-28 (+valueForKey:inArray:)
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

#ifndef VHF_H_VTEXT
#define VHF_H_VTEXT

#include "VGraphic.h"
#include "VPath.h"

#define	PTS_TEXT        8

#define PT_LOWERLEFT    0
#define	PT_MIDLEFT      1
#define	PT_UPPERLEFT    2
#define	PT_LOWERMID     3
#define	PT_LOWERRIGHT   4
#define	PT_MIDRIGHT     5
#define	PT_UPPERRIGHT   6
#define	PT_UPPERMID     7

@interface VText:VGraphic
{
    NSMutableAttributedString   *attributedString;  // text (attributes string)
    NSFont          *font;          // the font object
    float           rotAngle;       // the rotation angle
    float           aspectRatio;	// aspect ratio
    NSRect          bounds;         // text box
    BOOL            filled;
    BOOL            isSerialNumber;	// YES if we behave like a serial number */
    BOOL            fitHorizontal;	// YES if we size horizontally to fit */
    BOOL            centerVertical;	// YES if we center vertical */
    id              editView;
    id              textPath;       // to inform possible textPath of end editing
    id              graphicView;
    NSRect          lastEditingFrame;
    NSMutableArray	*serialStreams;	// holds the output streams for serial numbers
    NSColor         *fillColor;     // fillColor if we are filled
    NSColor         *endColor;      // endColor if we are graduated/radial filled
    float           graduateAngle;	// angle of graduate filling
    NSPoint         radialCenter;	// the center position for radial filling in percent to the bounds
    float           stepWidth;      // stepWidth the color will change by graduate/radial filling
}

/* class methods */
+ (VText*)textGraphic;
+ (NSTextView*)sharedText;
+ (NSString*)valueForKey:(NSString*)key inArray:(NSArray*)array;

/* text methods */
- (NSColor*)fillColor;
- (void)setFillColor:(NSColor*)col;
- (NSColor*)endColor;
- (void)setEndColor:(NSColor*)col;
- (float)graduateAngle;
- (void)setGraduateAngle:(float)a;
- (void)setRadialCenter:(NSPoint)rc;
- (NSPoint)radialCenter;
- (void)setStepWidth:(float)sw;
- (float)stepWidth;
- (void)setTextPath:tPath;

- (NSString*)string;
- (void)setString:(NSString*)string;
- (void)setString:(NSString*)string lineHeight:(float)lineHeight;
- (void)setString:(NSString*)string font:(NSFont*)aFont color:(NSColor*)aColor;
- (void)setString:(NSString*)string font:(NSFont*)aFont lineHeight:(float)lineHeight color:(NSColor*)aColor;
- (void)setAlignment:(NSTextAlignment)mode;
- (void)sizeToFit;
- (void)replaceTextWithString:(NSString*)string;
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString*)string;
- (void)replaceSubstring:(NSString*)substring withString:(NSString*)string;
- (void)setAttributedString:(NSAttributedString*)as;
- (NSAttributedString*)attributedString;

- (void)setRichTextData:(NSData*)theData;
- (NSData*)richTextData;
- (BOOL)edit:(NSEvent*)event in:(id)view;
- (void)setAspectRatio:(float)a;
- (void)setRotAngle:(float)angle;
- (float)rotAngle;
- (void)setBaseOrigin:(NSPoint)p;
- (void)setFont:(NSFont*)aFont;
- (NSFont*)font;
- (NSRect)textBox;		// raw bounds of text box
- (void)setTextBox:(NSRect)rect;
- (float)fontSize;
- (void)setFontSize:(float)v;
- (float)lineHeight;
- (void)setLineHeight:(float)v;
- (BOOL)centerVertical;
- (void)setCenterVertical:(BOOL)flag;
- (BOOL)fitHorizontal;
- (void)setFitHorizontal:(BOOL)flag;
- (void)kernToFitHorizontal;
- (void)setKerning:(float)v;
- (float)kerning;
- (id)getFlattenedObject;

- (int)stringLength;		// number of characters
- (float)characterOffsetAtIndex:(int)ix;
- (NSRect)boundingRectAtIndex:(int)ix;
- (VText*)subTextWithRange:(NSRange)range;

- (void)setSerialNumber:(BOOL)flag;
- (BOOL)isSerialNumber;
- (void)incrementSerialNumberBy:(int)o;
- (void)drawSerialNumberAt:(NSPoint)p withOffset:(int)o;

- (void)setSerialTextFor:(NSTextView*)drawText withOffset:(int)o setData:(BOOL)setData;
- (id)getFlattenedObjectAt:(NSPoint)position withOffset:(int)o;
- (VPath*)pathRepresentation;

@end

#endif // VHF_H_VTEXT
