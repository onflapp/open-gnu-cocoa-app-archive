//
//  UniLogoZip.h
//  UniLogoModel
//
//  Created by Jean-Alexis Montignies on 30/09/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SenZipPackage : NSObject {
	void *zip;
	NSString *zipFilePath;
	NSData *zipData;
	BOOL isFileTemporary;
}

+ (SenZipPackage *) zipPackage;
+ (SenZipPackage *) zipPackageWithPath: (NSString *)aPath;

- (id) initWithPath: (NSString *)aPath;

- (BOOL) addData: (NSData *)theData withPath: (NSString *)aPath;

- (void) close;

- (NSData *) zipData; // the zip must be closed first;
@end
