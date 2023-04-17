#!/bin/bash -n
#******************************************************************************************************
#  Purpose  : Function library script, to be used Application node.
#
#  SYNTAX   : sh funlibapps.sh instance
#             sh funlibapps.sh ORASUP
#
#  $Header 1.1 base version           2022/03/17 dikumar $
#  $Header 1.2 added killappssessions 2022/03/26 dikumar $
#  $Header 1.3 added fixed detach home. 2022/04/24 dikumar $
#
#******************************************************************************************************
#******************************************************************************************************
#
#  **********  A P P L I C A T I O N - F U N C T I O N - L I B R A R Y - S C R I P T - **********
#
#******************************************************************************************************
#******************************************************************************************************##
#
#  Library functions list
#	os_user_check   applmgr			: To validate current os user
#	source_profile  dbname			: To source profile file for DB
#	check_dbname 	dbname			: To validate given database name with current environment
#	check_dbprocess dbname			: Check running database process at OS level
#
#******************************************************************************************************##
	HOST_NAME=`uname -n | cut -f1 -d"."`

	#To validate current os user
	os_user_check()
	{
	user=$1
	if [ `whoami` != $user ]; then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: Error: User must be ${user} \n" | tee -a ${logf}
		exit 1
	fi
	}

	#To source profile file for DB
	source_profile()
	{
	dblower=${1,,}
	unset envfile
	envfile="/home/`whoami`/.${dblower}_profile"
	if [ ! -f ${envfile} ];
		then
		echo -e "ERROR: Target Environment profile ${envfile} file not found. \n" | tee -a ${logf}
		exit 1;
	else
    . ${envfile} > /dev/null
		sleep 2
	fi
	}

	source_patchfs()
	{
	unset ${ENVFILE}
	ENVFILE="${apptargetbasepath}/EBSapps.env"
	echo -e  "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP SET PATCHFS: ENV file is ${apptargetbasepath}/EBSapps.env " | tee -a ${logf}
	if [ ! -f ${ENVFILE} ];
	then
	   echo -e  "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP SET PATCHFS: Environment file $ENVFILE is not found. " | tee -a ${logf}
	   return 0
	else
	  #. ${ENVFILE} patch > /dev/null
	. ${ENVFILE} patch > /dev/null
  	  echo -e  "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP SET PATCHFS: FILE EDITION is SET To ${FILE_EDITION}. " | tee -a ${logf}
	  sleep 2
	fi
	unset ${ENVFILE}
	}

	killappssessions()
	{

	echo -e  "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: SESSION CLEANUP: Killing sessions. " | tee -a ${logf}
	kill -9  `ps -ef | grep '${apptargetbasepath}' | grep -v grep | awk '{print $2}'`  > /dev/null 2>&1
	sleep 5

	ps -ef | grep 'applmgr' | grep -v grep | awk '{print $2}' | while read -r sessid ; do
	pwdx ${sessid} | grep -q '${trgappname}' && kill -9 ${sessid} 2>/dev/null
	done

	sleep 4
	ps -ef | grep 'applmgr' | grep -v grep | awk '{print $2}' | while read -r sessid ; do
	pwdx ${sessid} | grep -q '${trgappname}' && kill -9 ${sessid} 2>/dev/null
	done

	sleep 3
	ps -ef | grep 'applmgr' | grep -v grep | awk '{print $2}' | while read -r sessid ; do
	pwdx ${sessid} | grep -q '${trgappname}' && kill -9 ${sessid} 2>/dev/null
	done

	echo -e  "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: SESSION CLEANUP: All sessions on ${HOST_NAME} are killed. " | tee -a ${logf}

	}

	compileinvalids()
	{

	os_user_check applmgr
	source_profile ${trgappname}

	echo -e  "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: COMPILE INVALIDS: Compiling invalid objects. " | tee -a ${logf}

	export SYSTUSER=`/dba/bin/getpass ${trgappname} system`
	export SYSTPASS=`echo $SYSTUSER | cut -d/ -f 2`

sqlplus  'sys/${SYSTPASS}@${trgappname} as sysdba'  << EOF > /dev/null
set echo on ;
spool ${restore_log}/spool_CompileInvalidObjects${trgappname^^}.${datetag}
exec sys.utl_recomp.recomp_parallel(10) ;
exec sys.utl_recomp.recomp_parallel(10) ;
exec sys.utl_recomp.recomp_parallel(10) ;
SPOOL OFF ;
exit
EOF
	echo -e  "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: COMPILE INVALIDS: Invaild Objects compiled. " | tee -a ${logf}
	}

	ebslogon()
	{

	if [ "${1}" = "ENABLE" ];
	then
		#echo -e "\n ******************  ENABLE EBS LOGON trigger. *************************"
sqlplus -s -L  /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect system/PmK5Bru#
ALTER TRIGGER EBS_LOGON ENABLE ;
exit
EOF
	_exitST=${?}

	elif [ "${1}" = "DISABLE" ];
	then
		#echo -e "\n ******************  DISABLE EBS LOGON trigger. *************************"
sqlplus -s -L  /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect system/PmK5Bru#
ALTER TRIGGER EBS_LOGON DISABLE ;
exit
EOF
	_exitST=${?}

	else
		echo -e "ERROR: ENABLE/DISABLE Action not specified for EBS LOGON trigger."

	fi

	if [ ${_exitST} -ne 0 ];
	then
		echo -e " ERROR: Disable EBS_LOGON failed, connectivity issue, please check"
	   return 1
	 fi

#echo -e "return 0"
	return 0

	}

	# Password validate function ######
	chk_apps_password()
	{


	unpw="apps/${1}@${2}"
sqlplus -s -L  /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect ${unpw}
exit
EOF

	if [ $? -ne 0 ]; then
		#   echo -e "return 1"
		return 1
	fi

	#echo -e "return 0"
	return 0
	}


	# Validate which APPS password is working - Source or Target
	validate_working_apps_password()
	{

	#echo -e "checking  ${SRCAPPSPASS} for validation."
	chk_apps_password ${SRCAPPSPASS} ${trgappname^^}
	_chkTpassRC1=$?
	sleep 1
	#echo -e "checking  ${APPSPASS} for validation."
	chk_apps_password ${APPSPASS} ${trgappname^^}
	_chkTpassRC2=$?
	sleep 1
	if [ ${_chkTpassRC1} -eq 0 ]; then
		echo -e  " "
		echo -e  "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: \t\t*******  Source APPS Password is working  *******" | tee -a ${logf}
        echo -e  " "
		workappspass=${SRCAPPSPASS}
	elif [ ${_chkTpassRC2} -eq 0 ]; then
        workappspass=${APPSPASS}
		echo -e  " "
		echo -e  "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: \t\t*******  Target APPS Password is working  *******" | tee -a ${logf}
        echo -e  " "
	else
		echo -e  "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: \t\t WARNING: \n Source and Target - Both APPS passwords are not working. Exiting !!\n" | tee -a ${logf}
	fi

	}

	# restore/untar mentioned tar file in the given runfs.
	restore_apps_tier()
	{

	vbkpfile=${apps_bkp_file}
	vbkpfileloc=${appsrunfsbase}


	if [ ! -d ${vbkpfileloc} ];
		then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Runfs ${vbkpfileloc} is not created. Creating it." | tee -a ${logf}
		mkdir -p ${vbkpfileloc}
		sleep 2
	else
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Runfs ${vbkpfileloc} found. " | tee -a ${logf}
	fi

	if [ ! -f ${vbkpfileloc}/${vbkpfile} ];
		then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: Error: Apps tier backup file not found. Cannot proceed. Exiting !!" | tee -a ${logf}
		sleep 2
		exit 1
	fi

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Decompressing backup file, it may take 15-20mins. " | tee -a ${logf}
	cd ${vbkpfileloc}
	tar -xzvf ${vbkpfile} >> ${restore_log}/untar_appsbkp${trgdbname}.${datetag}

	if [ ! -d ${vbkpfileloc}/EBSapps ];
		then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Tar file  could not create EBSapps. Exiting !!" | tee -a ${logf}
		echo ${vbkpfile} > ${vbkpfileloc}/EBSapps/restore.failed
		exit 1
		sleep 2
	fi

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Application tier backup file decompress completed." | tee -a ${logf}
	echo ${vbkpfile} > ${apptargetbasepath}/${runfs}/EBSapps/restore.complete
	}

	# set locally installed Oracle Client Oracle Home
	set_client_ohome()
	{

	# In case of application restore, we may not have ORACLE_HOME set.
	# Hence, set it to local oracle client home to detach and test oracle connectivity to database.
	if [ -z "${ORACLE_HOME}" ];
	then
			if [ -d ${apptargetbasepath}/fs2/EBSapps/10.1.2 ] ;
			then
				ORACLE_HOME=${apptargetbasepath}/fs2/EBSapps/10.1.2
			elif [ -d ${apptargetbasepath}/fs1/EBSapps/10.1.2 ] ;
			then
				ORACLE_HOME=${apptargetbasepath}/fs1/EBSapps/10.1.2
			fi
	else
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}:Oracle Home not available for use. Cannot run runInstaller.sh. Exiting!!" | tee -a ${logf}
	fi
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: ORACLE HOME set to local client home. " | tee -a ${logf}
	}

	# Password validate function ######
