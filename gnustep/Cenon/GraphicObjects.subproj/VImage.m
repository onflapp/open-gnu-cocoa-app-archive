/* VImage.m
 *
 * Copyright (C) 1996-2012 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1998-03-22
 * modified: 2012-01-30 (-drawWithPrincipal: if principal is nil -> set scale = 1.0)
 *           2010-04-14 (-initWithRepresentations: 10.6 keep image size despite using rep size)
 *           2010-02-25 (-initWithRepresentations: workaround for Mac OS 10.6 problem with image sizes < pixel size)
 *           2010-01-29 (-writeFilesToDirectory: modified type converion to work with Mac OS 10.6)
 *           2008-12-01 (-drawWithPrincipal: relief draw pale)
 *           2008-07-20 (other file types added)
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

#include <AppKit/AppKit.h>
#include "VImage.h"
#include "PathContour.h"
#include "../App.h"
#include "../DocView.h"
#include "../DocWindow.h"
#include "../Inspectors.h"
#include "../messages.h"

static int currentGraphicIdentifier = 1;

@interface VImage(PrivateMethods)
- (void)setParameter;
@end

@implementation VImage

/* Locking focus on an NSImage forces it to draw and thus verifies
 * whether there are any PostScript or TIFF errors in the source of
 * the image. lockFocus returns YES only if there are no errors.
 */
static BOOL checkImage(NSImage *anImage)
{
    if ([anImage isValid])
    {
        [anImage lockFocus];
        [anImage unlockFocus];
        return YES;
    }
    return NO;
}

#if defined(GNUSTEP_BASE_VERSION) || defined(__APPLE__) // GNUstep, Apple
static NSBitmapImageFileType fileTypeFromVImageType(VImageFileType fileType)
{
    switch (fileType)
    {
        case VImageTIFF_None:
        case VImageTIFF_LZW:
        case VImageTIFF_PackBits: return NSTIFFFileType;
        case VImageBMP:           return NSBMPFileType;
        case VImageGIF:           return NSGIFFileType;
        case VImageJPEG:          return NSJPEGFileType;
        case VImagePNG:           return NSPNGFileType;
    }
    return NSTIFFFileType;
}
static NSDictionary *propertiesForFileType(VImageFileType fileType, float compressionFactor)
{   NSMutableDictionary	*dict = [NSMutableDictionary dictionary];

    switch (fileType)
    {
        case VImageTIFF_None:
            [dict setObject:[NSNumber numberWithInt:NSTIFFCompressionNone] forKey:NSImageCompressionMethod];
            break;
        case VImageTIFF_LZW:
            [dict setObject:[NSNumber numberWithInt:NSTIFFCompressionLZW] forKey:NSImageCompressionMethod];
            break;
        case VImageTIFF_PackBits:
            [dict setObject:[NSNumber numberWithInt:NSTIFFCompressionPackBits] forKey:NSImageCompressionMethod];
            break;
        case VImageBMP:
            break;
        case VImageGIF:
            break;
        case VImageJPEG:
            [dict setObject:[NSNumber numberWithFloat:compressionFactor] forKey:NSImageCompressionFactor];
            break;
        case VImagePNG:
            break;
    }
    return dict;
}
#endif

+ (NSString*)fileExtensionForFileType:(VImageFileType)type
{
    switch (type)
    {
        default:
        case VImageTIFF_None:
        case VImageTIFF_LZW:
        case VImageTIFF_PackBits: return @"tiff";
        case VImageBMP:           return @"bmp";
        case VImageGIF:           return @"gif";
        case VImageJPEG:          return @"jpg";
        case VImagePNG:           return @"png";
    }
    return nil;
}
static NSTIFFCompression tiffCompressionFromVImageType(VImageFileType fileType)
{
    switch (fileType)
    {
        case VImageTIFF_LZW:      return NSTIFFCompressionLZW;
        case VImageTIFF_PackBits: return NSTIFFCompressionPackBits;
        default:                  return NSTIFFCompressionNone;
    }
    return NSTIFFCompressionNone;
}
static VImageFileType fileTypeForTIFFCompression(NSTIFFCompression tiffCompression)
{
    switch (tiffCompression)
    {
        case NSTIFFCompressionLZW:      return VImageTIFF_LZW;
        case NSTIFFCompressionPackBits: return VImageTIFF_PackBits;
        default:                        return VImageTIFF_None;
    }
    return VImageTIFF_None;
}

/* This sets the class version so that we can compatibly read old objects out of an archive.
 */
+ (void)initialize
{
    [VImage setVersion:4];
    return;
}

/* return accepted file type for platform */
+ (BOOL)isAcceptedFileType:(VImageFileType)type
{
    switch (type)
    {
#if defined(GNUSTEP_BASE_VERSION)
        case VImageTIFF_LZW:      return NO;
        default:                  return YES;
#elif defined(__APPLE__)
        default:                  return YES;
#else
        case VImageTIFF_None:
        case VImageTIFF_LZW:
        case VImageTIFF_PackBits: return YES;
        default:                  return NO;
#endif
    }
    return YES;
}

/* initialize
 */
- init
{
    [super init];
    identifier = currentGraphicIdentifier++;
    [self setParameter];
    return self;
}

- (NSString*)title		{ return @"Image"; }

/*
 * Creates a new NSImage and sets it to be scalable and to retain
 * its data (which means that when we archive it, it will actually
 * write the TIFF or PostScript data into the stream).
 */
- (id)initWithPasteboard:(NSPasteboard *)pboard;
{
    [self init];

    if (pboard)
    {
	image = [NSImage allocWithZone:(NSZone *)[self zone]];
	if ((image = [image initWithPasteboard:pboard]))
        {
	    [image setDataRetained:YES];
	    if (checkImage(image))
            {
		originalSize = [image size];
		[image setScalesWhenResized:YES];
		size = originalSize;
		return self;
	    }
	}
    }
    [self release];
    return nil;
}

/*
 * Creates an NSImage by reading data from an .eps or .tiff file.
 */
- (id)initWithFile:(NSString *)file
{
    return [self initWithRepresentations:[NSImageRep imageRepsWithContentsOfFile:file]];
}

/*
 * Creates an NSImage from existing representation
 * modified: 2010-04-14 (Mac OS 10.6: keep image size despite using rep size)
 */
- (id)initWithRepresentations:(NSArray*)reps
{   NSSize  scaledSize = NSZeroSize;

    [self init];

#ifdef __APPLE__    // workaround 10.6: if image size < pixel-size, only an image of size was loaded
    if ( NSAppKitVersionNumber >= NSAppKitVersionNumber10_6 &&
         [reps count] && [[reps objectAtIndex:0] isKindOfClass:[NSBitmapImageRep class]] )
    {   NSImageRep  *rep = [reps objectAtIndex:0];

        if ( [rep size].width != [rep pixelsWide] || [rep size].height != [rep pixelsHigh] )
        {   scaledSize = [rep size];
            [rep setSize:NSMakeSize([rep pixelsWide], [rep pixelsHigh])];
        }
    }
#endif

    image = [[NSImage allocWithZone:(NSZone *)[self zone]] init];
    [image addRepresentations:reps];
    [image setDataRetained:YES];
    if (checkImage(image))
    {   originalSize = [image size];
        [image setScalesWhenResized:YES];
        size = (scaledSize.width > 0.0) ? scaledSize : originalSize;
        return self;
    }
    [self release];
    return nil;
}

- copy
{   VImage *nImage = [[VImage allocWithZone:[self zone]] init];

    [nImage setImage:[image copy]];
    [nImage setSize:size];
    [nImage setOrigin:origin];
    //[nImage setParameter]; // init call it
    [nImage setThumbnail:thumbnail];
    [nImage setFileType:fileType];
    [nImage setCompressionFactor:compressionFactor];
    if (clipPath)
        [nImage join:clipPath];
    return nImage;
}

- (void)setImage:(NSImage*)nImage
{
    if ( image )
        [image release];
#ifdef USE_VHF_CLIPPING
    [clipImage release]; clipImage = nil;
#endif
    image = [nImage retain];
    originalSize = [image size];
    dirty = YES;
}
- (NSImage*)image	{ return image; }

/*
 * created: 1995-09-25
 * purpose: initializes all the stuff needed after a -read:
 */
- (void)setParameter
{
    selectedKnob = -1;
    clipPath = nil;
    thumbnail = NO;
    imageFile = [[NSString stringWithFormat:@"Image%d.tiff", identifier] retain];
    [self setLabel:[imageFile stringByDeletingPathExtension]];
    sourcePath = nil;
    fileType = VImageTIFF_LZW;
    compressionFactor = 0.9;
    compressionDirty = NO;
}

- (float)naturalAspectRatio
{
    if (!originalSize.height)
        return 0.0;
    return originalSize.width / originalSize.height;
}

- (void)setSize:(NSSize)newSize         { size = newSize; dirty = YES; }
- (NSSize)size                          { return size; }
- (NSSize)originalSize                  { return originalSize; }

- (void)setOrigin:(NSPoint)newOrigin    { origin = newOrigin; dirty = YES; }
- (NSPoint)origin                       { return origin; }

/* this sets the file name (extension) and label (no extension)
 */
- (NSString*)setName:(NSString*)str
{   NSString    *ext = [VImage fileExtensionForFileType:fileType];

    [imageFile release];
    if ( ! [[str pathExtension] isEqual:ext] )  // set correct path extension
        imageFile = [[[str stringByDeletingPathExtension] stringByAppendingPathExtension:ext] retain];
    else
        imageFile = [[NSString stringWithString:str] retain];

    /* set label to same name but without extension */
    if ( [str pathExtension] )
        [self setLabel:[str stringByDeletingPathExtension]];
    else
        [self setLabel:str];

    return imageFile;
}

- (NSString*)name			{ return imageFile; }

