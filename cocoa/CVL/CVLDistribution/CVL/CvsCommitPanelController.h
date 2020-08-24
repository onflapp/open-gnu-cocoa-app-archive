//
//  CvsCommitPanelController.h
//  CVL
//
//  Created by William Swats on Fri Jan 16 2004.
//  Copyright (c) 2004 Sente SA. All rights reserved.
//

#import <AppKit/AppKit.h>

@class CVLTextView;

@interface CvsCommitPanelController : NSWindowController
{
    IBOutlet NSTextField *titleTextField;
    IBOutlet CVLTextView *commitMessageTextView;
    IBOutlet NSPopUpButton *commitHistoryPopUpButton;
    IBOutlet NSButton *clearButton;
    IBOutlet NSMenuItem *clearMenuItem;
    IBOutlet NSButton *cancelButton;
    IBOutlet NSButton *okButton;
    NSMutableDictionary *commitHistory;
    NSString *templateFile;
    NSArray *committingFiles;
    int		modalResult;
    BOOL isClearMenuItemEnabled;
    BOOL doNotUpdateCommitMessageTextView;
    BOOL hasShownTemplatesAlert;
    BOOL useCvsTemplates;
}

- (int)showAndRunModal;
- (NSString *) showCommitPanelWithFiles:(NSArray *)someFiles usingTemplateFile:(NSString *)aTemplateFile;

- (IBAction)cancel:(id)sender;
- (IBAction)ok:(id)sender;
- (IBAction)insertCommitMessageFrom:(id)sender;
- (IBAction)clearCommitMessageHistory:(id)sender;
- (IBAction)clear:(id)sender;

- (NSString *)commitMessage;
- (void)updateGui;
- (void)updatePullDownButton;
- (void)updateControls;
- (void)updateTitle;
- (void)updateCommitMessageTextView;
- (NSString *)removeAllLeadingBlankLines:(NSString *)aMessage;
- (NSString *)removeAllCVSLines:(NSString *)aMessage;

- (NSDictionary *)commitHistory;
- (void)setCommitHistory:(NSDictionary *)newCommitHistory;

- (NSString *)templateFile;
- (void)setTemplateFile:(NSString *)newTemplateFile;
- (NSString *)templateContent;
- (NSString *) filteredTemplateContent;

- (NSArray *)committingFiles;
- (void)setCommittingFiles:(NSArray *)newCommittingFiles;

@end
