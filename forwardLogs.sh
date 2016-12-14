#! /bin/bash

HERE=`dirname $0`
CMD=`basename $0`

: ${stdout_log_file:="${HERE}/${CMD}.stdout.log"}
: ${stderr_log_file:="${HERE}/${CMD}.stderr.log"}


: ${redirect_output:=true}

if ${redirect_output}
then
    exec 1>"${stdout_log_file}" 2>"${stderr_log_file}"
fi

getMyDnsName () {

    my_dns_name=""

    my_ip_address=`curl --max-time 10 --silent ipinfo.io/ip`
    if [ -n "${my_ip_address}" ]
    then
	resolv_request_result=`host "${my_ip_address}"`
	my_dns_name=`
           set -- ${resolv_request_result}
           echo "$5"
        `
    fi

    if [ -n "${my_dns_name}" ]
    then
	echo "${my_dns_name}"
	return 1
    else
	echo "${my_ip_address}"
	return 0
    
    fi
}

date

: ${src_folder_to_copy:=/var/log/squid3}

chmod go-rwx ~/R4BigData_DIP_SquidLogsForwarder/ssh-key-*

my_name=`getMyDnsName`

remote_destination_dir="~/CollectorIn/${my_name}"

src_file_list=`echo ${src_folder_to_copy}/* 2>/dev/null`

if [ -z "${src_file_list}" ]
then
   exit 1
fi

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -F ~/R4BigData_DIP_SquidLogsForwarder/ssh-config log-collector-lan "mkdir -p ${remote_destination_dir}"

rsync -I --delete -a -vv -e "ssh -vv -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null log-collector-lan:${remote_destination_dir}/" ${src_folder_to_copy}

#!!! scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -F ~/R4BigData_DIP_SquidLogsForwarder/ssh-config "${src_folder_to_copy}"/* "log-collector-lan:${remote_destination_dir}"




