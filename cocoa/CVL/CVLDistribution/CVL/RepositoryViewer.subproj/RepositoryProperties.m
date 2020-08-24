//
//  RepositoryProperties.m
//  CVL
//
//  Created by William Swats on 11/12/2004.
//  Copyright 2004 Sente SA. All rights reserved.
//


/*" This class is used to contain the properties used to connect to a 
	repository when the user adds a repository to CVL. Could have used a 
	dictionary but this seemed to be the better choice at the time. Need to 
	replace all the instances of the property dictionary with instances of this
	class.
"*/

#import "RepositoryProperties.h"

#import "CVLDelegate.h"
#import "CvsRepository.h"
#import "AddRepositoryController.h"

#import <SenFoundation/SenFoundation.h>
#import <SenOpenPanelController.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

static NSMutableDictionary *repositoryPropertiesCache = nil;

@implementation RepositoryProperties

+ (NSMutableDictionary *)repositoryPropertiesCache
{
	if ( repositoryPropertiesCache == nil ) {
		repositoryPropertiesCache = [[NSMutableDictionary alloc] initWithCapacity:8];
	}
	return repositoryPropertiesCache;
}

- (id) init
{
	if((self = [super init])){
		[self setCvsExecutablePath:[[NSUserDefaults standardUserDefaults] stringForKey:@"CVSPath"]];
	}

	return self;
}

- (void) dealloc
    /*" This method releases our instance variables.
    "*/
{		
	RELEASE(repositoryMethod);
	RELEASE(repositoryPath);
	RELEASE(repositoryCompressionLevel);
	RELEASE(repositoryUser);
	RELEASE(repositoryHost);
	RELEASE(repositoryPassword);
	RELEASE(repositoryRoot);
	RELEASE(cvsExecutablePath);
	RELEASE(repositoryPort);
    [super dealloc];
}

- (NSDictionary *)propertiesDictionary
	/*" This method returns the properties of this class in a dictionary form.
		This is a dictionary with values for the keys "repositoryRoot", 
		"repositoryMethod", "repositoryUser", "repositoryHost", 
		"repositoryPath", "repositoryPassword" and "repositoryCompressionLevel".
    "*/
{
	NSString *aRepositoryMethod = nil;
	NSString *aRepositoryPath = nil;
	NSString *aRepositoryUser = nil;
	NSString *aRepositoryPassword = nil;
	NSString *aRepositoryHost = nil;
	NSString *aRepositoryRoot = nil;	
	NSNumber *aRepositoryCompressionLevel = nil;
	NSNumber *aRepositoryPort = nil;
	NSString *aPath;
	NSMutableDictionary *theRepositoryPropertiesDictionary = nil;
		
	theRepositoryPropertiesDictionary = [NSMutableDictionary dictionaryWithCapacity:8];
	
	aRepositoryMethod = [self repositoryMethod];
	// Method
	[theRepositoryPropertiesDictionary setObject:aRepositoryMethod forKey:METHOD_KEY];
	// Path
	aRepositoryPath = [self repositoryPath];
	if ( aRepositoryPath != nil ) {
		[theRepositoryPropertiesDictionary setObject:aRepositoryPath forKey:PATH_KEY];
	}
	// Compression Level
	aRepositoryCompressionLevel = [self repositoryCompressionLevel];
	SEN_ASSERT_CLASS(aRepositoryCompressionLevel, @"NSNumber");
	if ( aRepositoryCompressionLevel != nil ) {
		[theRepositoryPropertiesDictionary setObject:aRepositoryCompressionLevel 
									forKey:COMPRESSION_LEVEL_KEY];
	}
	// User
	aRepositoryUser = [self repositoryUser];
	if ( aRepositoryUser != nil ) {
		[theRepositoryPropertiesDictionary setObject:aRepositoryUser forKey:USER_KEY];
	}
	// Host
	aRepositoryHost = [self repositoryHost];
	if ( aRepositoryHost != nil ) {
		[theRepositoryPropertiesDictionary setObject:aRepositoryHost forKey:HOST_KEY];
	}	
	// Password
	aRepositoryPassword = [self repositoryPassword];
	if ( aRepositoryPassword != nil ) {
		[theRepositoryPropertiesDictionary setObject:aRepositoryPassword 
									forKey:PASSWORD_KEY];
	}	
	// Root
	aRepositoryRoot = [self repositoryRoot];
	if ( aRepositoryRoot != nil ) {
		[theRepositoryPropertiesDictionary setObject:aRepositoryRoot 
									forKey:ROOT_KEY];
	}	
	// cvs binary
	aPath = [self cvsExecutablePath];
	if ( aPath != nil ) {
		[theRepositoryPropertiesDictionary setObject:aPath 
											  forKey:CVS_EXECUTABLE_PATH_KEY];
	}	
	// Port
	aRepositoryPort = [self repositoryPort];
	SEN_ASSERT_CLASS(aRepositoryPort, @"NSNumber");
	if ( aRepositoryPort != nil ) {
		[theRepositoryPropertiesDictionary setObject:aRepositoryPort 
                                              forKey:PORT_KEY];
	}
	
	return theRepositoryPropertiesDictionary;
}