validate_apps_password()
	{
	set_client_ohome

	unpw="apps/${1}@${2}"
sqlplus -s -L  /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect ${unpw}
exit
EOF

	if [ $? -ne 0 ]; then
		#   echo -e "return 1"
		return 1
	fi

	#echo -e "return 0"
	return 0
	}

	# Detach Oracle Homes from Application tier
	detach_apps_oh()
	{

	INST_BASE=${apptargetbasepath}

	if [ ! -z ${appsclienthome} ]; then
	ORACLE_HOME=${appsclienthome}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP DETACH HOME: ORACLE_HOME set to ${ORACLE_HOME}. " | tee -a ${logf}
	else
		${ECHO} "Oracle Home not available for use. Cannot run runInstaller.sh. Exiting!!" | tee -a ${logf}
	fi

    #Detaching ORACLE_HOME
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP DETACH HOME: Detaching All the ORACLE_HOME from Application tier." | tee -a ${logf}
	sh $ORACLE_HOME/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs2/FMW_Home/webtier" >>  ${logf} 2>&1
    sh $ORACLE_HOME/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs2/FMW_Home/oracle_common" >>  ${logf} 2>&1
    sh $ORACLE_HOME/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs2/FMW_Home/Oracle_OAMWebGate1"  >>  ${logf} 2>&1
    sh $ORACLE_HOME/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs2/FMW_Home/Oracle_EBS-app1"  >>  ${logf} 2>&1

    sh $ORACLE_HOME/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs1/FMW_Home/webtier" >>  ${logf} 2>&1
    sh $ORACLE_HOME/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs1/FMW_Home/oracle_common" >>  ${logf} 2>&1
    sh $ORACLE_HOME/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs1/FMW_Home/Oracle_OAMWebGate1" >>  ${logf} 2>&1
    sh $ORACLE_HOME/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs1/FMW_Home/Oracle_EBS-app1" >>  ${logf} 2>&1
	sh $ORACLE_HOME/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs1/EBSapps/10.1.2"  >>  ${logf} 2>&1
	sh $ORACLE_HOME/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs2/EBSapps/10.1.2"  >>  ${logf} 2>&1


	if [ ! -f /etc/oraInst.loc ]; then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP DETACH HOME: oraInst.loc file is not available. Detaching ORACLE_HOME is not completed. " | tee -a ${logf}
		return 1
	else
	source /etc/oraInst.loc > /dev/null
	vinvloc=${inventory_loc}
	fi

	if [ ! -f ${vinvloc}/ContentsXML/inventory.xml.empty ]; then
		cp ${vinvloc}/ContentsXML/inventory.xml ${vinvloc}/ContentsXML/inventory.xml.empty
		sed -i '/connection/d' ${vinvloc}/ContentsXML/inventory.xml.empty
	elif [ -f ${vinvloc}/ContentsXML/inventory.xml.empty ]; then
		cp ${vinvloc}/ContentsXML/inventory.xml.empty ${vinvloc}/ContentsXML/inventory.xml
	fi

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP DETACH HOME: Detaching ORACLE_HOME completed " | tee -a ${logf}
	unset ${ORACLE_HOME} >>  ${logf} 2>&1
	sleep 2
	}

	# Move old application stack to allow new backup restoration
	move_old_stack()
	{

	if [ -z "${apptargetbasepath}" ];
	then

		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: ERROR: Target Application Base Path is not set. " | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE:        Cannot proceed. Exiting !! " | tee -a ${logf}
		sleep 2
		exit 1
	elif [ -z "${runfs}" ] || [ -z "${patchfs}" ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: ERROR: Source Application Run fs or Patch fs could not be identified. " | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE:        Cannot proceed. Exiting !! " | tee -a ${logf}
		sleep 2
		exit 1
	fi

	vrunbase=${apptargetbasepath}/${runfs}
	vpatchbase=${apptargetbasepath}/${patchfs}
	cd ${vrunbase}
	currentdir=`pwd`
	if [ "${vrunbase}" = "${currentdir}" ] && [ "${appsrunfsbase}" = "${currentdir}" ] ;
		then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Renaming Runfs EBSapps. " | tee -a ${logf}
		mv 	EBSapps  EBSapps.del >> ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Renaming Runfs FMW_Home. " | tee -a ${logf}
		mv FMW_Home  FMW_Home.del  >> ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Renaming Runfs inst home. " | tee -a ${logf}
		mv inst inst.del  >> ${logf}
		sleep 2
	else
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Correct directories could not be found." | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: apptargetbasepath is ${apptargetbasepath}" | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: appsrunfsbase is ${appsrunfsbase}" | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: currentdir is ${currentdir}" | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: All the above values must be same." | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Cannot proceed. Exiting !!" | tee -a ${logf}
		exit 1
	fi

	cd ${vpatchbase}
	currentdir=`pwd`
	if [ "${vpatchbase}" = "${currentdir}" ];
		then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Renaming Patchfs EBSapps. " | tee -a ${logf}
		mv 	EBSapps  EBSapps.del >> ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Renaming Patchfs FMW_Home. " | tee -a ${logf}
		mv FMW_Home  FMW_Home.del  >> ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Renaming Patchfs inst home. " | tee -a ${logf}
		mv inst inst.del  >> ${logf}
		sleep 2
	else
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Correct directories could not be found." | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: vpatchbase is ${vpatchbase}" | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: currentdir is ${currentdir}" | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: All the above values must be same." | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Cannot proceed. Exiting !!" | tee -a ${logf}
		exit 1
	fi

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RESTORE: Old Application stack is moved. !!" | tee -a ${logf}
	}

	#Validate and cleanup old stack
	cleanup_and_restore_apps()
	{
	markerfile=${apptargetbasepath}/${runfs}/EBSapps/restore.complete

	if [ -f ${markerfile} ];
	then
		chkrestorefile=`cat ${markerfile}`
		if [ "${chkrestorefile}" = "${apps_bkp_file}" ];
		then
			# Detach Oracle homes from Inventory.
			detach_apps_oh

			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: MESSAGE: Apps tier backup file already restored. No need to restore backup." | tee -a ${logf}
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: MESSAGE: Clearing up last session directories." | tee -a ${logf}

			rm -rf ${apptargetbasepath}/${patchfs}/EBSapps 2>/dev/null
			rm -rf ${apptargetbasepath}/${patchfs}/inst 2>/dev/null
			rm -rf ${apptargetbasepath}/${patchfs}/FMW_Home 2>/dev/null
			rm -rf ${apptargetbasepath}/${runfs}/inst 2>/dev/null
			rm -rf ${apptargetbasepath}/${runfs}/FMW_Home 2>/dev/null
			sleep 2
		else
			# Detach Oracle homes from Inventory.
			detach_apps_oh

			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: MESSAGE: Clearing up old  directories." | tee -a ${logf}
			# If marker file does not have same value as apps_bkp_file, then move old stack.
			#move_old_stack
			rm -rf ${apptargetbasepath}/${patchfs}/EBSapps 2>/dev/null
			rm -rf ${apptargetbasepath}/${patchfs}/inst 2>/dev/null
			rm -rf ${apptargetbasepath}/${patchfs}/FMW_Home 2>/dev/null
			rm -rf ${apptargetbasepath}/${runfs}/EBSapps 2>/dev/null
			rm -rf ${apptargetbasepath}/${runfs}/inst 2>/dev/null
			rm -rf ${apptargetbasepath}/${runfs}/FMW_Home 2>/dev/null

			# Restore apps tier backup
			restore_apps_tier
		fi
	elif [ ! -f ${markerfile} ];
	then
		# Detach Oracle homes from Inventory.
		detach_apps_oh

		# If marker file not found, it means last untar session failed. Hence remove everything.
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP CLEANUP: This is a fresh session." | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP CLEANUP: Run and Patch fs will be removed." | tee -a ${logf}

		rm -rf ${apptargetbasepath}/${patchfs}/EBSapps 2>/dev/null
		rm -rf ${apptargetbasepath}/${patchfs}/inst 2>/dev/null
		rm -rf ${apptargetbasepath}/${patchfs}/FMW_Home 2>/dev/null
		rm -rf ${apptargetbasepath}/${runfs}/inst 2>/dev/null
		rm -rf ${apptargetbasepath}/${runfs}/FMW_Home 2>/dev/null
		rm -rf ${apptargetbasepath}/${runfs}/EBSapps 2>/dev/null

		# Restore apps tier backup
		restore_apps_tier
	fi

	}


	# Pre-checks before executing adcfgclone
	validate_pre_adcfgclone()
	{

	skipadcfgclone="N"
	if [ -f ${restore_statedir}/adcfgclone.${datetag} ];
	then
		chkcfgstate=`cat ${restore_statedir}/adcfgclone.${datetag}`
		if [ ${vbkpfile} = ${chkcfgstate} ];
		then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl PRE VALIDATION: adcfgclone.pl is already completed." | tee -a ${logf}
		skipadcfgclone="Y"
		return 0
		fi
	fi

	# Restored File system fs and edition validation
	_pcontextf=${apptargetbasepath}/${runfs}/EBSapps/comn/clone/context/apps/${srcappname}_${srcadminapphost}.xml
	_chkfs=`grep "file_edition_name" ${_pcontextf}`
	_chked=`grep "file_edition_type" ${_pcontextf}`

	if [[ ${_chkfs} == *"${runfs}"* ]] ;
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP BACKUP VALIDATION: Supplied fs is ${runfs}." | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP BACKUP VALIDATION: Validated fs from restored backup is ${runfs}." | tee -a ${logf}
	elif [[ ${_chked} == *"run"* ]] && [[ ${_chkfs} == *"${runfs}"* ]] ;
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP BACKUP VALIDATION: Validated edition from restored backup is ${runfs}." | tee -a ${logf}
	elif [[ ${_chked} == *"patch"* ]] ;
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP BACKUP VALIDATION: ERROR: Restore Backup File system validation failed. Restored backup is not from RUN fs. Please validate. EXITING !!" | tee -a ${logf}
		exit 1
	else
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP BACKUP VALIDATION: ERROR: Restore Backup File system validation failed. Restored backup is not from RUN fs. Please validate. EXITING !!" | tee -a ${logf}
		exit 1
	fi

	# Validating txkWfClone.sh file exists and it have exit 0 added in first 2 lines to avoid long running adcfgclone.pl
	_FILE1=${apptargetbasepath}/${runfs}/EBSapps/appl/fnd/12.0.0/admin/template/txkWfClone.sh
	if [ -f "${_FILE1}" ] ;
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl PRE VALIDATION: txkWfClone.sh file found. Editing further." | tee -a ${logf}
		sed -i '2 i exit 0 \n'  ${_FILE1}
	else
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl PRE VALIDATION: Warning: txkWfClone.sh file not found. Please review." | tee -a ${logf}
		exit 1
	fi
	unset _FILE1

	}

	# run adcfgclone.pl with available values.
	run_adcfgclone()
	{

	# Validate pre-adcfgclone run checks
	validate_pre_adcfgclone

	if [ ${skipadcfgclone} = "N" ];
	then
		# Validating pairs file and adcfgclone
		unset _FILE1
		unset _FILE2
		_FILE1=${etc_home}/${trgappname}_${trgadminapphost}_${runfs}.txt
		_FILE2=${apptargetbasepath}/${runfs}/EBSapps/comn/clone/bin/adcfgclone.pl
		if [ -f "${_FILE1}" ] && [ -f "${_FILE2}" ] ;
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl PRE VALIDATION: ${runfs} Pairs file found. Proceeding further." | tee -a ${logf}
			sleep 2
		elif [ ! -f "${_FILE1}" ];
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl PRE VALIDATION: ${runfs} Pairs file not found. Application configuration cannot proceed. exiting !!" | tee -a ${logf}
			exit 1
		elif [ ! -f "${_FILE2}" ];
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl PRE VALIDATION: adcfgclone file not found. Application configuration cannot proceed. exiting !!" | tee -a ${logf}
			exit 1
		fi

		export CONFIG_JVM_ARGS="-Xms2048m -Xmx4096m"
		if [ "${runfs}" = "fs1" ] || [ "${runfs}" = "fs2" ] ;
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl RUN:" | tee -a ${logf}
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl RUN: ********  starting adcfgclone is from ${runfs} *******" | tee -a ${logf}
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl RUN:" | tee -a ${logf}
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl RUN:   Logfile :" | tee -a ${logf}
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl RUN:        ${restore_log}/adcfgcloneRun${trgappname}.${datetag}" | tee -a ${logf}

			{ echo "${SRCAPPSPASS}" ; echo "${SRCWLSPASS}" ; echo "n" ; } | perl ${INST_BASE}/${runfs}/EBSapps/comn/clone/bin/adcfgclone.pl component=appsTier pairsfile=${etc_home}/${trgappname}_${trgadminapphost}_${runfs}.txt dualfs=yes >  ${restore_log}/adcfgcloneRun${trgappname}.${datetag} 2>&1
			_exitSt1=$?
		else
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl RUN:Run fs is not validated. Make sure you have supplied fs1 or fs2. EXITING !!" | tee -a ${logf}
			exit 1
		fi

		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl RUN:**** Exit status for adcfgclone is ${_exitSt1} . " | tee -a ${logf}

		if [ "${_exitSt1}" = "0" ] ;
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl POST VALIDATION:********  adcfgclone.pl is completed successfully  *******  " | tee -a ${logf}
			echo ${vbkpfile} > ${restore_statedir}/adcfgclone.${datetag}
		else
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP adcfgclone.pl POST VALIDATION: ERROR:  adcfgclone.pl was failed. Please check the logs and restart. EXITING !! " | tee -a ${logf}
			exit 1
		fi
	fi

	}

	# Load up all passwords needed from getpass
load_getpass_password()
	{
	dbupper=${trgappname^^}

	#Load Target passwords
	export SYSTUSER=`/dba/bin/getpass ${dbupper} system`
	#echo ${SYSTUSER}
	export SYSTPASS=`echo $SYSTUSER | cut -d/ -f 2`
	export APPSUSER=`/dba/bin/getpass ${dbupper} apps`
	?
	#echo ${APPSUSER}
	export EXPDUSER=`/dba/bin/getpass ${dbupper} xxexpd`
	export EXPDPASS=`echo $EXPDUSER | cut -d/ -f 2`
	export OALLUSER=`/dba/bin/getpass ${dbupper} alloracle`
	export OALLPASS=`echo $OALLUSER | cut -d/ -f 2`
	export SYSADUSER=`/dba/bin/getpass ${dbupper} sysadmin`
	export SYSADPASS=`echo $SYSADUSER | cut -d/ -f 2`
	export WLSUSER=`/dba/bin/getpass ${dbupper} weblogic `
	export WLSPASS=`echo $WLSUSER | cut -d/ -f 2`
	export VSAPPREADUSER=`/dba/bin/getpass ${dbupper} sappreaduser  `
	export VSAPPREADPASS=`echo $VSAPPREADUSER | cut -d/ -f 2`
	export VSAPPWRITEUSER=`/dba/bin/getpass ${dbupper} sappwriteuser  `
	export VSAPPWRITEPASS=`echo $VSAPPWRITEUSER | cut -d/ -f 2`

	}

	#execute autoconfig
	run_autoconfig()
	{

	os_user_check applmgr
	source_profile ${trgappname^^}

	#Load Target passwords
	load_getpass_password

	#Validate working apps password, this will also validate connectivity.
	validate_working_apps_password

	#To keep track of autoconfig runs.
	autoconfigcnt=$((autoconfigcnt+1))

	sed -i '/connection/d' ${EBS_DOMAIN_HOME}/config/config.xml

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP AUTOCONFIG:          " | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP AUTOCONFIG: Running autoconfig....  Execution count ${autoconfigcnt}.       " | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP AUTOCONFIG:          " | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP AUTOCONFIG: Logfile ${restore_log}/run_autoconfig${autoconfigcnt}.${datetag}      " | tee -a ${logf}
	#echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP AUTOCONFIG: SRCPAPPSPASS : ${SRCAPPSPASS}  SRCWLSPASS : ${SRCWLSPASS}      " | tee -a ${logf}
	#echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP AUTOCONFIG: workappspass : ${workappspass} workwlspass : ${workwlspass}     " | tee -a ${logf}
	sh ${ADMIN_SCRIPTS_HOME}/adautocfg.sh  appspass=${workappspass}  > ${restore_log}/run_autoconfig${autoconfigcnt}.${datetag}
	rcode=$?
	if (( ${rcode} > 0 ));
	then
    	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP AUTOCONFIG: ERROR: autoconfig failed on application host ${HOST_NAME}. EXITING !!" | tee -a ${logf}
    	exit 1
	else
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP AUTOCONFIG: Autoconfig execution count ${autoconfigcnt} completed succesfully.      " | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP AUTOCONFIG:          " | tee -a ${logf}
    	sleep 2
	fi
	unset rcode
	sed -i '/connection/d' ${EBS_DOMAIN_HOME}/config/config.xml
	}


	delete_accessgate()
	{

	os_user_check applmgr
	source_profile ${trgappname^^}

	###### Delete Access Gate entries
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP REMOVE AccessGate: Deleting AccessGate Manage Server and SSO references." | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP REMOVE AccessGate: 		Logfile: ${restore_log}/DeleteAccessGateMS.${datetag}" | tee -a ${logf}
	echo -ne '\n' | perl $FND_TOP/patch/115/bin/txkSetAppsConf.pl -contextfile=$CONTEXT_FILE -configoption=removeMS -accessgate=${srcadminapphost}.${proddomain}:6809  > ${restore_log}/DeleteAccessGateMS.${datetag}  2>&1
	echo -ne '\n' | perl $FND_TOP/patch/115/bin/txkSetAppsConf.pl -contextfile=$CONTEXT_FILE -configoption=removeMS -accessgate=${srcapphost2}.${proddomain}:6809  >> ${restore_log}/DeleteAccessGateMS.${datetag}  2>&1
	echo -ne '\n' | perl $FND_TOP/patch/115/bin/txkSetAppsConf.pl -contextfile=$CONTEXT_FILE -configoption=removeMS -accessgate=${trgapphost}.${labdomain}:68${appspatchfsportpool} >> ${restore_log}/DeleteAccessGateMS.${datetag}  2>&1

	###### Delete Access Gate Managed server
	{ echo 'dummpyapps' ; echo 'dummyweblogic' ;} |  perl $AD_TOP/patch/115/bin/adProvisionEBS.pl ebs-delete-managedserver -contextfile=${CONTEXT_FILE}  -managedsrvname=oaea_server -servicetype=accessgate >> ${restore_log}/DeleteAccessGateMS.${datetag} 2>&1

	}

	remove_sso_reference()
	{

	os_user_check applmgr
	source_profile ${trgappname^^}

	load_getpass_password
	#gives workappspass
	validate_working_apps_password

	###### Clear SSO references
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP REMOVE SSO: 		Logfile: ${restore_log}/RemoveSSORef.${datetag}" | tee -a ${logf}
	sleep 2
	perl $FND_TOP/bin/txkrun.pl -script=SetSSOReg  -appspass=${workappspass} -removereferences=yes > ${restore_log}/RemoveSSORef.${datetag}

	}

	disable_ssl ()
	{
	source_profile ${trgappname^^}
	load_getpass_password
	#gives workappspass
	validate_working_apps_password

	##### DISABLE SSL from Application node
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP DISABLE SSL: DISABLE SSL from Application node." | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP DISABLE SSL: 		Logfile: ${restore_log}/DisableSSL.${datetag}" | tee -a ${logf}
	sleep 2
	perl $FND_TOP/bin/txkrun.pl -script=SetAdvCfg -appsuser=apps -appspass=${workappspass} -disable=SSL -s_webport=80${appsrunfsportpool} >  ${restore_log}/DisableSSL.${datetag}

	# Execute Autoconfig
	run_autoconfig
	}


	clean_inbound_outbound_dir()
	{
	os_user_check applmgr
	source_profile ${trgappname^^}

	##### Cleanup INBOUND/OUTBOUND Directories
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP in/outbound cleanup: Cleaning up Inboound/Outbound direcotries ." | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP in/outbound cleanup: 		Logfile: ${restore_log}/Cleanup_in_out_dir.${datetag}" | tee -a ${logf}
	sh ${lib_home}/delete_all_files_of_in_out_bound_r122.sh  -s ${trgappname,,}  > ${restore_log}/Cleanup_in_out_dir.${datetag} 2>&1
	sleep 2

	}

	xxexpd_top_softlink()
	{
	os_user_check applmgr
	source_profile ${trgappname^^}

	# Create SOFTLINKS in XXEXPD_TOP
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP XXEXPD_TOP softlinks: Create SOFTLINKS in XXEXPD_TOP." | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP XXEXPD_TOP softlinks: 		Logfile: ${restore_log}/xxexpd_top_softlinks.${datetag}" | tee -a ${logf}

	cd ${XXEXPD_TOP}/bin

	case ${XXEXPD_TOP} in
	*xxexpd* )
	   cd ${XXEXPD_TOP}/bin
	   sh  ./recreate_softlink_runFS.sh  > ${restore_log}/xxexpd_top_softlinks.${datetag}
	  ;;
	* ) echo "Error : XXEXPD_TOP not set, Softlinks not created !!"  ;;
	esac

	sleep 2
	}

        run_apps_sql()
        {
        os_user_check applmgr
        source_profile ${trgappname^^}

        #gives workappspass
        validate_working_apps_password

        echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP SQL: Executing apps based SQL post adcfgclone. " | tee -a ${logf}
        echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP SQL:    Logfile: ${restore_log}/spool_apps${trgappname^^}.${datetag} " | tee -a ${logf}

        ${ORACLE_HOME}/bin/sqlplus   -s apps/${workappspass} @${common_sql}/apps_update.sql  > ${restore_log}/spool_apps${trgappname^^}.${datetag}  2>&1
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP SQL: Executing ${trgappname^^} based sql." >> ${restore_log}/spool_apps${trgappname^^}.${datetag}  2>&1
        ${ORACLE_HOME}/bin/sqlplus   -s apps/${workappspass} @${common_sql}/apps_updateORASUP.sql  >> ${restore_log}/spool_apps${trgappname^^}.${datetag}  2>&1
        echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP SQL: Executing apps based SQL post adcfgclone. - Completed. " | tee -a ${logf}

        }


	gen_custom_env()
	{
	os_user_check applmgr
	source_profile ${trgappname^^}
	####### Create RUN and PATCH fs Custom env file
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Custom ENV: Create RUN and PATCH fs Custom env file." | tee -a ${logf}
	if [ -f "${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env" ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Custom ENV: Runfs Custom ENV exits as ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env." | tee -a ${logf}
	else
		echo "export XXEXPD_PMTS=/u05/oracle/BANKS/${trgappname}/Payments"  > ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXEXPD_DD=/u05/oracle/BANKS/${trgappname}/DirectDebit" >> ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export PATH=/u04/oracle/perforce:\$PATH:/dba/bin" >> ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export P4PORT=tcp:perforce:1985"  >> ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXEXPD_TOP_NE=/u04/oracle/R12/${trgappname}/XXEXPD/12.0.0" >> ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export CONFIG_JVM_ARGS=\"-Xms2048m -Xmx4096m\""  >> ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXEXPD_JAVA11_HOME=/usr/local/jdk11" >> ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		chmod 775 ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Custom ENV: Runfs Custom ENV created as :" | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Custom ENV:  ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env." | tee -a ${logf}
	fi

	if [ -f "${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env" ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Custom ENV: Patchfs Custom ENV exits as ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env." | tee -a ${logf}
	else
		echo "export XXEXPD_PMTS=/u05/oracle/BANKS/${trgappname}/Payments"  > ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXEXPD_DD=/u05/oracle/BANKS/${trgappname}/DirectDebit" >> ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export PATH=/u04/oracle/perforce:\$PATH:/dba/bin" >> ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export P4PORT=tcp:perforce:1985"  >> ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXEXPD_TOP_NE=/u04/oracle/R12/${trgappname}/XXEXPD/12.0.0" >> ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export CONFIG_JVM_ARGS=\"-Xms2048m -Xmx4096m\""  >> ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXEXPD_JAVA11_HOME=/usr/local/jdk11" >> ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		chmod 775 ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Custom ENV: Patchfs Custom ENV created as : " | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Custom ENV:  ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env." | tee -a ${logf}
	fi

	}


	postadcfgclone()
	{
	os_user_check applmgr
	source_profile ${trgappname^^}

	runfsctx=${apptargetbasepath}/${runfs}/inst/apps/${CONTEXT_NAME}/appl/admin/${CONTEXT_NAME}.xml
	patchfsctx=${apptargetbasepath}/${patchfs}/inst/apps/${CONTEXT_NAME}/appl/admin/${CONTEXT_NAME}.xml

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP POST RESTORE: Restoring TNS files." | tee -a ${logf}
	chmod -R 775 ${currentextractdir}/${runfs}/tns >> ${logf} 2>&1
	chmod -R 775 ${currentextractdir}/${patchfs}/tns   >> ${logf} 2>&1
	cp -r  ${currentextractdir}/${runfs}/tns/*  ${apptargetbasepath}/${runfs}/inst/apps/${CONTEXT_NAME}/ora/10.1.2/network/admin/.   >> ${logf} 2>&1
	cp -r  ${currentextractdir}/${patchfs}/tns/*  ${apptargetbasepath}/${patchfs}/inst/apps/${CONTEXT_NAME}/ora/10.1.2/network/admin/. >> ${logf} 2>&1
	sleep 2

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP POST RESTORE: Restoring Cert files." | tee -a ${logf}

	cp   -p ${currentextractdir}/app_others/wallet/fmw/cwallet.sso  ${apptargetbasepath}/fs1/FMW_Home/webtier/instances/EBS_web_OHS1/config/OPMN/opmn/wallet/.   >> ${logf} 2>&1
    cp   -p  ${currentextractdir}/app_others/wallet/fmw/cwallet.sso  ${apptargetbasepath}/fs1/FMW_Home/webtier/instances/EBS_web_OHS1/config/OHS/EBS_web/proxy-wallet/. >> ${logf} 2>&1
    cp   -p  ${currentextractdir}/app_others/wallet/fmw/cwallet.sso   ${apptargetbasepath}/fs1/FMW_Home/webtier/instances/EBS_web_OHS1/config/OHS/EBS_web/keystores/default/. >> ${logf} 2>&1

	cp   -p ${currentextractdir}/app_others/wallet/fmw/cwallet.sso  ${apptargetbasepath}/fs2/FMW_Home/webtier/instances/EBS_web_OHS1/config/OPMN/opmn/wallet/.  >> ${logf} 2>&1
    cp   -p  ${currentextractdir}/app_others/wallet/fmw/cwallet.sso  ${apptargetbasepath}/fs2/FMW_Home/webtier/instances/EBS_web_OHS1/config/OHS/EBS_web/proxy-wallet/.   >> ${logf} 2>&1
    cp   -p  ${currentextractdir}/app_others/wallet/fmw/cwallet.sso   ${apptargetbasepath}/fs2/FMW_Home/webtier/instances/EBS_web_OHS1/config/OHS/EBS_web/keystores/default/.   >> ${logf} 2>&1

	cp  -p ${currentextractdir}/app_others/wallet/java/cacerts  ${apptargetbasepath}/fs1/EBSapps/comn/util/jdk32/jre/lib/security/.   >> ${logf} 2>&1
    cp  -p ${currentextractdir}/app_others/wallet/java/cacerts ${apptargetbasepath}/fs1/EBSapps/comn/util/jdk32/jre/lib/security/../../../../jdk64/jre/lib/security/.  >> ${logf} 2>&1

	cp  -p ${currentextractdir}/app_others/wallet/java/cacerts  ${apptargetbasepath}/fs2/EBSapps/comn/util/jdk32/jre/lib/security/.   >> ${logf} 2>&1
    cp  -p ${currentextractdir}/app_others/wallet/java/cacerts ${apptargetbasepath}/fs2/EBSapps/comn/util/jdk32/jre/lib/security/../../../../jdk64/jre/lib/security/.  >> ${logf} 2>&1

    cp  -p ${currentextractdir}/app_others/xdo.cfg ${apptargetbasepath}/fs1/EBSapps/appl/xdo/12.0.0/resource/.    >> ${logf} 2>&1
    cp  -p ${currentextractdir}/app_others/xdo.cfg  ${apptargetbasepath}/fs2/EBSapps/appl/xdo/12.0.0/resource/.   >> ${logf} 2>&1

	cp   -p  ${currentextractdir}/fs1/ssl/ssl.conf  ${apptargetbasepath}/fs1/FMW_Home/webtier/instances/EBS_web_OHS1/config/OHS/EBS_web/ssl.conf  >> ${logf} 2>&1
    cp   -p  ${currentextractdir}/fs1/ssl/ssl.conf  ${apptargetbasepath}/fs2/FMW_Home/webtier/instances/EBS_web_OHS1/config/OHS/EBS_web/ssl.conf  >> ${logf} 2>&1


	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP VALIDATE CTXT FILE: Correcting Context file values." | tee -a ${logf}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_applcsf ${trgapplcsf}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_applcsf ${trgapplcsf}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_applptmp ${trgapplptmp}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_applptmp ${trgapplptmp}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_url_protocol ${trgurl_protocol}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_url_protocol ${trgurl_protocol}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_local_url_protocol ${trgurl_protocol}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_local_url_protocol ${trgurl_protocol}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_webentryurlprotocol ${trgurl_protocol}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_webentryurlprotocol ${trgurl_protocol}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_active_webport ${trgactive_webport}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_active_webport ${trgactive_webport}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_webssl_port ${trgwebssl_port}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_webssl_port ${trgwebssl_port}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_webentryhost ${trgwebentryhost}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_webentryhost ${trgwebentryhost}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_https_listen_parameter ${trghttps_listen_parameter}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_https_listen_parameter ${trghttps_listen_parameter}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_login_page ${trglogin_page}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_login_page ${trglogin_page}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_external_url ${trgexternal_url}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_external_url ${trgexternal_url}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_endUserMonitoringURL ${trgendUserMonitoringURL}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_endUserMonitoringURL ${trgendUserMonitoringURL}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_shared_file_system ${trgshared_file_system}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_shared_file_system ${trgshared_file_system}

	#java oracle.apps.ad.context.UpdateContext ${runfsctx} s_apps_jdbc_connect_descriptor ${trgapps_jdbc_connect_descriptor}
	#java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_apps_jdbc_connect_descriptor ${trgapps_jdbc_connect_descriptor}

	#java oracle.apps.ad.context.UpdateContext ${runfsctx} s_apps_jdbc_patch_connect_descriptor ${trgapps_jdbc_patch_connect_descriptor}
	#java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_apps_jdbc_patch_connect_descriptor ${trgapps_jdbc_patch_connect_descriptor}

	java oracle.apps.ad.context.UpdateContext ${runfsctx} s_apps_patch_alias ${trgapps_patch_alias}
	java oracle.apps.ad.context.UpdateContext ${patchfsctx} s_apps_patch_alias ${trgapps_patch_alias}

	# Run apps based sql steps.
	run_apps_sql
	# Autoconfig run
	run_autoconfig

	}

	compile_jsp()
	{
	os_user_check applmgr
	source_profile ${trgappname^^}

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Compile JSP: Compiling JSP - Will take 10mins." | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Compile JSP: 		Logfile: ${restore_log}/Compile_jsp${trgappname^^}.${datetag}" | tee -a ${logf}

	# Compiling JSP
	perl $FND_TOP/patch/115/bin/ojspCompile.pl --compile --flush -p 80 > ${restore_log}/Compile_jsp${trgappname^^}.${datetag} 2>&1
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Compile JSP: Compiling JSP - COMPLETED." | tee -a ${logf}

	}

	run_adop_fsclone()
	{
	os_user_check applmgr
	source_profile ${trgappname^^}

	#gives workappspass
	validate_working_apps_password

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP FS_CLONE: Executing FS_CLONE." | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP FS_CLONE: 	Logfile: ${restore_log}/adop_${trgappname,,}.fsclone " | tee -a ${logf}

	echo ${workwlspass} > ${restore_log}/.loadpass
	echo ${SYSTPASS} >> ${restore_log}/.loadpass
	echo ${WLSPASS} >> ${restore_log}/.loadpass
	echo "Y" >> ${restore_log}/.loadpass

	adop phase=fs_clone   workers=48 < ${restore_log}/.loadpass  > ${restore_log}/adopfsclone_${trgappname,,}.${datetag}

	if (( ${?} > 0 ));
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP FS_CLONE: ERROR: FS_CLONE failed. Please check logfile ${restore_log}/adop_${trgappname,,}.fsclone " | tee -a ${logf}
		rm -f ${restore_log}/.loadpass
		exit 1
	else
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP FS_CLONE: ADOP FS_CLONE completed successfully. " | tee -a ${logf}
		rm -f ${restore_log}/.loadpass
		sleep 2
	fi

	}


	# Running app node ETCC from application admin node
	run_app_etcc()
	{
	os_user_check applmgr
	source_profile ${trgappname^^}

	#gives workappspass
	validate_working_apps_password

	cd ${etc_home}/etcc/
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RUN ETCC: Running ETCC on application node." | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP RUN ETCC: 		Logfile: ${restore_log}/appnode_etcc_${trgappname^^}.${datetag}" | tee -a ${logf}
	{ echo "${workappspass}" ; } | sh ${etc_home}/etcc/checkMTpatch.sh  > ${restore_log}/appnode_etcc_${trgappname^^}.${datetag} 2> /dev/null  &
	sleep 2
	}


	user_password_reset()
	{

	os_user_check applmgr
	source_profile ${trgappname^^}

	#gives workappspass
	validate_working_apps_password

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP User Password reset: Generating Application User Password reset scripts. " | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP User Password reset:    Script: ${restore_log}/${trgappname^^}_resetpassword_fnd_user.sh " | tee -a ${logf}

sqlplus -s apps/${workappspass}@${trgappname^^} << EOF > /dev/null
set head off
set feed off
set line 999
set pages 200
set lines 300

spool ${restore_log}/${trgappname^^}_resetpassword_fnd_user.sh
select '. /home/applmgr/.'||lower('${trgappname,,}')||'_profile  > /dev/null' from dual;
select '  FNDCPASS apps/${workappspass} 0 Y system/PmK5Bru# USER  '|| USER_NAME || ' welcome123 '  from fnd_user where last_logon_date >= sysdate-120 or trunc(creation_date)=trunc(sysdate)
and end_date is null and user_name
not in ('AME_INVALID_APPROVER','APPLSYS','APPS','XXEXPD',
'ANONYMOUS',
'APPSMGR',
'ASADMIN',
'ASGADM',
'ASGUEST',
'AUTOINSTALL',
'CHAINSYS',
'CONCURRENT MANAGER',
'CORP_CONVERSION',
'CTLMSCHD',
'CTLMSCHD2',
'EXPD_INT',
'FEEDER SYSTEM',
'GUEST',
'IBE_ADMIN',
'IBE_GUEST',
'IBEGUEST',
'IEXADMIN',
'INITIAL SETUP',
'IRC_EMP_GUEST',
'IRC_EXT_GUEST',
'MERCH_CONVERSION',
'MOBILEADM',
'MOBILEDEV',
'OAMACCESS',
'OP_CUST_CARE_ADMIN',
'OP_SYSADMIN',
'PORTAL30',
'PORTAL30_SSO',
'STANDALONE BATCH PROCESS',
'SYSADMIN',
'VBANK_CONVERSION',
'WIZARD',
'XML_USER');
spool off

exit
EOF

	sed -i '/SYSADMIN/d' ${restore_log}/${trgappname^^}_resetpassword_fnd_user.sh

	${ECHO} "\n****************** Resetting FND User Passwords  ***********************************\n"
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP User Password reset:    Logfile: ${restore_log}/${trgappname^^}_resetpassword_fnd_user.${datetag} " | tee -a ${logf}
	sh ${restore_log}/${trgappname^^}_resetpassword_fnd_user.sh > ${restore_log}/reset_user_password${trgappname^^}.${datetag} 2>&1
	sleep 2
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP User Password reset:    Password reset script completed. " | tee -a ${logf}

	}


	upload_lookup()
	{

	os_user_check applmgr
	source_profile ${trgappname^^}

	cd ${restore_log}
	if [ ! -d ${restore_log}/uploadlog ] ; then
		mkdir -p ${restore_log}/uploadlog
	fi

	cd ${restore_log}/uploadlog
	export APPSUSER=`/dba/bin/getpass ${trgappname^^} apps`

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Upload Lookups: Uploading FND Lookups. " | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Upload Lookups:    Logfile: ${restore_log}/Upload_lookups${trgappname^^}.${datetag}  " | tee -a ${logf}
	sh ${uploaddir}/fnd_lookups/app_upload_fndlookup.sh  > ${restore_log}/Upload_lookups${trgappname^^}.${datetag}  2>&1

	#for file in ${uploaddir}/fnd_lookups/*.ldt
	#do
  	#	FNDLOAD ${APPSUSER} 0 Y UPLOAD $FND_TOP/patch/115/import/aflvmlu.lct ${file}  >> ${restore_log}/Upload_lookups${trgappname^^}.${datetag}  2>&1
	#done

	rm -f L*.log  /home/applmgr/L*.log >/dev/null 2>&1
	rm -f ${restore_log}/uploadlog/L*log
	}

	upload_user_responsibilities()
	{
	os_user_check applmgr
	source_profile ${trgappname^^}

	cd ${restore_log}
	if [ ! -d ${restore_log}/uploadlog ] ; then
		mkdir -p ${restore_log}/uploadlog
	fi

	cd ${restore_log}/uploadlog
	export APPSUSER=`/dba/bin/getpass ${trgappname^^} apps`

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Upload User Resp: Uploading USER Responsibilities. " | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Upload User Resp:    Logfile: ${restore_log}/Upload_lookups${trgappname^^}.${datetag}  " | tee -a ${logf}
	sh ${uploaddir}/fnd_users/app_upload_fnd_user.sh  > ${restore_log}/upload_user_resp${trgappname^^}.${datetag} >2&1

	#for file in ${uploaddir}/fnd_users/*.ldt
	#do
  	#	FNDLOAD ${APPSUSER} 0 Y UPLOAD $FND_TOP/patch/115/import/afscursp.lct ${file}  >> ${restore_log}/upload_user_resp${trgappname^^}.${datetag} >2&1
	#done
	rm -f L*log /home/applmgr/L*.log  >/dev/null 2>&1
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Upload User Resp: Uploading USER Responsibilities - Completed. " | tee -a ${logf}
	rm -f ${restore_log}/uploadlog/L*log
	#rm -f *.${datetag}
	#rm -f ${LOG_DIR}/L*.${datetag}

	}

	load_exchange_rate()
	{
	os_user_check applmgr
	source_profile ${trgappname^^}

	#gives workappspass
	validate_working_apps_password

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Load Exchange rates: Loading exchange rates. " | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Load Exchange rates:    Logfile: ${restore_log}/load_exchangeRates.${datetag} " | tee -a ${logf}

	${ORACLE_HOME}/bin/sqlplus   -s apps/${workappspass} @${common_sql}/loadExRates.sql  > ${restore_log}/load_exchangeRates.${datetag} 2>&1
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Load Exchange rates: Loading exchange rates - Completed. " | tee -a ${logf}

	}

	change_other_application_password()
	{
	os_user_check applmgr
	source_profile ${trgappname^^}

	#gives workappspass
	validate_working_apps_password

	cd ${restore_log}
	mkdir uploadlog > /dev/null 2>&1
	cd ${restore_log}/uploadlog
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP other password change: Changing SYSADMIN,ALLORACLE, XXEXPD Passwords." | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP other password change:     Logfile: ${restore_log}/changeOtherPasswords.${datetag}" | tee -a ${logf}
	$FND_TOP/bin/FNDCPASS apps/${workappspass} 0 Y system/PmK5Bru# USER   SYSADMIN  ${SYSADPASS}  > ${restore_log}/changeOtherPasswords.${datetag} 2>&1
	$FND_TOP/bin/FNDCPASS apps/${workappspass} 0 Y system/PmK5Bru# ALLORACLE ${OALLPASS}    >> ${restore_log}/changeOtherPasswords.${datetag}  2>&1
	$FND_TOP/bin/FNDCPASS apps/${workappspass} 0 Y system/PmK5Bru# ORACLE  XXEXPD ${EXPDPASS}    >> ${restore_log}/changeOtherPasswords.${datetag} 2>&1
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP other password change: SYSADMIN,ALLORACLE, XXEXPD Password change -- Completed." | tee -a ${logf}

	}

	change_runfs_password()
	{

	os_user_check applmgr
	source_profile ${trgappname^^}

	#Load target passwords
	load_getpass_password

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: Checking if APPS Password is already changed. " | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: Testing Connectivity with TARGET APPS password  " | tee -a ${logf}

	chk_apps_password ${APPSPASS} ${trgappname^^}
	_chkTpassRC=$?
	sleep 2
	if [ ${_chkTpassRC} -eq 0 ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: Database connection established with TARGET APPS password. " | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:   " | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:                    ====> APPS Password Change is not needed.<<====  " | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:   " | tee -a ${logf}

	   workappspass=${APPSPASS}
	   sleep 2
	elif [ ${_chkTpassRC} -ne 0 ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: Database connection could not be established with TARGET APPS password. " | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: Testing connectivity with Source APPS password. " | tee -a ${logf}
		chk_apps_password  ${SRCAPPSPASS} ${trgappname^^}
		_chkSrcpassRC=$?
		sleep 2
		if [ ${_chkSrcpassRC} -eq 0 ] && [ "${workappspass}" != "${APPSPASS}" ];
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: Database connection established with SOURCE APPS password. " | tee -a ${logf}
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: Changing APPS password for Runfs. " | tee -a ${logf}
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:    Logfile: ${restore_log}/resetAPPSpassword_${trgappname^^}.${datetag} " | tee -a ${logf}
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:   ====> Changing APPS Password <<==== " | tee -a ${logf}
			workappspass=${SRCAPPSPASS}
			sleep 2
			#FNDCPASS commands
			$FND_TOP/bin/FNDCPASS apps/${workappspass} 0 Y system/PmK5Bru# SYSTEM APPLSYS ${APPSPASS}  > ${restore_log}/resetAPPSpassword_${trgappname^^}.${datetag} 2>&1
			chk_apps_password ${APPSPASS} ${trgappname^^}
			_chkTpassRC=$?
			sleep 2
			if [ ${_chkTpassRC} -ne 0 ];
			then
				echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: ERROR: Database connection could not be established with NEW APPS password. " | tee -a ${logf}
				exit 1
			else
				echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:  " | tee -a ${logf}
				echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:                    ====> APPS Password Changed Successfully by FNDCPASS. <<====  " | tee -a ${logf}
				echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:  " | tee -a ${logf}
				workappspass=${APPSPASS}
			fi

		elif [[ ${_chkSrcpassRC} -ne 0 && ${_chkTpassRC} -ne 0 ]];
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: ERROR: Database connection could not be established with any apps password (SOURCE and TARGET).  " | tee -a ${logf}
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: ERROR: ABORTING Operation, Please make sure atleast one(source or target) password is working." | tee -a ${logf}
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:        Also check if database is available and listener is up." | tee -a ${logf}
			sleep 2
			exit 1
		else
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:  " | tee -a ${logf}
		fi

	fi

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: Starting RUN Fs AdminServer  " | tee -a ${logf}
	if [ "${FILE_EDITION}" = "run" ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: Starting AdminServer with Source WLS Credentials  " | tee -a ${logf}
		{ echo "${workwlspass}" ; echo "${workappspass}" ; } | ${ADMIN_SCRIPTS_HOME}/adadminsrvctl.sh start '-nopromptmsg'  > ${restore_log}/startAdminServer1.${datetag} 2>&1
		exit_code=$?
	elif [ "${FILE_EDITION}" = "patch" ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: You are running Run FS AdminServer startup from PATCH FS. " | tee -a ${logf}
	else
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: File System Edition could not be determined. It should be run or patch. Environment not set. " | tee -a ${logf}
	fi

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: Exit code returned from AdminServer Start ${exit_code}. " | tee -a ${logf}
	if [[ $exit_code -eq 0 || $exit_code -eq 2 ]];
	then
		sleep 2
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:     AdminServer is available now    " | tee -a ${logf}
	elif [[ $exit_code -eq 9 || $exit_code -eq 1 ]];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: Source credentials not working, Starting AdminServer with Target Credentials." | tee -a ${logf}
		#exit_code=1
		#exit 0
		{ echo "${WLSPASS}" ; echo "${workappspass}" ; } | ${ADMIN_SCRIPTS_HOME}/adadminsrvctl.sh start '-nopromptmsg' > ${restore_log}/startAdminServer2.${datetag}  2>&1
		exit_code=$?
		if [[ $exit_code -eq 0 || $exit_code -eq 2 ]];
		then
			sleep 2
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: **** AdminServer is available, Weblogic Password Change is not needed ****" | tee -a ${logf}
			workwlspass=${WLSPASS}
		elif [[ $exit_code -eq 9 || $exit_code -eq 1 ]];
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:     Target Weblogic password is also Invalid. Please validate the passwords." | tee -a ${logf}
		#exit_code=1
		exit 0
		fi
	else
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: ERROR: Weblogic Password validation failed, Both Source and Target weblogic passwords are not working." | tee -a ${logf}
		exit_code=0
		exit 0
	fi

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:  Running Context File Sync  (IGNORE stty errors)." | tee -a ${logf}
	{ echo "${workappspass}" ; echo "${workwlspass}" ; } |perl $AD_TOP/bin/adSyncContext.pl -contextfile=${CONTEXT_FILE}  > ${restore_log}/Context_filesync1.${datetag} 2>&1
	exit_code=$?
	sleep 5

	if [[ $exit_code -eq 0 || $exit_code -eq 1 ]];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:  Context File Sync completed Successfully." | tee -a ${logf}
	elif [[  $exit_code -eq 9 || $exit_code -eq 1 ]]; then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:  ERROR: Invalid credentials passed." | tee -a ${logf}
		exit_code=1
		exit 0
	else
	    echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:  Context File Sync exit status Could not be identified !!" | tee -a ${logf}
		exit_code=0
		exit 0
	fi

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change:  Updating NEW apps Password to WLS Console." | tee -a ${logf}
	{ echo 'updateDSPassword' ; echo "${CONTEXT_FILE}" ; echo "${workwlspass}" ; echo "${workappspass}" ; } |perl $FND_TOP/patch/115/bin/txkManageDBConnectionPool.pl > ${restore_log}/Console_apps_passwordUpdate.${datetag} 2>&1
	exit_code=$?
	sleep 2
	if [ $exit_code -eq 0 ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: New APPS password updated in EbsDataSource Successfully." | tee -a ${logf}
	elif [  $exit_code -eq 1 ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: ERROR: Invalid credentials passed." | tee -a ${logf}
		exit_code=1
		exit 0
	else
	    echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: EbsDataSource Update Status Could not be identified." | tee -a ${logf}
		exit_code=0
		exit 0
	fi

	if [ "${workwlspass}" == "${WLSPASS}" ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP WLS password change: **** Weblogic Password is already changed. ****" | tee -a ${logf}
	elif [   "${workwlspass}" != "${WLSPASS}" ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP WLS password change: Changing Weblogic Password (IGNORE stty errors)." | tee -a ${logf}
		{ echo "Yes" ; echo "${CONTEXT_FILE}" ; echo "${workwlspass}" ; echo "${WLSPASS}" ; echo "${workappspass}" ;} | perl $FND_TOP/patch/115/bin/txkUpdateEBSDomain.pl -action=updateAdminPassword > ${restore_log}/WLS_password_changeRunfs1.${datetag} 2>&1
		exit_code=$?;
		if [ $exit_code -eq 0 ];
		then
			sleep 2
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP WLS password change: **** Weblogic Password is changed successfully. ****" | tee -a ${logf}
			workwlspass=${WLSPASS}
		elif [   $exit_code -ne 0 ];
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP WLS password change: ERROR: Error recieved while changing weblogic password. Please check." | tee -a ${logf}
		else
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP WLS password change: Weblogic Password change status could not be validated, make sure you verify." | tee -a ${logf}
		fi
	else
	   echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP WLS password change: ERROR: Both weblogic passwords are invalid." | tee -a ${logf}
	fi

	# Autoconfig run
	run_autoconfig

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP WLS password change: Stopping AdminServer on Application Node." | tee -a ${logf}
	{ echo "${workwlspass}" ; echo "${workappspass}" ; } | ${ADMIN_SCRIPTS_HOME}/adadminsrvctl.sh stop '-nopromptmsg'  > ${restore_log}/stopAdminServerRunfs4.${datetag} 2>&1
	exit_code=$?
	if [[ $exit_code -eq 0 || $exit_code -eq 2 ]];
	then
	sleep 2
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: AdminServer is down for runfs." | tee -a ${logf}
		workwlspass=${WLSPASS}
	elif [[ $exit_code -eq 9 || $exit_code -eq 1 ]];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP apps password change: ERROR: Target Weblogic password is also Invalid. Please validate the passwords." | tee -a ${logf}
		#exit_code=1
		exit 0
	fi

	# Changing other Application passwords.
	change_other_application_password

	}

	change_patchfs_password()
	{

	os_user_check applmgr
	source_profile ${trgappname^^}

	# Load target passwords
	load_getpass_password

	# PATCH FS DISABLE EBS_LOGON triger
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Executing Patchfs password change steps." | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: PATCH FS DISABLING EBS_LOGON Trigger" | tee -a ${logf}
	ebslogon 'DISABLE'

	# Setting up Patch File system
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Setting up PATCH env." | tee -a ${logf}
	# Source patch environment
	#source_patchfs
	ENVFILE="${apptargetbasepath}/EBSapps.env"
	echo -e  "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP SET PATCHFS: ENV file is ${apptargetbasepath}/EBSapps.env " | tee -a ${logf}
if [ ! -f ${ENVFILE} ]; then
 echo -e  "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP SET PATCHFS: Environment file $ENVFILE is not found. " | tee -a ${logf}
	return 0
else
. ${ENVFILE} patch > /dev/null
echo -e  "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP SET PATCHFS: FILE EDITION is SET To ${FILE_EDITION}. " | tee -a ${logf}
sleep 2
fi

	# Autoconfig run
	run_autoconfig

	# PATCH FS  Delete Access Gate entries
	delete_accessgate

	# PATCH FS  APPS Password check
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Checking APPS Password." | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Testing Connectivity with TARGET APPS password." | tee -a ${logf}

	chk_apps_password ${APPSPASS} ${trgappname^^}
	_chkTpassRC=$?
	sleep 2
	if [ ${_chkTpassRC} -eq 0 ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Database connection established with TARGET APPS password." | tee -a ${logf}
		workappspass=${APPSPASS}
		sleep 2
	elif [ ${_chkTpassRC} -ne 0 ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Database connection could not be established with TARGET APPS password." | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Testing connectivity with Source APPS password." | tee -a ${logf}
		chk_apps_password  ${SRCAPPSPASS} ${trgappname^^}
		_chkSrcpassRC=$?
		sleep 2
		if [ ${_chkSrcpassRC} -eq 0 ] && [ "${workappspass}" != "${APPSPASS}" ];
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Database connection established with SOURCE APPS password." | tee -a ${logf}
			workappspass=${SRCAPPSPASS}
			sleep 2
		elif [[ ${_chkSrcpassRC} -ne 0 && ${_chkTpassRC} -ne 0 ]];
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change:  ERROR: Database connection could not be established with any apps password (SOURCE and TARGET). " | tee -a ${logf}
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change:  ERROR: ABORTING Operation, Please make sure atleast one(source or target) password is working." | tee -a ${logf}
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change:         Also check if database is available and listener is up.  " | tee -a ${logf}
			sleep 2
		else
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change:        " | tee -a ${logf}
		fi
	fi

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: File EDITION is ${FILE_EDITION}     " | tee -a ${logf}
	if [ "${FILE_EDITION}" = "patch" ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Starting AdminServer with Source Credentials." | tee -a ${logf}
		{ echo "${workwlspass}" ; echo "${workappspass}" ; } | ${ADMIN_SCRIPTS_HOME}/adadminsrvctl.sh start 'forcepatchfs'  '-nopromptmsg' > ${restore_log}/startAdminServerPatchfs2.${datetag} 2>&1
		exit_code=$?
	elif [ "${FILE_EDITION}" = "run" ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: You are running Patch FS AdminServer startup from RUN FS." | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patch fs password change steps will be skipped." | tee -a ${logf}
		return 0
	else
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: File System Edition could not be determined. It should be run or patch. Environment not set." | tee -a ${logf}
	fi

	if [[ $exit_code -eq 0 || $exit_code -eq 2 ]];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs AdminServer is available now" | tee -a ${logf}
	elif [[ $exit_code -eq 9 || $exit_code -eq 1 ]];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Source credentials not working, Starting AdminServer with Target Credentials" | tee -a ${logf}
		#exit_code=1
		#exit 0
		{ echo "${WLSPASS}" ; echo "${workappspass}" ; } | ${ADMIN_SCRIPTS_HOME}/adadminsrvctl.sh start 'forcepatchfs'  '-nopromptmsg' > ${restore_log}/startAdminServerPatchfs3.${datetag} 2>&1
		exit_code=$?;
		if [[ $exit_code -eq 0 || $exit_code -eq 2 ]];
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs AdminServer is available, Weblogic Password Change is not needed." | tee -a ${logf}
			workwlspass=${WLSPASS}
		elif [[ $exit_code -eq 9 || $exit_code -eq 1 ]];
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Target Weblogic password is also Invalid. Please validate the passwords." | tee -a ${logf}
			#exit_code=1
		fi
	else
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: ERROR: Weblogic Password validation failed, Both Source and Target weblogic passwords are not working." | tee -a ${logf}

	fi

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Running Context File Sync  (IGNORE stty errors)." | tee -a ${logf}
	{ echo "${workappspass}" ; echo "${workwlspass}" ; } |perl $AD_TOP/bin/adSyncContext.pl -contextfile=${CONTEXT_FILE}  > ${restore_log}/Context_sync_patchfs1.${datetag} 2>&1
	exit_code=$?;
	sleep 2

	if [[ $exit_code -eq 0 || $exit_code -eq 1 ]];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs Context File Sync completed Successfully. " | tee -a ${logf}
	elif [[  $exit_code -eq 9 || $exit_code -eq 1 ]];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Invalid credentials passed. " | tee -a ${logf}
		exit_code=1
		#exit 0
	else
	   echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs Context File Sync Status Could not be identified. " | tee -a ${logf}
		exit_code=0
		#exit 0
	fi

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs - Updating NEW apps Password to WLS Console " | tee -a ${logf}
	#{ echo 'updateDSPassword' ;  echo "${CONTEXT_FILE}" ; echo "${workwlspass}" ; echo "${workappspass}"} |perl $FND_TOP/patch/115/bin/txkManageDBConnectionPool.pl
	{ echo 'updateDSPassword' ; echo "$CONTEXT_FILE" ; echo "${workwlspass}" ; echo "${workappspass}" ; } |perl $FND_TOP/patch/115/bin/txkManageDBConnectionPool.pl > ${restore_log}/Console_UpdateAppsPassPatchfs1.${datetag} 2>&1

	exit_code=$?
	sleep 2
	if [ $exit_code -eq 0 ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs - New APPS password updated in EbsDataSource Successfully. " | tee -a ${logf}
	elif [   $exit_code -eq 1 ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs - Invalid credentials passed. " | tee -a ${logf}
		exit_code=1
		#exit 0
	else
	    echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs - EbsDataSource Update Status Could not be identified. " | tee -a ${logf}
		exit_code=0
		#exit 0
	fi

	if [ "${workwlspass}" == "${WLSPASS}" ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs - Weblogic Password is already changed. " | tee -a ${logf}
	elif [   "${workwlspass}" != "${WLSPASS}" ];
	then
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs - Chaning Weblogic Password (IGNORE stty errors). " | tee -a ${logf}
		{ echo "Yes" ; echo "${CONTEXT_FILE}" ; echo "${workwlspass}" ; echo "${WLSPASS}" ; echo "${workappspass}" ;} | perl $FND_TOP/patch/115/bin/txkUpdateEBSDomain.pl -action=updateAdminPassword > ${restore_log}/WLS_PasswordChangePatchfs1.${datetag} 2>&1
		exit_code=$?
		if [ $exit_code -eq 0 ];
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs - Weblogic Password is changed successfully. " | tee -a ${logf}
			workwlspass=${WLSPASS}
		elif [   $exit_code -ne 0 ];
		then
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: ERROR: Error recieved while changing weblogic password. Please check. " | tee -a ${logf}
		else
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs - Weblogic Password change status could not be validated, make sure you verify. " | tee -a ${logf}
		fi
	else
	   echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs - ERROR: Both weblogic passwords are invalid. " | tee -a ${logf}
	fi

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs - Running Autoconfig on Application Node. " | tee -a ${logf}
	sh ${ADMIN_SCRIPTS_HOME}/adautocfg.sh  appspass=${workappspass} > ${restore_log}/run_autoconffigPatchfs1.${datetag} 2>&1

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs - Stopping AdminServer on Application Node. " | tee -a ${logf}
	{ echo "${workwlspass}" ; echo "${workappspass}" ; } | ${ADMIN_SCRIPTS_HOME}/adadminsrvctl.sh stop 'forcepatchfs'  '-nopromptmsg' > ${restore_log}/StopAdminServerPatchfs4.${datetag} 2>&1
	sleep 4

	## PATCH FS ENABLE EBS_LOGON triger
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs - ENABLING EBS_LOGON Trigger. " | tee -a ${logf}
	ebslogon 'ENABLE'

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP Patchfs password change: Patchfs -   Sourceing RUN FS. " | tee -a ${logf}
	source_profile ${trgappname^^}

	}


	post_clone_validation()
	{
	os_user_check applmgr
	source_profile ${trgappname^^}

	#gives workappspass
	validate_working_apps_password

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP VALIDATION: Generating Validation report. " | tee -a ${logf}

sqlplus -s apps/${workappspass}@${trgappname^^} << EOF
set termout off
set feedback off
set verify off
set pagesize 1000
SET MARKUP HTML ON SPOOL ON
spool ${restore_log}/${trgappname^^}_sql_validation.html
@${common_sql}/main_sql_validate.sql
spool off
SET MARKUP HTML OFF
exit
EOF

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP VALIDATION: SQL base validations on Database Completed. " | tee -a ${logf}
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP VALIDATION: Sending Database validation report mailer. " | tee -a ${logf}
	mutt -e 'set content_type="text/html"' dikumar@expediagroup.com,omomin@expediagroup.com,kkatta@expediagroup.com -s "backupmgr: ${trgappname^^} Database Validation " <  ${restore_log}/${trgappname^^}_sql_validation.html

	}

	config_single_node()
	{

	# Cleanup and restore Application backup
	cleanup_and_restore_apps

	# Validate and run adcfgclone
	run_adcfgclone

ENVFILE="/home/`whoami`/.${trgappname,,}_profile"
if [ ! -f ${ENVFILE} ];
then
   printf "Environment file $ENVFILE is not found.\n"
   exit 1;
else
   . ${ENVFILE} > /dev/null
	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP POST CLONE: Run base is set to : $RUN_BASE "
   sleep 2
fi



	# Validate context file and run autoconfig
	postadcfgclone

	#Chaning all passwords on Runfs
	change_runfs_password

	#Chaning all passwords on Patchfs
	change_patchfs_password

	echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP POST CLONE: Running Post clone Application configuration steps." | tee -a ${logf}
	#Delete Access Gate entries
	delete_accessgate

	#Remove SSO references
	remove_sso_reference

	#Disable SSL
	#disable_ssl

	#Cleanup inbound and outbound directories
	clean_inbound_outbound_dir

	#Create softlinks in XXEXPD_TOP
	xxexpd_top_softlink

	# Generate Custom env files for run and patch fs
	gen_custom_env

	# Compile JSP files
	compile_jsp

	# Upload FND Lookups
	upload_lookup

	# Reset Application Users Passwords
	user_password_reset

	# Upload User responsibilities
	upload_user_responsibilities

	#Load exchange rates
	load_exchange_rate

	#Run application node etcc
	run_app_etcc

	#Compile invalid objects
	compileinvalids

	# Run adautoconfig
	run_autoconfig

	# Running post clone validations
	post_clone_validation

	# Run adop fs_clone
	#run_adop_fsclone

	}


#******************************************************************************************************
#
#  **********  A P P L I C A T I O N - F U N C T I O N - L I B R A R Y - S C R I P T - **********
#
#******************************************************************************************************
