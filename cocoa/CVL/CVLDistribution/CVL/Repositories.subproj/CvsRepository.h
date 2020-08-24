/* CvsRepository.h created by vincent on Thu 13-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>

#define ROOT_KEY				@"repositoryRoot"
#define METHOD_KEY				@"repositoryMethod"
#define USER_KEY				@"repositoryUser"
#define HOST_KEY				@"repositoryHost"
#define PATH_KEY				@"repositoryPath"
#define PASSWORD_KEY			@"repositoryPassword"
#define COMPRESSION_LEVEL_KEY	@"repositoryCompressionLevel"
#define CVS_EXECUTABLE_PATH_KEY	@"cvsExecutablePath"
#define PORT_KEY                @"repositoryPort"


@class NSArray, NSMutableArray, NSMutableDictionary, NSMutableString, NSMutableSet, NSDictionary, NSString, Request, CvsLoginRequest, CvsCheckoutRequest, CvsModule;

@interface CvsRepository : NSObject
{
    BOOL upToDate;
    BOOL isUpdating;
    NSString *root;
    NSString *CVSROOTWorkAreaPath;
	NSString *supportDirectory;
    NSMutableArray	*modules;
    NSArray* baseIgnoreWildCardsArray;
    NSArray* baseWrapperWildCardsArray;
    NSMutableDictionary *ignoredPatternDict;
    NSMutableDictionary *wrapperPatternDict;
    NSMutableSet *dirsControlled; //cached for efficiency
    CvsCheckoutRequest *checkoutRequest;
    NSString *method;
    BOOL	cvsRootCheckoutFailed;
	BOOL	previousOverrideCvsWrappersFileInHomeDirectory;
    NSMutableDictionary	*environment;
	NSNumber *compressionLevel;
	BOOL isRepositoryMarkedForRemoval;
	NSString	*cvsExecutablePath;
	NSString *path;
}
// do not subclass the following methods
+ (NSArray *) registeredRepositories;
+ (CvsRepository *) nullRepository;
+ (CvsRepository *) defaultRepository;
+ (void) setDefaultRepository:(CvsRepository *)aCvsRepository;
+ (CvsRepository *) repositoryWithRoot:(NSString *)aRepositoryRoot;
+ (CvsRepository *) repositoryWithProperties:(NSDictionary *)thePropertiesDictionary;
+ (Class)repositoryClassForMethod:(NSString *)methodName;
+ (void) registerRepository:(CvsRepository *)repository;
+ (NSString *) cvsFullRepositoryPathForDirectory:(NSString *)aDirectory;
+ (NSString *) cvsRepositoryPathForDirectory:(NSString *)aDirectory;
+ (NSString *) cvsRootPathForDirectory:(NSString *)aDirectory;
+ (NSString *) repositoriesSupportDirectory;
- (NSString *)supportDirectory;
- (void)setSupportDirectory:(NSString *)aDirectory;
+ (CvsRepository *)repositoryForPath:(NSString *)aPath;
+ (BOOL)disposeRepository:(CvsRepository *)aRepository;
+ (BOOL) isRepositoryToBeDisposed:(CvsRepository *)repository;

// do not call, subclass only
+ (NSString *)rootForProperties:(NSDictionary *)properties;
- initWithMethod:(NSString *)theMethod root:(NSString *)aRepositoryRoot;
- initWithProperties:(NSDictionary *)dictionary;
- (void)preferencesChanged:(NSNotification *)notification;
- (void) enableCvsWrappersOverride:(BOOL)enabled;

- (NSString *) homeDirectory;
- (BOOL)linkCvsFile:(NSString *)filename;
- (BOOL)linkCvsWrappersFile;
- (void)makeTheSupportDirectoryTheHomeForThisRepository;
- (void)makeTheUsersHomeTheHomeForThisRepository;

// no restrictions
- (NSDictionary *)properties;
- (BOOL)isUpToDate;
- (BOOL)isUsed;
- (CvsCheckoutRequest *)checkoutRequest;
- (NSString *)CVSROOTWorkAreaPath;
- (NSArray *)modulesSymbolicNames;
- (NSString *)root;
- (BOOL)isWrapper: (NSString*) aPath;
- (BOOL)isIgnored: (NSString*) aPath;
- (BOOL)isLocal;
- (BOOL)needsLogin; // repository answering yes must implement the 'Login' informal protocol
- (BOOL)isRepositoryMarkedForRemoval;
- (void)setIsRepositoryMarkedForRemoval:(BOOL)flag;

- (BOOL)isReadyForRequests;
- (Request *)gettingReadyRequest;
- (NSArray *) modules;
- (CvsModule *) moduleWithSymbolicName:(NSString *)aName;
- (BOOL) cvsRootCheckoutFailed;

- (CvsCheckoutRequest *) checkoutAgain; // Forces a new checkout
- (BOOL) isUpdating;
- (BOOL) isUpToDate_WithoutRefresh; // Does NOT force to be up-to-date; simply returns current status

- (NSDictionary *) environment;
- (void) setEnvironment:(NSDictionary *)aDict;
- (BOOL) isInheritedEnvironmentKey:(NSString *)aKey value:(NSString *)aValue; // Local overriding of environment, or standard environment?

- (void) invalidateDir:(NSString *)dirPath; // Invalidates ignored patterns for that dir

- (NSString *) username;
- (BOOL) isNullRepository;
- (NSNumber *)compressionLevel;
- (void)setCompressionLevel:(NSNumber *)aNewCompressionLevel;
- (NSString *)cvsExecutablePath;
- (void)setCvsExecutablePath:(NSString *)value;

- (NSString *)path;
- (void)setPath:(NSString *)newPath;

@end

@interface CvsRepository (Login)
- (void)setIsLoggedIn:(BOOL)flag;
- (BOOL)isLoggedIn;
- (Request *)loginRequest;
@end

