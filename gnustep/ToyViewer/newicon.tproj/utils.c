#include "utils.h"
#include <sys/param.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "event.h"

#ifdef DEBUG
static void printRsrc(void)
{
	ResType theType;
	int i;
	SInt16 n = Count1Types();
	fprintf(stderr, "DEBUG: %d resources\n", n);
	for (i = 1; i <= n; i++) {
		Get1IndType(&theType, i);
		fprintf(stderr, "%2d: \'%4s\'\n", i, (char *)&theType);
	}
}
#endif

static const UInt8 *makeAbsPath(const UInt8 *path, UInt8 buf[])
{
	const UInt8 *p;
	int i;

	if (path[0] == '/')
		return path;
	(void)getcwd(buf, MAXPATHLEN);
	for (i = 0; buf[i]; i++)
		;
	if (buf[i-1] != '/')
		buf[i++] = '/';
	for (p = path; *p; p++, i++)
		buf[i] = *p;
	buf[i] = 0;
	return buf;
}

static const UInt8 *makeAbsParentPath(const UInt8 *path, UInt8 buf[])
{
	int i, sl;

	if (path[0] == '/') {
		for (i = 0; path[i]; i++)
			buf[i] = path[i];
		buf[i] = 0;
	}else
		(void) makeAbsPath(path, buf);

	sl = -1;
	for (i = 0; buf[i]; i++)
		if (buf[i] == '/')
			sl = i;
	if (sl <= 0)
		return "/";
	buf[sl] = 0;
	return buf;
}

OSErr getFSSpecForPath(const UInt8 *path, FSSpec *spec)
{
	FSRef ref;
	HFSUniStr255 outName;
	OSErr err;
	UInt8 buf[MAXPATHLEN];

	err = FSPathMakeRef(makeAbsPath(path, buf), &ref, NULL);
	if (err != noErr)
		return err;
	err = FSGetCatalogInfo(&ref, kFSCatInfoNone, NULL, &outName, spec, NULL);
	return err;
}

OSErr getFSRefForPath(const UInt8 *path, FSRef *refp)
{
	UInt8 buf[MAXPATHLEN];
	return FSPathMakeRef(makeAbsPath(path, buf), refp, NULL);
}

static void makeIconPath(UInt8 *buf, const UInt8 *path)
{
	const UInt8 *iconfn = "Icon\r";
	int i;

	for (i = 0; path[i]; i++)
		buf[i] = path[i];
	if (i > 0 && buf[i-1] != '/')
		buf[i++] = '/';
	while (*iconfn)
		buf[i++] = *iconfn++;
	buf[i] = 0;
}

OSErr getFSSpecForDirIcon(const UInt8 *path, FSSpec *spec)
{
	UInt8 buf[MAXPATHLEN];

	makeIconPath(buf, path);
	if (access(buf, W_OK) != 0) {
		FILE *fp = fopen(buf, "w");
		if (fp != NULL)
			(void)fclose(fp);
	}
	return getFSSpecForPath(buf, spec);
}

void removeDirIcon(const UInt8 *path)
{
	UInt8 buf[MAXPATHLEN];

	makeIconPath(buf, path);
	if (access(buf, F_OK) == 0)
		(void)unlink(buf);
}

OSErr getFSRefForParenPath(const UInt8 *path, FSRef *refp)
{
	UInt8 buf[MAXPATHLEN];
	return FSPathMakeRef(makeAbsParentPath(path, buf), refp, NULL);
}

OSErr getFSSpecForParenPath(const UInt8 *path, FSSpec *spec)
{
	UInt8 buf[MAXPATHLEN];
	return getFSSpecForPath(makeAbsParentPath(path, buf), spec);
}

SInt16 openRsrcForkAndGetIcon(FSSpec *spec, Handle *handlep)
{
	int forkRefNum;
	Handle iconHandle;

	forkRefNum = FSpOpenResFile(spec, fsRdPerm);
	if (forkRefNum < 0)
		return forkRefNum;
	UseResFile(forkRefNum);

	iconHandle = Get1Resource(
		kIconFamilyType /* 'icns' */, kCustomIconResource);
#ifdef DEBUG
	if (iconHandle)
		fprintf(stderr, "Debug: Icon Resource=\'%4s\' (%d)\n",
			(char *)*iconHandle, *(int *)(*iconHandle + 4));
#endif
	*handlep = iconHandle;

	return forkRefNum;
}

