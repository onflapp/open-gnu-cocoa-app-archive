#ifdef WIN32
#define OBJECT_LINKS_BROKEN
#endif

/*
 * This first one is only used by compatibility.m and gvPasteboard.m.
 * It will not be required once gvPasteboard.m is changed to use
 * property lists as Draw's new pasteboard format.
 */

@interface NSMutableArray(Compatibility)

- (id)initFromList:(id)aList;

@end

/* These are used to read old files. */

#define FIRST_OPENSTEP_VERSION 300

@interface DrawDocument(FileCompatibility)

+ (BOOL)isPreOpenStepFile:(NSString *)file;
+ openPreOpenStepFile:(NSString *)file;

@end
