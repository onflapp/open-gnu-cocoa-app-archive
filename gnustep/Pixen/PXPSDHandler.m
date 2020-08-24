//
//  PXPSDHandler.m
//  Pixen-XCode
//
//  Created by Andy Matuschak on Thu Jun 10 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXPSDHandler.h"
#import <QuickTime/QuickTime.h>

@implementation PXPSDHandler

/*(Handle)dataRefForData:data
{
	Str255 mimeTypePascalStr;
	Str255 namePascalStr;
	Handle dataRefXtnsnHndl;
	ComponentInstance dataHandler;
	PointerDataRef dataref = 
		              (PointerDataRef)NewHandle(sizeof(PointerDataRefRecord));
	Handle dataRefWithExtensions;
	

	
	osstat = OpenADataHandler(dataRef,
							  PointerDataHandlerSubType, 
							  nil, 
							  (OSType)0, 
							  nil, 
							  kDataHCanRead, 
							  &dataHandler);
	
	// now that the data handler has copied it,
	// we don't need our original copy of the data ref
	DisposeHandle((Handle)dataref);
	
	// mix in the the mime type of the media
	osstat = PtrToHand(mimeTypePascalStr, 
					   &dataRefXtnsnHndl, 
					                      mimeTypePascalStr[0]+1);
	
	osstat = DataHSetDataRefExtension(dataHandler, 
									                                    dataRefXtnsnHndl, 
									                                    kDataRefExtensionMIMEType);
	                                  DisposeHandle(dataRefXtnsnHndl);
	
	// mix in the name of the media
	osstat = PtrToHand(namePascalStr, 
					                      &dataRefXtnsnHndl, 
					                      namePascalStr[0]+1);
	
	osstat = DataHSetDataRefExtension(dataHandler, 
									                                    dataRefXtnsnHndl, 
									                                    kDataRefExtensionFileName);
	                                  DisposeHandle(dataRefXtnsnHndl);
	
	// retrieve the data ref with its added extensions
	DataHGetDataRef(dataHandler, &dataRefWithExtensions);
	
	// don't need our data handler instance anymore
	CloseComponent(dataHandler);
}*/

+imagesForPSDData:(NSData *)data
{
	ComponentInstance importer, exporter = 0;
	PointerDataRef dataRef = (PointerDataRef)NewHandle(sizeof(PointerDataRefRecord));
	long imageCount = 0;
	int i;
	id images = [[NSMutableArray alloc] init];
	
	char * buffer = malloc([data length]);
	[data getBytes:buffer];
	(**dataRef).data = buffer;
	(**dataRef).dataLength = [data length];
	
	GetGraphicsImporterForDataRef((Handle)dataRef,PointerDataHandlerSubType,&importer);
	GraphicsImportGetImageCount(importer, &imageCount);
	for (i = 0; i < imageCount; i++)
	{
		long offset, size;
		
		GraphicsImportSetImageIndex(importer, i);
		PointerDataRef testRef = (PointerDataRef)NewHandle(sizeof(PointerDataRefRecord));
		GraphicsImportGetDataOffsetAndSize(importer, &offset, &size);
		GraphicsImportGetDataReference(importer, (Handle *)testRef, NULL);
		// create a Graphics Exporter component that will write BMP data
		OSErr err = OpenADefaultComponent(GraphicsExporterComponentType, kQTFileTypeBMP, &exporter);
		if (err == noErr)
		{
			// set export parameters
			Handle bmpDataH = NewHandle(0);
			GraphicsExportSetInputGraphicsImporter(exporter, importer);
			GraphicsExportSetOutputHandle(exporter, bmpDataH);
			
			// export data to BMP into handle
			unsigned long actualSizeWritten = 0;
			err = GraphicsExportDoExport(exporter, &actualSizeWritten);
			if (err == noErr)
			{
				// export done: create the NSData that will be returned
				HLock(bmpDataH);
				id image = [[[NSImage alloc] initWithData:[NSData dataWithBytes:*bmpDataH length:GetHandleSize(bmpDataH)]] autorelease];
				[images addObject:image];
				HUnlock(bmpDataH);
			}
			DisposeHandle(bmpDataH);
			CloseComponent(exporter);
		}
	}
	CloseComponent(importer);
	DisposeHandle((Handle)dataRef);
	free(buffer);
	[images autorelease];
	return images;
}

@end
