#!/bin/bash
#
## bluray.sh
## Last edited 171109 Christopher Lausted
##
## Help with burning a UDF Bluray disc.
## 
## For nice Zenity examples, see
## <http://linux.byexamples.com/archives/265/a-complete-zenity-dialog-examples-2/> 
## <https://help.gnome.org/users/zenity/stable/> 
## Strategy similar to 
## <http://allgood38.io/burn-bluray-data-disks-on-linux-minimize-coasters.html>
## Use packages udftools & cdrecord v3.01+.  Xenial has v3.02.  
## Ubuntu PPA for cdrecord is "ppa:brandonsnider/cdrtools" 
##   <https://launchpad.net/~brandonsnider/+archive/ubuntu/cdrtools> 
##
## Issues.
##   Must have root access to use losetup.  Consider fuseiso instead.
##   Or can I create permanent 25 and 50GB scratch partitions?  
##   Zenity is old and limited.  Consider YAD.
##   md5sum error checking is not included yet. 
##
## A typical bluray script looks like this:
##   $ truncate -s 50GB image.udf
##   $ mkudffs --vid="My Label" image.udf
##   $ sudo losetup -f image.udf
##   $ sudo mount /dev/loop0 /mnt
##   (copy files)
##   $ sudo umount /dev/loop0
##   $ sudo losetup -d /dev/loop0
##   $ cdrecord -v -dao driveropts=burnfree dev=/dev/sr0 image.udf

## Ask how much data to write: $xSize, $xSizeKB. 
choice=`zenity  --list --radiolist  \
  --width=300 --height=250  \
  --text "What size disc will you write?"  \
  --column "Pick" --column "Disc size"  \
  TRUE   "Dual layer BD (50GB)"  \
  FALSE  "Single layer BD (25GB)"  \
  FALSE  "DVD (4.7GB)"  \
  FALSE  "CD (600MB)"  \
  FALSE  "Test mode (10MB)"  `
test $? -eq 0 || exit 1 
if [[ $choice == *"50GB"* ]]; then  
  xSize="50GB"
  xSizeKB="50000000"
elif [[ $choice == *"25GB"* ]]; then
  xSize="25GB"
  xSizeKB="25000000"
elif [[ $choice == *"4.7GB"* ]]; then
  xSize="4700MB"
  xSizeKB="4700000"
elif [[ $choice == *"600MB"* ]]; then
  xSize="600MB"
  xSizeKB="600000"
elif [[ $choice == *"10MB"* ]]; then
  xSize="10MB"
  xSizeKB="10000"
fi
echo "Image of size $xSize or $xSizeKB chosen."

## Ask what to call the temporary image: $imageUDF. 
imageUDF=`zenity --file-selection --save --confirm-overwrite   \
  --title="Where would you like to save the $xSize image?"  \
  --filename="image.udf"  \
  --file-filter="*.udf"  \
  --file-filter="*.img"  \
  --file-filter="*" `
test $? -eq 0 || exit 1
echo "Image file name <$imageUDF>" 

## Check if the selected directory is writeable.
touch $imageUDF
if [ $? -ne 0 ]; then 
  zenity --error --text="Unable to create file.  Do you have permission to write $imageUDF?"
  exit 1
fi

## Check if there is enough space.  Use df to find KB.
free=`df $imageUDF | awk '{print $4}' | tail -1`
echo $free
if [ $free -lt $xSizeKB ]; then 
  zenity --error --text="There is only $free KB of space free.  Exiting." 
  exit 1
fi

## Ask for a label for the disc: $discLabel.
discLabel=`zenity --entry \
  --title="Disc label" \
  --text="What would you like to call the disc?" \
  --entry-text "My Bluray"`
test $? -eq 0 || exit 1
echo "Disc label <$discLabel>" 

## Ask which Bluray writing device to use: $bluray. 
bluray=`zenity --file-selection  \
  --title="Which device is the bluray writer?"  \
  --filename="/dev/sr0"  \
  --file-filter="Disc Devices (sr*,cd*,dvd*) | sr* | cd* | dvd*" `
test $? -eq 0 || exit 1
echo "Bluray device <$bluray>"

## Create disc image file.
truncate -s $xSize $imageUDF
mkudffs --vid="$discLabel" $imageUDF

## Check which block device is free (e.g. /dev/loop0)
loopx=`losetup -f`
## Attach logical block device and mount.  (Old method)
#mkdir -p /tmp/bluray 
#gksudo -- sh -c "losetup -f $imageUDF; mount $loopx /tmp/bluray; chmod 777 /tmp/bluray"
## Attache logical block device and mount.  (New method) 
udisksctl loop-setup -f $imageUDF
udisksctl mount -b $loopx
mountpt=`udisksctl info -b $loopx | grep MountPoints | awk '{print $2}'`

## COPY DATA NOW
sleep 1
xdg-open $mountpt
zenity --info --text="Copy your data now into $mountpt.  Press OK when finished."

## Unmount & unattach.
#gksudo -- sh -c "umount $loopx; losetup -d $loopx" 
udisksctl unmount -b $loopx
udisksctl loop-delete -b $loopx

## Confirm that the user wants to write the disc.
zenity --question --timeout=60  \
  --text="Are you ready to write the bluray disc?  You may cancel within 60s." 
test $? -eq 1 && exit 1

## Use cdrecord to write the disc.
cmd="cdrecord -v -dao -eject speed=4 driveropts=burnfree dev=$bluray $imageUDF"
echo $cmd
$cmd

exit 1