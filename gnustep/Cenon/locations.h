/* locations.h
 * Cenon file locations
 *
 * Copyright (C) 1995-2011 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1993-08-24
 * modified: 2011-12-02 (auto, i-cut extension added)
 *           2010-07-04 (svg extension added)
 *           2010-06-30 (tiff extension added)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by vhf interservice GmbH. Among other things, the
 * License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this program; see the file LICENSE. If not, write to vhf.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#ifndef VHF_H_LOCATIONS
#define VHF_H_LOCATIONS

#define APP_ID		@"02"			// the id of the application
#define APPNAME		@"Cenon"		// the name of the application

/* directories where files like device configurations are searched
 */
/* GNUstep */
#ifdef GNUSTEP_BASE_VERSION
//#    define HOMELIBRARY	@"GNUstep/Library/Cenon"	// home library (added to home directory)
//#    define LOCALLIBRARY	@"/usr/GNUstep/Local/Library/Cenon"	// global library
#    define BUNDLEFOLDER	@"Bundles/Cenon"		// folder for modules
/* Apple */
#else
#ifdef __APPLE__
//#    define HOMELIBRARY	@"Library/Cenon"		// home library (added to home directory)
//#    define LOCALLIBRARY	@"/Library/Cenon"		// global library
#    define BUNDLEFOLDER	@"Extensions/Cenon"		// folder for modules
/* OpenStep 4.2 */
#else
#    define HOMELIBRARY		@"Library/Cenon"		// home library (added to home directory)
#    define LOCALLIBRARY	@"/LocalLibrary/Cenon"		// global library
#    define BUNDLEFOLDER	@"Bundles/Cenon"		// folder for modules
#endif
#endif

/* file extensions */
#define DOCUMENT_EXT    @"cenon"		// the extension for projects
#define HPGL_EXT        @"hpgl"			// the extension for HPGL
#define GERBER_EXT      @"gerber"		// the extension for Gerber
#define DIN_EXT         @"din"			// the extension for DIN
#define EPS_EXT         @"eps"			// the extension for EPS
#define PDF_EXT         @"pdf"			// the extension for PDF
#define DXF_EXT         @"dxf"			// the extension for DXF
#define DATA_EXT        @"dat"			// the extension for data files
#define FONT_EXT        @"font"			// the extension for type1 fonts
#define AFM_EXT         @"afm"			// the extension for type1 afm
#define TIFF_EXT        @"tiff"         // the extension for TIFF
#define SVG_EXT         @"svg"          // the extension for SVG

#define AUTO_EXT        @"auto"         // the extension for flexible automation
#define ICUT_EXT        @"cut"          // the extension for i-cut files

#define DICT_EXT        @".dict"		// extension of dictionaries (dot!)

/* for building the device popup */
#define DEV_EXT         @"dev"			// the extension for device files
#define	XYZPATH         @"Devices/xyz"
#define	HPGLPATH        @"Devices/hpgl"
#define	GERBERPATH      @"Devices/gerber"
#define	DINPATH         @"Devices/din"

#define CROPMARK_FOLDER @"CropMarks"		// directory for crop mark cenon files
#define CHARCONV_FOLDER @"CharConversion"	// directory for character conversion tables
#define	AI_HEADER       @"psImportAI3.prolog"	// name of prolog for AI import

#endif // VHF_H_LOCATIONS
