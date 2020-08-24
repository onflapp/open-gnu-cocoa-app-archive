PikoPixel Sources for Mac OS X & GNUstep
Version 1.0 BETA9
(c) 2013-2018 Josh Freeman
http://twilightedge.com


ABOUT
-----
   PikoPixel is a free, open-source graphical application for drawing & editing
pixel-art images.


BUILDING ON OS X
----------------
   Building PikoPixel 1.0 BETA9 for Mac OS X requires Xcode 3 or later.

   Open PikoPixel/PikoPixel.xcodeproj in Xcode to build & run the application.

   Xcode may warn about updating the project to use Xcode's recommended settings.
Updating the settings is not necessary - PikoPixel should build successfully with
the project's original settings.

   If you do perform Xcode's recommended settings changes, do not update the
"Enable Weak References in Manual Retain Release" setting, as enabling that
setting will cause build issues. (Uncheck that setting's entries in the update
list - note that it appears twice).


BUILDING ON GNUSTEP
-------------------
   Building PikoPixel 1.0 BETA9 for GNUstep requires a GNUstep development
environment with either of GNUstep's supported compiler+runtime setups
(GCC+gobjc or clang+objc2), and the following GNUstep library versions (or
later):

- GNUstep Base library version 1.24.9
  (released Mar. 20, 2016)

- GNUstep GUI & Back libraries version 0.25.0
  (released Jun. 15, 2016)

   Your distro's repository may contain GNUstep development-environment
packages with the required minimum library versions. For example, on
Ubuntu 16.10+ or Debian 9+, the following set of packages contain all you need
for building PikoPixel:
build-essential libgnustep-gui-dev gnustep-examples

   More info on installing GNUstep:
http://wiki.gnustep.org/index.php/User_Guides
http://wiki.gnustep.org/index.php/Platform:Linux
http://wiki.gnustep.org/index.php/GNUstep_under_Ubuntu_Linux

   With a compatible GNUstep development environment installed, your shell
environment must be set up to run GNUstep-make; See "4.1 Environment Setup":
http://www.gnustep.org/resources/documentation/User/GNUstep/gnustep-howto_4.html
    
   Once GNUstep-make is set up, PikoPixel can be built using the following
commands:

cd PikoPixel
make
sudo -E make install

   After installing, type the following to run PikoPixel:

openapp PikoPixel

   PikoPixel can be added to your desktop environment's menus by copying its
desktop-entry file (found in PikoPixel.app/Resources) to your desktop
environment's entries directory (usually /usr/share/applications):

sudo desktop-file-install --rebuild-mime-info-cache PikoPixel.app/Resources/PikoPixel.desktop

   Once its desktop-entry file is installed, PikoPixel should appear in your
desktop applications list under 'Graphics'.


LICENSE
-------
PikoPixel is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your
option) any later version approved for PikoPixel by its copyright holder (or
an authorized proxy).

PikoPixel is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
details.

You should have received a copy of the GNU Affero General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
