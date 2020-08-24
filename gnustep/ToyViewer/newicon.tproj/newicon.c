#import <Carbon/Carbon.h>
#import <CoreServices/CoreServices.h>
#include <stdio.h>
#include <unistd.h>
#include "utils.h"
#include "custom.h"

static IconFamilyHandle getIconHandle(FILE *fp, Boolean isdir)
{
	IconFamilyHandle iconHandle;
	int err;

	err = readImage(fp);
	if (err != c_NoErr) {
		fprintf(stderr, "ERROR: Can't read image data\n");
		return NULL;
	}
	if (isdir)
		attachDirMark();
	err = allocIconHandle(&iconHandle);
	if (err == c_NoErr)
		err = setIconImages(iconHandle);
	if (err != noErr) {
		fprintf(stderr, "ERROR(%d): Can't make icon\n", err);
		return NULL;
	}
	return iconHandle;
}

static int attachIcon(const UInt8 *fileName, IconFamilyHandle iconHandle, Boolean isdir)
{
	SInt16 forkRefNum;
	FSSpec fsSpec;
	int err;

	if (isdir) {
		if (iconHandle == NULL) {
			removeDirIcon(fileName);
			return 0;
		}
		err = getFSSpecForDirIcon(fileName, &fsSpec);
	}else
		err = getFSSpecForPath(fileName, &fsSpec);
	if (err != noErr) {
		fprintf(stderr, "Error(%d): Can't get FSSpec for %s\n", err, fileName);
		return 1;
	}
	if (isdir)
		forkRefNum = openRsrcForkWithEmptyIcon(&fsSpec, 'MACS', 'icon');
	else
		forkRefNum = openRsrcForkWithEmptyIcon(&fsSpec, '????', '????');
	if (forkRefNum < 0) {
		fprintf(stderr, "Error: Can't open resource fork\n");
		return 1;
	}

	if (iconHandle != NULL) {
		AddResource((Handle)iconHandle,
			kIconFamilyType /* 'icns' */, kCustomIconResource, "");
		err = ResError();
		if (err != noErr) {
			fprintf(stderr, "Error(%d): Can't add resource\n", err);
		}
	}

	UpdateResFile(forkRefNum);
	err = ResError();
	if (err != noErr) {
		fprintf(stderr, "Error(%d): Can't update resource\n", err);
	}

	(void) FSCloseFork(forkRefNum);

	return 0;
}

static void help(void)
{
	fprintf(stderr, "newicon (ver.1.2  2002.03.07)\n");
	fprintf(stderr, "Usage: newicon [options] [target-filename]\n");
	fprintf(stderr, "Options:  -i input.icns     read icon-data from icns file\n");
	fprintf(stderr, "          -p input.ppm      read icon-data from ppm file (\"-\" = stdin)\n");
	fprintf(stderr, "          -d                delete icon of the target\n");
	fprintf(stderr, "          (Note: Specify only one of -i, -p, or -d)\n");
	fprintf(stderr, "          -o target         specify target file explicitly\n");
	fprintf(stderr, "          -s output.icns    save icon-data\n");
	fprintf(stderr, "          -D[0|1]           directory Mark On(default) / Off\n");
	exit(1);
}

