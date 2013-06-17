-- Applescript to collect and display hardware and configuration info
-- by Daniel Moore
-- Version 1.0.31
-- June 17, 2013

-- This script displays a column of items on the left with their corresponding info on the
-- right. For many items the info is nothing more than "OK."

-- The following variables should be set to customize the script to your environment.
-- There is no code to handle empty variables and I haven't tested that way.

set my_help_desk_email to "help.desk@yourdomain.com"
set my_help_desk_phone to "123-456-7890"

-- hd_fullness_threshold is maximum percentage you'll tolerate before warning that hard 
-- drive is too full
set hd_fullness_threshold to 90

-- enter Munki SoftwareRepoURL value without a trailing /
set my_software_repo to "http://munkirepo.yourdomain.com"

-- enter Apple SUS URL
set apple_sus_url to "http://swupd.yourdomain.com/index_ok.sucatalog"

-- enter the search domain to expect when on your organization's network
set my_search_domain to "yourdomain.com"

-- enter an ip address to reverse lookup and the expected results from that lookup
set ip_address_to_reverse_lookup to "0.0.0.0"
set reverse_lookup_expected_result to "static.yourdomain.com"

-- All of the organization's Macs are supposed to be bound to AD. To check that the 
-- computer is bound to AD, I lookup the UID of a particular user.
set ad_user_to_lookup to "ad-user"
set ad_uid to "246801357"

-- od_user_to_lookup and od_uid should be for the same account
set od_user_to_lookup to "od0user"
set od_uid to "999"
set od_server_hostname to "odmaster.yourdomain.com"

-- The variables below are for the dialog box. I couldn't decide on the text to display 
-- when there was a problem with an item so I made it a variable.
set not_ok_text to "Not OK"

-- help_desk_info is the information to display when all is well
set help_desk_info to "Help Desk -
Email:" & tab & my_help_desk_email & "
Phone:" & tab & my_help_desk_phone

-- help_desk_call is the information to display when there are problems. It calls more 
-- attention to itself than help_desk_info
set help_desk_call to "------------------------------------------------
Please contact the Help Desk -
Email:" & tab & my_help_desk_email & "
Phone:" & tab & my_help_desk_phone

-- help_desk_text defaults to "info" but will be set to "call" if there are problems 
set help_desk_text to help_desk_info

-- Don't change any variables below

-- get basic info 
set computer_name to get computer name of (get system info)
try
	set asset_tag to do shell script "/usr/bin/defaults read /Library/Preferences/com.apple.RemoteDesktop Text1"
	if asset_tag is equal to "" then
		set asset_tag to "?"
	end if
on error
	set asset_tag to "Unable to determine"
end try
set model_id to do shell script "sysctl -n hw.model"
set os_version to get system version of (get system info)


-- get serial number 
set get_serial_number to "/usr/sbin/ioreg -l | /usr/bin/awk -F \\\" ' /IOPlatformSerialNumber/ { print $4 } '"
try
	set serial_number to do shell script of get_serial_number
	if serial_number is equal to "" then
		set serial_number to "Unable to determine"
	end if
on error
	set serial_number to "Unable to determine"
end try


-- get RAM 
set raw_RAM to physical memory of (get system info)
if raw_RAM > 1024 then
	set RAM_unit to "GB"
	set RAM_amount to raw_RAM / 1024
else
	set RAM_unit to "MB"
	set RAM_amount to raw_RAM
end if

-- get hd info 
set hd_capacity to do shell script "/bin/df -H / | /usr/bin/awk 'NR==2 {print $2}' | /usr/bin/sed 's/G/\\ GB/'"
set hd_free_space to do shell script "/bin/df -H / | /usr/bin/awk 'NR==2 {print $4}' | /usr/bin/sed 's/G/\\ GB/'"
set hd_used_space to do shell script "/bin/df -H / | /usr/bin/awk 'NR==2 {print $3}' | /usr/bin/sed 's/G/\\ GB/'"
set hd_danger_threshold to do shell script "/bin/df -H / | /usr/bin/awk 'NR==2 {print $5}' | /usr/bin/sed 's/%//'"
if hd_danger_threshold as integer is greater than hd_fullness_threshold as integer then
	set hd_danger_threshold_text to " - Too full!"
else
	set hd_danger_threshold_text to ""
end if

-- get IP addresses 
if os_version begins with "10.4" then
	set ip_address_tiger to get IPv4 address of (get system info)
else
	set get_ip_address_0 to "networksetup -getinfo Ethernet 2>/dev/null | /usr/bin/awk '/^IP address:/ {print $3}'"
	set ip_address_0 to do shell script "/bin/bash -c " & quoted form of get_ip_address_0
	if ip_address_0 begins with "169" then
		set ip_address_0 to "self-assigned"
	else if ip_address_0 begins with "127" then
		set ip_address_0 to "loopback"
	else if ip_address_0 is equal to "" then
		set ip_address_0 to "none"
	end if