- (BOOL) cvsExistsAtPath:(NSString *)path
{
	NSFileManager	*fileManager = nil;
	BOOL isDirectory = NO;
	BOOL doesFileExists = NO;
	
	// Make sure the path exists and is a directory.
	fileManager = [NSFileManager defaultManager];
	doesFileExists = [fileManager senFileExistsAtPath:path 
										  isDirectory:&isDirectory];
	
	return doesFileExists && !isDirectory;
}

- (BOOL)doesRepositoryPathExist:(NSString *)aRepositoryPath
	/*" This method returns YES if the directory path given in the argument 
		aRepositoryPath exists on the local machine. If this directory does not
		exists then an alert panel is displayed to the user and NO is returned 
		from this method.

		See also #{-validateRepositoryProperties};
	"*/
{
	NSFileManager	*fileManager = nil;
	BOOL isAValidDirectory = NO;
	BOOL isDirectory = NO;
	BOOL doesDirectoryExists = NO;
	
	// Make sure the path exists and is a directory.
	fileManager = [NSFileManager defaultManager];
	doesDirectoryExists = [fileManager senFileExistsAtPath:aRepositoryPath 
											   isDirectory:&isDirectory];
	if ( doesDirectoryExists == YES ) {
		if ( isDirectory == YES ) {
			isAValidDirectory = YES;
		} else {
			(void)NSRunAlertPanel(@"Add Repository Error",
				  @"This path \"%@\" is not a directory. Please select only directories.", 
				  @"OK", nil, nil, aRepositoryPath);
			isAValidDirectory = NO;			
		}
	} else {
		(void)NSRunAlertPanel(@"Add Repository Error",
			  @"This path \"%@\" does not exists. Please enter another path.", 
			  @"OK", nil, nil, aRepositoryPath);
		isAValidDirectory = NO;
	}
	return isAValidDirectory;		
}

- (NSString *)repositoryMethod
	/*" This is the get method for the instance variable named 
		repositoryMethod. The repositoryMethod is the access method for the 
		repository. It is one of the following three methods: "local", "pserver"
		and "ext".

		See also #{-setRepositoryMethod:}
    "*/
{
    return repositoryMethod; 
}

- (void)setRepositoryMethod:(NSString *)newRepositoryMethod
	/*" This is the set method for the instance variable named 
		repositoryMethod. The repositoryMethod is the access method for the 
		repository. It is one of the following three methods: "local", "pserver"
		and "ext".

		See also #{-repositoryMethod}
    "*/
{
    if (repositoryMethod != newRepositoryMethod) {
        [newRepositoryMethod retain];
        [repositoryMethod release];
        repositoryMethod = newRepositoryMethod;
    }
}


- (NSString *)repositoryPath
	/*" This is the get method for the instance variable named 
		repositoryPath. The repositoryPath is the absolute path to the 
		repository whether it is on the local machine or a remote server.

		See also #{-setRepositoryPath:}
    "*/
{
    return repositoryPath; 
}

- (void)setRepositoryPath:(NSString *)newRepositoryPath
	/*" This is the set method for the instance variable named 
		repositoryPath. The repositoryPath is the absolute path to the 
		repository whether it is on the local machine or a remote server.

		See also #{-repositoryPath}
    "*/
{
    if (repositoryPath != newRepositoryPath) {
        [newRepositoryPath retain];
        [repositoryPath release];
        repositoryPath = newRepositoryPath;
    }
}

