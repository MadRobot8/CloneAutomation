#!/bin/bash
#******************************************************************************************************#
#  Purpose  : Script to restore application backup to application tier and configure application.
#
#  SYNTAX   : sh restoreappsw.sh instance
#             sh restoreappsw.sh ORASUP
#
#  $Header 1.2 2022/03/23 dikumar $
#  $Header 1.3 moved restart_dir to instance.properties file 2022/05/01 dikumar $
#******************************************************************************************************#

#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - R E S T O R E - S C R I P T **********
#
#******************************************************************************************************##
#***************************************************************************************************##
#       Assigning Local variables.
#***************************************************************************************************#

    dbupper=${1^^}
    dblower=${1,,}
	HOST_NAME=`uname -n | cut -f1 -d"."`
    ECHO="echo -e `date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: "
    scr_home=/u01/oracle/backupmgr
    etc_home="${scr_home}/etc"
    bin_home="${scr_home}/bin"
    lib_home="${scr_home}/lib"
    util_home="${scr_home}/utils"
    common_sql="${scr_home}/sql"

#******************************************************************************************************##
#
#  Libraries for Application functions
#******************************************************************************************************##

. ${lib_home}/funlibapps.sh
. ${lib_home}/os_check_dir.sh

#******************************************************************************************************##
#
#  Creating missing directories
#******************************************************************************************************##

        echo -e "\n\n\n\n\n"
        sleep 2
        ${ECHO} "     **********************************************************************************"
        ${ECHO} "    "
        ${ECHO} "                      THIS IS START OF ${dbupper} APPLICATION RESTORE SESSION.   "
        ${ECHO} "    "
        ${ECHO} "     **********************************************************************************"
        sleep 4


        #To check and create os directories if missing.
        os_check_dir >/dev/null 2>&1

#***************************************************************************************************###
#
# Using instance.properties to load instance specific settings
#***************************************************************************************************###

    envfile="${etc_home}/instance.properties"
    if [ ! -f ${envfile} ];
    then
        ${ECHO} "ERROR: Target Environment instance.properties file not found.\n"
        exit 1;
    else
        . ${etc_home}/instance.properties ${dbupper}
        sleep 2
    fi


	envfile="${trgapprestart_dir}/clone.rsp"
	if [ ! -f ${envfile} ];
	then
		${ECHO} "ERROR: Target Environment clone.rsp file not found.\n"
		exit 1;
	else
		. ${trgapprestart_dir}/clone.rsp
		${ECHO} "APP CONFIGURE : clone.rsp found as ${trgapprestart_dir}/clone.rsp. "
		${ECHO} "APP CONFIGURE : Start date is : ${startdate}"

		sleep 2
	fi
	unset envfile

#******************************************************************************************************##
#
# Cleanup old log and setup logfiles.
#******************************************************************************************************##
	#chmod 775 ${restore_log}
	#cd ${restore_log}
	#currnetdir=`pwd`
	#if [ ${restore_log} = ${currnetdir} ] ;
	#then
	#	if [ -f ${restore_log}/restoredate ];
	#	then
	#	lastrestore=`cat ${restore_log}/restoredate`
	#	tempbkplog=${restore_log}/${lastrestore}
	#	mkdir -p ${tempbkplog}
	#	mv *.* ${tempbkplog}/.
	#	else
	#	lastrestore=$(date -d "`date +%Y%m%d` - 1 days" +%Y%m%d)
	#	tempbkplog=${restore_log}/${lastrestore}
	#	mkdir -p ${tempbkplog}
	#	mv *.* ${tempbkplog}/.
	#	fi
	#fi

#******************************************************************************************************#
#
# Restore apps tier backup for the Run fs
#******************************************************************************************************#

	if [ -z ${startdate} ]; then
		datetag=`date '+%Y%m%d'`
	else
		datetag=${startdate}
	fi

	echo ${datetag} > ${restore_log}/restoredate
	logf=${restore_log}/appRestoreMain${dbupper^^}.${datetag}
	${ECHO} "Logfile for this session is at  ${HOST_NAME}" | tee ${logf}
	${ECHO} "			   ${logf}. " | tee -a ${logf}

	#We will encrypt these password fetches
	SRCAPPSPASS=Lty5uidfget99uTe
	SRCWLSPASS=0ebsl0gicweb
	workappspass=${SRCAPPSPASS}
	workwlspass=${SRCWLSPASS}

	# Run application restore and configure along with Application post clone steps.
	config_single_node

	exit
#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - R E S T O R E - S C R I P T - END **********
#
#******************************************************************************************************#