- (NSImage*)thumbnailImage
{   int			i;
    NSArray		*imageReps;
    NSBitmapImageRep	*bmImageRep = nil;

    /* get bitmap of image */
    imageReps = [image representations];
    for (i=0; i<(int)[imageReps count]; i++)
    {   id	bitmapRep = [imageReps objectAtIndex:i];

        if ( [bitmapRep isKindOfClass:[NSBitmapImageRep class]] )
        {   bmImageRep = bitmapRep;
            break;
        }
    }
    if (bmImageRep)
    {   int		y, x, bps, bppixel, bpr, ha, pl, bypplane, spp, oRows, rows, bitspr, columns;
        long			abypplane, lx, ly, abpr, oColumns;
        unsigned char		*data[5], *aplanes[5];
        float			xf, yf;
        NSString		*csname;
        NSImage			*aImage;
        NSBitmapImageRep	*abitmap;

        /* analyse bitmap (mash planar 234 components) */
        bypplane = [bmImageRep bytesPerPlane];
        bpr = [bmImageRep bytesPerRow];
        bitspr = bpr * 8;
        bppixel = [bmImageRep bitsPerPixel];
        bps = [bmImageRep bitsPerSample];
        spp = [bmImageRep samplesPerPixel];
        ha = [bmImageRep hasAlpha];
        pl = [bmImageRep isPlanar];
        csname = [bmImageRep colorSpaceName];
        if ( !pl )
            data[0] = [bmImageRep bitmapData];
        else
            [bmImageRep getBitmapDataPlanes:data];

        oRows = [bmImageRep pixelsHigh];
        oColumns = [bmImageRep pixelsWide];
        columns = floor(size.width); // rect.size.width
        rows = floor(size.height);

        aImage = [[NSImage allocWithZone:(NSZone *)[self zone]] initWithSize:NSMakeSize(columns, rows)];
        /* create image with 1, 2, 3 or 4 planes -> W (1), WA (2), RGB (3) or RGBA (4) */
        abitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                          pixelsWide:columns
                                                          pixelsHigh:rows
                                                       bitsPerSample:bps
                                                     samplesPerPixel:(spp <= 4) ? spp : 4
                                                            hasAlpha:ha isPlanar:YES
                                                      colorSpaceName:((spp == 1) ? NSCalibratedWhiteColorSpace
                                                                                 : csname)
                                                         bytesPerRow:(columns*bps)/8
                                                        bitsPerPixel:bps];
        [abitmap getBitmapDataPlanes:aplanes];
        abpr = [abitmap bytesPerRow];
        abypplane = [abitmap bytesPerPlane];

        xf = ((float)oColumns/columns); // imageSize.   -2
        yf = ((float)oRows/rows);
        // ly = 0
        for (y=0, ly=((int)yf/2.0); y<rows && ly < oRows; y++,
             ly+=((yf*y)-((int)(yf*y))>=(yf*(y-1))-((int)(yf*(y-1))))?((int)yf):((int)yf+1))
        {   long	by = abypplane - (y * abpr) - abpr; // part height
            long	lby = bypplane - (ly * bpr) - bpr; // original heigt
            // lx = 0
            for (x=0, lx=((int)xf/2.0); x<abpr && lx < bpr; x++,
                 lx+=((xf*x)-((int)(xf*x))>=(xf*(x-1))-((int)(xf*(x-1))))?((int)xf):((int)xf+1))
            {
                *((aplanes[0]+by+x)) = (pl) ? *((data[0]+lby+lx)) : *((data[0]+lby+lx*spp)); // r || c
                if (spp > 2) // g b || m y
                {   *((aplanes[1]+by+x)) = (pl) ? *((data[1]+lby+lx)) : *((data[0]+lby+lx*spp+1));
                    *((aplanes[2]+by+x)) = (pl) ? *((data[2]+lby+lx)) : *((data[0]+lby+lx*spp+2));
                    if (!ha && spp > 3) // k
                        *((aplanes[3]+by+x)) = (pl) ? *((data[3]+lby+lx)) : *((data[0]+lby+lx*spp+3));
                }
                if (ha)
                    *((aplanes[(spp == 4) ? 3:1]+by+x)) =
                        (pl) ? *((data[((spp == 4) ? 3:1)]+lby+lx)) : *((data[0]+lby+lx*spp+((spp == 4) ? 3:1)));
            }
        }
        [aImage addRepresentation:abitmap];
        [abitmap release];
        [aImage setDataRetained:YES];
        if (checkImage(aImage))
            [aImage setScalesWhenResized:YES];
        else
        {   [aImage release];
            return nil;
        }
        return aImage;
    }
    return nil;
}
- (void)setThumbnail:(BOOL)flag
{   NSString	*filename = [[[[[self class] currentView] document] filename]
                             stringByAppendingPathComponent:[imageFile lastPathComponent]];

#ifdef USE_VHF_CLIPPING
    [clipImage release]; clipImage = nil;
#endif

    thumbnail = flag;
    dirty = YES;
    /* if YES create thumbnail */
    if (thumbnail)
    {
        if ((thumbImage = [self thumbnailImage]))
        {
            originalSize = [thumbImage size];
            if ([[NSFileManager defaultManager] fileExistsAtPath:filename])
            {   /* file allready saved -> release */
                [image release];
                image = nil;
            }
        }
        else
            thumbnail = NO;
    }
    else if (!image) // load image from file
    {	NSArray	*reps = nil;

        if ([[NSFileManager defaultManager] fileExistsAtPath:filename])
            reps = [NSImageRep imageRepsWithContentsOfFile:filename];
        else if ([[NSFileManager defaultManager] fileExistsAtPath:sourcePath])
            reps = [NSImageRep imageRepsWithContentsOfFile:sourcePath];
        if (reps)
        {
            image = [[NSImage allocWithZone:(NSZone *)[self zone]] init];
            [image addRepresentations:reps];
            [image setDataRetained:YES];
            if (checkImage(image))
            {
                originalSize = [image size];
                [image setScalesWhenResized:YES];
            }
            else
            {   [image release];
                image = nil;
            }
        }
    }
    if (!thumbnail && thumbImage)
    {   [thumbImage release];
        thumbImage = nil;
    }
}
- (BOOL)thumbnail                           { return thumbnail; }

- (void)setFileType:(VImageFileType)type
{   NSString    *ext = [[self class] fileExtensionForFileType:type];

    fileType = type;
    compressionDirty = YES;
    if ( ! [[imageFile pathExtension] isEqual:ext] )  // set correct path extension
    {   NSString    *name = [[imageFile stringByDeletingPathExtension] stringByAppendingPathExtension:ext];
        [self setName:name];
    }
}
- (VImageFileType)fileType;                 { return fileType; }
- (void)setCompressionFactor:(float)f;      { compressionFactor = f; compressionDirty = YES; }
- (float)compressionFactor;                 { return compressionFactor; }

- (id)clipPath                              { return clipPath; }

/*
 * subclassed methods
 */

/* returns the selected knob or -1
 */
- (int)selectedKnobIndex
{
    return selectedKnob;
}

/* set the selection of the plane
 */
- (void)setSelected:(BOOL)flag
{
    if (!flag)
        selectedKnob = -1;
    [super setSelected:flag];
}

- (void)scale:(float)x :(float)y withCenter:(NSPoint)cp
{
    if (clipPath)
        [clipPath scale:x :y withCenter:cp];
    origin.x = ScaleValue(origin.x, cp.x, x);
    origin.y = ScaleValue(origin.y, cp.y, y);
    size.width *= x;
    size.height *= y;
    dirty = YES;
}

- (void)join:obj
{
    if (clipPath)
        [clipPath release];
    if ([obj isMemberOfClass:[VRectangle class]] && [obj radius])
        clipPath = [[obj pathRepresentation] retain];
    else
        clipPath = [obj retain];
}

/* dissolve ourself to ulist
 */
- (void)splitTo:ulist
{
    if (!clipPath)
    {   [ulist addObject:self];
        return;
    }
    [ulist addObject:self]; // 2008-06-08: moved before clipPath in ulist
    [clipPath setSelected:YES];
    [clipPath setDirty:YES];
    [ulist addObject:clipPath];
    [self setSelected:YES];
    [self setDirty:YES];
    [clipPath release]; clipPath = nil;
#ifdef USE_VHF_CLIPPING
    [clipImage release]; clipImage = nil;
#endif
}

/* antialiasing for OpenStep and GNUstep
 * 8 bits per sample only
 */
#ifndef __APPLE__
void antialiasColorFromBits(unsigned char **data, int byteY, int px, int bps, int spp, BOOL p, NSString *colorSpaceName, int bits, int bpr, long *rgba)
{   long	x, y, cr=0, cg=0, cb=0, ca=0;

    if (p)
    {   int	add;

        for (y=0; y<bits; y++)
        {
            for (x=0; x<bits; x++)
            {
                add = byteY+px+x-y*bpr;
                cr += *(data[0]+add); // x*bsp/8 -> (x*(8/8))
                if (spp > 2) // rgb
                {   cg += *(data[1]+add);
                    cb += *(data[2]+add);
                    if (spp > 3) // rgba || cmyk
                        ca += *(data[3]+add);
                }
                if (spp == 2) // bwa
                    ca += *(data[1]+add);
            }
        }
    }
    else // meshed
    {   int	add;

        for (y=0; y<bits; y++)
        {
            for (x=0; x<bits; x++)
            {
                add = byteY+px+x*spp-y*bpr;
                cr += *((data[0]+add)); // spp+bsp/8 -> (spp*(8/8))
                if (spp > 2) // rgb
                {
                    cg += *((data[0]+add+1));
                    cb += *((data[0]+add+2));
                    if (spp > 3) // rgba || cmyk
                        ca += *((data[0]+add+3));
                }
                if (spp == 2) // bwa
                    ca += *((data[0]+add+1));
            }
        }
    }
    // middle color of all bits*bits pixels
    rgba[0] = (float)cr/(float)(bits*bits);
    rgba[1] = (float)cg/(float)(bits*bits);
    rgba[2] = (float)cb/(float)(bits*bits);
    rgba[3] = (float)ca/(float)(bits*bits);
}