- (BOOL)validateRepositoryPath:(id *)aPathPtr error:(NSError **)outError
	/*" This validation method is passed two parameters by-reference, the value
		object to validate, pointed to by aPathPtr, and the NSError used to 
		return error information.


		There are three possible outcomes from this validation method:


		_{1. The object value is valid, so YES is returned without altering the
		value object or the error.}


		_{2. The object value is modified so that it is valid. In this case YES
		is returned after setting the value parameter to the newly validated 
		value. The error is returned unaltered.}


		_{3. The object value is not valid and canÕt be modified so that it is
		valid. In this case NO is returned after setting the error parameter to
		an NSError object that indicates the reason validation failed.}

		This method is call by the bindings implementation. Here we are checking
		to see if the repository path ends with a slash. If it does then we
		return an error using the CVL_ERROR_DOMAIN and error code 1002. We 
		started error numbering at 1001 and then numbered the error codes 
		consecutively. It also seems that changing the value and returning YES 
		does not work completely. The bindings do not update the UI although the
		value of repositoryPath in this object is updated.
"*/
{
	NSString *aRepositoryPath = nil;
	NSString *anErrorMsg = nil;
	NSString *aLocalizedErrorMsg = nil;
    NSError *anError = nil;
	NSDictionary *aUserInfo = nil;
	
	aRepositoryPath = *aPathPtr;
	if ( aRepositoryPath == nil ) return YES;
		
	if ( [aRepositoryPath hasSuffix:@"/"] == YES ) {
		// If we have a validation error then write the error message to the error
		// pointer passed in.
		anErrorMsg = [NSString stringWithFormat:
			@"The Repository Path that you entered \"%@\" has a trailing slash. CVS does not handle trailing slash very well. Please remove the trailing slash.",
			aRepositoryPath];
		if ( outError != NULL ) {
			aLocalizedErrorMsg = NSLocalizedString(anErrorMsg,
									   @"A Repository Path validation Error");                
			aUserInfo = [NSDictionary dictionaryWithObject:aLocalizedErrorMsg 
											 forKey:NSLocalizedDescriptionKey];
			anError = [NSError errorWithDomain:CVL_ERROR_DOMAIN 
										  code:1002 
									  userInfo:aUserInfo];
			*outError = anError;
		}        
		return NO;
	}
	return YES;
}

- (NSNumber *)repositoryCompressionLevel
	/*" This is the get method for the instance variable named 
		repositoryCompressionLevel. The repositoryCompressionLevel is the
		compression level for this repository. Valid levels are 1 (high speed, 
		low compression) to 9 (low speed, high compression), or 0 to disable 
		compression (the default). Only has an effect on the CVS client. 
		Compression levels are save in the user defaults on a per repository 
		bases. They can be changed in the repository viewer, not in preferences.

		See also #{-setRepositoryCompressionLevel:}
    "*/
{
    return repositoryCompressionLevel; 
}

- (void)setRepositoryCompressionLevel:(NSNumber *)newRepositoryCompressionLevel
	/*" This is the set method for the instance variable named 
		repositoryCompressionLevel. The repositoryCompressionLevel is the
		compression level for this repository. Valid levels are 1 (high speed, 
		low compression) to 9 (low speed, high compression), or 0 to disable 
		compression (the default). Only has an effect on the CVS client. 
		Compression levels are save in the user defaults on a per repository 
		bases. They can be changed in the repository viewer, not in preferences.

		See also #{-repositoryCompressionLevel}
    "*/
{
    if (repositoryCompressionLevel != newRepositoryCompressionLevel) {
        [newRepositoryCompressionLevel retain];
        [repositoryCompressionLevel release];
        repositoryCompressionLevel = newRepositoryCompressionLevel;
    }
}

- (BOOL)validateRepositoryProperties
	/*" Invoked when the user clicks on the Add Button in the Add Repository
		Panel and before the panel is closed. This method returns a YES if the 
		repository method is "local" and the absolute path in the instance 
		variable repositoryPath exists. Yes is also returned for all the other
		repository methods. If this method returns No then the Add Repository
		Panel is kept open to allow the user to enter a valid repository path.
	"*/
{
	NSString *aRepositoryPath = nil;
	BOOL isAValidDirectory = YES;
	BOOL isAValidCVS = [self cvsExistsAtPath:[self cvsExecutablePath]];
	
	// If a local repository then check to see if the directory exist.
	if ( [repositoryMethod isEqualToString :@"local"] ) {
		aRepositoryPath = [self repositoryPath];
		isAValidDirectory = [self doesRepositoryPathExist:aRepositoryPath];
	}
	return isAValidDirectory && isAValidCVS;
}

