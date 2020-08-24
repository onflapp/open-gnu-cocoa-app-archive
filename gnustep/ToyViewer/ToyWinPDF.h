//
//  ToyWinPDF.h
//  ToyViewer
//
//  Created by ogihara on Tue Apr 24 2001.
//  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
//

#import "ToyWinVector.h"

@interface ToyWinPDF : ToyWinVector

/* Overload */
- (NSData *)openEPSData;
- (NSData *)openPDFData;
- (void)makeComment:(commonInfo *)cinf;

@end