- (BOOL)compositeAntialiased:(float)scale toPoint:(NSPoint)p
{   NSPoint		imageScale;
    int			i;
    float		sumScale = 1.0, pW, pH;
    NSArray		*imageReps;
    NSBitmapImageRep	*bmImageRep = nil;

    /* get bitmap of image */
    imageReps = [image representations];
    for (i=0; i<(int)[imageReps count]; i++)
    {   id	bitmapRep = [imageReps objectAtIndex:i];

        if ( [bitmapRep isKindOfClass:[NSBitmapImageRep class]] )
        {   bmImageRep = bitmapRep;
            break;
        }
    }
    if (bmImageRep)
    {   pW = [bmImageRep pixelsWide];
        pH = [bmImageRep pixelsHigh];
    }
    else
        return NO;
    /* antialiase image ? */
    imageScale.x = size.width / pW; // originalSize.width;
    imageScale.y = size.height / pH; // originalSize.height;
    sumScale = 1 / (imageScale.x * scale);
    if ( Diff(imageScale.x, imageScale.y) < TOLERANCE && (sumScale-floor(sumScale)) < TOLERANCE &&
         sumScale >= 2 && sumScale <= 20 )
    {   int			bits = sumScale;
        int			y, x, bps, bppixel, bpr, ha, pl, bypplane, spp, oRows, rows, bitspr, columns;
        long			abypplane, lx, ly, rgba[4];
        unsigned char		*data[5], *aplanes[5];
        NSString		*csname;
        NSImage			*aImage;
        NSBitmapImageRep	*abitmap;

        /* analyse bitmap (mash planar 2,3,4 components) */
        bypplane = [bmImageRep bytesPerPlane];
        bpr = [bmImageRep bytesPerRow];
        bitspr = bpr * 8;
        bppixel = [bmImageRep bitsPerPixel];
        bps = [bmImageRep bitsPerSample];
        if (bps != 8)
            return NO;
        spp = [bmImageRep samplesPerPixel];
        ha = [bmImageRep hasAlpha];
        pl = [bmImageRep isPlanar];
        csname = [bmImageRep colorSpaceName];
        if ( !pl )
            data[0] = [bmImageRep bitmapData];
        else
            [bmImageRep getBitmapDataPlanes:data];

        /* antialias bitmap with factor bits */
        oRows = bypplane / bpr;	// rows (original height)
        rows = oRows / bits;	// rows of antialiased image
        columns = (pl) ? (bpr / bits) : ((bpr/spp) / bits);
        bitspr -= ((pl)?(bits*bps):(bits*spp*bps))/2;

        aImage = [[NSImage allocWithZone:(NSZone *)[self zone]] initWithSize:NSMakeSize(columns, rows)];
        /* create image with 1, 2, 3 or 4 planes -> W (1), WA (2), RGB (3) or RGBA (4) */
        abitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                          pixelsWide:columns
                                                          pixelsHigh:rows
                                                       bitsPerSample:8
                                                     samplesPerPixel:(spp <= 4) ? spp : 4
                                                            hasAlpha:ha isPlanar:YES
                                                      colorSpaceName:(spp == 1) ? NSCalibratedWhiteColorSpace
                                                                                : csname
                                                         bytesPerRow:columns
                                                        bitsPerPixel:8];
        [abitmap getBitmapDataPlanes:aplanes];
        abypplane = rows*columns;

        for (y=0, ly=0; y<oRows && ly < rows; y+=bits, ly++)
        {   long	byteY = bypplane - (y * bpr) - bpr; // up is down
            long	by = abypplane - (ly * columns) - columns; // anitaliased height

            for (x=0, lx=0; x<bitspr && lx<columns; x+=(pl)?(bits*bps):(bits*spp*bps), lx++)
            {
                antialiasColorFromBits(data, byteY, x/8, bps, spp, pl, csname, bits, bpr, rgba);
                *(aplanes[0]+by+lx) = rgba[0];
                if (spp > 2)
                {
                    *(aplanes[1]+by+lx) = rgba[1];
                    *(aplanes[2]+by+lx) = rgba[2];
                    if (!ha && spp > 3)
                        *(aplanes[3]+by+lx) = rgba[3];
                }
                if (ha)
                    *(aplanes[(spp == 4) ? 3 : 1]+by+lx) = rgba[3];
            }
        }
        [aImage addRepresentation:abitmap];
        [aImage compositeToPoint:p operation:NSCompositeSourceOver];
        [aImage release];
        [abitmap release];
        return YES;
    }
    return NO;
}
#endif	// OpenStep + GNUstep

- (BOOL)compositeInRect:(NSRect)rect toPoint:(NSPoint)p withScale:(float)scale
{   int			i;
    NSArray		*imageReps;
    NSBitmapImageRep	*bmImageRep = nil;

    if (!rect.size.width || !rect.size.height)
        return NO;

    /* get bitmap of image */
    imageReps = [((thumbImage && VHFIsDrawingToScreen())?thumbImage:image) representations];
    for (i=0; i<(int)[imageReps count]; i++)
    {   id	bitmapRep = [imageReps objectAtIndex:i];

        if ( [bitmapRep isKindOfClass:[NSBitmapImageRep class]] )
        {   bmImageRep = bitmapRep;
            break;
        }
    }
    if (bmImageRep)
    {   int			y, x, bps, bppixel, bpr, ha, pl, bypplane, spp, oRows, rows, bitspr, columns;
        long			abypplane, lx, ly, abpr, oColumns;
        unsigned char		*data[5], *aplanes[5];
        float			xf, yf;
        NSString		*csname;
        NSImage			*aImage;
        NSBitmapImageRep	*abitmap;
        NSSize			imageSize = [((thumbImage && VHFIsDrawingToScreen())?thumbImage:image) size];

        /* analyse bitmap (mash planar 234 components) */
        bypplane = [bmImageRep bytesPerPlane];
        bpr = [bmImageRep bytesPerRow];
        bitspr = bpr * 8;
        bppixel = [bmImageRep bitsPerPixel];
        bps = [bmImageRep bitsPerSample];
        spp = [bmImageRep samplesPerPixel];
        ha = [bmImageRep hasAlpha];
        pl = [bmImageRep isPlanar];
        csname = [bmImageRep colorSpaceName];
        if ( !pl )
            data[0] = [bmImageRep bitmapData];
        else
            [bmImageRep getBitmapDataPlanes:data];

        oRows = [bmImageRep pixelsHigh];
        oColumns = [bmImageRep pixelsWide];
        columns = floor(rect.size.width);
        rows = floor(rect.size.height);

        aImage = [[NSImage allocWithZone:(NSZone *)[self zone]] initWithSize:NSMakeSize(columns, rows)];
        /* create image with 1, 2, 3 or 4 planes -> W (1), WA (2), RGB (3) or RGBA (4) */
        abitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                          pixelsWide:columns
                                                          pixelsHigh:rows
                                                       bitsPerSample:bps
                                                     samplesPerPixel:(spp <= 4) ? spp : 4
                                                            hasAlpha:ha isPlanar:YES
                                                      colorSpaceName:((spp == 1) ? NSCalibratedWhiteColorSpace :
                                                                                   csname)
                                                         bytesPerRow:(((columns*bps)/8.0 > 0.0) ?
                                                                      ((columns*bps)/8.0+1) : ((columns*bps)/8.0))
                                                        bitsPerPixel:bps];
        [abitmap getBitmapDataPlanes:aplanes];
        abpr = [abitmap bytesPerRow];
        abypplane = [abitmap bytesPerPlane];
        xf = ((float)oColumns/imageSize.width);
        yf = ((float)oRows/imageSize.height);

        ly = floor(oRows * ((rect.origin.y-origin.y)*scale/imageSize.height));
        for (y=0; y<rows && ly < oRows; y++,
             ly+=((yf*y)-((int)(yf*y))>=(yf*(y-1))-((int)(yf*(y-1))))?((int)yf):((int)yf+1))
        {   long	by = abypplane - (y * abpr) - abpr; // part height
            long	lby = bypplane - (ly * bpr) - bpr; // original heigt

            lx = floor(((pl) ? (bpr) : (bpr/spp)) * ((rect.origin.x-origin.x)*scale/imageSize.width));
            for (x=0; x<abpr && lx < bpr; x++,
                 lx += ((xf*x)-((int)(xf*x))>=(xf*(x-1))-((int)(xf*(x-1)))) ? ((int)xf) : ((int)xf+1))
            {
                *((aplanes[0]+by+x)) = (pl) ? *((data[0]+lby+lx)) : *((data[0]+lby+lx*spp));
                if (spp>2)
                {   *((aplanes[1]+by+x)) = (pl) ? *((data[1]+lby+lx)) : *((data[0]+lby+lx*spp+1));
                    *((aplanes[2]+by+x)) = (pl) ? *((data[2]+lby+lx)) : *((data[0]+lby+lx*spp+2));
                    if (!ha && spp > 3)
                        *((aplanes[3]+by+x)) = (pl) ? *((data[3]+lby+lx)) : *((data[0]+lby+lx*spp+3));
                }
                if (ha)
                    *((aplanes[(spp == 4) ? 3:1]+by+x)) =
                        (pl) ? *((data[((spp == 4) ? 3:1)]+lby+lx)) : *((data[0]+lby+lx*spp+((spp == 4) ? 3:1)));
            }
        }
        [aImage addRepresentation:abitmap];
        [aImage compositeToPoint:rect.origin operation:NSCompositeSourceOver]; // rect.origin
        [aImage release];
        [abitmap release];
        return YES;
    }
    return NO;
}

/* clip image from clip path
 * this is a workaround for GNUstep (X11), not having a complex clipping
 * we create an alpha image with the clipping path having inside alpha = 1.0
 * We return no autoreleased image here !!!
 */
