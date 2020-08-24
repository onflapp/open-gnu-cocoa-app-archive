/* CvsModule.m created by stephane on Wed 08-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CvsModule.h"
#import "NSString_SenCaseInsensitiveComparison.h"
#import <CvsRepository.h>
#import <NSString+Lines.h>
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>
#import <AGRegex/AGRegexes.h>
#import <CVLConsoleController.h>



@implementation CvsModule

/*" Module list can be retrieved with cvs checkout -c and cvs checkout -s 
    commands. Using -c option, we get a parsed module list with all options; all 
    components are separated by a space. Description of one module can extend
    beyond one line, beginning with spaces on following lines. Inline comments 
    are not retrieved.  Using -s option, we can get inline comments, but not the 
    options! So, to get all info, we'd need to perform two requests, and merge
    their results. To save a new module list, we could simply replace module 
    definitions one after the other in the original file, thus we don't loose 
    general comments and file structure. Using cvs built-in functionalities will
    avoid us to make errors in modules parsing...
"*/

+ (NSArray *) parseModuleDescription:(NSString *)aModuleDescription forRepository:(CvsRepository *)aRepository errors:(NSArray **)moduleErrorsPtr
    /*" This method will parse the contents of aModuleDescription and return an 
        array of CvsModules for the repository in aRepository and in addition 
        will return any errors in an array pointed to by moduleErrorsPtr. This 
        method tries to parse all lines; if an error occurs in a line, it will 
        continue to next line. This method can be used to check validity of a 
        module file.
     "*/
{
    NSString            *aCopy = nil;
    NSString            *aCopy2 = nil;
    NSString            *aCopy3 = nil;
    NSArray				*linesArray;
    NSMutableDictionary	*modulesDictionary = nil;
    NSMutableArray		*moduleErrors = nil;
    NSString            *anError = nil;
    CvsModule           *aModule = nil;
    NSString            *lineString = nil;
    NSEnumerator        *lineEnum = nil;
    unsigned int        num = 0;

    // <modules> parsing is defined in project cvs: src/mkmodules.c:write_dbmfile()
    // 1) Check for trailing backslashes and replace them and the following EOL with a space
    // 2) Check for lines beginning with # (MUST be first line character), and remove them
    // 3) Remove prefixing spaces (isspace())
    // 4) Remove empty lines
    // 5) Check each key is unique and has a value
    // Module descriptions are parsed later in src/modules.c:do_module()
    // Everything following # is ignored
    
    SEN_ASSERT_CONDITION(( moduleErrorsPtr != NULL ));
    
    aCopy = [aModuleDescription copy];
    
    // 1) Check for lines extended on successive lines with a backslash.
    aCopy2 = [aCopy replaceMatchesOfPattern:@"\\\\\\n"
                                 withString:@" " 
                                    options:0];
    
    // 2) Remove comment lines
    aCopy3 = [aCopy2 replaceMatchesOfPattern:@"^#.*\\n"
                                  withString:@"" 
                                     options:AGRegexMultiline];

    linesArray = [aCopy3 lines];
    num = [linesArray count];
    if ( num > 0 ) {
        moduleErrors = [NSMutableArray array];
        modulesDictionary = [NSMutableDictionary dictionaryWithCapacity:num];
        lineEnum = [linesArray objectEnumerator];
        while ( (lineString = [lineEnum nextObject]) ) {
            lineString = [lineString replaceMatchesOfPattern:@"#.*" 
                                                  withString:@"" 
                                                     options:0]; // Remove inline comment
            aModule = [self parseModuleLine:lineString 
                              forRepository:aRepository 
                                     errors:moduleErrors];
            if ( aModule != nil ) {
                if([modulesDictionary objectForKey:[aModule symbolicName]]) {
                    anError = [NSString stringWithFormat:
                        @"Module \"%@\" is defined more than once -- new definition ignored.", 
                        [aModule symbolicName]];
                    [moduleErrors addObject:anError];
                    
                } else {
                    [modulesDictionary setObject:aModule forKey:[aModule symbolicName]];
                }                
            }
        }
    }

    [aCopy release];

    if ( isNotEmpty(moduleErrors) ) {
        [[moduleErrors retain] autorelease];
        *moduleErrorsPtr = moduleErrors;                
    }
    return [modulesDictionary allValues];
}