end if

if os_version does not start with "10.4" then
	if os_version starts with "10.5" or os_version starts with "10.6" then
		set get_ip_address_1 to "networksetup -getinfo Airport 2>/dev/null | /usr/bin/awk '/^IP address/ { print $3 }'"
	else if os_version starts with "10.7" or os_version starts with "10.8" then
		set get_ip_address_1 to "networksetup -getinfo Wi-Fi 2>/dev/null | /usr/bin/awk '/^IP address/ { print $3 }'"
	end if
	
	set ip_address_1 to do shell script "/bin/bash -c " & quoted form of get_ip_address_1
	if ip_address_1 begins with "169" then
		set ip_address_1 to "self-assigned"
	else if ip_address_1 begins with "127" then
		set ip_address_1 to "loopback"
	else if ip_address_1 is equal to "" then
		set ip_address_1 to "none"
	end if
end if

if model_id contains "Air" or model_id contains "MacBookPro10," then
	set ip_address_1 to ip_address_0
	set ip_address_0 to "none"
end if

-- get hostnames 
set hostname to host name of (get system info)
set local_hostname to do shell script "/usr/sbin/scutil --get LocalHostName"
set ad_computer_name to do shell script "/usr/sbin/dsconfigad -show | /usr/bin/awk '/Computer Account/ { print $4 }' | /usr/bin/sed 's/\\$//'"

-- get network hardware addresses 
set get_wifi_hardware_address to "/usr/sbin/networksetup -listallhardwareports | /usr/bin/egrep -A 2 '(AirPort)|(Wi-Fi)' | /usr/bin/awk '/Ethernet Address:/ { print $3 }'"
set wifi_hardware_address to do shell script "/bin/bash -x -c " & quoted form of get_wifi_hardware_address
if wifi_hardware_address is equal to "" then set wifi_hardware_address to "none"
set get_ethernet_hardware_address to "/usr/sbin/networksetup -listallhardwareports | /usr/bin/egrep -A 2 'Hardware Port: Ethernet' | /usr/bin/awk '/Ethernet Address:/ { print $3 }'"
set ethernet_hardware_address to do shell script "/bin/bash -x -c " & quoted form of get_ethernet_hardware_address
if ethernet_hardware_address is equal to "" then set ethernet_hardware_address to "none"
set ethernet_hardware_address_tiger to get primary Ethernet address of (get system info)

-- get munki info
-- checks a large number of munki bits to make sure everything is ok.

-- get client identifier
try
	set munki_client_identifier to do shell script "/usr/bin/defaults read /Library/Preferences/ManagedInstalls ClientIdentifier 2>/dev/null"
	if munki_client_identifier is equal to "" then
		set munki_client_identifier to not_ok_text
		set help_desk_text to help_desk_call
	end if
on error
	set munki_client_identifier to not_ok_text
	set help_desk_text to help_desk_call
end try

if os_version begins with "10.4" then
	set munki_software to "N/A"
else
	try
		set munki_code_ok to do shell script "du -d 0 /usr/local/munki 2>/dev/null | /usr/bin/awk '{ print $1 }'"
		set munki_launch_agents_ok to do shell script "ls /Library/LaunchAgents | /usr/bin/grep -c munki"
		set munki_launch_daemons_ok to do shell script "ls /Library/LaunchDaemons | /usr/bin/grep -c munki"
		if munki_code_ok as integer is greater than 1500 and munki_launch_agents_ok as integer is equal to 4 and munki_launch_daemons_ok as integer is equal to 4 then
			set munki_software to "OK"
		else
			set munki_software to not_ok_text
		end if
	on error
		set munki_software to not_ok_text
	end try
end if

try
	set software_repo_config to do shell script "/usr/bin/defaults read /Library/Preferences/ManagedInstalls SoftwareRepoURL 2>/dev/null"
	if software_repo_config is equal to my_software_repo or software_repo_config is equal to my_software_repo & "/" then set munki_check to "OK"
	if software_repo_config does not contain my_software_repo then
		set munki_check to not_ok_text
	end if
on error
	set munki_check to not_ok_text
end try

if munki_check is equal to "OK" and munki_software is equal to "OK" then
	set munki_ok to "OK"
else
	set munki_ok to not_ok_text
	set help_desk_text to help_desk_call
end if

-- get SUS config 
try
	set apple_sus_setting to do shell script "defaults read /Library/Preferences/com.apple.SoftwareUpdate CatalogURL 2>/dev/null"
	if apple_sus_setting is equal to apple_sus_url then
		set apple_sus_config_check to "OK"
	else
		set apple_sus_config_check to not_ok_text
		set help_desk_text to help_desk_call
	end if
