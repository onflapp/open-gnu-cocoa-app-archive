#import "draw.h"

@implementation DrawSpellText

- (void)checkSpelling:(id)sender  {
    [[[[self window] delegate] graphicView] checkSpelling:sender];
}

- (void)ignoreSpelling:(id)sender  {
    [[[[self window] delegate] graphicView] ignoreSpelling:sender];
}

@end
