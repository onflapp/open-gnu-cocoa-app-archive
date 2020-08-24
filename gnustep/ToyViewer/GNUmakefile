include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS=ADController.bproj ColorTune.bproj ChangeColor.bproj \
	    Enhance.bproj Noise.bproj SoftFrame.bproj \
	    Posterize.bproj Resize.bproj Reduction.bproj\
	    ImageOpr.bproj BackgCtr.bproj

APP_NAME=ToyViewer
PACKAGE_NAME=ToyViewer

ToyViewer_OBJC_FILES=AlertShower.m BundleLoader.m cmyk.m ColorMap.m ColorSpaceCtrl.m \
DirList.m Exttab.m ImageOpCtr.m ImgOperatorClipped.m ImgOperator.m ImgOprAbs.m\
ImgToolCtrlAbs.m InspectorCtrl.m IntervalTimer.m NSStringAppended.m PrefControl.m \
PrintInfoCtrl.m RecentFileList.m rescale.m ToyViewer_main.m ToyViewEvent.m ToyView.m \
ToyWindow.m ToyWinDraw.m ToyWinEPS.m ToyWinEPSRead.m ToyWinGIF.m ToyWin.m ToyWinPCD.m \
ToyWinPict.m ToyWinPPM.m ToyWinSave.m ToyWinVector.m TVController.m \
TVpbService.m TVwinMgr.m WaitMessageCtr.m
#ToyWinPDF.m
ToyViewer_C_FILES= colorLuv.c dcttable.c getpixel.c imfunc.c iofunc.c ppmread.c \
quicksort.c strfunc.c

ToyViewer_HEADER_FILES=ADController.h AlertShower.h  bmp.h BundleLoader.h colorLuv.h \
ColorMap.h colormapsub.h ColorSpaceCtrl.h common.h dcttable.h DirList.h Exttab.h \
getpixel.h ImageOpCtr.h imfunc.h ImgOperatorClipped.h ImgOperator.h ImgOprAbs.h \
ImgToolCtrlAbs.h InspectorCtrl.h IntervalTimer.h NSStringAppended.h PercentView.h \
PlayControl.h ppm.h PrefControl.h PrintInfoCtrl.h ras2pxo.h rasterfile.h RecentFileList.h \
rescale.h strfunc.h ToyView.h ToyWindow.h ToyWinEPS.h ToyWinGIF.h ToyWin.h ToyWinPCD.h \
ToyWinPDF.h ToyWinPict.h ToyWinPPM.h ToyWinVector.h TVController.h version.h WaitMessageCtr.h


ToyViewer_RESOURCE_FILES=images/* \
			 ADController.bproj/ADController.bundle \
			 ColorTune.bproj/ColorTune.bundle  \
			 ChangeColor.bproj/ColorChange.bundle \
			 Enhance.bproj/Enhance.bundle \
			 Noise.bproj/Noise.bundle \
			 SoftFrame.bproj/SoftFrame.bundle \
			 Posterize.bproj/Posterize.bundle \
			 Resize.bproj/Resize.bundle \
			 Reduction.bproj/Reduction.bundle \
			 ImageOpr.bproj/ImageOpr.bundle \
			 BackgCtr.bproj/BackgCtr.bundle \
			 ToyViewer.gorm ToyWin.gorm ImageOpr.gorm \
		         Inspector.gorm  


ToyViewer_GUI_LIBS=-lDithering

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
