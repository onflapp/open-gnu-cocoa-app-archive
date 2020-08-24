#include <Carbon/Carbon.h>
#include <CoreServices/CoreServices.h>
#include <ApplicationServices/ApplicationServices.h>


#ifdef __ANDERSON_CODE__
//
// See http://developer.apple.com/dev/techsupport/develop/issue20/20anderson.html
//

static OSErr getAddressOfFinder(AEDesc *descp)
{
	ProcessSerialNumber	psn;
	ProcessInfoRec		theProc;
	OSErr			err;

// Initialize the process serial number to specify no process.
	psn.highLongOfPSN = 0;
	psn.lowLongOfPSN = kNoProcess;
   
// Initialize the fields in the ProcessInfoRec, or we'll have memory 
// hits in random locations.
	theProc.processInfoLength = sizeof(ProcessInfoRec);
	theProc.processName = NULL;
	theProc.processAppSpec = NULL;
	theProc.processLocation = NULL;
   
// Loop through all processes, looking for the Finder.
	while (true) {
      		err = GetNextProcess(&psn);
		if (err == noErr)
			err = GetProcessInformation(&psn, &theProc);

		if (err != noErr)
			return err;
		if ((theProc.processType == 'FNDR') &&
			(theProc.processSignature == 'MACS'))
			break;
	}


	AECreateDesc(typeProcessSerialNumber,
		(Ptr)&psn, sizeof(ProcessSerialNumber), descp);
	return noErr;
}
#endif /* __ANDERSON_CODE__ */

OSErr updateFinderIcon(FSSpec *changedItem)
{
	AEDesc finderAddr, direct;
	AppleEvent theEvent, reply;
	AliasHandle aliasRec;
	OSErr err;
	UInt32 fndr = 'MACS';

//	err = getAddressOfFinder(&finderAddr);

	err = AECreateDesc(typeApplSignature, (Ptr)&fndr,
		sizeof(OSType), &finderAddr);
	if (err != noErr)
		return err;
	err = AECreateAppleEvent(kAEFinderSuite, kAESync, &finderAddr,		kAutoGenerateReturnID, kAnyTransactionID, &theEvent);
	if (err != noErr)
		return err;
	(void)AEDisposeDesc(&finderAddr);

	err = NewAlias(NULL, changedItem, &aliasRec);	if (err != noErr)
		return err;

	HLock((Handle)aliasRec);
	err = AECreateDesc(typeAlias, (Ptr)(*aliasRec),		GetHandleSize((Handle)aliasRec), &direct);	HUnlock((Handle)aliasRec);
	if (err != noErr)
		return err;
	err = AEPutParamDesc(&theEvent, keyDirectObject, &direct);
	if (err != noErr)
		return err;
	(void)AEDisposeDesc(&direct);
	err = AESend(&theEvent, &reply, kAENoReply, kAENormalPriority,
		kAEDefaultTimeout, NULL, NULL);

	DisposeHandle((Handle)aliasRec);
	return err;
}
