//
//  SenZipPackage.m
//  UniLogoModel
//
//  Created by Jean-Alexis Montignies on 30/09/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "SenZipPackage.h"
#import <zip.h>

@implementation SenZipPackage

- (struct zip *) zip
{
	return (struct zip *) zip;
}

+ (NSString *) newTemporaryPath
{
	NSString *temporaryPath = NSTemporaryDirectory();
	temporaryPath = [temporaryPath stringByAppendingPathComponent: [[NSProcessInfo processInfo] globallyUniqueString]];
	temporaryPath = [temporaryPath stringByAppendingPathExtension: @"zip"];
	
	return temporaryPath;
}

- (id)initWithPath: (NSString *) aPath isTemporary:(BOOL) isTemporary
{
	self = [super init];
	int error;
	zip =  zip_open ([aPath cString], ZIP_CREATE | ZIP_EXCL, &error);
	if (zip == NULL) {
		[self release];
		return nil;
	}
	zipFilePath = [aPath retain];
	isFileTemporary = isTemporary;
	return self;
}


- (id)initWithPath: (NSString *) aPath
{
	return [self initWithPath:aPath isTemporary:NO];
}


- (id) init
{
	return [self initWithPath:[[self class] newTemporaryPath] isTemporary:YES];
}


+ (SenZipPackage *) zipPackage
{
	return [[[self alloc] init] autorelease];
}

+ (SenZipPackage *) zipPackageWithPath: (NSString *)aPath
{
	return [[[self alloc] initWithPath: aPath] autorelease];
}


- (void)dealloc
{
	if (zip != NULL) {
		zip_close ((struct zip *)zip);
	}
	if (isFileTemporary && (zipFilePath != nil)) {
		[[NSFileManager defaultManager] removeFileAtPath: zipFilePath handler: nil]; 
	}
	[zipData release];
	[super dealloc];
}

- (BOOL)addData: (NSData *)theData withPath: (NSString *)aPath
{
	struct zip_source * sourceBuffer = zip_source_buffer((struct zip *)zip, [theData bytes], [theData length], 0);
	if (sourceBuffer != NULL) {
		if (zip_add((struct zip *)zip, [aPath cString], sourceBuffer) == 0) {
			return YES;
		}
		zip_source_free (sourceBuffer);
	}
	return NO;
}

- (void)close
{
	if (zip != NULL) {
		zip_close ((struct zip *)zip);
		zip = NULL;
	}
}

- (NSData *)zipData
{
	if (zip != NULL) return nil; // the zip must be closed first
	if (zipData == nil) {
		zipData = [[NSData alloc] initWithContentsOfFile: zipFilePath];
	}
	return zipData;
}

@end