+ (CvsModule *) parseModuleLine:(NSString *)lineString forRepository:(CvsRepository *)aRepository errors:(NSMutableArray *)moduleErrors
    /*" This method will parse the contents of the line given in lineString and 
        return a CvsModule for the repository in aRepository and in addition 
        will return any errors in the mutable array moduleErrors. This array has
        to be passed into this method.
    "*/
{
    // cvs uses getopt() with ' ' and '\t' as authorized separators
    // In values, module names beginning with ! are ignored (for aliases only)
    // When parsing options, if an option appears more than once, the last occurence is used
    // Authorized options are -a (with one and more arguments)
    // or -i, -o, -e, -t, -u, -d (with one argument)
    // or -l (without any argument)
    // Option -s (with one argument) is ignored
    // cvs uses GNU's getopt(); getopt() is defined in <bsd/unistd.h>
    NSString        *anError = nil;
    CvsModule		*aModule = nil;
    NSArray			*wordsFromLine = nil;
    NSEnumerator	*wordEnum = nil;
    NSString		*aWord = nil;
    NSString		*firstWord = nil;
    NSArray         *someAliases = nil;
    unsigned int    wordCount = 0;
    NSRange         anAliasesRange;
    
    SEN_ASSERT_CONDITION(( moduleErrors != nil ));

    // Authorized separators are space and tab.
    wordsFromLine = [lineString splitStringWithPattern:@"[ \\t]+" 
                                               options:0]; 
    wordCount = [wordsFromLine count];
    // If this is an empty line just return nil.
    if ( wordCount == 0 ) return nil; 
    
    firstWord = [wordsFromLine objectAtIndex:0];
    if ( wordCount == 1 ) {
        // If this is an empty word just return nil.
        if ( (firstWord == nil) || ([firstWord length] == 0) ) {
            return nil; 
        }                
        anError = [NSString stringWithFormat:
            @"Module \"%@\" is wrongly defined: contains only a symbolic name without any content.", 
            [wordsFromLine lastObject]];
        [moduleErrors addObject:anError];
        return nil; 
    }
    
    aModule = [[self allocWithZone:[aRepository zone]] init];    
    [aModule setRepository:aRepository];
    wordEnum = [wordsFromLine objectEnumerator];
    [aModule setSymbolicName:[wordEnum nextObject]]; // Index 0
    aWord = [wordEnum nextObject]; // Index 1
    if ( [aWord isEqualToString:@"-a"] ) {
        // Option MUST be separated from file list; cvs does not like it otherwise
        if(wordCount < 3){
            anError = [NSString stringWithFormat:
                @"Module \"%@\" is wrongly defined: no aliases but has option \"-a\".", 
                [aModule symbolicName]];
            [moduleErrors addObject:anError];
            return nil; 
        }
        // Alias names beginning with ! will be ignored by cvs
        anAliasesRange = NSMakeRange(2, wordCount - 2);
        someAliases = [wordsFromLine subarrayWithRange:anAliasesRange];
        [aModule setAliases:someAliases];
    } else {
        NSMutableDictionary	*theOptions = [NSMutableDictionary dictionaryWithCapacity:10];
        NSMutableArray		*theFiles = [NSMutableArray array];
        NSMutableArray		*additionalModulesNames = [NSMutableArray array];
        
        do {
            if ( [aWord hasPrefix:@"-"] ) {
#warning (Stephane) BUG 1000097 - Some unsupported option definition types!
                // WARNING: options may be appended in a single block, like in -ld,
                // and option arguments may be appended to option, like in -dMyDirectory
                // Currently we do NOT support this!!!
                NSString	*param = [wordEnum nextObject];
                
                if ( [aModule directory] != nil ) {
                    anError = [NSString stringWithFormat:
                        @"Module \"%@\" is wrongly defined: option \"%@\" defined after directory.", 
                        [aModule symbolicName], aWord];
                    [moduleErrors addObject:anError];
                    return nil;
                }
                if ( [aWord isEqualToString:@"-l"] ) {
                    // Option -l requires no parameter! Top-level directory only
                    // -- do not recurse.
                    param = @""; 
                }
                if ( param == nil ) {
                    anError = [NSString stringWithFormat:
                        @"Module \"%@\" is wrongly defined: no parameter after option \"%@\".", 
                        [aModule symbolicName], aWord];
                    [moduleErrors addObject:anError];
                    return nil;
                }
                [theOptions setObject:param forKey:aWord]; // We don't care if option was already defined, like cvs
            } else {
                // WARNING: documentation on cvs has a bug: in 1.10.3, they allow to define a module like this:
                // myModule &anotherModule
                // without any directory...
                if ( ![aWord hasPrefix:@"&"] && ![aModule directory] ) {
                    [aModule setDirectory:aWord];
                } else if ( [aWord hasPrefix:@"&"] ) {
                    if ( [aWord length] <= 1 ){
                        anError = [NSString stringWithFormat:
                            @"Module \"%@\"is wrongly defined: no module name after \"&\".", 
                            [aModule symbolicName]];
                        [moduleErrors addObject:anError];
                        return nil;
                    }
                    [additionalModulesNames addObject:[aWord substringFromIndex:1]];
                } else {
                    /*
                     // cvs supports this, but docs seems to tell the opposite
                     // Let's support is anyway
                     if ( [additionalModulesNames count] != 0 ) {
                         anError = [NSString stringWithFormat:
                            @"Module \"%@\" is wrongly defined: adds file definition after modules enumeration.\n%@",
                             [aModule symbolicName], lineString];
                         [moduleErrors addObject:anError];
                         return nil;
                     }
                     */
                    [theFiles addObject:aWord];
                }
            }
        } while ( (aWord = [wordEnum nextObject]) );
        
        if ( ![aModule directory] && 
             ![theFiles count] && 
             ![additionalModulesNames count]) {
            anError = [NSString stringWithFormat:
                @"Module \"%@\" is wrongly defined: it has no directory, not even a module or file.", 
                [aModule symbolicName]];
            [moduleErrors addObject:anError];
        } else {
            if([theFiles count])
                [aModule setFiles:theFiles];
            if([additionalModulesNames count])
                [aModule setAdditionalModuleNames:additionalModulesNames];
            if([theOptions count])
                [aModule setOptions:theOptions];
        }
    }
    [aModule autorelease];
    return aModule;
}

