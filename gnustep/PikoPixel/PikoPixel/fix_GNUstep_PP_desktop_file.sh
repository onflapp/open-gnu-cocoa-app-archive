# Script to modify PikoPixel.desktop for better integration with Freedesktop environments

# 1) Add a "%F" to the end of the "Exec=" line, otherwise the desktop manager won't allow
# image documents in its file browser to choose PikoPixel as the app to open them.
# Can't use sed's in-place option, because the sed version on FreeBSD uses a different syntax
# for -i, so instead using a temporary file.
sed -e 's/^Exec=.*PikoPixel$/& %F/' PikoPixel.app/Resources/PikoPixel.desktop \
> PikoPixel.app/Resources/PikoPixel_fixed.desktop \
&& mv PikoPixel.app/Resources/PikoPixel_fixed.desktop PikoPixel.app/Resources/PikoPixel.desktop

# 2) Add "StartupWMClass=" line
grep -q "StartupWMClass=" PikoPixel.app/Resources/PikoPixel.desktop \
|| echo "StartupWMClass=PikoPixel" >> PikoPixel.app/Resources/PikoPixel.desktop

# 3) Add "Keywords=" line
grep -q "Keywords=" PikoPixel.app/Resources/PikoPixel.desktop \
|| echo "Keywords=Graphics;Pixelart;Icon;Bitmap;Raster;Image;Png;Gif;Jpg;Tiff;Bmp;Art;Draw;Paint;Fill;Pencil;Trace;" \
>> PikoPixel.app/Resources/PikoPixel.desktop

