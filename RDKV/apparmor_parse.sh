#!/bin/sh

# Apparmor_blocklist file is used to manage apparmor processes at run-time.
# The tr181 command for accesscontrol when invoked will add processes to be
# confined under apparmor and the mode (enforce/complain/disable) to
# /opt/secure/Apparmor_blocklist file.
# Sample usage : tr181 -s -v "irMgrMain:enforce#lighttpd:enforce" Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.NonRootSupport.ApparmorBlocklist

Apparmor_blocklist="/opt/secure/Apparmor_blocklist"

# Apparmor_defaults file is used to define apparmor processes at build-time.
# The default system-wide profile gets added to Apparmor_defaults from generic layer.
# Other platform specific profiles gets added to Apparmor_defaults from platform specific layer.

Apparmor_defaults="/etc/apparmor/apparmor_defaults"

PROFILES_DIR="/etc/apparmor.d/"
PARSER="/sbin/apparmor_parser"
SYSFS_AA_PATH="/sys/kernel/security/apparmor/profiles"
RDKLOGS="/opt/logs/startup_stdout_log.txt"

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

if [ ! -f $Apparmor_blocklist ]; then
        touch $Apparmor_blocklist
fi

while read line; do
        mode=`echo $line | cut -d ":" -f 2`
        process=`echo $line | cut -d ":" -f 1`
        profile=`ls -ltr $PROFILES_DIR | grep $process | awk '{print $9}'`
        if [ ! -z $profile ]; then
             if [ "$mode" == "enforce" ]; then
                   $PARSER -rW $PROFILES_DIR/$profile
             elif [ "$BUILD_TYPE" != "prod" ]; then
                     if [ "$mode" == "complain" ]; then
                           $PARSER -rWC $PROFILES_DIR/$profile
                     fi
             fi
        fi
done<$Apparmor_defaults

while read line; do
        mode=`echo $line | cut -d ":" -f 2`
        process=`echo $line | cut -d ":" -f 1`
        profile=`ls -ltr $PROFILES_DIR | grep $process | awk '{print $9}'`
           if [ ! -z $profile ]; then
                if [ "$mode" == "enforce" ]; then
                      $PARSER -rW $PROFILES_DIR/$profile
                elif [ "$mode" == "complain" ]; then
                      $PARSER -rWC $PROFILES_DIR/$profile
                elif [ "$mode" == "disable" ]; then
                      $PARSER -R $PROFILES_DIR/$profile
                else
                      echo "Apparmor profile:unknown $profile mode"
                fi
           fi
done<$Apparmor_blocklist

list=`cat $SYSFS_AA_PATH | grep complain | awk '{print $1}' | tr '\n'  ','`
cnt=`cat $SYSFS_AA_PATH | grep complain | wc -l
`
if [ ! -z "$list" ]; then
     echo "List of profiles in Apparmor-complain mode:$cnt : $list" >> $RDKLOGS
     t2ValNotify "APPARMOR_C_split:" "$cnt,$list"
fi
list=`cat $SYSFS_AA_PATH | grep enforce | awk '{print $1}' | tr '\n'  ','`
cnt=`cat $SYSFS_AA_PATH | grep enforce | wc -l`
if [ ! -z "$list" ]; then
     echo "List of profiles in Apparmor-enforce mode:$cnt : $list"  >> $RDKLOGS
     t2ValNotify "APPARMOR_E_split:" "$cnt,$list"
fi