#ifdef USE_VHF_CLIPPING
#define MAX_SIDESTEPS 20	// maximum number of side-steps before giving up
- (NSImage*)clipImage:(NSImage*)anImage withPath:(VGraphic*)cPath scale:(float)scale
{   int			i, cnt;
    NSArray		*imageReps;
    NSBitmapImageRep	*aBitmap = nil, *cBitmap;
    NSImage		*cImage;
    NSString		*csname = nil;
    int			spp, w, h, alphaIx;
    float		y, yMin, yMax;
    NSRect		bRect;
    VLine		*line = [VLine line];
    NSPoint		*pts, p0, p1;
    unsigned char	*planes[5], *aPlanes[5];

    /* get bitmap of image */
    imageReps = [anImage representations];
    for (i=0; i<(int)[imageReps count]; i++)
    {   id	bitmapRep = [imageReps objectAtIndex:i];

        if ( [bitmapRep isKindOfClass:[NSBitmapImageRep class]] )
        {   aBitmap = bitmapRep;
            break;
        }
    }

    /* analyse bitmap (mash planar 2,3,4 components) */
    if ([aBitmap bitsPerSample] != 8)
    {   NSLog(@"VImage, clipImage: unsupported bits per sample %d", [aBitmap bitsPerSample]);
        return nil;
    }
    spp = [aBitmap samplesPerPixel];
    if ([aBitmap hasAlpha])
        spp--; // we dont wont two alpha planes !
    w = [aBitmap pixelsWide];
    h = [aBitmap pixelsHigh];
    csname = [aBitmap colorSpaceName];

    cImage = [[NSImage allocWithZone:(NSZone *)[self zone]] initWithSize:NSMakeSize(w, h)];
    [cImage setScalesWhenResized:YES];
    [cImage setDataRetained:YES];
    /* create image with 1, 2, 3 or 4 planes -> W (1), WA (2), RGB (3) or RGBA (4) */
    cBitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                      pixelsWide:w pixelsHigh:h
                                                   bitsPerSample:8
                                                 samplesPerPixel:(spp == 1) ? 2 : ((spp == 3) ? 4 : 5)
                                                        hasAlpha:YES
                                                        isPlanar:YES
                                                  colorSpaceName:(spp == 1) ? NSDeviceWhiteColorSpace
                                                                            : csname
                                                     bytesPerRow:w
                                                    bitsPerPixel:8];
    //[cBitmap setSize:NSMakeSize(w, h)];
    [cImage addRepresentation:cBitmap];
    [cBitmap release];
    [cBitmap getBitmapDataPlanes:planes];

    /* copy planes of source image to RGB or CMYK or White plane of prepared image rep */
    [aBitmap getBitmapDataPlanes:aPlanes];
    alphaIx = (spp > 2) ? ((spp > 3) ? 4 : 3) : 1;
    for (i=0; i<w*h; i++)
    {
        if ([aBitmap isPlanar])
        {
            *((planes[0]+i)) = *(aPlanes[0]+i);
            if (spp > 2)
            {   *(planes[1]+i) = *(aPlanes[1]+i);
                *(planes[2]+i) = *(aPlanes[2]+i);
                if (spp > 3)
                    *(planes[3]+i) = *(aPlanes[3]+i);
            }
            *(planes[alphaIx]+i) = 0;	// all transparent
        }
        else
        {
            *(planes[0]+i) = *(aPlanes[0]+(i*spp));
            if (spp > 2)
            {   *(planes[1]+i) = *(aPlanes[0]+(i*spp)+1);
                *(planes[2]+i) = *(aPlanes[0]+(i*spp)+2);
                if (spp > 3)
                    *(planes[3]+i) = *(aPlanes[0]+(i*spp)+3);
            }
            *((planes[alphaIx]+i)) = 0;	// all transparent
        }
    }

    /* intersect clip path line by line and set pixel ranges of alpha channel accordingly */
    [cPath scale:w/size.width :h/size.height withCenter:origin];
    bRect = [cPath coordBounds];
    yMin = bRect.origin.y + 0.5;
    yMax = bRect.origin.y + bRect.size.height + 0.5;
    p0.x = bRect.origin.x - 2000.0; p1.x = bRect.origin.x+bRect.size.width + 2000.0;
    for ( y=yMin; y<yMax; y++ )
    {
        for (i=0; i<MAX_SIDESTEPS; i++)	// we need to find a position where we don't hit an edge
        {
            p0.y = p1.y = y + (float)i*(0.5*TOLERANCE);
            [line setVertices:p0 :p1];
            if ( !(cnt = [cPath getIntersections:&pts with:line]) )
                break;
            if ( cnt <= 1 )		// unpossible = tolerance problem in intersection methods
            {	free(pts); pts = NULL;
                continue;
            }
            if ( Even(cnt) &&		// when cnt is even we are probably ok
                 (![cPath isKindOfClass:[VPath class]] ||		// arc or rectangle
                  ![(VPath*)cPath pointArrayHitsCorner:pts :cnt]) )	// make sure we hit no edge
                break;
            if (i < MAX_SIDESTEPS-1)	// try again with side step
            {	free(pts); pts = 0; }
        }
        if ( i >= MAX_SIDESTEPS )
            NSLog(@"VImage (-clipImage:): troubles with extreme path!");
        sortPointArray(pts, cnt, p0);	// sort points from left to right
        if ( cnt <= 1 || !Even(cnt) )	// we hit an edge or other mischief
        {   free(pts); pts = 0;
            continue;
        }

        /* set alpha plane (use 'x/1000db planes[3]' in gdb to examine results) */
        for (i=0; i<cnt-1; i++)
        {   int	j, x0, x1, yi;

            if ( !Even(i) )	// outside of clip path
                continue;
            x0 = Max(pts[i].x   - origin.x, 0.0);
            x1 = Min(pts[i+1].x - origin.x, w);
            yi = h - (int)(y-origin.y);
            if (yi > h || yi < 0)
                break;
            for (j=x0; j<x1; j++)
                *(planes[alphaIx] + yi*w + j) = 255;
        }
    }
    [cPath scale:1.0/(w/size.width) :1.0/(h/size.height) withCenter:origin];
    //[cImage setSize:NSMakeSize(floor(size.width*scale), floor(size.height*scale))];

    return cImage;
}
#endif

- (NSImage*)separateImageWithColor:(NSColor*)sepColor
{   int			i;
    NSArray		*imageReps;
    NSBitmapImageRep	*bmImageRep = nil;

    /* get bitmap of image */
    imageReps = [image representations];
    for (i=0; i<(int)[imageReps count]; i++)
    {   id	bitmapRep = [imageReps objectAtIndex:i];

        if ( [bitmapRep isKindOfClass:[NSBitmapImageRep class]] )
        {   bmImageRep = bitmapRep;
            break;
        }
    }
    if (bmImageRep)
    {   int			y, x, bps, bppixel, bpr, ha, pl, bypplane, spp, rows, bitspr, columns;
        long			sbypplane, sbpr;
        unsigned char		*data[5], *splanes[5];
        NSImage			*sepImage;
        NSBitmapImageRep	*sepbitmap;

        /* analyse bitmap (mash planar 234 components) */
        bypplane = [bmImageRep bytesPerPlane];                             // [bmImageRep colorSpaceName]
        bpr = [bmImageRep bytesPerRow];
        bitspr = bpr * 8;
        bppixel = [bmImageRep bitsPerPixel];
        bps = [bmImageRep bitsPerSample];
        spp = [bmImageRep samplesPerPixel];

        /* draw only in black || rgb never draw in black */
        /* draw white rectangle */
        if ((bps != 8) || ((spp == 1 || spp == 2) && [sepColor blackComponent] == 0.0))
        {
            if (bps != 8)
                NSLog(@"VImage, separateImageWithColor: unsupported bits per sample %d", bps);
            return nil;
        }

        ha = [bmImageRep hasAlpha];
        pl = [bmImageRep isPlanar];
        if ( !pl )
            data[0] = [bmImageRep bitmapData];
        else
            [bmImageRep getBitmapDataPlanes:data];

        rows = [bmImageRep pixelsHigh];
        columns = [bmImageRep pixelsWide];

        sepImage = [[NSImage allocWithZone:(NSZone *)[self zone]] initWithSize:NSMakeSize(columns, rows)];
	[sepImage setScalesWhenResized:YES];
        [sepImage setDataRetained:YES];
        /* create image with 1 planes -> W (1) component */
        sepbitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                          pixelsWide:columns
                                                          pixelsHigh:rows
                                                       bitsPerSample:bps
                                                     samplesPerPixel:1
                                                            hasAlpha:NO isPlanar:YES
                                                      colorSpaceName:NSCalibratedWhiteColorSpace
                                                         bytesPerRow:(columns*bps)/8.0
                                                        bitsPerPixel:bps];
        [sepbitmap getBitmapDataPlanes:splanes];
        sbpr = [sepbitmap bytesPerRow];
        sbypplane = [sepbitmap bytesPerPlane];

        for (y=0; y<rows; y++)
        {   long	by = sbypplane - (y * sbpr) - sbpr; // sepImage height
            long	lby = bypplane - (y * bpr) - bpr; // original heigt

            for (x=0; x < sbpr; x++)
            {   long	c = 0, m = 0, y = 0, k = 0;

                if ([bmImageRep colorSpaceName] == NSCalibratedRGBColorSpace)
                {
                    c = 255 - ((pl) ? *((data[0]+lby+x)) : *((data[0]+lby+x*spp)));
                    m = 255 - ((pl) ? *((data[1]+lby+x)) : *((data[0]+lby+x*spp+1)));
                    y = 255 - ((pl) ? *((data[2]+lby+x)) : *((data[0]+lby+x*spp+2)));

                    if (c >= 253 && m >= 253 && y >= 253)
                    {   /* realy black */
                        c = 127;
                        m = y = 0;
                        k = 255;
                    }
                    else if (Min(c, Min(m, y)) > 1)
                    {   long	min = Min(c, Min(m, y));

                        k = min;
                        c -= min;
                        m -= min;
                        y -= min;
                   }
                }
                if (spp <= 2 && [sepColor blackComponent])
                    *((splanes[0]+by+x)) = (pl) ? *((data[0]+lby+x)) : *((data[0]+lby+x*spp)); // w 255-k
                else if ([bmImageRep colorSpaceName] == NSDeviceCMYKColorSpace && [sepColor blackComponent])
                    *((splanes[0]+by+x)) = 255 - ((pl) ? *((data[3]+lby+x)) : *((data[0]+lby+x*spp+3))); // 255-k
                else if ([sepColor blackComponent])
                    *((splanes[0]+by+x)) = 255 - k;
                else if ([bmImageRep colorSpaceName] == NSDeviceCMYKColorSpace && [sepColor cyanComponent])
                    *((splanes[0]+by+x)) = 255 - ((pl) ? *((data[0]+lby+x)) : *((data[0]+lby+x*spp))); // 255-c
                else if ([sepColor cyanComponent])
                    *((splanes[0]+by+x)) = 255 - c; // was r
                else if ([bmImageRep colorSpaceName] == NSDeviceCMYKColorSpace && [sepColor magentaComponent])
                    *((splanes[0]+by+x)) = 255 - ((pl) ? *((data[1]+lby+x)) : *((data[0]+lby+x*spp+1))); // 255-m
                else if ([sepColor magentaComponent])
                    *((splanes[0]+by+x)) = 255 - m; // was g
                else if ([bmImageRep colorSpaceName] == NSDeviceCMYKColorSpace && [sepColor yellowComponent])
                    *((splanes[0]+by+x)) = 255 - ((pl) ? *((data[2]+lby+x)) : *((data[0]+lby+x*spp+2))); // 255-y
                else if ([sepColor yellowComponent])
                    *((splanes[0]+by+x)) = 255 - y; // was b
            }
        }

        [sepImage addRepresentation:sepbitmap];
        [sepbitmap release];

        return sepImage;
    }
    return nil;
}

/*
 * draws the image
 */
