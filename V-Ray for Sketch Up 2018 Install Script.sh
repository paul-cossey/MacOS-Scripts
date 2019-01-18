#!/bin/sh

# This script assumes that the silent Educational V-Ray installer (with all supporting files copied to "vray_edu_36003_sketchup_osx.app/Contents/MacOS/") .app has been copied to /Users/Shared

# V-Ray needs to have SketchUp 2018 either already opened to install, or the below folder copied to /Library/Application Support. Sets permissions.
cp -Rvf /Users/Shared/vray_edu_36003_sketchup_osx.app/Contents/MacOS/SketchUp\ 2018 /Library/Application\ Support/
chown -Rvf root:wheel /Library/Application\ Support/SketchUp\ 2018
chmod -Rvf 777 /Library/Application\ Support/SketchUp\ 2018

# Sets permissions and then Copies V-Ray for SketchUp Licence file to all previously logged in users.
chown -Rvf root:wheel /Users/Shared/vray_edu_36003_sketchup_osx.app/Contents/MacOS/.ChaosGroup
chmod -Rvf 777 //Users/Shared/vray_edu_36003_sketchup_osx.app/Contents/MacOS/.ChaosGroup

myUSERS=$(ls /Users)
for i in $(echo $myUSERS)
do
if [[ $i != "."* ]]
then
cp -Rvf /Users/Shared/vray_edu_36003_sketchup_osx.app/Contents/MacOS/.ChaosGroup /Users/$i/
fi
done

# Copies licence files to default profile and sets permissions
cp -Rvf /Users/Shared/.ChaosGroup /System/Library/User\ Template/English.lproj/
chown -Rvf root:wheel /System/Library/User\ Template/English.lproj/.ChaosGroup
chmod -Rvf 777 /System/Library/User\ Template/English.lproj/.ChaosGroup

# Silent install for V-Ray
cd /Users/Shared/vray_edu_36003_sketchup_osx.app/Contents/MacOS ; ./vray_edu_36003_sketchup_osx -configFile="config.xml" -gui=0 -quiet=1 -ignoreErrors=1

# Removes V-Ray installer from /Users/Shared
rm -Rvf /Users/Shared/vray_edu_36003_sketchup_osx.app

# Set correct Home Folder permissions in an Active Directory Environment

####################################################################################################
#
# More information: http://macmule.com/2013/02/18/correct-ad-users-home-mobile-home-folder-permissions/
#
# GitRepo: https://github.com/macmule/CorrectADUsersHomeFolderPermissions
#
# License: http://macmule.com/license/
#
####################################################################################################

###
# Get the Active Directory Node Name
###
adNodeName=`dscl /Search read /Groups/Domain\ Users | awk '/^AppleMetaNodeLocation:/,/^AppleMetaRecordName:/' | head -2 | tail -1 | cut -c 2-`

###
# Get the Domain Users groups Numeric ID
###
domainUsersPrimaryGroupID=`dscl /Search read /Groups/Domain\ Users | grep PrimaryGroupID | awk '{ print $2}'`

###
# Gets the unique ID of the Users account locally, if that fails performs a lookup
###
  uniqueID ()
{
		# Attempt to query the local directory for the users UniqueID
		accountUniqueID=`dscl . -read /Users/$1 2>/dev/null | ﻿grep UniqueID | cut -c 11-`

		# If no value recived for the Users account, attempt a lookup on the domain
		if [ -z "$accountUniqueID" ]; then
					echo "Account is not on this mac..."
					accountUniqueID=`dscl "$adNodeName" -read /Users/$1 2>/dev/null | grep UniqueID | awk '{ print $2}'`
		fi
}

###
# Sets IFS to newline
###
IFS=$'\n'

###
# Returns a list of all folders found under /Users
###
for userFolders in `ls -d -1 /Users/* | cut -c 8- | sed -e 's/ /\\ /g' | grep -v "Shared"`

