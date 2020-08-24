#!/bin/sh
# update project from archive

PROJECT=~/Projects/Libraries/VHFImport		# project directory (the directory we have to copy)
ARCHIVE=/Network/vhfInterservice/Projects/Libraries/VHFImport	# archive directory

echo Copy files from $ARCHIVE to $PROJECT

# copy files
cd $ARCHIVE
echo Copying files

for fn in `find	. \
  -type d \( -name '*.nib' -o -name 'Help' -o -name 'ProjectHeaders' \) -prune \
  -o -type f \( -name '*.sh' -o -name '*.gmodel' -o -name '.dir.tiff' -o -name 'Help.rtf' \) \
  -o -print`
do
  if [ -d $fn ]; then
    if [ ! -d $PROJECT/$fn ]; then
      mkdir $PROJECT/$fn
    fi
  else if [ -f $fn ]; then
    fn=`echo $fn | sed -e 's|./||'`

    # tiff files
    if [ `echo $fn | grep -c '.tiff'` != '0' -a `echo $fn | grep -c '/'` == '0' ]; then
      if ! cmp -s $fn $PROJECT/Icons/$fn ; then
        echo Icons/$fn
        cp $fn $PROJECT/Icons/$fn
      fi

    # log files -> ChangeLog/
    else if [ `echo $fn | grep -c '....-...txt'` != '0' -a `echo $fn | grep -c 'ChangeLog'` = '0' ]; then
      if ! cmp -s $fn $PROJECT/ChangeLog/$fn ; then
        echo ChangeLog/$fn
        cp $fn $PROJECT/ChangeLog/$fn
      fi

    # skip some files
    #else if [ `echo $fn | grep -c 'English.lproj/Localizable.strings'` != '0' ]; then
    #  echo -n
    #  #echo skip $fn

    # other files
    else
      if ! cmp -s $fn $PROJECT/$fn ; then
        echo $fn
        cp $fn $PROJECT/$fn
      fi

    fi fi
  fi fi
done


# update Cenon
PROJECTS=~/Projects
IMPORT=$PROJECTS/Libraries/VHFImport

cd $PROJECTS/Cenon/Source/Cenon
cp -R $IMPORT .
