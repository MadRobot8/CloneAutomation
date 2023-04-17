#!/bin/bash
mailstatus()
{
HOST_NAME=$(uname -n | cut -f1 -d".")
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "


if [ ! -f ${restore_statedir}/statereport ]; then
    ${ECHO} "MAILER : ERROR: Status file could not be found. Status email cannot be sent."
    return 0
fi

#echo "To: dikumar@expediagroup.com
#MIME-Version: 1.0
#Content-Type: multipart/mixed;
#Subject:CLONE STATUS: ${dbupper} In progress
#Content-Type: text/html" > ${restart_dir}/statusmailheader

#cat ${restart_dir}/statusmailheader ${restore_statedir}/statereport |/usr/sbin/sendmail -t
cat "${restart_dir}"/statusmailheader  > "${restore_log}"/mailer.html
cat "${restore_statedir}"/statereport   >> "${restore_log}"/mailer.html
mutt -e 'set content_type="text/html"' dikumar@expediagroup.com -s "Clone Status: ${trgappname^^} Database Validation " <  "${restore_log}"/mailer.html

}