do
	# Return folder name found in /Users/
	echo "$userFolders..."
	# Check to see if folders contain a /Desktop folder, if they do assume it's a Home Folder
	if [ -d /Users/"$userFolders"/Desktop ]; then

		# Pass $userFolders to function uniqueID
		uniqueID "$userFolders"
		echo "User $userFolders's UniqueID = $accountUniqueID..."

		### The below is well echoed so should be explanatory ###

		if [ -z "$accountUniqueID" ]; then

			echo "Account is not local & cannot be found on $adNodeName... "
			echo "Removing all ACL's from /Users/$userFolders/ Account..."
			sudo chmod -R -N /Users/$userFolders

			echo "Clearing locks on any locked files/folder found in /Users/$userFolders/..."
			sudo chflags -R nouchg /Users/$userFolders

			echo "Making /Users/$userFolders/ fully accessible to all..."
			sudo chmod -R 777 /Users/$userFolders

		else

			echo "Removing all ACL's from /Users/$userFolders/ Account..."
			sudo chmod -R -N /Users/$userFolders

			echo "Clearing locks on any locked files/folder found in /Users/$userFolders/..."
			sudo chflags -R nouchg /Users/$userFolders

				if [ 1000 -gt "$accountUniqueID" ]; then
					echo "$accountUniqueID is a local account..."
					echo "As local account, setting Owners to $accountUniqueID:staff..."
					sudo chown -R $accountUniqueID:staff /Users/$userFolders/
				else
					echo "User $userFolders is a Domain account..."
					echo "$domainUsersPrimaryGroupID is the ID for the Domain Users group..."
					echo "As domain account, setting Owners to $accountUniqueID:$domainUsersPrimaryGroupID..."
					sudo chown -R $accountUniqueID:$domainUsersPrimaryGroupID /Users/$userFolders
				fi

			echo "Setting rwxr--r-- permission for Owner, Read for Everyone for everything under /Users/$userFolders..."
			sudo chmod -R 755 /Users/$userFolders/

			if [ -d /Users/$userFolders/Desktop/ ]; then
				echo "Setting rwx permission for Owner, None for Everyone for /Users/$userFolders/Desktop..."
				sudo chmod 700 /Users/$userFolders/Desktop/
			fi

			if [ -d /Users/$userFolders/Documents/ ]; then
				echo "Setting rwx permission for Owner, None for Everyone for /Users/$userFolders/Documents..."
				sudo chmod 700 /Users/$userFolders/Documents/
			fi

			if [ -d /Users/$userFolders/Downloads/ ]; then
				echo "Setting rwx permission for Owner, None for Everyone for /Users/$userFolders/Downloads..."
				sudo chmod 700 /Users/$userFolders/Downloads/
			fi

			if [ -d /Users/$userFolders/Library/ ]; then
				echo "Setting rwx permission for Owner, None for Everyone for /Users/$userFolders/Library..."
				sudo chmod 700 /Users/$userFolders/Library/
			fi

			if [ -d /Users/$userFolders/Movies/ ]; then
				echo "Setting rwx permission for Owner, None for Everyone for /Users/$userFolders/Movies..."
				sudo chmod 700 /Users/$userFolders/Movies/
			fi

			if [ -d /Users/$userFolders/Music/ ]; then
				echo "Setting rwx permission for Owner, None for Everyone for /Users/$userFolders/Music..."
				sudo chmod 700 /Users/$userFolders/Music/
			fi

			if [ -d /Users/$userFolders/Pictures/ ]; then
				echo "Setting rwx permission for Owner, None for Everyone for /Users/$userFolders/Pictures..."
				sudo chmod 700 /Users/$userFolders/Pictures/
			fi

				# If the Public folder exists in /Users/$userFolders/, give it it's special permissions
				if [ -d /Users/$userFolders/Public/ ]; then
					echo "Setting Read only access for Everyone to /Users/$userFolders/Public/..."
					sudo chmod -R 755 /Users/$userFolders/Public
						# If the Drop Box folder exists in /Users/$userFolders/, give it it's special permissions
						if [ -d /Users/$userFolders/Public/Drop\ Box/ ]; then
							echo "Drop Box folder found, setting Write only access for Everyone to /Users/$userFolders/Public/Drop Box/..."
							sudo chmod -R 733 /Users/$userFolders/Public/Drop\ Box/
						fi
				else
				# Notify if not found
					echo "Public folder not found @ /Users/$userFolders/Public/..."
				fi

				# If the Sites folder exists in /Users/$userFolders/, give it it's special permissions
				if [ -d /Users/$userFolders/Sites/ ]; then
					echo "Setting Read only access for Everyone to /Users/$userFolders/Public/..."
					sudo chmod -R 755 /Users/$userFolders/Public
				else
				# Notify if not found
					echo "Sites folder not found @ /Users/$userFolders/Sites/..."
				fi
			fi
			#Creates a new line in the output, making it more readable
			echo ""
	else
		echo "No Desktop folder in /Users/$userFolders/.. Setting rwx for all to /Users/$userFolders/..."
		sudo chmod -R 777 /Users/$userFolders/
	fi

done

###
# Resets IFS
###
unset IFS


exit 0
