//
//  RightSizeColumn.h
//  CVL
//
//  Created by William Swats on 10/29/2004.
//  Copyright 2004 Sente SA. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface RightSizeColumn : NSObject
{
	NSBrowser *browser;
	int column;
	float rightSizeWidth;
	float previousSizeWidth;
	BOOL isRightSizeWidth;
}


- (id)initWithBrowser:(NSBrowser *)aBrowser forColumn:(int)aColumn;

- (NSBrowser *)browser;
- (void)setBrowser:(NSBrowser *)newBrowser;

- (int)column;
- (void)setColumn:(int)newColumn;

- (float)rightSizeWidth;
- (void)setRightSizeWidth:(float)newRightSizeWidth;

- (float)previousSizeWidth;
- (void)setPreviousSizeWidth:(float)newPreviousSizeWidth;

- (BOOL)isRightSizeWidth;
- (void)setIsRightSizeWidth:(BOOL)flag;

- (float)calcCurrentWidth;
- (float)calcRightSizeWidth;


@end