- (NSString *)repositoryUser
	/*" This is the get method for the instance variable named repositoryUser. 
		The repositoryUser is the user that is logged into the cvs server. Or if
		a local repository then it is the user logged into the local machine.

		See also #{-setRepositoryUser:}
    "*/
{
    return repositoryUser; 
}

- (void)setRepositoryUser:(NSString *)newRepositoryUser
	/*" This is the set method for the instance variable named repositoryUser. 
		The repositoryUser is the user that is logged into the cvs server. Or if
		a local repository then it is the user logged into the local machine.

		See also #{-repositoryUser}
    "*/
{
    if (repositoryUser != newRepositoryUser) {
        [newRepositoryUser retain];
        [repositoryUser release];
        repositoryUser = newRepositoryUser;
    }
}


- (NSString *)repositoryHost
	/*" This is the get method for the instance variable named repositoryHost. 
		The repositoryHost is the name of the machine on which the repository 
		resides.

		See also #{-setRepositoryHost:}
    "*/
{
    return repositoryHost; 
}

- (void)setRepositoryHost:(NSString *)newRepositoryHost
	/*" This is the set method for the instance variable named repositoryHost. 
		The repositoryHost is the name of the machine on which the repository 
		resides.

		See also #{-repositoryHost}
    "*/
{
    if (repositoryHost != newRepositoryHost) {
        [newRepositoryHost retain];
        [repositoryHost release];
        repositoryHost = newRepositoryHost;
    }
}


- (NSString *)repositoryPassword
	/*" This is the get method for the instance variable named repositoryPassword. 
		The repositoryPassword is the password needed by the repository user to 
		log into the cvs repository.

		See also #{-setRepositoryPassword:}
    "*/
{
    return repositoryPassword; 
}

- (void)setRepositoryPassword:(NSString *)newRepositoryPassword
	/*" This is the set method for the instance variable named repositoryPassword. 
		The repositoryPassword is the password needed by the repository user to 
		log into the cvs repository.

		See also #{-repositoryPassword}
    "*/
{
    if (repositoryPassword != newRepositoryPassword) {
        [newRepositoryPassword retain];
        [repositoryPassword release];
        repositoryPassword = newRepositoryPassword;
    }
}


- (NSString *)repositoryRoot
	/*" This is the get method for the instance variable named repositoryRoot. 
		The repositoryRoot is use for remote repositories only. The 
		repositoryRoot is in the format of: 

		!{[:method:][[user][:password]@]hostname[:[port]]/path/to/repository}

		See also #{-setRepositoryRoot:}
    "*/
{
    return repositoryRoot; 
}

- (void)setRepositoryRoot:(NSString *)newRepositoryRoot
	/*" This is the set method for the instance variable named repositoryRoot. 
		The repositoryRoot is use for remote repositories only. The 
		repositoryRoot is in the format of: 

		!{[:method:][[user][:password]@]hostname[:[port]]/path/to/repository}

		Note: Specifying a password in the repository name is not recommended
		during checkout, since this will cause cvs to store a cleartext copy of
		the password in each created directory.

		See also #{-repositoryRoot}
    "*/
{
    if (repositoryRoot != newRepositoryRoot) {
        [newRepositoryRoot retain];
        [repositoryRoot release];
        repositoryRoot = newRepositoryRoot;
    }
}

- (NSString *)cvsExecutablePath
{
    return cvsExecutablePath;
}

- (void) setCvsExecutablePath:(NSString *)value
{
	ASSIGN(cvsExecutablePath, value);
}

- (NSNumber *)repositoryPort
{
    return repositoryPort;
}

- (void)setRepositoryPort:(NSNumber *)newRepositoryPort
{
    ASSIGN(repositoryPort, newRepositoryPort);
}

