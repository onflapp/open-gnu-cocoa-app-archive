/*
    PPGNUstepGlueUtilities.m

    Copyright 2014-2018 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for GNUstep.
    PikoPixel is a graphical application for drawing & editing pixel-art images.

    PikoPixel is free software: you can redistribute it and/or modify it under
    the terms of the GNU Affero General Public License as published by the
    Free Software Foundation, either version 3 of the License, or (at your
    option) any later version approved for PikoPixel by its copyright holder (or
    an authorized proxy).

    PikoPixel is distributed in the hope that it will be useful, but WITHOUT ANY
    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
    details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#ifdef GNUSTEP

#import "PPGNUstepGlueUtilities.h"

#import "NSObject_PPUtilities.h"
#import "PPApplication.h"
#import "PPScreencastController.h"


#define macroSystemHasProcessNamed(processName)     \
            ((system("pgrep -x " #processName " >/dev/null 2>&1") == 0) ? YES : NO)


#define macroCheckWindowManager_Budgie          macroSystemHasProcessNamed(budgie-wm)

#define macroCheckWindowManager_Compiz          macroSystemHasProcessNamed(compiz)

#define macroCheckWindowManager_Gala            macroSystemHasProcessNamed(gala)

#define macroCheckWindowManager_KWin            (macroSystemHasProcessNamed(kwin)           \
                                                || macroSystemHasProcessNamed(kwin_x11)     \
                                                || macroSystemHasProcessNamed(kwin_wayland))

#define macroCheckWindowManager_Marco           macroSystemHasProcessNamed(marco)

// Muffin WM (Cinnamon desktop) is a shared library and doesn't have its own process;
// Check instead for the Cinnamon DE.
#define macroCheckWindowManager_Muffin          macroSystemHasProcessNamed(cinnamon)

// Mutter WM (GNOME Shell desktop) is a shared library and doesn't have its own process;
// Check instead for gnome-shell, however, if the display manager is gdm3, it may be running
// its own additional gnome-shell process, so if gdm3 is discovered, check that either it
// doesn't spawn an extra gnome-shell process (depends on gdm3's version), or there's at least
// two gnome-shell processes running - otherwise the DE is probably not GNOME Shell.
#define macroCheckWindowManager_Mutter          (macroSystemHasProcessNamed(gnome-shell)     \
                                                && (!macroSystemHasProcessNamed(gdm3)        \
                                                    || !GDM3SpawnsAnExtraGnomeShellProcess() \
                                                    || SystemHasMultipleGnomeShellProcesses()))

#define macroCheckWindowManager_Openbox         macroSystemHasProcessNamed(openbox)

#define macroCheckWindowManager_WindowMaker     macroSystemHasProcessNamed(wmaker)

#define macroCheckWindowManager_Xfwm            macroSystemHasProcessNamed(xfwm4)


#define kMaxNumStoredSelectors                  10


static void PerformUserDefaultsSelectors(void);

static bool GDM3SpawnsAnExtraGnomeShellProcess(void);
static bool SystemHasMultipleGnomeShellProcesses(void);

static SEL *gUserDefaultsSelectors = NULL;
static int gNumUserDefaultsSelectors = 0;
static bool gGSBackendDidLoad = NO,
                gHadUserDefaultsSelectorError_UnableToAllocateMemoryForSelectors = NO,
                gHadUserDefaultsSelectorError_StoredSelectorsArrayTooSmall = NO;

// Stored NSUserDefaults selectors are called from an overridden private NSApplication method,
// _init, which is the last overrideable method call before the GNUstep backend is loaded

@interface NSApplication (PPGNUstepGlueUtilities)

- (void) _init;

@end


bool PPGSGlueUtils_WindowManagerMatchesTypeMask(unsigned typeMatchMask)
{
    static unsigned windowManagerTypeMask = 0;
    static bool didCheckWindowManagerType = NO;

    if (!didCheckWindowManagerType)
    {
        if (macroCheckWindowManager_Budgie)
        {
            windowManagerTypeMask = kPPGSWindowManagerTypeMask_Budgie;
        }
        else if (macroCheckWindowManager_Compiz)
        {
            windowManagerTypeMask = kPPGSWindowManagerTypeMask_Compiz;
        }
        else if (macroCheckWindowManager_Gala)
        {
            windowManagerTypeMask = kPPGSWindowManagerTypeMask_Gala;
        }
        else if (macroCheckWindowManager_KWin)
        {
            windowManagerTypeMask = kPPGSWindowManagerTypeMask_KWin;
        }
        else if (macroCheckWindowManager_Marco)
        {
            windowManagerTypeMask = kPPGSWindowManagerTypeMask_Marco;
        }
        else if (macroCheckWindowManager_Muffin)
        {
            windowManagerTypeMask = kPPGSWindowManagerTypeMask_Muffin;
        }
        else if (macroCheckWindowManager_Openbox)
        {
            windowManagerTypeMask = kPPGSWindowManagerTypeMask_Openbox;
        }
        else if (macroCheckWindowManager_WindowMaker)
        {
            windowManagerTypeMask = kPPGSWindowManagerTypeMask_WindowMaker;
        }
        else if (macroCheckWindowManager_Xfwm)
        {
            windowManagerTypeMask = kPPGSWindowManagerTypeMask_Xfwm;
        }
        else if (macroCheckWindowManager_Mutter) // Most complicated check, so leave until last
        {
            windowManagerTypeMask = kPPGSWindowManagerTypeMask_Mutter;
        }
        else
        {
            windowManagerTypeMask = 0;
        }

        didCheckWindowManagerType = YES;
    }

    return (windowManagerTypeMask & typeMatchMask) ? YES : NO;
}

bool PPGSGlueUtils_PerformNSUserDefaultsSelectorBeforeGSBackendLoads(SEL selector)
{
    // This function is called from +load methods, so don't use ObjC classes (may not be loaded)

    if (gGSBackendDidLoad)
    {
        goto ERROR;
    }

    if (!gUserDefaultsSelectors)
    {
        gUserDefaultsSelectors = (SEL *) malloc (kMaxNumStoredSelectors * sizeof(SEL));

        if (!gUserDefaultsSelectors)
        {
            gHadUserDefaultsSelectorError_UnableToAllocateMemoryForSelectors = YES;

            goto ERROR;
        }
    }

    if (gNumUserDefaultsSelectors >= kMaxNumStoredSelectors)
    {
        gHadUserDefaultsSelectorError_StoredSelectorsArrayTooSmall = YES;

        goto ERROR;
    }

    gUserDefaultsSelectors[gNumUserDefaultsSelectors++] = selector;

    return YES;

ERROR:
    return NO;
}

static void PerformUserDefaultsSelectors(void)
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    int selectorIndex;

    if (gHadUserDefaultsSelectorError_UnableToAllocateMemoryForSelectors)
    {
        NSLog(@"ERROR: Out of memory in "
                "PPGSGlueUtils_PerformNSUserDefaultsSelectorBeforeGSBackendLoads()");
    }

    if (gHadUserDefaultsSelectorError_StoredSelectorsArrayTooSmall)
    {
        NSLog(@"ERROR: Selector array is full - unable to store all delayed selector(s) in "
                "PPGSGlueUtils_PerformNSUserDefaultsSelectorBeforeGSBackendLoads(); Need to "
                "increase kMaxNumStoredSelectors to more than (%d) in PPGNUstepGlueUtilities.m",
                (int) kMaxNumStoredSelectors);
    }

    for (selectorIndex = 0; selectorIndex < gNumUserDefaultsSelectors; selectorIndex++)
    {
        NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
        SEL selector = gUserDefaultsSelectors[selectorIndex];

        if (selector && [userDefaults respondsToSelector: selector])
        {
            [userDefaults performSelector: selector];
        }
        else
        {
            NSLog(@"ERROR: Invalid NSUserDefaults selector, %@, passed to "
                    "PPGSGlueUtils_PerformNSUserDefaultsSelectorBeforeGSBackendLoads()",
                    (selector) ? NSStringFromSelector(selector) : @"NULL");
        }

        [autoreleasePool release];
    }

    free(gUserDefaultsSelectors);
    gUserDefaultsSelectors = NULL;

    gNumUserDefaultsSelectors = 0;
}

@implementation PPApplication (PPGNUstepGlueUtilities)

// Stored NSUserDefaults selectors are called from an overridden private NSApplication method,
// _init, which is the last overrideable method call before the GNUstep backend is loaded

- (void) _init
{
    PerformUserDefaultsSelectors();

    if ([[super class] instancesRespondToSelector: @selector(_init)])
    {
        [super _init];
    }

    gGSBackendDidLoad = YES;
}

@end

#define kLastGDM3MinorVersionToSpawnAnExtraGnomeShellProcess 28 // GDM3 Version 3.28

static bool GDM3SpawnsAnExtraGnomeShellProcess(void)
{
    const char *sysCmd_GDM3Version = "gdm3 --version",
                *sysOutputScanFormatStr = "GDM %i.%i";
    const int numScannedValuesExpected = 2;
    FILE *sysOutputStream;
    int gdm3MajorVersion, gdm3MinorVersion;
    bool gdm3SpawnsAnExtraGnomeShellProcess = NO;

    sysOutputStream = popen(sysCmd_GDM3Version, "r");

    if (sysOutputStream)
    {
        if (!feof(sysOutputStream)
            && (fscanf(sysOutputStream, sysOutputScanFormatStr, &gdm3MajorVersion,
                        &gdm3MinorVersion)
                == numScannedValuesExpected))
        {
            if ((gdm3MajorVersion == 3)
                && (gdm3MinorVersion <= kLastGDM3MinorVersionToSpawnAnExtraGnomeShellProcess))
            {
                gdm3SpawnsAnExtraGnomeShellProcess = YES;
            }
        }

        pclose(sysOutputStream);
    }

    return gdm3SpawnsAnExtraGnomeShellProcess;
}

static bool SystemHasMultipleGnomeShellProcesses(void)
{
    const char *sysCmd_CountGnomeShellProcesses = "pgrep -x gnome-shell | wc -l",
                *sysOutputScanFormatStr = "%d";
    const int numScannedValuesExpected = 1;
    FILE *sysOutputStream;
    int numGnomeShellProcesses = 0;

    sysOutputStream = popen(sysCmd_CountGnomeShellProcesses, "r");

    if (sysOutputStream)
    {
        if (!feof(sysOutputStream))
        {
            if (fscanf(sysOutputStream, sysOutputScanFormatStr, &numGnomeShellProcesses)
                != numScannedValuesExpected)
            {
                numGnomeShellProcesses = 0;
            }
        }

        pclose(sysOutputStream);
    }

    return (numGnomeShellProcesses > 1) ? YES : NO;
}

#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

static SEL *gScreencastControllerSelectors = NULL;
static int gNumScreencastControllerSelectors = 0;

bool PPGSGlueUtils_PerformPPScreencastControllerSelectorOnEnableOrDisable(SEL selector)
{
    static bool screencastControllerPatchIsInstalled = NO;

    if (!selector)
    {
        NSLog(@"ERROR: NULL selector in "
                "PPGSGlueUtils_PerformPPScreencastControllerSelectorOnEnableOrDisable()");

        goto ERROR;
    }

    if (!gScreencastControllerSelectors)
    {
        gScreencastControllerSelectors = (SEL *) malloc (kMaxNumStoredSelectors * sizeof(SEL));

        if (!gScreencastControllerSelectors)
        {
            NSLog(@"ERROR: Out of memory in "
                    "PPGSGlueUtils_PerformPPScreencastControllerSelectorOnEnableOrDisable()");

            goto ERROR;
        }
    }

    if (gNumScreencastControllerSelectors >= kMaxNumStoredSelectors)
    {
        NSLog(@"ERROR: Selector array is full - unable to store all delayed selector(s) in "
                "PPGSGlueUtils_PerformPPScreencastControllerSelectorOnEnableOrDisable(); Need "
                "to increase kMaxNumStoredSelectors to more than (%d) in "
                "PPGNUstepGlueUtilities.m",
                (int) kMaxNumStoredSelectors);

        goto ERROR;
    }

    gScreencastControllerSelectors[gNumScreencastControllerSelectors++] = selector;

    if (!screencastControllerPatchIsInstalled)
    {
        screencastControllerPatchIsInstalled =
            macroSwizzleInstanceMethod(PPScreencastController, setEnabled:,
                                        ppGSPatch_SetEnabled:);
    }

    return YES;

ERROR:
    return NO;
}

@implementation PPScreencastController (PPGNUstepGlueUtilities)

- (void) ppGSPatch_SetEnabled: (bool) enableScreencasting
{
    bool screencastingWasEnabled, screencastingIsEnabled;
    int selectorIndex;

    screencastingWasEnabled = (_screencastingIsEnabled) ? YES : NO;

    [self ppGSPatch_SetEnabled: enableScreencasting];

    screencastingIsEnabled = (_screencastingIsEnabled) ? YES : NO;

    if (screencastingWasEnabled == screencastingIsEnabled)
    {
        return;
    }

    for (selectorIndex = 0; selectorIndex < gNumScreencastControllerSelectors; selectorIndex++)
    {
        [self performSelector: gScreencastControllerSelectors[selectorIndex]];
    }
}

@end

#else   // !PP_OPTIONAL__BUILD_WITH_SCREENCASTING

void PPGSGlueUtils_PerformPPScreencastControllerSelectorOnEnableOrDisable(SEL selector)
{
}

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING

@implementation NSUserDefaults (PPGNUstepGlueUtilities)

+ (bool) ppGSGlueUtils_RegisterDefaultsFromDictionaryNamed: (NSString *) dictionaryName
{
    NSString *dictionaryPath;
    NSDictionary *dictionary;

    if (!dictionaryName)
        goto ERROR;

    dictionaryPath = [[NSBundle mainBundle] pathForResource: dictionaryName ofType: @"plist"];

    if (!dictionaryPath)
        goto ERROR;

    dictionary = [NSDictionary dictionaryWithContentsOfFile: dictionaryPath];

    if (!dictionary)
        goto ERROR;

    [[self standardUserDefaults] registerDefaults: dictionary];

    return YES;

ERROR:
    return NO;
}

@end

#endif  // GNUSTEP

