//
//  RepositoryProperties.h
//  CVL
//
//  Created by William Swats on 11/12/2004.
//  Copyright 2004 Sente SA. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class CvsRepository;
@class CvsLocalRepository;
@class CvsPserverRepository;
@class AddRepositoryController;

@interface RepositoryProperties : NSObject
{
	NSString *repositoryMethod;
	NSString *repositoryPath;
	NSNumber *repositoryCompressionLevel;
	NSString *repositoryUser;
	NSString *repositoryHost;
	NSString *repositoryPassword;
	NSString *repositoryRoot;
	NSString *cvsExecutablePath;
	NSNumber *repositoryPort;
}

+ (NSMutableDictionary *)repositoryPropertiesCache;
+ (RepositoryProperties *)parseRepositoryRoot:(NSString *)aRepositoryRoot;

- (NSDictionary *)propertiesDictionary;
- (BOOL)validateRepositoryProperties;

- (NSString *)repositoryMethod;
- (void)setRepositoryMethod:(NSString *)newRepositoryMethod;

- (NSString *)repositoryPath;
- (void)setRepositoryPath:(NSString *)newRepositoryPath;
- (BOOL)validateRepositoryPath:(id *)aPathPtr error:(NSError **)outError;

- (NSNumber *)repositoryCompressionLevel;
- (void)setRepositoryCompressionLevel:(NSNumber *)newRepositoryCompressionLevel;

- (NSString *)repositoryUser;
- (void)setRepositoryUser:(NSString *)newRepositoryUser;

- (NSString *)repositoryHost;
- (void)setRepositoryHost:(NSString *)newRepositoryHost;

- (NSString *)repositoryPassword;
- (void)setRepositoryPassword:(NSString *)newRepositoryPassword;

- (NSString *)repositoryRoot;
- (void)setRepositoryRoot:(NSString *)newRepositoryRoot;

- (NSString *)cvsExecutablePath;
- (void)setCvsExecutablePath:(NSString *)value;

- (NSNumber *)repositoryPort;
- (void)setRepositoryPort:(NSNumber *)newRepositoryPort;

- (BOOL)isEqual:(RepositoryProperties *)myRepositoryProperties ignorePort:(BOOL)portIsIgnored;
- (NSString *)repositoryRootWithoutPort;

@end