+ (RepositoryProperties *)parseRepositoryRoot:(NSString *)aRepositoryRoot
	/*" This method will parse the repository root string passed to it in the 
		argument named aRepositoryRoot. If it findes no inconsistances then this
		method will return an instance of the class RepositoryProperties with 
		the results of this parsing. If any errors are encountered then an alert
		panel will be displayed to the user and nil will be returned from this
		method. Following are the format of the different repository root 
		strings that this method can parse:

		_{:(gserver|kserver|pserver):[[user][:password]@]host[:[port]]/path}
		_{[:(ext|server):][[user]@]host[:]/path}
		_{:local:e:\path}
		_{:fork:/path}
	"*/

{
    RepositoryProperties *newRepositoryProperties;
	NSString	*aWorkingCopy		= nil;
	NSString	*aMethod			= nil;
	NSString	*theNonPathPart		= nil;
	NSString	*thePath			= nil;
	NSString	*aUserAndPassword	= nil;
	NSString	*aUser				= nil;
	NSString	*aPassword			= nil;
	NSString	*aHostAndPort		= nil;
	NSString	*aHost				= nil;
	NSString	*aPortString		= nil;
	NSNumber	*aPort				= nil;

	NSRange		 aRange;
	int			 aPortValue			= 0;

	if ( isNilOrEmpty(aRepositoryRoot) ) {
		return nil;
	}
	
	// Check to see if this entry is already in our cache. 
	// If it is then just return it.
	newRepositoryProperties = [[self repositoryPropertiesCache] objectForKey:aRepositoryRoot];
	if ( newRepositoryProperties != nil ) {
		return newRepositoryProperties;
	}

	// It was not in our cache so create a new one.
	newRepositoryProperties = [[RepositoryProperties alloc] init];

	// Create a pointer of the repository root passed to this method to work with.
	aWorkingCopy = aRepositoryRoot;
	
	if ( [aWorkingCopy hasPrefix:@":"] == YES ) {
		
		aWorkingCopy = [aWorkingCopy substringFromIndex:1];

		aRange = [aWorkingCopy rangeOfString:@":"];
		if ( aRange.location == NSNotFound ) {
			(void)NSRunAlertPanel(@"Repository Root Error",
				  @"This Repository Root \"%@\" has no closing colon (:).", 
				  @"OK", nil, nil, aRepositoryRoot);
			[newRepositoryProperties release];
			return nil;
		}
		
		aMethod = [aWorkingCopy substringToIndex:aRange.location];
		aWorkingCopy = [aWorkingCopy substringFromIndex:(aRange.location + 1)];

		// Check the access method
		if ( [aMethod isEqualToString:@"local"] ||
			 [aMethod isEqualToString:@"pserver"] ||
			 [aMethod isEqualToString:@"kserver"] ||
			 [aMethod isEqualToString:@"gserver"] ||
			 [aMethod isEqualToString:@"server"] ||
			 [aMethod isEqualToString:@"ext"] ||
			 [aMethod isEqualToString:@"fork"] ) {
			[newRepositoryProperties setRepositoryMethod:aMethod];
		} else {
			(void)NSRunAlertPanel(@"Repository Root Error",
				  @"This Repository Root \"%@\" has an invalid method of \"%@\". It has to be one of the following: local, pserver, kserver, gserver, server, ext or fork.", 
				  @"OK", nil, nil, aRepositoryRoot, aMethod);
			[newRepositoryProperties release];
			return nil;
		}

    } else {
		// If there is no method specified then assume that it is local if the
		// path is absolute, otherwise assume the method is ext if not.
		if ( [aWorkingCopy hasPrefix:@"/"] == YES ) {
			aMethod = @"local";
		} else {
			aMethod = @"ext";
		}
		[newRepositoryProperties setRepositoryMethod:aMethod];
    }


	if ( ([aMethod isEqualToString:@"local"] == NO) &&
		 ([aMethod isEqualToString:@"fork"] == NO) ) {
		// For the remote access methods.
		
		// Split the remaining string into two parts. The path part and the non-
		// path part. The non-path part will look like this:
		// [[user][:password]@]host[:[port]]
		aRange = [aWorkingCopy rangeOfString:@"/"];
		if ( aRange.location == NSNotFound ) {
			(void)NSRunAlertPanel(@"Repository Root Error",
				  @"This Repository Root \"%@\" has an invalid path. It is missing a slash (/) in front of the path.", 
				  @"OK", nil, nil, aRepositoryRoot);
			[newRepositoryProperties release];
			return nil;
		}
		
		theNonPathPart = [aWorkingCopy substringToIndex:aRange.location];
		thePath = [aWorkingCopy substringFromIndex:aRange.location];
		[newRepositoryProperties setRepositoryPath:thePath];

		// Check to see if there is a username[:password] in the string.
		aRange = [theNonPathPart rangeOfString:@"@"];
		if ( aRange.location == NSNotFound ) {
			aHostAndPort = theNonPathPart;
		} else {
			aUserAndPassword = [theNonPathPart substringToIndex:aRange.location];
			aHostAndPort = [theNonPathPart substringFromIndex:(aRange.location + 1)];

			// Check for a password.
			aRange = [aUserAndPassword rangeOfString:@":"];
			if ( aRange.location == NSNotFound ) {
				aUser = aUserAndPassword;
				[newRepositoryProperties setRepositoryUser:aUser];
			} else {
				aUser = [aUserAndPassword substringToIndex:aRange.location];
				[newRepositoryProperties setRepositoryUser:aUser];
				aPassword = [aUserAndPassword substringFromIndex:(aRange.location + 1)];
				[newRepositoryProperties setRepositoryPassword:aPassword];
			}
		}

		// Parse the host[:[port]] part of the string.
		aRange = [aHostAndPort rangeOfString:@":"];
		if ( aRange.location == NSNotFound ) {
			aHost = aHostAndPort;
			[newRepositoryProperties setRepositoryHost:aHost];
		} else {
			aHost = [aHostAndPort substringToIndex:aRange.location];
			[newRepositoryProperties setRepositoryHost:aHost];
			aPortString = [aHostAndPort substringFromIndex:(aRange.location + 1)];
			aPortValue = [aPortString intValue];
			if ( aPortValue > 0 ) {
				aPort = [NSNumber numberWithInt:aPortValue];
				[newRepositoryProperties setRepositoryPort:aPort];
			}
		}
    }

	// Validate the various properties
	
	// Check for a host if there is a user.
	if ( isNotEmpty(aUser) && isNilOrEmpty(aHost) ) {
		(void)NSRunAlertPanel(@"Repository Root Error",
			  @"This Repository Root \"%@\" has an user but it is missing a host name.", 
			  @"OK", nil, nil, aRepositoryRoot);
		[newRepositoryProperties release];
		return nil;		
	}

	// Check the local access method.
    if ( [aMethod isEqualToString:@"local"] == YES ) {
		if ( isNotEmpty(aUser) ) {
			(void)NSRunAlertPanel(@"Repository Root Error",
				  @"This Repository Root \"%@\" has a local access method but also specifies a user. This is not allowed.", 
				  @"OK", nil, nil, aRepositoryRoot);
			[newRepositoryProperties release];
			return nil;	
		}
		if ( isNotEmpty(aHost) ) {
			(void)NSRunAlertPanel(@"Repository Root Error",
				  @"This Repository Root \"%@\" has a local access method but also specifies a host. This is not allowed.", 
				  @"OK", nil, nil, aRepositoryRoot);
			[newRepositoryProperties release];
			return nil;	
		}
		if ( [thePath isAbsolutePath] == NO ) {
			(void)NSRunAlertPanel(@"Repository Root Error",
				  @"This Repository Root \"%@\" has a local access method but also specifies a relative path. This is not allowed.", 
				  @"OK", nil, nil, aRepositoryRoot);
			[newRepositoryProperties release];
			return nil;	
		}
	}

	// Fork method checks
	if ( [aMethod isEqualToString:@"fork"] == YES ) {
		if ( isNotEmpty(aUser) ) {
			(void)NSRunAlertPanel(@"Repository Root Error",
				  @"This Repository Root \"%@\" has a fork access method but also specifies a user. This is not allowed.", 
				  @"OK", nil, nil, aRepositoryRoot);
			[newRepositoryProperties release];
			return nil;	
		}
		if ( isNotEmpty(aHost) ) {
			(void)NSRunAlertPanel(@"Repository Root Error",
				  @"This Repository Root \"%@\" has a fork access method but also specifies a host. This is not allowed.", 
				  @"OK", nil, nil, aRepositoryRoot);
			[newRepositoryProperties release];
			return nil;	
		}		
		if ( [thePath isAbsolutePath] == NO ) {
			(void)NSRunAlertPanel(@"Repository Root Error",
				  @"This Repository Root \"%@\" has a fork access method but also specifies a relative path. This is not allowed.", 
				  @"OK", nil, nil, aRepositoryRoot);
			[newRepositoryProperties release];
			return nil;	
		}		
	}
	
	// A password check.
	if ( ([aMethod isEqualToString:@"pserver"] == NO) &&
		 isNotEmpty(aPassword)) {
		(void)NSRunAlertPanel(@"Repository Root Error",
			  @"This Repository Root \"%@\" has a password specified. This is only allowed for the pserver access method. The method here is \"%@\"", 
			  @"OK", nil, nil, aRepositoryRoot, aMethod);
		[newRepositoryProperties release];
		return nil;			
	}
	
	// A port check.
	if ( ([aMethod isEqualToString:@"gserver"] == NO) &&
		 ([aMethod isEqualToString:@"kserver"] == NO) &&
		 ([aMethod isEqualToString:@"pserver"] == NO) &&
		 (aPort != nil) ) {
		(void)NSRunAlertPanel(@"Repository Root Error",
			  @"This Repository Root \"%@\" has a port specified of value %@. This is only allowed for the gserver, kserver and pserver access methods. The method here is \"%@\"", 
			  @"OK", nil, nil, aRepositoryRoot, aPort, aMethod);
		[newRepositoryProperties release];
		return nil;			
	}
	    
	// Save this entry in our cache.
	[[self repositoryPropertiesCache] setObject:newRepositoryProperties forKey:aRepositoryRoot];

    return newRepositoryProperties;
}

