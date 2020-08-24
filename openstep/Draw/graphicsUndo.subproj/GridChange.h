@interface GridChange : Change
{
    id		graphicView;
    int 	oldSpacing;
    float 	oldGray;
    BOOL	oldVisible;
    BOOL	oldEnabled;
    int 	newSpacing;
    float 	newGray;
    BOOL	newVisible;
    BOOL	newEnabled;
}

- initGraphicView:aGraphicView;
- (NSString *)changeName;
- (void)saveBeforeChange;
- (void)undoChange;
- (void)redoChange;
- (BOOL)subsumeChange:change;

@end
