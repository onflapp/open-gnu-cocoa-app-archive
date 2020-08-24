@interface UngroupGraphicsChange : Change
{
    id 		graphicView;
    NSMutableArray	*changeDetails;
    NSMutableArray	*groups;
}

- initGraphicView:aGraphicView;
- (NSString *)changeName;
- (void)saveBeforeChange;
- (void)undoChange;
- (void)redoChange;
- (Class)changeDetailClass;

@end
