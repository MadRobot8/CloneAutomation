#!/bin/bash
#***************************************************************************************************##
#  Purpose  : To prepare application tier for clone.
#  SYNTAX   : sh prepareapps.sh instance
#             sh prepareapps.sh ORASUP
#
#  $Header 1.1 single node steps 2022/03/23 dikumar $
#  $Header 1.2 multi node steps  2022/03/24 dikumar $
#
#***************************************************************************************************##

#***************************************************************************************************###
#
#  **********   A P P L I C A T I O N - P R E P A R E - S C R I P T   **********#
#***************************************************************************************************###

#***************************************************************************************************###
#
#	Local variable declaration.
#***************************************************************************************************###

dbupper=${1^^}
dblower=${1,,}
HOST_NAME=$(uname -n | cut -f1 -d".")
export scr_home=/u05/oracle/autoclone
export util_home="${scr_home}/utils"

#***************************************************************************************************###
#
# Using instance.properties to load instance specific settings
#***************************************************************************************************###

envfile="${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
if [ ! -f ${envfile} ];  then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment instance.properties file not found.\n"
    exit 1;
else
    source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
    sleep 1
fi
unset envfile

envfile="/home/$(whoami)/.${dblower}_profile"
if [ ! -f "${envfile}" ]; then
	echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": "ERROR: Target Environment profile ${envfile} file not found on application server.\n"
	exit 1;
else
	source "${envfile}" > /dev/null
	sleep 1
fi

#******************************************************************************************************##
#  Libraries for Application functions
#******************************************************************************************************##
log_dir="${extractlogdir}"
preparelog="${log_dir}"/prepareApps"${dbupper}".log
echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  "logfile for this session is at  ${HOST_NAME}." | tee "${preparelog}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  "			   ${preparelog}. " | tee -a "${preparelog}"

APPSUSER=$(/dba/bin/getpass "${dbupper}" apps)
APPSPASS=$(echo "${APPSUSER}" | cut -d/ -f 2)
WLSUSER=$(/dba/bin/getpass "${dbupper}" weblogic)
WLSPASS=$(echo "${WLSUSER}" | cut -d/ -f 2)
export APPSUSER APPSPASS WLSUSER WLSPASS

unpw="${APPSUSER}@${dbupper}"
sqlplus -s -L  /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect ${unpw}
exit
EOF

if [ $? -ne 0 ]; then
   echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: WARNING: APPS passwords are not working, script will be exit."
   exit 1
fi

echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: *******  APPS Password is working  *******"
#***************************************************************************************************###
# Calling precloneextractapps.sh script to take extract and backups before clone.
#***************************************************************************************************###

	sleep 2
	if [ -n  "${trgapphost}" ]; then
		currenthost=$(hostname -a)
		if [[ ${currenthost} == *"${trgapphost}"* ]]; then
			echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": " Running Extract on ${trgapphost}. " | tee -a "${preparelog}"
			sh ${common_utils}/precloneextractapps.sh "${trgappname^^}" | tee -a "${preparelog}"
		else
			echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": " Running Extract on ${trgapphost}. " | tee -a "${preparelog}"
			ssh -q "${trgappsosuser}"@"${trgapphost}"."${labdomain}" "sh ${common_utils}/precloneextractapps.sh ${trgappname^^}"
		fi
	fi

	if [ -n  "${trgapphost2}" ]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Running Extract on ${trgapphost2}. " | tee -a "${preparelog}"
		ssh -q "${trgappsosuser}"@"${trgapphost2}"."${labdomain}" "sh ${common_utils}/precloneextractapps.sh ${trgappname^^}"
	fi

	if [ -n  "${trgapphost3}" ]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Running Extract on ${trgapphost3}. " | tee -a "${preparelog}"
		ssh -q "${trgappsosuser}"@"${trgapphost3}"."${labdomain}" "sh ${common_utils}/precloneextractapps.sh ${trgappname^^}"
		
	fi

	if [ -n "${trgapphost4}" ]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Running Extract on ${trgapphost4}. " | tee -a "${preparelog}"
		ssh -q "${trgappsosuser}"@"${trgapphost4}"."${labdomain}" "sh ${common_utils}/precloneextractapps.sh ${trgappname^^}"
	fi

