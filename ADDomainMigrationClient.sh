#!/bin/sh
#Active directory domain migration script - edit to suit your environment

# Sets new time server

# Use "/usr/sbin/systemsetup -listtimezones" to see a list of available list time zones.
TimeZone="Europe/London"
TimeServer="NTP Server"

############# Pause for network services #############
/bin/sleep 10
#################################################

#!/bin/bash

# get current wifi device
CURRENT_DEVICE=$(networksetup -listallhardwareports | awk '$3=="Wi-Fi" {getline; print $2}')
echo "Current Wi-Fi Device = '$CURRENT_DEVICE'"

# turn on wifi
networksetup -setairportpower $CURRENT_DEVICE on

/usr/sbin/systemsetup -setusingnetworktime on 

#Set an initial time zone
/usr/sbin/systemsetup -settimezone $TimeZone

#Set specific time server
/usr/sbin/systemsetup -setnetworktimeserver $TimeServer

# enable location services
/bin/launchctl unload /System/Library/LaunchDaemons/com.apple.locationd.plist
uuid=`/usr/sbin/system_profiler SPHardwareDataType | grep "Hardware UUID" | cut -c22-57`
/usr/bin/defaults write /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd.$uuid LocationServicesEnabled -int 1
/usr/sbin/chown -R _locationd:_locationd /var/db/locationd
/bin/launchctl load /System/Library/LaunchDaemons/com.apple.locationd.plist

# set time zone automatically using current location 
/usr/bin/defaults write /Library/Preferences/com.apple.timezone.auto Active -bool true

/usr/sbin/systemsetup -setusingnetworktime on 

/usr/sbin/systemsetup -gettimezone
/usr/sbin/systemsetup -getnetworktimeserver

/bin/sleep 10

##########################################################################################

#!/bin/sh

#Authenticated Unbind from OLD AD Domain
# Active Directory domain 
domain="DOMIAN.Name" 


 # Username/Password used to perform binding 
 username="USERNAME" 
 password="PASSWORD" 

 ## More variables - No need to edit 

 olddomain=$( dsconfigad -show | awk '/Active Directory Domain/{print $NF}' ) 
 computername=$( scutil --get ComputerName ) 
 adcomputerid=$( echo "${computername}" | tr [:lower:] [:upper:] ) 
 prefix="${adcomputerid:0:6}" 

 echo "Using computer name '${adcomputerid}'..." 
 echo "" 


 ## Unbind if already bound 


 # If the domain is correct 
 if [[ "${olddomain}" == "${domain}" ]]; then 
   # Check the id of a user 
   id -u "${username}" > /dev/null 2>&1 


   # If the check was successful... 
   if [[ $? == 0 ]]; then 
     echo -n "This machine is bound to AD. Unbinding..." 


     # Unbind from AD 
     dsconfigad -remove -force -u "${username}" -p "${password}" 


     # Re-check the id of a user 
     id -u "${username}" > /dev/null 2>&1 

     # If the check was successful... 
     if [[ $? == 0 ]]; then 
       echo "Failed (Error code: 1)" 
       exit 1 
     else 
       echo "Success" 
       echo "" 
     fi 
   fi 
 fi 

sleep 50

killall DirectoryService

##########################################################################################
 
# Active Directory Bind to NEW Domain
 
#
computerid=`/usr/sbin/scutil --get LocalHostName`
 
# Standard parameters
domain="DOMAIN.name"
udn="USERNAME"			
password="PASSWORD"					
ou="COMPUTER NODE ADDRESS"
 
# Advanced options
alldomains="enable"			
localhome="enable"			
protocol="smb"				
mobile="disable"			
mobileconfirm="disable"		
useuncpath="enable"			
user_shell="/bin/bash"		
preferred="PREFERED DC SERVER"	
							
admingroups="DOMIAN\domain admins"	
 
# Login hook setting -- specify the path to a login hook that you want to run instead of this script
 
### End of configuration
 
# Activate the AD plugin
defaults write /Library/Preferences/DirectoryService/DirectoryService "Active Directory" "Active"
plutil -convert xml1 /Library/Preferences/DirectoryService/DirectoryService.plist
sleep 5
 
# Bind to AD
dsconfigad -f -a $computerid -domain $domain -u "$udn" -p "$password" -ou "$ou"
 
# Configure advanced AD plugin options
if [ "$admingroups" = "" ]; then
	dsconfigad -nogroups
else
	dsconfigad -groups "$admingroups"
fi
 
dsconfigad -alldomains $alldomains -localhome $localhome -protocol $protocol \
	-mobile $mobile -mobileconfirm $mobileconfirm -useuncpath $useuncpath \
	-shell $user_shell $preferred
 
# Restart DirectoryService (necessary to reload AD plugin activation settings)
killall DirectoryService
 
# Add the AD node to the search path
if [ "$alldomains" = "enable" ]; then
	csp="/Active Directory/All Domains"
else
	csp="/Active Directory/$domain"
fi
 
#dscl /Search -create / SearchPolicy CSPSearchPath
#dscl /Search -append / CSPSearchPath "/Active Directory/All Domains"
#dscl /Search/Contacts -create / SearchPolicy CSPSearchPath
#dscl /Search/Contacts -append / CSPSearchPath "/Active Directory/All Domains"
 
# This works in a pinch if the above code does not
defaults write /Library/Preferences/DirectoryService/SearchNodeConfig "Search Node Custom Path Array" -array "/Active Directory/All Domains"
defaults write /Library/Preferences/DirectoryService/SearchNodeConfig "Search Policy" -int 3
defaults write /Library/Preferences/DirectoryService/ContactsNodeConfig "Search Node Custom Path Array" -array "/Active Directory/All Domains"
defaults write /Library/Preferences/DirectoryService/ContactsNodeConfig "Search Policy" -int 3
 
plutil -convert xml1 /Library/Preferences/DirectoryService/SearchNodeConfig.plist

dsconfigad -passinterval 0


sleep 50

##########################################################################################

#Changes permissions on local Home Folders 

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

##########################################################################################

# Removes the Keychain from all local users

myUSERS=$(ls /Users)
for i in $(echo $myUSERS)
do
#
#
if [[ $i != "."* ]]
then 
rm -Rvf /users/$i/Library/Keychains/*	
fi
done

##########################################################################################

#Munki Install and Config

curl https://munkibuilds.org/latest2.sh | sh
defaults write /Library/Preferences/ManagedInstalls SoftwareRepoURL "https://SERVER ADDRESS"
defaults write /Library/Preferences/ManagedInstalls ClientIdentifier "MANIFESTNAME"
defaults write /Library/Preferences/ManagedInstalls InstallAppleSoftwareUpdates "true"
defaults write /Library/Preferences/ManagedInstalls SuppressUserNotification "true"
defaults write /Library/Preferences/ManagedInstalls FollowHTTPRedirects "all"
defaults write /Library/Preferences/ManagedInstalls InstallRequiresLogout "true"
defaults write /Library/Preferences/ManagedInstalls UnattendedAppleUpdates "true"
defaults write /Library/Preferences/MunkiReport Passphrase "Munki Report Business Unit"

/bin/bash -c "$(curl -s --max-time 10 MunkiReportURL"
defaults write /Library/Preferences/MunkiReport ReportItems -dict-add ard_model "/Library/Preferences/com.apple.RemoteDesktop.plist"

##########################################################################################

#Sets DNS Search domain to both NUA and NUCA

networksetup -setsearchdomains Ethernet NewDomain OldDomain

exit 0