- (void)drawWithPrincipal:principal
{   NSPoint         p;
    NSSize          currentSize;
    NSRect          bounds, rect;
    float           scale = (principal) ? [principal scaleFactor] : 1.0;
    NSBezierPath    *bPath;
    BOOL            releaseImage = NO;
    NSImage         *sepImage = nil; // color separated image

    if (size.width < 1.0 || size.height < 1.0)
        return;

    bounds.origin = origin;
    bounds.size   = size;
    bounds.size.width  *= scale;
    bounds.size.height *= scale;

    [super drawWithPrincipal:principal];	// set color

    if (image || thumbImage)
    {
        if (!VHFIsDrawingToScreen() && !image)
        {
            /* load image */
            if ([[NSFileManager defaultManager] fileExistsAtPath:sourcePath])
            {   image = [[NSImage allocWithZone:(NSZone *)[self zone]] init];
                [image addRepresentations:[NSImageRep imageRepsWithContentsOfFile:sourcePath]];
                [image setDataRetained:YES];
                [image setScalesWhenResized:YES];
                releaseImage = YES;
            }
            else
                return;
        }
        p = origin;
        currentSize = [((thumbImage && VHFIsDrawingToScreen())?thumbImage:image) size];
        if (currentSize.width != bounds.size.width || currentSize.height != bounds.size.height)
        {
            if ([((thumbImage && VHFIsDrawingToScreen())?thumbImage:image) scalesWhenResized])
                [((thumbImage && VHFIsDrawingToScreen())?thumbImage:image) setSize:bounds.size];
            else
            {
                p.x = origin.x + floor((bounds.size.width  - currentSize.width)  / 2.0 + 0.5);
                p.y = origin.y + floor((bounds.size.height - currentSize.height) / 2.0 + 0.5);
            }
        }

        /* Color separation
         */
        if (!VHFIsDrawingToScreen() && [principal separationColor])
        {
            if (!(sepImage = [self separateImageWithColor:[principal separationColor]]))
            {
                /* draw white clipPath */
                if (clipPath)
                {   NSColor	*oldFillColor = nil;
                    int		oldFill  = [clipPath filled];
                    float	oldWidth = [clipPath width];

                    [clipPath setWidth:0.0];
                    [clipPath setFilled:1];
                    if (oldFill)
                        oldFillColor = [[(VPath*)clipPath fillColor] retain];
                    [(VPath*)clipPath setFillColor:[NSColor whiteColor]];
                    [clipPath drawWithPrincipal:principal]; // draw the white clipPath
                    [clipPath setFilled:oldFill];
                    [clipPath setWidth:oldWidth];
                    if (oldFill)
                    {   [(VPath*)clipPath setFillColor:oldFillColor];
                        [oldFillColor release];
                    }
                }
                else /* draw a white Rectangle */
                {   [[NSColor whiteColor] set];
                    NSRectFill(bounds);
                }
                if (releaseImage)
                {   [image release];
                    image = nil;
                }
                return;
            }
            currentSize = [sepImage size];
            if (currentSize.width != bounds.size.width || currentSize.height != bounds.size.height)
                [sepImage setSize:bounds.size];
        }

        /* clip and composite image
         */
        if (clipPath) // clip with clipPath gsave
        {
#ifdef USE_VHF_CLIPPING
            /* GNUstep (X11) doesn't support complex clipping
             * so we clip our image ourself
             * FIXME: We should do the complex clip only, if we have a complex path (?)
             */
            if (VHFIsDrawingToScreen())
            {
                if (sepImage /*&& !VHFIsDrawingToScreen() && [principal separationColor]*/)
                {   NSImage	*sepClipImage=nil;

                    if ( (sepClipImage = [self clipImage:sepImage withPath:clipPath scale:scale]) )
                    {   [sepClipImage setSize:NSMakeSize(floor(size.width*scale), floor(size.height*scale))];
                        [sepClipImage compositeToPoint:p operation:NSCompositeSourceOver];
                        [sepClipImage release];
                    }
                    [sepImage release];
                    return;
                }
                if ( clipImage ||
                     (clipImage = [self clipImage:((thumbImage) ? thumbImage : image)
                                         withPath:clipPath scale:scale]) )
                {
                    [clipImage setSize:NSMakeSize(floor(size.width*scale), floor(size.height*scale))];
                    [clipImage compositeToPoint:p operation:NSCompositeSourceOver];
                    return;
                }
            }
#endif
            bPath = [NSBezierPath bezierPath];
            PSgsave();
            [bPath setLineWidth:0.0];
            [bPath setLineCapStyle:NSRoundLineCapStyle];
            [bPath setLineJoinStyle:NSRoundLineJoinStyle];
            if ([clipPath isMemberOfClass:[VPath class]])
            {   int     i, cnt = [[(VPath*)clipPath list] count];
                NSPoint currentPoint = NSMakePoint(LARGENEG_COORD, LARGENEG_COORD);

                for (i=0; i<cnt; i++)
                    currentPoint = [[[(VPath*)clipPath list] objectAtIndex:i] appendToBezierPath:bPath
                                                                            currentPoint:currentPoint];
            }
            else
            {   NSPoint	currentPoint = NSMakePoint(LARGENEG_COORD, LARGENEG_COORD);

                currentPoint = [(VLine*)clipPath appendToBezierPath:bPath currentPoint:currentPoint];
            }
            [bPath setWindingRule:NSEvenOddWindingRule];
            [bPath addClip];
        }	// end clipPath
        /* ???
         if ([[image bestRepresentationForDevice:nil] isOpaque])
        {
            [[NSColor whiteColor] set];
            NSRectFill(bounds);
        }*/

        /* display or print
         */
#ifndef __APPLE__	// GNUstep/OpenStep (Apple has antialiasing)
        if (!thumbnail && VHFIsDrawingToScreen() && [self compositeAntialiased:scale toPoint:p])
        {
            if (clipPath)
                PSgrestore();
            return;
        }
#endif
        if ([principal cache] && !sepImage) // not for colorseparation
        {   NSImage	*img = (thumbImage && VHFIsDrawingToScreen()) ? thumbImage : image;

            PSgsave();	// needed for GNUstep
                if ( [principal mustDrawPale] && relief )   //  Relief: draw a light green rect instead
                {   NSColor	*col = [NSColor colorWithCalibratedRed:0.8 green:1.0 blue:0.8 alpha:1.0];

                    [NSBezierPath setDefaultLineCapStyle: NSRoundLineCapStyle];
                    [NSBezierPath setDefaultLineJoinStyle:NSRoundLineJoinStyle];
                    [col set];
                    [NSBezierPath fillRect:NSMakeRect(bounds.origin.x, bounds.origin.y, size.width, size.height)];
                }   // FIXME: relief above should be removed and image should be composited pale
                else
                    [img compositeToPoint:p operation:NSCompositeSourceOver];
            PSgrestore();
        }
        /* Color separation
         */
        else if ( (sepImage /*&& !VHFIsDrawingToScreen() && [principal separationColor]*/) ||
                  (bounds.size.width < 10000.0 && bounds.size.height < 10000.0)) // 10000 86000000
        {
            bounds.size = size; // important
#ifdef __APPLE__	// Apple works
            rect = bounds;
#else			// workaround for OpenStep
            rect = NSIntersectionRect(bounds, [principal visibleRect]);
#endif
            if (rect.size.width && rect.size.height)
            {   NSPoint	pOld = p;

                p = rect.origin;
                rect.origin.x = (rect.origin.x - pOld.x)*scale;
                rect.origin.y = (rect.origin.y - pOld.y)*scale;
                rect.size.width  *= scale; // important
                rect.size.height *= scale;

                if (sepImage /*&& !VHFIsDrawingToScreen() && [principal separationColor]*/)
                {   [sepImage compositeToPoint:p fromRect:rect operation:NSCompositeSourceOver];
                    [sepImage release];
                }
                else if ( [principal mustDrawPale] && relief )  // draw a light green rect instead
				{   NSColor	*col = [NSColor colorWithCalibratedRed:0.8 green:1.0 blue:0.8 alpha:1.0];

					[col set];
					//[NSBezierPath fillRect:NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)];
					[NSBezierPath fillRect:NSMakeRect(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height)];
				}   // FIXME: relief above should be removed and image should be composited pale
                else
                    [((thumbImage && VHFIsDrawingToScreen()) ? thumbImage : image)
                     compositeToPoint:p fromRect:rect operation:NSCompositeSourceOver];
            }
        }
        /* display huge images with work around
         * openstep doesnt work good if we draw more than 10 000 000 pixels
         * we draw here only the visible part
         */
        else
        {
            bounds.size = size; // important
#ifdef __APPLE__	// Apple works
            //rect = bounds;    // 2011-02-28: seems to be better equal to OpenStep
            rect = NSIntersectionRect(bounds, [principal visibleRect]);
#else			// workaround for OpenStep
            rect = NSIntersectionRect(bounds, [principal visibleRect]);
#endif
            if (rect.size.width && rect.size.height)
            {   rect.size.width *= scale; // important
                rect.size.height *= scale;
                [self compositeInRect:rect toPoint:p withScale:scale];
            }
        }

        /* release print image */
        if (releaseImage)
        {   [image release];
            image = nil;
        }
        //if (dontCache && VHFIsDrawingToScreen())
        //    [image recache];
        if (clipPath)
            PSgrestore();
    }
}

/*
 * Returns the bounds.  The flag variable determines whether the
 * knobs should be factored in. They may need to be for drawing but
 * might not if needed for constraining reasons.
 */
- (NSRect)coordBounds
{   NSPoint	ll, ur;
    NSRect	bRect;

    ll.x = origin.x + ((size.width<0.0) ? size.width : 0.0);
    ll.y = origin.y + ((size.height<0.0) ? size.height : 0.0);
    ur.x = origin.x + ((size.width>0.0) ? size.width : 0.0);
    ur.y = origin.y + ((size.height>0.0) ? size.height : 0.0);

    bRect.origin = ll;
    bRect.size.width  = MAX(ur.x - ll.x, 0.1);
    bRect.size.height = MAX(ur.y - ll.y, 0.1);

    return bRect;
}

/*
 * Returns the bounds with the given rotation.
 */
- (NSRect)boundsAtAngle:(float)angle withCenter:(NSPoint)cp
{   NSPoint	p, ll, ur;
    NSRect	bRect;

    p = origin;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    ll = ur = p;

    p.x = origin.x + size.width;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Min(ur.x, p.x); ll.y = Min(ur.y, p.y);

    p.y = origin.y + size.height;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Min(ur.x, p.x); ll.y = Min(ur.y, p.y);

    p = origin;
    p.y = origin.y + size.height;
    vhfRotatePointAroundCenter(&p, cp, -angle);
    ll.x = Min(ll.x, p.x); ll.y = Min(ll.y, p.y);
    ur.x = Min(ur.x, p.x); ll.y = Min(ur.y, p.y);

    bRect.origin = ll;
    bRect.size.width  = Max(ur.x - bRect.origin.x, 1.0);
    bRect.size.height = Max(ur.y - bRect.origin.y, 1.0);
    return bRect;
}

/*
 * Depending on the pt_num passed in, return the rectangle
 * that should be used for scrolling purposes. When the rectangle
 * passes out of the visible rectangle then the screen should
 * scroll. If the first and last points are selected, then the second
 * and third points are included in the rectangle. If the second and
 * third points are selected, then they are used by themselves.
 */
- (NSRect)scrollRect:(int)pt_num inView:(id)aView
{   float	knobsize;
    NSRect	aRect;

    if (pt_num == -1)
        aRect = [self bounds];
    else
    {	NSPoint	p;

        p = [self pointWithNum:pt_num];
        aRect.origin.x = p.x;
        aRect.origin.y = p.y;
        aRect.size.width = 0;
        aRect.size.height = 0;
    }

    knobsize = -[VGraphic maxKnobSizeWithScale:[aView scaleFactor]]/2.0;
    aRect = NSInsetRect(aRect , knobsize , knobsize);
    return aRect;
}

