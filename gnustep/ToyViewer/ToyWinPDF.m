//
//  ToyWinPDF.m
//  ToyViewer
//
//  Created by ogihara on Tue Apr 24 2001.
//  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
//

#import "ToyWinPDF.h"
#import <AppKit/NSImage.h>
#import <AppKit/NSPDFImageRep.h>
#import "ToyView.h"

@implementation ToyWinPDF

/* Overload */
- (NSData *)openEPSData
{
	id	tv = [self toyView];
	return [tv dataWithEPSInsideRect:[tv frame]];
}

- (NSData *)openPDFData
{
	NSPDFImageRep *rep;

	rep = (NSPDFImageRep *)[[[self toyView] image]
			bestRepresentationForDevice:nil];
	return [rep PDFRepresentation];
}

/* Overload */
- (void)makeComment:(commonInfo *)cinf
{
	sprintf(cinf->memo, "%d x %d  PDF", cinf->width, cinf->height);
}

@end