int main(int argc, char *argv[])
{
	int ac, opc;
	int conflict = 0;
	OSErr err;
	Boolean delete = false;
	Boolean isDir = false;
	Boolean dirMark = true;
	const char *icnsFname = NULL;
	const char *picFname = NULL;
	const char *outFname = NULL;
	const char *saveFname = NULL;
	FSSpec saveSpec;
	IconFamilyHandle iconHandle = NULL;

	for (ac = 1; ac < argc; ac++) {
		if (argv[ac][0] != '-') {
			if (outFname == NULL)
				outFname = argv[ac];
			break;
		}
		opc = argv[ac][1];
		switch (opc) {
		case 'i':
		case 'p':
			if (ac+1 >= argc) {
				fprintf(stderr, "ERROR: No input file name\n");
				return 1;
			}
			++ac;
			if (opc == 'i')
				icnsFname = argv[ac];
			else
				picFname = argv[ac];
			conflict++;
			break;
		case 'o':
			if (ac+1 < argc)
				outFname = argv[++ac];
			break;
		case 's':
			if (ac+1 < argc)
				saveFname = argv[++ac];
			break;
		case 'd':
			delete = true;
			conflict++;
			break;
		case 'D':
			switch (argv[ac][2]) {
			case '0': dirMark = false;  break;
			case '1': dirMark = true;  break;
			}
			break;
		case 'h':
		default:
			help();
			break;
		}
	}

// Check parameters...
	if (conflict > 1) {
		fprintf(stderr, "ERROR: Specify only one: -i, -p, or -d\n");
		return 1;
	}
	if (outFname == NULL) {
		fprintf(stderr, "ERROR: No output file name\n");
		return 1;
	}
	if (!isRegularFile(outFname, &isDir)) {
		fprintf(stderr, "ERROR: Illegal output file type\n");
		return 1;
	}

// What kind of input is given ?
	if (icnsFname != NULL) {
		FSSpec inSpec;
		err = getFSSpecForPath(icnsFname, &inSpec);
		if (err == noErr)
			err = ReadIconFile(&inSpec, &iconHandle);
		if (err != noErr) {
			fprintf(stderr, "ERROR: Can't access input: %s\n", icnsFname);
			return 1;
		}
	}else if (picFname != NULL) {
		FILE *fp;
		if (strcmp(picFname, "-") == 0)
			fp = stdin;
		else
			fp = fopen(picFname, "rb");
		if (fp != NULL) {
			iconHandle = getIconHandle(fp, isDir && dirMark);
			(void)fclose(fp);
		}else
			fprintf(stderr, "ERROR: Can't open file %s\n", picFname);
		if (iconHandle == NULL)
			return 1;
	}

// If need to save icon...
	if (saveFname) {
		if (access(saveFname, W_OK) != 0) {
			FILE *fp = fopen(saveFname, "w");
			if (fp != NULL)
				(void)fclose(fp);
		}
		err = getFSSpecForPath(saveFname, &saveSpec);
		if (err != noErr) {
			fprintf(stderr, "Error(%d): Can't get FSSpec for %s\n",
				err, saveFname);
			return 1;
		}
	}

// Main Job
	if (iconHandle != NULL) {	// Icon image is given
		err = attachIcon(outFname, iconHandle, isDir);
		if (err != noErr) {
			fprintf(stderr, "ERROR(%d): Can't attach icon: %s\n",
				err, outFname);
			return 1;
		}
		if (saveFname) {
			err = WriteIconFile(iconHandle, &saveSpec);
			if (err != noErr)
				fprintf(stderr, "WARNING(%d): Can't save icon: %s\n",
					err, saveFname);
		}
	}else {	// No Icon image
		if (saveFname) {
			SInt16 refNum;
			IconFamilyHandle handle;
			FSSpec fsSpec;
			err = getFSSpecForPath(outFname, &fsSpec);
			if (err != noErr) {
				fprintf(stderr, "ERROR(%d): Can't access file: %s\n",
					err, outFname);
				return 1;
			}
			refNum = openRsrcForkAndGetIcon(&fsSpec, (Handle *)&handle);
			if (handle != NULL) {
			    err = WriteIconFile(handle, &saveSpec);
			    if (err != noErr)
				fprintf(stderr, "WARNING(%d): Can't save icon: %s\n",
					err, saveFname);
			}
			(void) FSCloseFork(refNum);
		}
		if (delete) {
			err = attachIcon(outFname, NULL, isDir);
			if (err != noErr) {
				fprintf(stderr, "ERROR(%d): Can't remove icon: %s\n",
					err, outFname);
				return 1;
			}
		}
	}

	err = notifyToFinder(outFname, !delete, isDir);

	return err;
}