/* 
 * This method constains the point to the bounds of the view passed
 * in. Like the method above, the constaining is dependent on the
 * control point that has been selected.
 */
- (void)constrainPoint:(NSPoint *)aPt andNumber:(int)pt_num toView:(DocView*)aView
{   NSPoint	viewMax;
    NSRect	viewRect;

    viewRect = [aView bounds];
    viewMax.x = viewRect.origin.x + viewRect.size.width;
    viewMax.y = viewRect.origin.y + viewRect.size.height;

    viewMax.x -= MARGIN;
    viewMax.y -= MARGIN;
    viewRect.origin.x += MARGIN;
    viewRect.origin.y += MARGIN;

    aPt->x = MAX(viewRect.origin.x, aPt->x);
    aPt->y = MAX(viewRect.origin.y, aPt->y);

    aPt->x = MIN(viewMax.x, aPt->x);
    aPt->y = MIN(viewMax.y, aPt->y);
}

/*
 * created:   25.09.95
 * modified:
 * parameter: pt_num	number of vertices
 *            p		the new position in
 * purpose:   Sets a vertice to a new position.
 *            If it is a edge move the vertices with it
 *            Default must be the last point!
 */
- (void)movePoint:(int)pt_num to:(NSPoint)p
{   NSPoint	pc;
    NSPoint	pt;

    /* set point */
    switch (pt_num)
    {
        case PT_LL:	pc = origin; break;
        case PT_UL:	pc.x = origin.x; pc.y = origin.y + size.height; break;
        case PT_LR:	pc.x = origin.x + size.width; pc.y = origin.y; break;
        default:
        case PT_UR:	pc.x = origin.x + size.width; pc.y = origin.y + size.height;
    }

    pt.x = p.x - pc.x;
    pt.y = p.y - pc.y;
    [self movePoint:pt_num by:pt];
}

/*
 * pt_num is the changing control point. pt holds the relative change in each coordinate. 
 * The relative is needed and not the absolute because the closest inside control point
 * changes when one of the outside points change.
 */
- (void)movePoint:(int)pt_num by:(NSPoint)pt
{   BOOL	alternate = [(App*)NSApp alternate];
    float	x, y;
    NSSize	oldSize = size;

    /* set point */
    switch (pt_num)
    {
        case PT_LL:
            x = origin.x + size.width;
            origin.x += pt.x;
            origin.y += pt.y;
            size.width -= pt.x;
            size.height -= pt.y;
            if ( alternate )
            {   size.width = size.height * [self naturalAspectRatio];
                origin.x = x - size.width;
            }
            if (clipPath)
            {
                x = size.width/oldSize.width;
                y = size.height/oldSize.height;
                [clipPath scale:x :y withCenter:NSMakePoint(origin.x+size.width, origin.y+size.height)]; // ur
            }
            break;
        case PT_UL:
            x = origin.x + size.width;
            origin.x += pt.x;
            size.width -= pt.x;
            size.height += pt.y;
            if ( alternate )
            {   size.width = size.height * [self naturalAspectRatio];
                origin.x = x - size.width;
            }
            if (clipPath)
            {
                x = size.width/oldSize.width;
                y = size.height/oldSize.height;
                [clipPath scale:x :y withCenter:NSMakePoint(origin.x+size.width, origin.y)]; // lr
            }
            break;
        case PT_LR:
            origin.y += pt.y;
            size.width += pt.x;
            size.height -= pt.y;
            /* keep: natural aspect ratio */
            if ( alternate )
                size.width = size.height * [self naturalAspectRatio];
            if (clipPath)
            {
                x = size.width/oldSize.width;
                y = size.height/oldSize.height;
                [clipPath scale:x :y withCenter:NSMakePoint(origin.x, origin.y+size.height)]; // ul
            }
            break;
        case PT_UR:
        default:
            size.width += pt.x;
            size.height += pt.y;
            /* keep: natural aspect ratio */
            if ( alternate )
                size.width = size.height * [self naturalAspectRatio];
            if (clipPath)
            {
                x = size.width/oldSize.width;
                y = size.height/oldSize.height;
                [clipPath scale:x :y withCenter:origin]; // ll
            }
    }
    dirty = YES;
}

/* The pt argument holds the relative point change. */
- (void)moveBy:(NSPoint)pt
{
    [self setOrigin:NSMakePoint(origin.x+pt.x, origin.y+pt.y)];
    if (clipPath)
        [clipPath moveBy:pt];
}

- (int)numPoints
{
    return PTS_IMAGE;
}

/* Given the point number, return the point.
 */
- (NSPoint)pointWithNum:(int)pt_num
{
    switch (pt_num)
    {
        case PT_LL:	return origin;
        case PT_UL:	return NSMakePoint( origin.x, origin.y + size.height );
        case PT_LR:	return NSMakePoint( origin.x + size.width, origin.y );
        default:
        case PT_UR:	return NSMakePoint( origin.x + size.width, origin.y + size.height );
    }
    return NSMakePoint( 0.0, 0.0);
}

/*
 * Check for a edge point hit.
 * parameter:	p		the mouse position
 *		fuzz		the distance inside we snap to a point
 *		pt		the edge point
 *		controlsize	the size of the controls
 */
- (BOOL)hitEdge:(NSPoint)p fuzz:(float)fuzz :(NSPoint*)pt :(float)controlsize
{   NSRect	knobRect, hitRect;
    int		i;

    hitRect.origin.x = p.x -fuzz/2.0;
    hitRect.origin.y = p.y -fuzz/2.0;
    hitRect.size.width = hitRect.size.height = fuzz;
    knobRect.size.width = knobRect.size.height = controlsize;

    for (i=0; i<PTS_RECTANGLE; i++)
    {	NSPoint	p;

        p = [self pointWithNum:i];
        knobRect.origin.x = p.x - controlsize/2.0;
        knobRect.origin.y = p.y - controlsize/2.0;
        if (!NSIsEmptyRect(NSIntersectionRect(hitRect , knobRect)))
        {   *pt = p;
            //selectedKnob = i;
            return YES;
        }
    }

    return NO;
}

/*
 * Check for a control point hit.
 * Return the point number hit in the pt_num argument.
 */
- (BOOL)hitControl:(NSPoint)p :(int*)pt_num controlSize:(float)controlsize
{   NSRect	knobRect;
    int		i;

    knobRect.size.width = knobRect.size.height = controlsize;
    for (i=0; i<PTS_RECTANGLE; i++)
    {	NSPoint	pt = [self pointWithNum:i];

        knobRect.origin.x = pt.x - controlsize/2.0;
        knobRect.origin.y = pt.y - controlsize/2.0;
        if ( NSPointInRect(p, knobRect) )
        {   *pt_num = i;
            selectedKnob = i;
            return YES;
        }
    }
    return NO;
}

/*
 * modified: 2008-06-27
 */
- (BOOL)hit:(NSPoint)p fuzz:(float)fuzz
{   NSRect  aRect, bRect;
    int     i;

    if (clipPath)   // clipped image -> we use the clip path for selection
    {   BOOL    flag;

        if ([clipPath respondsToSelector:@selector(setFilled:optimize:)])
            [(VPath*)clipPath setFilled:YES optimize:NO];
        else
            [clipPath setFilled:YES];
        flag = [clipPath hit:p fuzz:fuzz];
        if ([clipPath respondsToSelector:@selector(setFilled:optimize:)])
            [(VPath*)clipPath setFilled:NO optimize:NO];
        else
            [clipPath setFilled:NO];
        return flag;
    }
    if (!Prefs_SelectByBorder)
    {
        bRect.origin.x    = origin.x - fuzz;
        bRect.origin.y    = origin.y - fuzz;
        bRect.size.width  = size.width  + 2.0*fuzz;
        bRect.size.height = size.height + 2.0*fuzz;
        if ( NSPointInRect(p, bRect) )
            return YES;
        return NO;
    }

    aRect.origin.x = floor(p.x - fuzz);
    aRect.origin.y = floor(p.y - fuzz);
    aRect.size.width  = ceil(p.x + fuzz) - aRect.origin.x;
    aRect.size.height = ceil(p.y + fuzz) - aRect.origin.y;
    for (i=0; i<PTS_RECTANGLE; i++)
    {	NSPoint	p0, p1;

        p0 = [self pointWithNum:i];
        p1 = [self pointWithNum:((i+1<PTS_RECTANGLE) ? i+1 : 0)];

        bRect.origin.x = floor(Min(p0.x, p1.x) - 1);
        bRect.origin.y = floor(Min(p0.y, p1.y) - 1);
        bRect.size.width  = ceil(Max(p0.x, p1.x) + 2) - bRect.origin.x;
        bRect.size.height = ceil(Max(p0.y, p1.y) + 2) - bRect.origin.y;
        if ( !NSIsEmptyRect(NSIntersectionRect(aRect, bRect)) )
            return YES;
    }
    return NO;
}

/* get contour with pixels
 * return the calculated path and the linePath (with the up and down engraving lines)
 */
- (VPath*)contour:(float)w
{   PathContour	*pathContour = [[PathContour new] autorelease];

    // TODO: this would be better as one PolyLine per subpath !
    return [pathContour contourImage:self width:w];
}

