
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "InfoController.h"
#import <CvsVersionRequest.h>
#import <AppKit/AppKit.h>



@implementation InfoController

+ (InfoController*) new
{
    static InfoController* theInstance= nil;
    if (!theInstance) {
        theInstance= [[self alloc] init];
    }
    return theInstance;
}


- (void)awakeFromNib
{
    NSCalendarDate	*releaseDate;
    NSString		*dateFormat;
    NSString	*releaseDateString;

    [expirationMesgCell setStringValue:@""];
    [versionCell setStringValue:@""];
    dateFormat = @"%m/%d/%y";
    releaseDate = [NSCalendarDate dateWithString:[NSString stringWithCString:__DATE__] calendarFormat:dateFormat locale:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle bundleForClass:[NSCalendarDate class]] pathForResource:@"English" ofType:@"" inDirectory:@"Languages"]]];
     if ([releaseDate yearOfCommonEra] < 1990)
         // Thank you to Tom Hageman <trh@xs4all.nl> for this "quick&dirty y2k fix"
         releaseDate = [releaseDate dateByAddingYears:((2099-[releaseDate yearOfCommonEra])/100)*100 months:0 days:0 hours:0 minutes:0 seconds:0];
    if(!releaseDate)
        releaseDateString = [NSString stringWithCString:__DATE__];
    else
        releaseDateString = [releaseDate descriptionWithCalendarFormat:@"%b %d, %Y"];
    [versionCell setStringValue:[NSString stringWithFormat:@"CVL.app Version %@ %@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"], releaseDateString]];
}

- (void)showPanel
{
  if (!thePanel)
  {
    [NSBundle loadNibNamed:@"InfoPanel" owner:self];
  }
  [thePanel makeKeyAndOrderFront:self] ;
}

- (void)showCvsPanel
{
    CvsVersionRequest	*versionRequest;

    if (!cvsInfoPanel)
  {
    [NSBundle loadNibNamed:@"InfoPanel" owner:self];
  }
    [cvsInfoPanel makeKeyAndOrderFront:self] ;

    versionRequest = [CvsVersionRequest cvsVersionRequest];
    [versionRequest setIsQuiet:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cmdEnded:) name:@"RequestCompleted" object:versionRequest];
    [versionRequest schedule];
}

- (void) cmdEnded:(NSNotification *)notification
{
    if([[notification object] isKindOfClass:[CvsVersionRequest class]]){

        if([[notification object] succeeded]){
            NSString	*aString = [[[notification object] result] objectForKey:@"version"];

            aString = [aString stringByAppendingString:@"\n\nMore information about cvs can also be retrieved from:\nhttp://www.loria.fr/~molli/cvs-index.html\nhttp://www.codefab.com/cvs.html"];
            [textView setString:aString];
        }
        else
            [textView setString:@"N/A"];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[notification name] object:[notification object]];
}

- (void) showImg: sender
{
  [imgView setImage: [NSImage imageNamed:@"x"]];
}

- (IBAction) openMailer:(id)sender
{
    NSPasteboard	*pboard = [NSPasteboard pasteboardWithUniqueName];

    [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pboard addTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pboard setString:[sender title] forType:NSStringPboardType];

    (void)NSPerformService(@"Mail/Send To", pboard);
}

- (IBAction) openURL:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[sender title]]];
}

@end
