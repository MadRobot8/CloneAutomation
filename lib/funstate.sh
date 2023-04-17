#!/bin/bash


#The whole clone process is divided in STAGE
# Database restore stage=DBRESTORE
# Application restore stage=APPRESTORE
# Post Application restore stage=POSTAPPRESTORE
# Clone Validation stage=VALIDATE
#


loaddbrestorestage()
{

statereport=${restore_statedir}/statereport
stagefile=${restore_statedir}/clonestage
clonestage=$(<"${stagefile}")
echo -e "Current Clone Stage = Database restore" > ${statereport}
statefile=${restore_statedir}/dbstate
dbstate=$(<"${statefile}")
statefile=${restore_statedir}/dbfilecount.run
vfilecount=$(<"${statefile}")
statefile=${restore_statedir}/restorestate
restorestate=$(<"${statefile}")


if [ -z ${dbstate} ]; then
    echo -e "Current Database State = UNKNOWN " >> ${statereport}
elif [ "${dbstate}" == "NOMOUNT_RESTORE" ]; then
    echo -e "Current Database State = NO MOUNT (Ready for restore)" >> ${statereport}
elif [ "${dbstate}" == "MOUNT_RESTORE" ]; then
    echo -e "Current Database State = MOUNT (Restore is running)"  >> ${statereport}
    echo -e "Datafile restore count = ${vfilecount}"  >> ${statereport}  
elif [ "${dbstate}" == "MOUNT_RECOVER" ]; then
    echo -e "Current Database State = MOUNT (Database recovery is running..)" >> ${statereport}
elif [ "${dbstate}" == "OPEN_RECOVER" ]; then
    echo -e "Current Database State = OPEN (Database opened after recovery.)" >> ${statereport}

fi 

if [ -z ${restorestate} ]; then
    echo -e "Current Restore Database session status = UNKNOWN " >> ${statereport}
else 
    echo -e "Current Restore Database session status = ${restorestate} " >> ${statereport}
fi


}



getstate()
{

HOST_NAME=$(uname -n | cut -f1 -d".")
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "

if [ -z ${restore_statedir} ]; then
    ${ECHO} "State directory is not set. State cannot be determined."
    return 0
fi

if [ "${clonestage}" == "DBRESTORE" ]; then
    #load current state in this stage
    loaddbrestorestage
elif [ "${clonestage}" == "APPRESTORE" ]; then
    #load current state in this stage
    loadapprestorestage
elif [ "${clonestage}" == "POSTAPPRESTORE" ]; then
    #load current state in this stage
    loadpostclonestage
fi

}