/*[self saveToCMYKTiff:directory];*/
- (BOOL)saveToCMYKTiff:(NSString*)directory
{   int                 i;
    NSArray             *imageReps;
    NSBitmapImageRep    *bmImageRep = nil;
    NSFileManager       *fileManager = [NSFileManager defaultManager];
    NSData              *imageData;

    if (!image)	// load image
    {	NSString	*backupFilename = [directory stringByAppendingString:@"~"];
        NSArray		*reps = nil;
        NSString	*backupPath, *backupSourcePath;

        backupPath = [backupFilename stringByAppendingPathComponent:[imageFile lastPathComponent]];
        backupSourcePath = [backupFilename stringByAppendingPathComponent:[sourcePath lastPathComponent]];
        if ([fileManager fileExistsAtPath:sourcePath])
            reps = [NSImageRep imageRepsWithContentsOfFile:sourcePath];
        else if ([fileManager fileExistsAtPath:backupPath])
            reps = [NSImageRep imageRepsWithContentsOfFile:backupPath];
        else if ([fileManager fileExistsAtPath:backupSourcePath])
            reps = [NSImageRep imageRepsWithContentsOfFile:backupSourcePath];
        if (reps)
        {   image = [[NSImage allocWithZone:(NSZone *)[self zone]] init];
            [image addRepresentations:reps];
            [image setDataRetained:YES];
        }
    }
    if (!image)
        return NO;

    /* get bitmap of image */
    imageReps = [image representations];
    for (i=0; i<(int)[imageReps count]; i++)
    {   id	bitmapRep = [imageReps objectAtIndex:i];

        if ( [bitmapRep isKindOfClass:[NSBitmapImageRep class]] )
        {   bmImageRep = bitmapRep;
            break;
        }
    }
    if (bmImageRep)
    {   int			y, x, bps, bppixel, bpr, ha, pl, bypplane, spp, rows, bitspr, columns;
        long			cmykbypplane, cmykbpr;
        unsigned char		*data[5], *cmykplanes[5];
        NSImage			*cmykImage;
        NSBitmapImageRep	*cmykbitmap;
        NSString		*cmykFilename = nil, *string;
        NSAutoreleasePool	*pool = [NSAutoreleasePool new];

        if (![VImage isAcceptedFileType:fileType])
            fileType = VImageTIFF_None;	// default

        string = [NSString stringWithFormat:@"%@_cmyk.tiff", [imageFile stringByDeletingPathExtension]];
        cmykFilename = vhfPathWithPathComponents([directory stringByDeletingLastPathComponent], string, nil);

        if (![fileManager isWritableFileAtPath:[directory stringByDeletingLastPathComponent]])
        {
            NSLog(@"VImage.m: -saveToCMYKTiff: file not writable %@", cmykFilename);
            if (thumbnail && thumbImage)
            {   [image release];
                image = nil;
            }
            [pool release];
            return NO;
        }
        /* check if allways cmyk */
        if ([bmImageRep colorSpaceName] == NSDeviceCMYKColorSpace)
        {
            if (thumbnail && thumbImage)
            {   [image release];
                image = nil;
            }
            /* save to file imageFile_cmyk in sourcePath */ // [imageFile lastPathComponent] ??
            imageData = [image TIFFRepresentationUsingCompression:tiffCompressionFromVImageType(fileType)
                                                           factor:0.0];
            [imageData writeToFile:cmykFilename atomically:NO];
            [pool release];
            return YES;
        }
        if ([bmImageRep colorSpaceName] != NSCalibratedRGBColorSpace)
        {
            if (thumbnail && thumbImage)
            {   [image release];
                image = nil;
            }
            [pool release];
            return NO;
        }

        /* create an cmyk NSBitmapRep */

        /* analyse bitmap (mash planar 234 components) */
        bypplane = [bmImageRep bytesPerPlane];                             // [bmImageRep colorSpaceName]
        bpr = [bmImageRep bytesPerRow];
        bitspr = bpr * 8;
        bppixel = [bmImageRep bitsPerPixel];
        bps = [bmImageRep bitsPerSample];
        spp = [bmImageRep samplesPerPixel];

        /* draw only in black || rgb never draw in black */
        /* draw white rectangle */
        if ((bps != 8)) // ((spp == 1 || spp == 2))
        {
            if (thumbnail && thumbImage)
            {   [image release];
                image = nil;
            }
            if (bps != 8)
                NSLog(@"VImage, saveToCMYKTiff: unsupported bits per sample %d", bps);
            [pool release];
            return NO;
        }

        ha = [bmImageRep hasAlpha];
        pl = [bmImageRep isPlanar];
        if ( !pl )
            data[0] = [bmImageRep bitmapData];
        else
            [bmImageRep getBitmapDataPlanes:data];

        rows = [bmImageRep pixelsHigh];
        columns = [bmImageRep pixelsWide];

        cmykImage = [[NSImage allocWithZone:(NSZone *)[self zone]] initWithSize:NSMakeSize(columns, rows)];
	[cmykImage setScalesWhenResized:YES];
        [cmykImage setDataRetained:YES];
        /* create image with 4 planes -> cmyk (4) components */
        cmykbitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                          pixelsWide:columns
                                                          pixelsHigh:rows
                                                       bitsPerSample:bps
                                                     samplesPerPixel:((spp <= 2) ? 1 : 4)
                                                            hasAlpha:NO isPlanar:YES
                                                      colorSpaceName:NSDeviceCMYKColorSpace
                                                         bytesPerRow:(columns*bps)/8.0
                                                        bitsPerPixel:bps];
        [cmykbitmap getBitmapDataPlanes:cmykplanes];
        cmykbpr = [cmykbitmap bytesPerRow];
        cmykbypplane = [cmykbitmap bytesPerPlane];

        for (y=0; y<rows; y++)
        {   long	by = cmykbypplane - (y * cmykbpr) - cmykbpr; // cmykImage height
            long	lby = bypplane - (y * bpr) - bpr; // original heigt

            for (x=0; x < cmykbpr; x++)
            {
                if (spp <= 2)
                    *((cmykplanes[3]+by+x)) = 255 - ((pl) ? *((data[0]+lby+x)) : *((data[0]+lby+x*spp))); // w k
                else
                {   //long	c, m, yc, k = 0;
                    long	r, g, b, ci, mi, yi, ki;
                    float	rf, gf, bf;
                    NSColor	*cmykCol, *rgbCol;
//#if 0
                    /* use OpenStep color conversion */
                    r = ((pl) ? *((data[0]+lby+x)) : *((data[0]+lby+x*spp)));
                    g = ((pl) ? *((data[1]+lby+x)) : *((data[0]+lby+x*spp+1)));
                    b = ((pl) ? *((data[2]+lby+x)) : *((data[0]+lby+x*spp+2)));

                    rf = (float)r/255.0;
                    gf = (float)g/255.0;
                    bf = (float)b/255.0;
                    rgbCol = [NSColor colorWithCalibratedRed:rf green:gf blue:bf alpha:1.0];
                    cmykCol = [rgbCol colorUsingColorSpaceName:NSDeviceCMYKColorSpace];
                    ci = ((long)([cmykCol cyanComponent] * 255.0));
                    mi = ((long)([cmykCol magentaComponent] * 255.0));
                    yi = ((long)([cmykCol yellowComponent] * 255.0));
                    ki = ((long)([cmykCol blackComponent] * 255.0));
                    *((cmykplanes[0]+by+x)) = ci;
                    *((cmykplanes[1]+by+x)) = mi;
                    *((cmykplanes[2]+by+x)) = yi;
                    *((cmykplanes[3]+by+x)) = ki;
//#endif
#if 0
                    c = 255 - ((pl) ? *((data[0]+lby+x)) : *((data[0]+lby+x*spp))); // 255-r = c
                    m = 255 - ((pl) ? *((data[1]+lby+x)) : *((data[0]+lby+x*spp+1))); // 255-g = m
                    yc = 255 - ((pl) ? *((data[2]+lby+x)) : *((data[0]+lby+x*spp+2))); // 255-b = y

                    if (c >= 253 && m >= 253 && yc >= 253)
                    {   /* realy black */
                        c = 127;
                        m = y = 0;
                        k = 255;
                    }

                    else if (Min(c, Min(m, yc)) > 1)
                    {   long	min = Min(c, Min(m, yc));

                        k = min; // /2.0; // zu dunkel bei den mittleren Farben
// all for MetalSurface conversion
//k -= 5;
//if (k < 0) k = 0;

                        c -= min;
//c += 5;
//if (c > 255) c = 255;
                        m -= min;
//m *= 0.8;
                        yc -= min;
//yc *= 0.8;
                   }

                    *((cmykplanes[0]+by+x)) = c;
                    *((cmykplanes[1]+by+x)) = m;
                    *((cmykplanes[2]+by+x)) = yc;
                    *((cmykplanes[3]+by+x)) = k;
#endif
                }
            }
        }

        [cmykImage addRepresentation:cmykbitmap];
        [cmykbitmap release];

        if (thumbnail && thumbImage)
        {   [image release];
            image = nil;
        }

        /* save to file imageFile_cmyk in sourcePath */ // [imageFile lastPathComponent] ??
        imageData = [cmykImage TIFFRepresentationUsingCompression:tiffCompressionFromVImageType(fileType)
                                                           factor:0.0];
        [imageData writeToFile:cmykFilename atomically:NO];
        [pool release];
        return YES;
    }
    if (thumbnail && thumbImage)
    {   [image release];
        image = nil;
    }
    return NO;
}

