/* VImage.h
 *
 * Copyright (C) 1996-2008 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1998-03-22
 * modified: 2008-07-20 (+fileExtensionForFileType)
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

#ifndef VHF_H_VIMAGE
#define VHF_H_VIMAGE

#include "VGraphic.h"
#include "VPath.h"

#define PTS_IMAGE	4
#define PT_LL		0
#define PT_UL		1
#define PT_UR		2   // changed 2008-06-08
#define PT_LR		3

#ifdef GNUSTEP_BASE_VERSION
#    define USE_VHF_CLIPPING	YES
#endif

typedef enum
{
    VImageBMP           = 1,	// BMP
    VImageGIF           = 2,	// GIF
    VImageJPEG          = 3,	// JPEG
    VImagePNG           = 4,	// PNG
    VImageTIFF_None     = 10,	// TIFF
    VImageTIFF_LZW      = 11,	// TIFF LZW
    VImageTIFF_PackBits = 12	// TIFF pack bits
    //VImageTIFF_CMYK     = 20	// TIFF CMYK (LZW or No compression)
} VImageFileType;

@interface VImage:VGraphic
{
    NSPoint     origin;
    NSSize      size;
    NSImage     *image;
    NSString    *imageFile;     // file NSImage is stored to
    NSString    *sourcePath;    // our source path where we load the image
    NSSize      originalSize;   // the original size
    int         selectedKnob;   // index of the selected knob (0 - 3 or -1)
    int         identifier;
    BOOL        thumbnail;
    NSImage     *thumbImage;
    VGraphic    *clipPath;
    int         fileType;       // the file type (tiff, jpg, gif, etc.)
    float       compressionFactor;
    BOOL        compressionDirty;
#ifdef USE_VHF_CLIPPING
    NSImage     *clipImage;     // we save the clip image, because it so slow
#endif
}

/* class methods */
+ (NSString*)fileExtensionForFileType:(VImageFileType)fileType;
+ (BOOL)isAcceptedFileType:(VImageFileType)fileType;

/* image methods */
- (id)initWithPasteboard:(NSPasteboard *)pboard;
- (id)initWithFile:(NSString *)file;
- (id)initWithRepresentations:(NSArray*)reps;

- (void)setImage:(NSImage*)nImage;
- (NSImage*)image;

//- (void)setVertices:(NSPoint)origin :(NSPoint)size;
//- (void)getVertices:(NSPoint*)origin :(NSPoint*)size;
- (float)naturalAspectRatio;
- (void)setSize:(NSSize)size;
- (NSSize)size;
- (NSSize)originalSize;
- (void)setOrigin:(NSPoint)origin;
- (NSPoint)origin;
- (NSString*)setName:(NSString*)str;
- (NSString*)name;
- (void)setThumbnail:(BOOL)flag;
- (BOOL)thumbnail;
- (void)setFileType:(VImageFileType)type;
- (VImageFileType)fileType;
- (void)setCompressionFactor:(float)f;
- (float)compressionFactor;
- (id)clipPath;
- (int)selectedKnobIndex;
- (void)join:obj;

- (void)writeFilesToDirectory:(NSString*)directory;

@end

#endif // VHF_H_VIMAGE