SInt16 openRsrcForkWithEmptyIcon(FSSpec *spec, OSType creator, OSType fileType)
{
	int forkRefNum;
	int err;
	Boolean isnew = false;

	forkRefNum = FSpOpenResFile(spec, fsRdWrPerm);
	if (forkRefNum < 0) {
		FSpCreateResFile(spec, '????', '????', smRoman);
		if((err = ResError()) != noErr) {
#ifdef DEBUG
			fprintf(stderr, "Error(%d): Can't create new fork\n", err);
#endif
			return -1;
		}
		forkRefNum = FSpOpenResFile(spec, fsRdWrPerm);
		if (forkRefNum < 0) {
#ifdef DEBUG
			fprintf(stderr, "Error(%d): Can't open file\n", err);
#endif
			return forkRefNum;
		}
		isnew = true;
	}

	UseResFile(forkRefNum);

	if (! isnew) {
		Handle iconHandle = Get1Resource(
			kIconFamilyType /* 'icns' */, kCustomIconResource);
#ifdef DEBUG
		if (iconHandle)
			fprintf(stderr, "Debug: Icon Resource=\'%4s\' (%d)\n",
				(char *)*iconHandle, *(int *)(*iconHandle + 4));
#endif
		if (iconHandle) {
			RemoveResource(iconHandle);
			DisposeHandle(iconHandle);
		}
	}
	UpdateResFile(forkRefNum);

	return forkRefNum;
}

#define HasCustomIcon	0x400
#define IsInvisible	0x4000

static OSErr setCustomIconFlag(FSSpec *specp, UInt32 flags, Boolean flag)
{
	FInfo fndrInfo;
	OSErr err;

	err = FSpGetFInfo(specp, &fndrInfo);
	if (err != noErr)
		return err;
	if (flag)
		fndrInfo.fdFlags |= flags;
	else
		fndrInfo.fdFlags &= ~flags;
	err = FSpSetFInfo(specp, &fndrInfo);
#ifdef DEBUG
	fprintf(stderr, "Debug: fdFlags=%x\n", (unsigned int)fndrInfo.fdFlags);
#endif
	return err;
}

static OSErr setCustomIconCatalog(const UInt8 *fileName, Boolean flag)
{
	FSRef ref;
	FSCatalogInfo catalogInfo;
	OSErr err;

	err = getFSRefForPath(fileName, &ref);
	if (err != noErr)
		return err;
	err = FSGetCatalogInfo(&ref, kFSCatInfoFinderInfo,
			&catalogInfo, NULL, NULL, NULL);
	if (err != noErr)
		return err;
#ifdef DEBUG
	{
		int i;
		for (i = 0; i < 16; i++)
			fprintf(stderr, " %02x", catalogInfo.finderInfo[i]);
		fputc('\n', stderr);
	}
#endif
	/* Without Icon: 00 00 00 00 00 00 00 00 03 e0 00 c0 00 81 01 07 */
	/* With    Icon: 00 00 00 00 00 00 00 00 07 e0 00 c0 00 81 01 07 */
	if (flag)
		catalogInfo.finderInfo[8] |= 0x04;
	else
		catalogInfo.finderInfo[8] &= 0xfb;
	err = FSSetCatalogInfo(&ref, kFSCatInfoFinderInfo, &catalogInfo);
#ifdef DEBUG
	{
		int i;
		err = FSGetCatalogInfo(&ref, kFSCatInfoFinderInfo,
			&catalogInfo, NULL, NULL, NULL);
		for (i = 0; i < 16; i++)
			fprintf(stderr, " %02x", catalogInfo.finderInfo[i]);
		fputc('\n', stderr);
	}
#endif
	return err;
}

int notifyToFinder(const char *outFname, Boolean customIcon, Boolean isdir)
{
	FSSpec outSpec;
	FSRef dirRef;
	OSErr err = noErr;

	if (isdir) {
		if (customIcon) {
			err = getFSSpecForDirIcon(outFname, &outSpec);
			if (err == noErr)
				err = setCustomIconFlag(&outSpec,
					HasCustomIcon | IsInvisible, true);
		}
		if (err == noErr)
			err = setCustomIconCatalog(outFname, customIcon);
		(void) getFSSpecForPath(outFname, &outSpec);
	}else {
		(void) getFSSpecForPath(outFname, &outSpec);
		err = setCustomIconFlag(&outSpec, HasCustomIcon, customIcon);
	}

	if (err != noErr)  {
		fprintf(stderr, "ERROR(%d): Can't set icon enabled: %s\n",
			err, outFname);
		return 1;
	}

	err = updateFinderIcon(&outSpec);
	if (err != noErr)
		fprintf(stderr, "WARNING(%d): Can't send Apple Event\n", err);

	err = getFSRefForParenPath(outFname, &dirRef);
	if (err == noErr)
		err = FNNotify(&dirRef, kFNDirectoryModifiedMessage, 0);
	if (err != noErr)
		fprintf(stderr, "WARNING(%d): Can't get parent directory: %s\n",
			err, outFname);

// AGAIN!!
// I don't know why we should do it twice...
	err = updateFinderIcon(&outSpec);
	if (err != noErr)
		fprintf(stderr, "WARNING(%d): Can't send Apple Event\n", err);

	return 0;
}

Boolean isRegularFile(const char *outFname, Boolean *isDir)
{
	struct stat sbuf;
	unsigned int mode;

	*isDir = false;
	if (stat(outFname, &sbuf) < 0)
		return false;
	mode = sbuf.st_mode & S_IFMT;
	if (mode == S_IFREG)
		return true;
	if (mode == S_IFDIR) {
		*isDir = true;
		return true;
	}
	return false;
}
