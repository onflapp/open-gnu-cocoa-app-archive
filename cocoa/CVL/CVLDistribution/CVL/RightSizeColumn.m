//
//  RightSizeColumn.m
//  CVL
//
//  Created by William Swats on 10/29/2004.
//  Copyright 2004 Sente SA. All rights reserved.
//
/*" This class calculates and holds the state of a browser column sizes. There 
	are two sizes of interest. One is the current size which is saved in the 
	previous size instance variable. The other is the right size. This is the
	ideal width for a column. This is the smallest width that contains all the
	content without clipping or truncating. This class enables the CVL browser 
	viewer to now perform a “right-size” operation; that is, double clicking the
	column resize icon will size a column to the smallest width that contains 
	all the content without clipping or truncating. Double clicking again will 
	restore the column to its previous size.

	The CVL browser viewer controller will create an instance of this class for
	each column; but only on a as needed bases.
"*/

#import "RightSizeColumn.h"
#import "SenBrowserCell.h"

@implementation RightSizeColumn


- (id)init
{
	SEN_NOT_DESIGNATED_INITIALIZER(@"-initWithBrowser:forColumn:");
    
    return nil;
}

- (id)initWithBrowser:(NSBrowser *)aBrowser forColumn:(int)aColumn
	/*" This is the designated init method for this class. This method also 
		calculates and sets the current column width to the previous size width.
	"*/
{
	float theCurrentWidth = 0.0;
	
	if ( (self = [super init]) ) {
		browser = [aBrowser retain];
		column = aColumn;
		theCurrentWidth = [self calcCurrentWidth];
		[self setPreviousSizeWidth:theCurrentWidth];
	}
	return self;
}

- (void)dealloc
{
    [browser release];
    browser = nil;
	
    [super dealloc];
}


- (NSString *)description
    /*" This method overrides supers implementation. Here we return the browser 
		column, the previous width, the right size width and isRightSizeWidth 
		enabled.
    "*/
{
    return [NSString stringWithFormat:
		 @"%@: column = %d, previousSizeWidth = %f, rightSizeWidth = %f isRightSizeWidth = %@", 
        [super description], column, previousSizeWidth, rightSizeWidth,
        (isRightSizeWidth ? @"YES" : @"NO")];
}

- (NSBrowser *)browser
    /*" This is the get method for the browser instance variable. The bowser is
		the one who has a column that this class is setting and saving the 
		column widths.

		See also #{-setBrowser:}
    "*/
{
    return [[browser retain] autorelease]; 
}

- (void)setBrowser:(NSBrowser *)newBrowser
    /*" This is the set method for the browser instance variable.

		See also #{-browser}
    "*/
{
    if (browser != newBrowser) {
        [newBrowser retain];
        [browser release];
        browser = newBrowser;
    }
}

- (int)column
    /*" This is the get method for the column instance variable. The column is
		the column that this class is setting and saving the column widths.

		See also #{-setColumn:}
    "*/
{ 
	return column;
}

- (void)setColumn:(int)newColumn
    /*" This is the set method for the column instance variable.

		See also #{-column}
    "*/
{
    column = newColumn;
}


- (float)rightSizeWidth
    /*" This is the get method for the rightSizeWidth instance variable. The 
		rightSizeWidth is the ideal width for a column. This is the smallest
		width that contains all the content without clipping or truncating.

		See also #{-setRightSizeWidth:}
    "*/
{
	return rightSizeWidth;
}

- (void)setRightSizeWidth:(float)newRightSizeWidth
    /*" This is the set method for the rightSizeWidth instance variable. 

		See also #{-rightSizeWidth}
    "*/
{
    rightSizeWidth = newRightSizeWidth;
}


- (float)previousSizeWidth
    /*" This is the get method for the previousSizeWidth instance variable. The 
		previousSizeWidth is the previous width for a column. This is the width 
		of the column before it was set to the right size width. This class 
		saves this value so that the user can return the column to this size by
		double clicking on the column resize icon a second time.

		See also #{-setPreviousSizeWidth:}
    "*/
{
	return previousSizeWidth;
}

- (void)setPreviousSizeWidth:(float)newPreviousSizeWidth
    /*" This is the set method for the previousSizeWidth instance variable. 

		See also #{-previousSizeWidth}
    "*/
{
    previousSizeWidth = newPreviousSizeWidth;
}


- (BOOL)isRightSizeWidth
    /*" This is the get method for the isRightSizeWidth instance variable. The 
		isRightSizeWidth is a boolean indicating where or nor the column 
		supported by this instance is at the right size or not. If it is then 
		isRightSizeWidth is YES, otherwise it is NO.

		See also #{-setIsRightSizeWidth:}
    "*/
{
	return isRightSizeWidth;
}

- (void)setIsRightSizeWidth:(BOOL)flag
    /*" This is the set method for the isRightSizeWidth instance variable. 

		See also #{-isRightSizeWidth}
    "*/
{
    isRightSizeWidth = flag;
}


- (float)calcCurrentWidth
    /*" This method calculates and returns the current width of the column 
		supported by this instance.
    "*/
{
	NSMatrix *aMatrix = nil;
	NSSize aCellSize = {0.0, 0.0};
	float theCurrentWidth = 0.0;
	
	SEN_ASSERT_NOT_NIL(browser);
	
	aMatrix = [browser matrixInColumn:column];
	aCellSize = [aMatrix cellSize];
	theCurrentWidth = [browser columnWidthForColumnContentWidth:aCellSize.width];
	
	return theCurrentWidth;
}

- (float)calcRightSizeWidth
    /*" This method calculates and returns the right size width of the column 
		supported by this instance. The rightSizeWidth is the ideal width for a 
		column. This is the smallest width that contains all the content without
		clipping or truncating.
    "*/
{
	id theBrowserDelegate = nil;
	NSMatrix *aMatrix = nil;
	SenBrowserCell *aCell = nil;
	NSSize aCellSize = {0.0, 0.0};
	int aCount = 0;
	int aRow = 0;
	float aWidth = 0.0;
	float maxWidth = 0.0;
	float aRightSizeWidth = 0.0;
	
	aMatrix = [browser matrixInColumn:column];
	aCount = [aMatrix numberOfRows];
	theBrowserDelegate = [browser delegate];
	SEN_ASSERT_NOT_NIL(theBrowserDelegate);
	while ( aRow < aCount ) {
		aCell = [aMatrix cellAtRow:aRow column:0];
		aCellSize = [aCell cellSize];
		aWidth = aCellSize.width;
		if ( aWidth > maxWidth ) {
			maxWidth = aWidth;
		}
		aRow++;
	}
	aRightSizeWidth = [browser columnWidthForColumnContentWidth:maxWidth];

	return aRightSizeWidth;
}


@end