#***************************************************************************************************###
# Calling adstpall.sh script on all nodes to stop application before clone.
#***************************************************************************************************###

	sleep 2
	if [ -n  "${trgapphost}" ]; then
		currenthost=$(hostname -a)
		if [[ ${currenthost} == *"${trgapphost}"* ]]; then
			echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Stopping services on ${trgapphost}. " | tee -a "${preparelog}"
			sh ${common_utils}/stopapps.sh "${trgappname^^}" >> "${preparelog}"
		else
			echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Stopping services on ${trgapphost}. " | tee -a "${preparelog}"
			ssh -q "${trgappsosuser}"@"${trgapphost}"."${labdomain}" "sh ${common_utils}/stopapps.sh ${trgappname^^}" >> "${preparelog}"
		fi
	fi

	if [ -n "${trgapphost2}" ]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Stopping services on ${trgapphost2}. " | tee -a "${preparelog}"
		ssh -q "${trgappsosuser}"@"${trgapphost2}"."${labdomain}" "sh ${util_home}/stopapps.sh ${trgappname^^}" >> "${preparelog}"
	fi

	if [ -n  "${trgapphost3}" ]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Stopping services on ${trgapphost3}. " | tee -a "${preparelog}"
		ssh -q "${trgappsosuser}"@"${trgapphost3}"."${labdomain}" "sh ${common_utils}/stopapps.sh ${trgappname^^}" >> "${preparelog}"
	fi

	if [ -n   "${trgapphost4}" ]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Stopping services on ${trgapphost4}. " | tee -a "${preparelog}"
		ssh -q "${trgappsosuser}"@"${trgapphost4}"."${labdomain}" "sh ${common_utils}/stopapps.sh ${trgappname^^}" >> "${preparelog}"
	fi


#***************************************************************************************************###
#
# Detaching Application node ORACLE HOMES from inventory.
#***************************************************************************************************###

	sleep 2
	if [ -n  "${trgapphost}" ]; then
		currenthost=$(hostname -a)
		if [[ ${currenthost} == *"${trgapphost}"* ]]; then
			echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Running Detach Home on ${trgapphost}. " | tee -a "${preparelog}"
			sh "${common_utils}"/detachOracleHome.sh "${trgappname^^}" >> "${preparelog}"
		else
			echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Running Detach Home on ${trgapphost}. " | tee -a "${preparelog}"
			ssh -q "${trgappsosuser}"@"${trgapphost}"."${labdomain}" "sh ${common_utils}/detachOracleHome.sh ${trgappname^^}"
		fi
	fi

	if [ -n  "${trgapphost2}" ] ; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Running Detach Home on ${trgapphost2}. " | tee -a "${preparelog}"
		ssh -q "${trgappsosuser}"@"${trgapphost2}"."${labdomain}" "sh ${common_utils}/detachOracleHome.sh ${trgappname^^}"
	fi

	if [ -n  "${trgapphost3}" ]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Running Detach Home on ${trgapphost3}. " | tee -a "${preparelog}"
		ssh -q "${trgappsosuser}"@"${trgapphost3}"."${labdomain}" "sh ${common_utils}/detachOracleHome.sh ${trgappname^^}"
	fi

	if [ -n  "${trgapphost4}" ]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Running Detach Home on ${trgapphost4}. " | tee -a "${preparelog}"
		ssh -q "${trgappsosuser}"@"${trgapphost4}"."${labdomain}" "sh ${common_utils}/detachOracleHome.sh ${trgappname^^}"
	fi

#***************************************************************************************************##
# De-registering instance from SSO, if trgappssoenable="Y" in instance.properties.
#***************************************************************************************************###

	sleep 2
	if [ "${trgappssoenable}" = "Y" ];  then
		currenthost=$(hostname -a)
		if [[ ! -z  ${trgapphost} ]] && [[ ${currenthost} == *"${trgapphost}"* ]]; then
			sh "${common_utils}"/deregsso.sh "${trgappname^^}" | tee -a "${preparelog}"
		fi
	fi

	echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  "***** Prepare Application Scripts completed   *****"  | tee -a "${preparelog}"
	exit
#***************************************************************************************************###
#
#  **********   E N D   O F   P R E P A R E   A P P L I C A T I O N  S C R I P T   **********
#
#***************************************************************************************************###