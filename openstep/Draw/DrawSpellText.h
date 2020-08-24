// DrawSpellText overrides two key spelling methods to give the GraphicView top-level control of the spelling process.

@interface DrawSpellText : NSTextView
{
}

- (void)checkSpelling:(id)sender;
- (void)ignoreSpelling:(id)sender;

@end