on error
	set apple_sus_config_check to not_ok_text
	set help_desk_text to help_desk_call
end try

-- get kbox config 
try
	set kbox_check to do shell script "/bin/ps ax"
	if kbox_check contains "/Library/Application Support/Dell/KACE/bin/AMPAgent" then
		set kbox_state to "OK"
	else
		set kbox_state to not_ok_text
		set help_desk_text to help_desk_call
	end if
on error
	set kbox_state to ErrorText
	set help_desk_text to help_desk_call
end try

-- Directory: DNS checks 
set search_domain to do shell script "cat /etc/resolv.conf 2>&1 | /usr/bin/awk '/domain/ { print $2 }'"
set reverse_lookup_result to do shell script "/usr/bin/dig " & ip_address_to_reverse_lookup & " +short | /usr/bin/awk '/name =/ {print $4}'"

-- Directory: AD checks 
set ad_user_lookup to do shell script "/usr/bin/dscl /Search -read /Users/" & ad_user_to_lookup & " UniqueID | /usr/bin/awk '{ print $2 }'"

if ad_user_lookup is equal to ad_uid then
	set ad_report to "OK"
else if search_domain does not contain my_search_domain and reverse_lookup_result does not contain reverse_lookup_expected_result then
	set ad_report to "Can't tell on this network"
else
	set ad_report to not_ok_text
	set help_desk_text to help_desk_call
end if

-- Directory: generic OD check 
set od_user_lookup to do shell script "/usr/bin/dscl /Search -read /Users/" & od_user_to_lookup & " UniqueID | /usr/bin/awk '{ print $2 }'"

if od_user_lookup is equal to od_uid then
	set od_item to "Open Directory:"
	set od_report to "OK
"
else if search_domain does not contain my_search_domain and reverse_lookup_result does not contain reverse_lookup_expected_result then
	set od_item to "Open Directory:"
	set od_report to "Can't tell on this network
"
else
	set od_item to "Open Directory:"
	set od_report to not_ok_text & "
"
	set help_desk_text to help_desk_call
end if

-- begin output dialog 
if os_version begins with "10.5" or os_version begins with "10.6" or os_version begins with "10.7" or os_version begins with "10.8" then
	display alert "System Info" message "Computer name: " & tab & tab & computer_name & "
Mac model:" & tab & tab & tab & model_id & "
System version: " & tab & tab & os_version & "
Asset tag:" & tab & tab & tab & tab & asset_tag & "
Serial number: " & tab & tab & tab & serial_number & "

Hardware -" & "
Memory: " & tab & tab & tab & tab & RAM_amount & " " & RAM_unit & "
Hard drive capacity:" & tab & tab & hd_capacity & "
Hard drive used:" & tab & tab & hd_used_space & hd_danger_threshold_text & "

Network -" & "
IP address (Ethernet): " & tab & ip_address_0 & "
IP address (Wireless): " & tab & ip_address_1 & "
Ethernet address: " & tab & tab & ethernet_hardware_address & "
Wireless address: " & tab & tab & wifi_hardware_address & "

Software Services -" & "
Client Identifier:" & tab & tab & munki_client_identifier & "
Munki:" & tab & tab & tab & tab & munki_ok & "
Update server:" & tab & tab & tab & apple_sus_config_check & "
Inventory agent:" & tab & tab & kbox_state & "

Directories - " & "
Active Directory:" & tab & tab & ad_report & "
" & od_item & tab & tab & od_report & "
" & help_desk_text
else if os_version begins with "10.4" then
	display alert "System Info" message "Computer name: " & tab & tab & computer_name & "
Mac model:" & tab & tab & tab & model_id & "
System version: " & tab & tab & os_version & "
Asset tag:" & tab & tab & tab & tab & asset_tag & "
Serial number: " & tab & tab & tab & serial_number & "

Hardware -" & "
Memory: " & tab & tab & tab & tab & RAM_amount & " " & RAM_unit & "
Hard drive capacity:" & tab & tab & hd_capacity & "
Hard drive used:" & tab & tab & hd_used_space & hd_danger_threshold_text & "

Network -" & "
IP address: " & tab & tab & tab & ip_address_tiger & "
Ethernet address: " & tab & tab & ethernet_hardware_address_tiger & "

Software Services -" & "
Kbox agent:" & tab & tab & tab & kbox_state & "

Directories - " & "
Active Directory:" & tab & tab & ad_report & "
" & od_item & tab & tab & od_report & "
" & help_desk_info
else
	display dialog "Sorry - not tested on this version of the operating system!" with icon 2 buttons {"OK"} default button {"OK"}
end if
-- end output dialog 

