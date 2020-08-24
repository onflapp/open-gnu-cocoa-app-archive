// Copyright (c) 2000, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

// This code is based on OmniWebLauncher code, copyright 1998-1999 Omni Development, Inc.
// This code is published with the approval of Omni Development.
// Original code can be retrieved from:
// ftp://ftp.omnigroup.com/pub/software/Source/OpenStep/Applications/OmniWebLauncher-1999-04-19.tar.gz
//
// Modifications to the original code:
// - support for WIN32
// - target is now a tool; no longer an application
// - removed dependencies to OmniBase framework
// - removed OpenStep compatibility code
// - removed assertions
// - customized for CVL

// This launcher application is a hack to allow us to bundle frameworks inside our app-wrapper, solving the versionitis problems associated with releasing different apps (OmniWeb, OmniPDF, etc.) all of which use the same set of frameworks.  The basic idea is we create a launcher application that just adds its wrapper directory to the DYLD_FRAMEWORK_PATH environment variable, then launches the real application.

// When building this for product, you should copy the real application and all its associated frameworks into the Resources subdirectory of the launcher application.  Also, make sure that the CustomInfo.plist here is in synch with the one in the real application.  (We should probably just make it a symbolic link.)  Then you can install the launcher wrapper anywhere (e.g. /Local/Applications) and it will run without any additional frameworks needing to be installed.


#ifndef WIN32
#import <unistd.h>
#endif
#import <stdlib.h>
#import <string.h>
#ifndef WIN32
#import <sys/param.h>
#endif
#import <stdio.h>
#ifdef WIN32
#import <windows.h>
#import <winnt.h>
#import <process.h> // execve
#endif


#ifdef WIN32
#define MAXPATHLEN OFS_MAXPATHNAME

#define getwd(pathPtr) GetCurrentDirectory(MAXPATHLEN, pathPtr)
#define chdir(pathPtr) SetCurrentDirectory(pathPtr)
#endif

extern char **environ;


#define DEFAULT_SYSTEM_FRAMEWORK_PATH "/Local/Library/Frameworks:/Network/Library/Frameworks:/System/Library/Frameworks"