- (BOOL)writesFiles
{
    return (image) ? YES : NO;
}
- (void)writeFilesToDirectory:(NSString*)directory
{   NSString		*filename = [directory stringByAppendingPathComponent:[imageFile lastPathComponent]];
    NSString		*thFilename = [directory stringByAppendingPathComponent:[imageFile lastPathComponent]];
    NSFileManager	*fileManager = [NSFileManager defaultManager];

//[self saveToCMYKTiff:directory]; /// hack debug test only !

    if (![VImage isAcceptedFileType:fileType])
        fileType = VImageTIFF_None;	// default

    if (thumbnail && thumbImage)
    {   NSString	*str = [NSString stringWithFormat:@"%@_.tiff", [imageFile stringByDeletingPathExtension]];
        thFilename = [directory stringByAppendingPathComponent:[str lastPathComponent]];
        if (![fileManager fileExistsAtPath:filename])
            [[thumbImage TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:0.0]
             writeToFile:thFilename atomically:NO];
    }
    if (compressionDirty && !image) // load image and save new (fileType has changed)
    {	NSString	*backupFilename = [directory stringByAppendingString:@"~"];
        NSArray		*reps = nil;
        NSString	*backupPath, *backupSourcePath;

        backupPath = [backupFilename stringByAppendingPathComponent:[imageFile lastPathComponent]];
        backupSourcePath = [backupFilename stringByAppendingPathComponent:[sourcePath lastPathComponent]];
        if ([fileManager fileExistsAtPath:sourcePath])
            reps = [NSImageRep imageRepsWithContentsOfFile:sourcePath];
        else if ([fileManager fileExistsAtPath:backupPath])
            reps = [NSImageRep imageRepsWithContentsOfFile:backupPath];
        else if ([fileManager fileExistsAtPath:backupSourcePath])
            reps = [NSImageRep imageRepsWithContentsOfFile:backupSourcePath];
        if (reps)
        {   image = [[NSImage allocWithZone:(NSZone *)[self zone]] init];
            [image addRepresentations:reps];
            [image setDataRetained:YES];
        }
        compressionDirty = NO;
    }
    if (!image && ![fileManager fileExistsAtPath:filename])
    {	NSString	*backupFilename = [directory stringByAppendingString:@"~"];
        NSString	*backupPath, *backupSourcePath;

        backupPath = [backupFilename stringByAppendingPathComponent:[imageFile lastPathComponent]];
        backupSourcePath = [backupFilename stringByAppendingPathComponent:[sourcePath lastPathComponent]];
        /* move the image instead of copying */
        if (Prefs_RemoveBackups && [sourcePath isEqual:filename] && [fileManager fileExistsAtPath:backupPath])
            [fileManager movePath:backupPath toPath:filename handler:nil];
        /* copy image from path where we load the image to our new path */
        else if ([fileManager fileExistsAtPath:sourcePath])
            [fileManager copyPath:sourcePath toPath:filename handler:nil];
        /* else we check if a backup path exist */
        else if ([fileManager fileExistsAtPath:backupPath])
            [fileManager copyPath:backupPath toPath:filename handler:nil];
        /* copy image from path (old imageName - if renamed with thumbimage)  to our new path */
        else if ([fileManager fileExistsAtPath:backupSourcePath])
        {   [fileManager copyPath:backupSourcePath toPath:filename handler:nil];
            if (sourcePath)
                [sourcePath release];
            sourcePath = [filename retain];
        }
        /* else we need a message */
        else
            NSRunAlertPanel(SAVE_TITLE, CANT_SAVE, nil, nil, nil);
    }
    else if (image && ![fileManager fileExistsAtPath:filename])
    {   NSData	*data;

#       if !defined(GNUSTEP_BASE_VERSION) && !defined(__APPLE__)    // OpenStep
        data = [image TIFFRepresentationUsingCompression:tiffCompressionFromVImageType(fileType)
                                                  factor:0.0];
#       else    // GNUstep, Apple
        if ( (fileType >= VImageTIFF_None && fileType <= VImageTIFF_PackBits) ) // TIFF
        {
            data = [image TIFFRepresentationUsingCompression:tiffCompressionFromVImageType(fileType)
                                                      factor:0.0];
#           ifdef __APPLE__
              if (!data)  // for example 4-bit TIFF
                  data = [image TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:0.0];
#           endif
        }
        else    // GIF, JPG, PNG, ...
        {   NSArray             *reps = [image representations];
            NSBitmapImageRep    *rep = ([reps count]) ? [reps objectAtIndex:0] : nil;

#           ifdef __APPLE__ // workaround NSCGImageSnapshotRep (drag into doc)
            if ( !rep || ! [rep isKindOfClass:[NSBitmapImageRep class]] )
            {   data = [image TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:0.0];
                rep = [NSBitmapImageRep imageRepWithData:data];
            }
#           endif
            data = [rep representationUsingType:fileTypeFromVImageType(fileType)
                                     properties:propertiesForFileType(fileType, compressionFactor)];
            //data = [NSBitmapImageRep representationOfImageRepsInArray:[image representations] // doesn't work on Mac  10.6
            //                         usingType:fileTypeFromVImageType(fileType)
            //                         properties:propertiesForFileType(fileType, compressionFactor)];
        }
#       endif
        [data writeToFile:filename atomically:NO];
        if (sourcePath)
            [sourcePath release];
        sourcePath = [filename retain];
        if (thumbnail && thumbImage)
        {   [image release];
            image = nil;
        }
    }
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}{NSPoint=ff}", &origin, &size];
    //[aCoder encodeValuesOfObjCTypes:"{NSPoint=ff}", &originalSize];
    [aCoder encodePoint:origin];            // 2012-01-08
    [aCoder encodeSize:size];
    [aCoder encodeSize:originalSize];
    [aCoder encodeValuesOfObjCTypes:"i", &identifier];
    if (!imageFile)
        imageFile = [[NSString stringWithFormat:@"Image%d.tiff", identifier] retain];
    [aCoder encodeValuesOfObjCTypes:"@", &imageFile];
    [aCoder encodeValuesOfObjCTypes:"@", &image];
    [aCoder encodeValuesOfObjCTypes:"@", &thumbImage];
    [aCoder encodeValuesOfObjCTypes:"@", &clipPath];
    [aCoder encodeValuesOfObjCTypes:"cif", &thumbnail, &fileType , &compressionFactor];
    [aCoder encodeValuesOfObjCTypes:"@", &sourcePath];
}
- (id)initWithCoder:(NSCoder *)aDecoder
{   int	version;

    [self setParameter];
    [super initWithCoder:aDecoder];
    version = [aDecoder versionForClassName:@"VImage"];
    if ( version < 1 )
    {   [aDecoder decodeValuesOfObjCTypes:"{ff}{ff}", &origin, &size];
        [aDecoder decodeValuesOfObjCTypes:"{ff}", &originalSize];
    }
    else
    {   //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}{NSPoint=ff}", &origin, &size];
        //[aDecoder decodeValuesOfObjCTypes:"{NSPoint=ff}", &originalSize];
        origin       = [aDecoder decodePoint];  // 2012-01-08
        size         = [aDecoder decodeSize];
        originalSize = [aDecoder decodeSize];
    }
    [aDecoder decodeValuesOfObjCTypes:"i", &identifier]; // from copied object
    if (identifier >= currentGraphicIdentifier)
        currentGraphicIdentifier = identifier+1;
    else
        identifier = currentGraphicIdentifier++; // the next one ! - need a new name !
    [aDecoder decodeValuesOfObjCTypes:"@", &imageFile];
    if (![imageFile hasSuffix:@".tiff"])
    {   NSString    *path = [[[[[self class] currentView] document] filename] stringByAppendingPathComponent:imageFile];
        image = [[NSUnarchiver unarchiveObjectWithFile:path] retain];
        [imageFile release];
        imageFile = [[imageFile stringByAppendingString:@".tiff"] retain];
    }
    if (version >= 3)
    {   [aDecoder decodeValuesOfObjCTypes:"@", &image];
        [aDecoder decodeValuesOfObjCTypes:"@", &thumbImage];
    }
    else
    {   image = [[NSImage allocWithZone:(NSZone *)[self zone]] init];
        [image addRepresentations:[NSImageRep imageRepsWithContentsOfFile:[[[[[self class] currentView] document] filename] stringByAppendingPathComponent:imageFile]]];
        [image setDataRetained:YES];
        [image setScalesWhenResized:YES];
    }
    imageFile = [[NSString stringWithFormat:@"Image%d.tiff", identifier] retain]; // rename -> new VImage

    if (version >= 2 && version < 4)	// 2000-11-07 - 2008-03-18
        [aDecoder decodeValuesOfObjCTypes:"ci", &relief, &reliefType];

    if (version >= 3)
    {   [aDecoder decodeValuesOfObjCTypes:"@", &clipPath];
        [aDecoder decodeValuesOfObjCTypes:"cif", &thumbnail, &fileType , &compressionFactor];
        [aDecoder decodeValuesOfObjCTypes:"@", &sourcePath];
    }
    return self;
}

/* archiving with property list
 * modified: 2008-07-19 (in init  != tiff case removed, because it was from archiver an just preventing success)
 */
- (id)propertyList
{   NSMutableDictionary	*plist = [super propertyList];

    [plist setObject:propertyListFromNSPoint(origin) forKey:@"origin"];
    [plist setObject:propertyListFromNSSize(size) forKey:@"size"];
    [plist setObject:propertyListFromNSSize(originalSize) forKey:@"originalSize"];
    if (!imageFile)
        imageFile = [[NSString stringWithFormat:@"Image%d.tiff", identifier] retain];
    [plist setObject:imageFile forKey:@"imageFile"];
    [plist setInt:identifier forKey:@"identifier"];
    if (clipPath)
        [plist setObject:[clipPath propertyList] forKey:@"clipPath"];
    if (thumbnail) [plist setObject:@"YES" forKey:@"thumbnail"];
    [plist setInt:fileType forKey:@"fileType"];
    if (fileType == VImageJPEG)
        [plist setObject:propertyListFromFloat(compressionFactor) forKey:@"compressionFactor"];
    return plist;
}
- (id)initFromPropertyList:(id)plist inDirectory:(NSString *)directory
{   id          plistObject, obj;
    NSString    *className, *str = nil, *path;

    [self setParameter];
    [super initFromPropertyList:plist inDirectory:directory];
    origin = pointFromPropertyList([plist objectForKey:@"origin"]);
    size = sizeFromPropertyList([plist objectForKey:@"size"]);
    originalSize = sizeFromPropertyList([plist objectForKey:@"originalSize"]);
    identifier = [plist intForKey:@"identifier"];
    if (identifier >= currentGraphicIdentifier)
        currentGraphicIdentifier = identifier+1;
    imageFile = [[plist objectForKey:@"imageFile"] retain];
    if ( !label )   // no label yet, we make one
        label = [[imageFile stringByDeletingPathExtension] retain];

    /* thumbnail */
    thumbnail = ([plist objectForKey:@"thumbnail"] ? YES : NO);
    if (thumbnail)
        str = [NSString stringWithFormat:@"%@_.tiff", [imageFile stringByDeletingPathExtension]];
    if (thumbnail &&
        [[NSFileManager defaultManager] fileExistsAtPath:[directory stringByAppendingPathComponent:str]])
    {   thumbImage = [[NSImage allocWithZone:(NSZone *)[self zone]] init];
        path = [directory stringByAppendingPathComponent:str];
        [thumbImage addRepresentations:[NSImageRep imageRepsWithContentsOfFile:path]];
        [thumbImage setDataRetained:YES];
        [thumbImage setScalesWhenResized:YES];
    }
    {   image = [[NSImage allocWithZone:(NSZone *)[self zone]] init];
        path = [directory stringByAppendingPathComponent:imageFile];
        [image addRepresentations:[NSImageRep imageRepsWithContentsOfFile:path]];
        [image setDataRetained:YES];
        [image setScalesWhenResized:YES];
    }
    sourcePath = [[directory stringByAppendingPathComponent:imageFile] retain];
    originalSize = [((thumbImage) ? thumbImage : image) size];

    /* clipPath */
    plistObject = [plist objectForKey:@"clipPath"];
    if (plistObject)
    {   className = [plistObject objectForKey:@"Class"];
        obj = [NSClassFromString(className) allocWithZone:[self zone]];
        if (!obj)	// load old projects (< 3.50 beta 13)
            obj = [NSClassFromString(newClassName(className)) allocWithZone:[self zone]];
        clipPath = [obj initFromPropertyList:plistObject inDirectory:directory];
    }
    else
        clipPath = nil;

    if ([plist objectForKey:@"compressionType"])	// old (< 3.64 2004-10-06)
        fileType = fileTypeForTIFFCompression([plist intForKey:@"compressionType"]);
    else
        fileType = [plist intForKey:@"fileType"];
    if (!fileType)
        fileType = VImageTIFF_None;	// default
    if ([plist objectForKey:@"compressionFactor"])
        compressionFactor = [plist floatForKey:@"compressionFactor"];
    else
        compressionFactor = 0.9;    // 10% compression

    return self;
}


- (void)dealloc
{
    if (clipPath)
    {   [clipPath release];
#ifdef USE_VHF_CLIPPING
        [clipImage release];
#endif
    }
    if (thumbnail)
        [thumbImage release];
    [image release];
    [imageFile release];
    if (sourcePath)
        [sourcePath release];
    [super dealloc];
}

@end