+ (NSArray *) modulesWithContentsOfFile:(NSString *)aPath forRepository:(CvsRepository *)aRepository
    /*" This method returns an array of CvsModules created from the information
        in the file given in aPath for the repository given in aRepository. If 
        this file cannot be opened for reading then an alert panel is presented 
        to the user.
    "*/
{
    NSString *aModuleDescription = nil;
    NSArray *moduleErrors = nil;
    NSArray	*result = nil;

    aModuleDescription = [NSString stringWithContentsOfFile:aPath];
    // Test to see if we could actually read the file.
    if( aModuleDescription == nil ) {
        // Error: aModuleDescription was nil.
        NSString *aTitle = nil;
        NSString *aMessage = nil;
        
        aTitle = [NSString stringWithFormat:@"CVL Warning"];
        aMessage = [NSString stringWithFormat:
            @"The CVS module file \"%@\" could not be opened for reading.",
            aPath];
        (void)NSRunAlertPanel(aTitle, aMessage, nil, nil, nil);    
        return nil;
    }
    result = [self modulesWithModuleDescription:aModuleDescription 
                                  forRepository:aRepository 
                                         errors:&moduleErrors];
    return result;
}

+ (NSArray *) modulesWithModuleDescription:(NSString *)aModuleDescription forRepository:(CvsRepository *)aRepository errors:(NSArray **)moduleErrorsPtr
    /*" This method returns an array of CvsModules created from the information
        in the argument aModuleDescription for the repository given in 
        aRepository. If any errors are encountered in the parsing of the module
        description then they are returned using the pointer argument named
        moduleErrorsPtr. It is posible to have both CvsModules returned and 
        errors ignored. Errors are also presented in an alert panel to the user
        and logged to the console.
    "*/
{
    NSArray *moduleErrors = nil;
    NSArray	*result = nil;
    NSMutableString *aMsg = nil;
    
    SEN_ASSERT_CONDITION(( moduleErrorsPtr != NULL ));

    NS_DURING
        result = [self parseModuleDescription:aModuleDescription 
                                forRepository:aRepository 
                                       errors:&moduleErrors];
        if ( isNotEmpty(moduleErrors) ) {  
            NSEnumerator *anErrorEnumerator = nil;
            NSString *anError = nil;
            unsigned int aLineNumber = 0;
            
            // Append errors to end of message.
            aMsg = [NSMutableString stringWithFormat:
                @"The module file for repository \"%@\" contained the following errors:\n\n",
                [aRepository root]];
            anErrorEnumerator = [moduleErrors objectEnumerator];
            while ( (anError = [anErrorEnumerator nextObject]) ) {
                aLineNumber++;
                [aMsg appendFormat:@"%d. %@\n", aLineNumber, anError];
            }
            // First write out errors to console.
            [[CVLConsoleController sharedConsoleController] outputError:aMsg];
                
            // Then display an error panel to the user.
            (void)NSRunAlertPanel(@"CVS module Errors", aMsg, nil, nil, nil);                
        }
    NS_HANDLER        
        aMsg = [NSMutableString stringWithFormat:
            @"The module file Exception is \"%@\"\nReason is \"%@\"", 
            [localException name], 
            [localException reason]];
        SEN_LOG(aMsg);
    NS_ENDHANDLER
        if ( isNotEmpty(moduleErrors) ) {
            [[moduleErrors retain] autorelease];
            *moduleErrorsPtr = moduleErrors;                
        }
    return result;
}