- (BOOL)isEqual:(RepositoryProperties *)otherRepositoryProperties ignorePort:(BOOL)portIsIgnored
	/*" This method will return YES if this instance is equal to the instance
		otherRepositoryProperties. If portIsIgnored is YES then the port value 
		of the two objects is ignored for purposes of equality. Equality here is
		meant to mean that all the instance variables are equal with the 
		exception of the repositoryCompressionLevel and the repositoryRoot. The 
		repositoryCompressionLevel has no bearing on what we mean by equality 
		here. And the repositoryRoot is made up of the value of the other 
		instance varibles and hence does not need to be included in the equality
		check.
"*/
{
	// Developer Note: As of 21-Jul-2005 this method is not being used. At some 
	// point when this class takes over the duties of the repository properties 
	// dictionary then this method will be useful. William Swats
	NSString *otherRepositoryMethod		= nil;
	NSString *otherRepositoryPath		= nil;
	NSString *otherRepositoryUser		= nil;
	NSString *otherRepositoryPassword	= nil;
	NSString *otherRepositoryHost		= nil;
	NSString *otherCvsExecutablePath	= nil;
	NSNumber *otherRepositoryPort		= nil;
	NSNumber *tmpRepositoryPort			= nil;
	NSNumber *tmpOtherRepositoryPort	= nil;
	
	otherRepositoryMethod = [otherRepositoryProperties repositoryMethod];
	if ( isNilOrEmpty(repositoryMethod) && isNotEmpty(otherRepositoryMethod) ) {
		return NO;
	}
	if ( isNotEmpty(repositoryMethod) && isNilOrEmpty(otherRepositoryMethod) ) {
		return NO;
	}
	if ( isNotEmpty(repositoryMethod) && isNotEmpty(otherRepositoryMethod) ) {
		if ( [repositoryMethod isEqualToString:otherRepositoryMethod] == NO ) {
			return NO;
		}		
	}
	
	otherRepositoryPath = [otherRepositoryProperties repositoryPath];
	if ( isNilOrEmpty(repositoryPath) && isNotEmpty(otherRepositoryPath) ) {
		return NO;
	}
	if ( isNotEmpty(repositoryPath) && isNilOrEmpty(otherRepositoryPath) ) {
		return NO;
	}
	if ( isNotEmpty(repositoryPath) && isNotEmpty(otherRepositoryPath) ) {
		if ( [repositoryPath isEqualToString:otherRepositoryPath] == NO ) {
			return NO;
		}
	}
	
	otherRepositoryUser = [otherRepositoryProperties repositoryUser];
	if ( isNilOrEmpty(repositoryUser) && isNotEmpty(otherRepositoryUser) ) {
		return NO;
	}
	if ( isNotEmpty(repositoryUser) && isNilOrEmpty(otherRepositoryUser) ) {
		return NO;
	}
	if ( isNotEmpty(repositoryUser) && isNotEmpty(otherRepositoryUser) ) {
		if ( [repositoryUser isEqualToString:otherRepositoryUser] == NO ) {
			return NO;
		}
	}
	
	otherRepositoryPassword = [otherRepositoryProperties repositoryPassword];
	if ( isNilOrEmpty(repositoryPassword) && isNotEmpty(otherRepositoryPassword) ) {
		return NO;
	}
	if ( isNotEmpty(repositoryPassword) && isNilOrEmpty(otherRepositoryPassword) ) {
		return NO;
	}
	if ( isNotEmpty(repositoryPassword) && isNotEmpty(otherRepositoryPassword) ) {
		if ( [repositoryPassword isEqualToString:otherRepositoryPassword] == NO ) {
			return NO;
		}
	}
	
	otherRepositoryHost = [otherRepositoryProperties repositoryHost];
	if ( isNilOrEmpty(repositoryHost) && isNotEmpty(otherRepositoryHost) ) {
		return NO;
	}
	if ( isNotEmpty(repositoryHost) && isNilOrEmpty(otherRepositoryHost) ) {
		return NO;
	}
	if ( isNotEmpty(repositoryHost) && isNotEmpty(otherRepositoryHost) ) {
		if ( [repositoryHost isEqualToString:otherRepositoryHost] == NO ) {
			return NO;
		}
	}
	
	otherCvsExecutablePath = [otherRepositoryProperties cvsExecutablePath];
	if ( isNilOrEmpty(cvsExecutablePath) && isNotEmpty(otherCvsExecutablePath) ) {
		return NO;
	}
	if ( isNotEmpty(cvsExecutablePath) && isNilOrEmpty(otherCvsExecutablePath) ) {
		return NO;
	}
	if ( isNotEmpty(cvsExecutablePath) && isNotEmpty(otherCvsExecutablePath) ) {
		if ( [cvsExecutablePath isEqualToString:otherCvsExecutablePath] == NO ) {
			return NO;
		}
	}
	
	if ( portIsIgnored == NO ) {
		otherRepositoryPort = [otherRepositoryProperties repositoryPort];
		if (repositoryPort == nil) {
			tmpRepositoryPort = [NSNumber numberWithInt:0];
		}
		if (otherRepositoryPort == nil) {
			tmpOtherRepositoryPort = [NSNumber numberWithInt:0];
		}
		if ( [tmpRepositoryPort isEqual:tmpOtherRepositoryPort] == NO ) {
			return NO;
		}				
	}
	
	return YES;
}

