//
//  CvsTagFormatter.h
//  CVL
//
//  Created by William Swats on Wed Jul 23 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface CvsTagFormatter : NSFormatter
{

}

@end

#ifdef RHAPSODY
#import <AppKit/NSTextField.h>
@interface NSTextField(CvsTagFormatter)
- (void)setFormatter:(NSFormatter *)formatter;
@end
#endif