+ (BOOL) checkModuleDescription:(NSString *)moduleDescription forRepository:(CvsRepository *)aRepository
    /*" This method returns YES if there are no errors encountered in the 
	parsing of the module information given in moduleDescription for the 
	repository given in aRepository; otherwise NO is returned.
    "*/
{
    NSArray	*moduleErrors = nil;
    
    (void)[self modulesWithModuleDescription:moduleDescription 
									forRepository:aRepository 
										   errors:&moduleErrors];
    if ( isNotEmpty(moduleErrors) ) {
        return NO;
    }
    return YES;
}

- (void) dealloc
{
    RELEASE(symbolicName);
    RELEASE(aliases);
    RELEASE(directory);
    RELEASE(files);
    RELEASE(additionalModuleNames);
    RELEASE(options);
    
    [super dealloc];
}

- (NSString *) description
{
    NSMutableString	*description = [symbolicName mutableCopy];

    if(aliases && [aliases count]){
        [description appendString:@" -a "];
        [description appendString:[aliases componentsJoinedByString:@" "]];
    }
    else{
        if(options && [options count]){
            NSEnumerator	*keyEnum = [options keyEnumerator];
            NSString		*aKey;

            while ( (aKey = [keyEnum nextObject]) ) {
                [description appendFormat:@" %@ %@", aKey, [options objectForKey:aKey]];
            }
        }
        [description appendString:@" "];
        [description appendString:directory];
        if(files && [files count]){
            [description appendString:@" "];
            [description appendString:[files componentsJoinedByString:@" "]];
        }
        if(additionalModuleNames && [additionalModuleNames count]){
            [description appendString:@" &"];
            [description appendString:[additionalModuleNames componentsJoinedByString:@" &"]];
        }        
    }

    if(repository)
        [description appendFormat:@" (in %@)", [repository root]];

    return [description autorelease];
}

- (CvsRepository *) repository
{
    return repository;
}

- (void) setRepository:(CvsRepository *)aRepository
{
    repository = aRepository;
}

- (NSString *) symbolicName
{
    return symbolicName;
}

- (void) setSymbolicName:(NSString *)aSymbolicName
{
    ASSIGN(symbolicName, aSymbolicName);
}

- (NSArray *) aliases
{
    return aliases;
}

- (void) setAliases:(NSArray *)names
{
    ASSIGN(aliases, names);
}

- (NSString *) directory
{
    return directory;
}

- (void) setDirectory:(NSString *)aDirectory
{
    ASSIGN(directory, aDirectory);
}

- (NSArray *) files
{
    return files;
}

- (void) setFiles:(NSArray *)names
{
    ASSIGN(files, names);
}

- (NSArray *) additionalModuleNames
{
    return additionalModuleNames;
}

- (void) setAdditionalModuleNames:(NSArray *)names
{
    ASSIGN(additionalModuleNames, names);
}

- (NSString *) outputDirectoryName
{
    NSString	*aName;

    if(options && (aName = [options objectForKey:@"-d"]))
        return aName;
    
    // WARNING: one case is not handled at all: aliases!
    // If a module is defined by aliasing some paths/modules, many workareas can be opened at once
    // In case of aliases, cvs will create directories as defined by aliases, and not as defined by
    // the module symbolicName.

    if(aliases && [aliases count]){
        // Currently, let's at least support 1 alias item
        CvsModule	*aliasedModule = [[self repository] moduleWithSymbolicName:[aliases objectAtIndex:0]];

        if(aliasedModule)
            return [aliasedModule outputDirectoryName];
        else
            // By path
            return [aliases objectAtIndex:0];
        // If we want to support multiple alias items, we should change -[CVLDelegate requestCompleted:]
        // and -[CvsCheckoutRequest destinationPath] to get all the aliases
    }
    
    return symbolicName;
}

- (void) setOutputDirectoryName:(NSString *)anOutputDirectoryName
{
    if(!options)
        options = [NSMutableDictionary dictionaryWithObject:anOutputDirectoryName forKey:@"-d"];
    else
        [options setObject:anOutputDirectoryName forKey:@"-d"];
}

- (NSString *) statusOption
{
    NSString	*aName = nil;
    
    if(options)
        aName = [options objectForKey:@"-s"];
    return aName;
}

- (void) setStatusOption:(NSString *)aStatusOption
{
    if(!options)
        options = [NSMutableDictionary dictionaryWithObject:aStatusOption forKey:@"-s"];
    else
        [options setObject:aStatusOption forKey:@"-s"];
}

- (NSDictionary *) options
{
    return options;
}

- (void) setOptions:(NSDictionary *)someOptions
{
    [options autorelease];
    options = [someOptions mutableCopyWithZone:[self zone]];
}

- (NSComparisonResult) compareSymbolicName:(CvsModule *)aModule
{
    return [symbolicName senCaseInsensitiveCompare:[aModule symbolicName]];
}

@end
