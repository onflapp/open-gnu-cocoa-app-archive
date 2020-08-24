/*
    PPGNUstepPrefix.h

    Copyright 2014-2018 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for GNUstep.
    PikoPixel is a graphical application for drawing & editing pixel-art images.

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
*/

#ifdef GNUSTEP

#   import "PPGNUstepFrameworksVersionCheck.h"

//  MinGW: May have #defined ERROR, so undefine it (PikoPixel uses ERROR as a goto label)
#   ifdef ERROR
#       undef ERROR
#   endif

//  Solaris: Define missing math functions
#   ifdef __sun
#       define floorf(x) floor(x)
#       define ceilf(x) ceil(x)
#       define roundf(x) round(x)
#       define round(x) floor(x + 0.5)
#   endif

#endif  // GNUSTEP
