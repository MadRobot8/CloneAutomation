#!/bin/bash
#***************************************************************************************************##
#  Purpose  : To prepare application tier for clone.
#  SYNTAX   : sh preparedb.sh instance
#             sh preparedb.sh ORASUP
#
#  $Header 1.1 single node steps 2022/03/23 dikumar $
#  $Header 1.2 multi node steps  2022/09/ dikumar $
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
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S") : ${HOST_NAME}: "
scr_home=/u05/oracle/autoclone
etc_home="${scr_home}/etc"
bin_home="${scr_home}/bin"
lib_home="${scr_home}/lib"
util_home="${scr_home}/utils"
common_sql="${scr_home}/sql"

#***************************************************************************************************###
#
# Using instance.properties to load instance specific settings
#***************************************************************************************************###

envfile="${etc_home}"/properties/"${dbupper}".prop
if [ ! -f "${envfile}" ] ; then
	echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": "ERROR: Target Environment instance.properties file not found.\n"  | tee -a  "${logf}"
	exit 1;
else
	source "${envfile}"
	sleep 2
fi

unset envfile
envfile=/home/$(whoami)/."${dblower}"_profile
if [ ! -f "${envfile}" ]; then
	echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": "ERROR: Target Environment profile ${envfile} file not found.\n"  | tee -a  "${logf}"
	exit 1;
else
	source "${envfile}" > /dev/null
	sleep 2
fi

#******************************************************************************************************##
#  Libraries for Application functions
#******************************************************************************************************##
source ${lib_home}/os_check_dir.sh
os_check_dir

echo -e "\n\n"
logf="${restore_log}"/prepareDB"${dbupper}".log
echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  "Logfile for this session is at  ${HOST_NAME}." | tee "${logf}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  "			   ${logf}. " | tee -a "${logf}"


APPSUSER=$(/dba/bin/getpass "${dbupper}" apps)
APPSPASS=$(echo "${APPSUSER}" | cut -d/ -f 2)
export APPSUSER APPSPASS

unpw="${APPSUSER}@${dbupper}"
sqlplus -s -L  /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect ${unpw}
exit
EOF

if [ $? -ne 0 ]; then
   echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): $(HOST_NAME): WARNING: APPS passwords are not working, script will be exit."
fi

echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): $(HOST_NAME): *******  APPS Password is working  *******"
#***************************************************************************************************###
#
# Calling precloneextractdb.sh script to take extract and backups before clone.
#***************************************************************************************************###

sleep 2
if [ ! -z  "${trgdbhost}" ]; then
	currenthost=$(uname -n | cut -f1 -d".")
	if [[ ${currenthost} == *"${trgdbhost}"* ]]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": " Running Extract on ${trgdbhost}. " | tee -a "${logf}"
		sh "${util_home}"/precloneextractdb.sh "${trgdbname^^}" | tee -a "${logf}"
	else
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": " Running Extract on ${trgdbhost}. " | tee -a "${logf}"
		ssh -q oracle@"${trgdbhost}"."${labdomain}" "sh ${util_home}/precloneextractdb.sh ${trgdbname^^}"
	fi
fi

if [[ ! -z  ${trgdbhost2} ]]; then
	echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Running Extract on ${trgdbhost2}. " | tee -a "${logf}"
	ssh -q oracle@"${trgdbhost2}"."${labdomain}" "sh ${util_home}/precloneextractdb.sh ${trgdbname^^}"
fi



#***************************************************************************************************###
#
# Calling stopdb.sh script on all nodes to stop application before clone.
#
#***************************************************************************************************###

	sleep 2
	if [[ ! -z  ${trgdbhost} ]]; then
		currenthost=
		if [[ ${currenthost} == *"${trgdbhost}"* ]]; then
			echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Stopping services on ${trgdbhost}. " | tee -a "${logf}"
			sh ${util_home}/stopdb.sh "${trgdbname^^}" >> "${logf}"
		else
			echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Stopping services on ${trgdbhost}. " | tee -a "${logf}"
			ssh -q oracle@"${trgdbhost}"."${labdomain}" "sh ${util_home}/stopdb.sh ${trgdbname^^}" >> "${logf}"
		fi
	fi

	if [[ ! -z  "${trgdbhost2}" ]]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  " Stopping services on ${trgdbhost2}. " | tee -a "${logf}"
		ssh -q oracle@"${trgdbhost2}"."${labdomain}" "sh ${util_home}/stopdb.sh ${trgdbname^^}" >> "${logf}"
	fi

	echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}":  "***** Prepare Database Scripts completed   *****"  | tee -a "${logf}"
	exit
#***************************************************************************************************###
#
#  **********   E N D - O F - P R E P A R E - D A T A B A S E -  S C R I P T   **********
#
#***************************************************************************************************###