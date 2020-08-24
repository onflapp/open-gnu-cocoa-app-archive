#import <Carbon/Carbon.h>
#import <CoreServices/CoreServices.h>

OSErr getFSSpecForPath(const UInt8 *path, FSSpec *spec);
OSErr getFSRefForPath(const UInt8 *path, FSRef *refp);
OSErr getFSSpecForDirIcon(const UInt8 *path, FSSpec *spec);
void removeDirIcon(const UInt8 *path);
OSErr getFSRefForParenPath(const UInt8 *path, FSRef *refp);
OSErr getFSSpecForParenPath(const UInt8 *path, FSSpec *spec);
SInt16 openRsrcForkAndGetIcon(FSSpec *spec, Handle *handlep);
SInt16 openRsrcForkWithEmptyIcon(FSSpec *spec, OSType creator, OSType fileType);
int notifyToFinder(const char *outFname, Boolean customIcon, Boolean isdir);
Boolean isRegularFile(const char *outFname, Boolean *isDir);
