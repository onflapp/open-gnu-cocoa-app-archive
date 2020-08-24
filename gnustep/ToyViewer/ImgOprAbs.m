//
//  ImgOprAbs.m
//  ToyViewer
//
//  Created by ogihara on Thu Nov 15 2001.
//  Copyright (c) 2001 Takeshi Ogihara. All rights reserved.
//

#import "ImgOprAbs.h"
#import <Foundation/NSString.h>
#import <Foundation/NSBundle.h>
#import "AlertShower.h"


@implementation ImgOprAbs

/* Virtual */
+ (int)opcode {
	return NoOperation;
}

+ (NSString *)oprString {
	// NSString *s = NSLocalizedString(opkey, Effects);
	return nil;
}

+ (BOOL)check:(int)check info:(const commonInfo *)cinf filename:(NSString *)fn
{
	if ((check & ck_EPS)
	&& (cinf->type == Type_eps || cinf->type == Type_pdf)) {
		[WarnAlert runAlert:fn : Err_EPS_PDF_IMPL];
		return NO;
	}
	if ((check & ck_CMYK) && cinf->cspace == CS_CMYK) {
		[WarnAlert runAlert:fn : Err_IMPLEMENT];
		return NO;
	}
	if ((check & ck_MONO) && cinf->numcolors == 1) {
		[WarnAlert runAlert:fn : Err_OPR_IMPL];
		return NO;
	}
	if (cinf->width >= MAXWidth - 4 || cinf->height >= MAXWidth - 4) {
		[ErrAlert runAlert:fn : Err_MEMORY];
		return NO;
	}
	return YES;
}

+ (NSString *)oprStringOf:(NSString *)opkey
{
	NSString *s = NSLocalizedString(opkey, Effects);
	if (s == nil)
		return opkey;
	return s;
}

@end