int main(int argc, const char *argv[]) {
    char *currentFrameworkPath;
    char newFrameworkPath[8192];
    const char *pathToLauncherBinary;
    const char *pointerToFinalSlashInPathToLauncherBinary;
    char pathToLauncherAppWrapper[MAXPATHLEN];
    char pathToRealApplicationBinary[MAXPATHLEN];
    const char *applicationName;

    // Note:  Yes, this code would be cleaner in Objective C.  However, that would mean we'd have to start up the Objective C run-time, and since we're just going to terminate as soon as possible we really don't want this to take longer than necessary.  (Also, the Objective C run-time probably has some side effects with respect to our mach ports which we don't want to trigger.)

    // The path to the launcher binary (that's us, dude!) is in argv[0]
    pathToLauncherBinary = argv[0];

    // Calculate the application name and the path to its wrapper
#ifdef WIN32
    // First, let's replace slashes with backslashes...
    for(pointerToFinalSlashInPathToLauncherBinary = pathToLauncherBinary + strlen(pathToLauncherBinary) - 1; pointerToFinalSlashInPathToLauncherBinary >= pathToLauncherBinary; pointerToFinalSlashInPathToLauncherBinary--)
        if(*pointerToFinalSlashInPathToLauncherBinary == '/')
            *(char *)pointerToFinalSlashInPathToLauncherBinary = '\\';
    
    for(pointerToFinalSlashInPathToLauncherBinary = pathToLauncherBinary + strlen(pathToLauncherBinary) - 1; pointerToFinalSlashInPathToLauncherBinary >= pathToLauncherBinary; pointerToFinalSlashInPathToLauncherBinary--)
        if(*pointerToFinalSlashInPathToLauncherBinary == '\\')
            break;
    pointerToFinalSlashInPathToLauncherBinary = (pointerToFinalSlashInPathToLauncherBinary >= pathToLauncherBinary ? pointerToFinalSlashInPathToLauncherBinary : NULL);
#else
    pointerToFinalSlashInPathToLauncherBinary = rindex(pathToLauncherBinary, '/');
#endif
    if (!pointerToFinalSlashInPathToLauncherBinary) {
        // No (back)slashes in the path to the launcher binary

        // Our application name is simply the path
        applicationName = pathToLauncherBinary;

        // Our wrapper had better be the current working directory.
        getwd(pathToLauncherAppWrapper);
    } else {
        // Our application name follows that final (back)slash
        applicationName = pointerToFinalSlashInPathToLauncherBinary + 1;

        // The (possibly relative) path to the app wrapper is everything up to that final slash
        strcpy(pathToLauncherAppWrapper, pathToLauncherBinary);
        pathToLauncherAppWrapper[pointerToFinalSlashInPathToLauncherBinary - pathToLauncherBinary] = '\0'; // truncate at the final slash

#ifdef WIN32
        // Check for drive letter and URN formats (C:\, or \\machine\)
        if ((pathToLauncherAppWrapper[1] == ':' && pathToLauncherAppWrapper[2] == '\\') || (pathToLauncherAppWrapper[0] == '\\' && pathToLauncherAppWrapper[1] == '\\')) {
#else
        if (pathToLauncherAppWrapper[0] == '/') {
#endif
            // The app wrapper path is already an absolute path, just use it
        } else {
            char originalWorkingDirectory[MAXPATHLEN];

            // Turn the app wrapper path into a relative path.  This would sure be easy with NSString's path utilities, but...

            // Save the original working directory
            getwd(originalWorkingDirectory);
            // chdir() accepts relative paths
            chdir(pathToLauncherAppWrapper);
            // and getwd() returns absolute paths
            getwd(pathToLauncherAppWrapper);
            // Restore the original working directory
            chdir(originalWorkingDirectory);
        }
    }
    // We've now calculated our application name, and the absolute path to our app wrapper

    // Create a new framework path, so it will search for frameworks within our app wrapper before it looks for them anywhere else.

    // Start with the path to our app wrapper's Resources subdirectory
#ifdef WIN32
    sprintf(newFrameworkPath, "PATH=%s\\Resources\\Executables;", pathToLauncherAppWrapper);
#else
    sprintf(newFrameworkPath, "%s/Resources/Frameworks:", pathToLauncherAppWrapper);
#endif

    // Append the standard framework path
#ifdef WIN32
    if ((currentFrameworkPath = getenv("PATH"))) {
#else
    if ((currentFrameworkPath = getenv("DYLD_FRAMEWORK_PATH"))) {
#endif
        // There's already a framework path, append it to the new path
        strcat(newFrameworkPath, currentFrameworkPath);
    } else {
        const char *homeDirectory;

        // There's no framework path currently set, so we should append the standard framework path

        // Append $HOME/Library/Frameworks to the path
        if ((homeDirectory = getenv("HOME"))) {
            strcat(newFrameworkPath, homeDirectory);
#ifdef WIN32
            strcat(newFrameworkPath, "\\Library\\Frameworks:");
#else
            strcat(newFrameworkPath, "/Library/Frameworks:");
#endif
        }

        // Append the default system framework path to the new path
#ifdef WIN32
        {
            char *nextRoot = getenv("NEXT_ROOT");

            if(nextRoot){
                strcat(newFrameworkPath, nextRoot);
                strcat(newFrameworkPath, "\\Local\\Library\\Executables:");
                strcat(newFrameworkPath, nextRoot);
                strcat(newFrameworkPath, "\\Library\\Executables");
            }
        }
#else
        strcat(newFrameworkPath, DEFAULT_SYSTEM_FRAMEWORK_PATH);
#endif
    }

#ifdef WIN32
    // Set the PATH environment variable to use our new path
    (void)putenv(newFrameworkPath);
#else
    // Set the DYLD_FRAMEWORK_PATH environment variable to use our new path
    setenv("DYLD_FRAMEWORK_PATH", newFrameworkPath, 1);
#endif
        
    // Launch the real application

    // It should live in the launcher's appWrapper's Resources directory under the name <applicationName>.app/<applicationName>
#ifdef WIN32
    (void)strncpy(newFrameworkPath, applicationName, strlen(applicationName) - 4);
    newFrameworkPath[strlen(applicationName) - 4] = '\0';
    sprintf(pathToRealApplicationBinary, "%s\\Resources\\%s.app\\%s", pathToLauncherAppWrapper, newFrameworkPath, applicationName);
#else
    sprintf(pathToRealApplicationBinary, "%s/Resources/%s.app/%s", pathToLauncherAppWrapper, applicationName, applicationName);
#endif

    // Let the user know what we're doing
    fprintf(stderr, "Launching %s...\n", pathToRealApplicationBinary);

    // We'll be passing the real application the exact same arguments we received, except that we'll pass it the path to itself in argv[0] rather than the path to us.
    argv[0] = pathToRealApplicationBinary;

    // Execute the real application.  If successful, this call does not return.  (It doesn't fork off a process, it launches the other application in place of the current application within the current process.)
#ifdef WIN32
    execve(pathToRealApplicationBinary, argv, (const char * const *)environ);
#else
    execve(pathToRealApplicationBinary, argv, environ);
#endif

    // This code does not get called in normal operation:  if execve() succeeds, it doesn't return, so in this case execve() must have failed.

    // Print the error message associated with the current error condition
    perror(pathToRealApplicationBinary);

    // Return an error status.
    return 1;
}