- (NSString *)repositoryRootWithoutPort
	/*" This method returns the repository root string that is calculated from 
		the various instance variables of this class. If there is no access 
		method in this instance an empty string is returned.
	"*/
{
	NSMutableString	*aRoot	= nil;
	
	aRoot = [NSMutableString stringWithCapacity:128];

	if ( isNilOrEmpty(repositoryMethod) ) {
		return aRoot;
	}

	if ( ([repositoryMethod isEqualToString:@"local"] == YES) ||
		 ([repositoryMethod isEqualToString:@"fork"] == YES) ) {
		if ( isNotEmpty(repositoryPath) ) {
			[aRoot appendFormat:@"%@", repositoryPath];
		}
	} else {
		[aRoot appendFormat:@":%@:", repositoryMethod];
		if ( isNotEmpty(repositoryUser) ) {
			[aRoot appendFormat:@"%@", repositoryUser];
		}
		if ( isNotEmpty(repositoryPassword) ) {
			[aRoot appendFormat:@":%@", repositoryPassword];
		}
		if ( isNotEmpty(repositoryHost) ) {
			[aRoot appendFormat:@"@%@:", repositoryHost];
		}
		if ( isNotEmpty(repositoryPath) ) {
			[aRoot appendFormat:@"%@", repositoryPath];
		}
	}
	return aRoot;
}


@end
