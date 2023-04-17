#!/bin/bash
#******************************************************************************************************
# $Header 1.0 2022/08/15 dikumar fundbrestore.sh
#  Purpose  : Function library for remote database restore.
#
#  SYNTAX   :
#
#  Author   : Dinesh Kumar
#******************************************************************************************************#
#******************************************************************************************************##
#  **********  C A L L - R E M O T E - D A T A B A S E - R E S T O R E - T A S K - F U N - S C R I P T **********
#******************************************************************************************************##

sumbit_dbrestore()
{
HOST_NAME=$(uname -n | cut -f1 -d".")
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "

if [ -z "${dbosuser}" ] || [ -z "${trgdbhost}" ] || [ -z "${labdomain}" ] || [ -z "${trginstname}" ] ; then
    ${ECHO} "All the required values are not set. Make sure property file is sourced. Exiting !!"
    exit 1
fi

# Call the database restore script over ssh with source apps password as input.
ssh -q "${dbosuser}"@"${trgdbhost}"."${labdomain}" " nohup sh ${exe_home}/clonedbrestore.sh  ${workappspass}  > ${restore_log}/maindbrestore${trginstname}.${startdate} 2>&1 & "
if [ $? != 0 ]; then
    ${ECHO} "DB RESTORE: ERROR received while submitting database restore job via ssh. Please check. Exiting !!"
    cat "${restore_log}"/maindbrestore."${startdate}"
    exit 1
else    
    ${ECHO} "DB RESTORE: Restore job submitted successfully in nohup at ${trgdbhost}.${labdomain} "
    return 0
fi 

}
#******************************************************************************************************##
#  **********  C A L L - R E M O T E - D A T A B A S E - R E S T O R E - T A S K - F U N - S C R I P T - E N D **********
#******************************************************************************************************##
