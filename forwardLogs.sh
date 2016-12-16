#! /bin/bash

HERE=`dirname $0`
CMD=`basename $0`

: ${stdout_log_file:="${HERE}/${CMD}.stdout.log"}
: ${stderr_log_file:="${HERE}/${CMD}.stderr.log"}


: ${redirect_output:=true}

if [ -z "${remote_host_spec}" ]
then
	echo "ERROR: usage
	$CMD <valid ssh host specification>" 1>&2
	exit 1
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

# check if I am on a foreign net or not
collector_accespoint_dns_name='LPuteaux-657-1-23-37.w193-251.abo.wanadoo.fr.'

my_name=`getMyDnsName`

if [ "${my_name}" = "${collector_accespoint_dns_name}" ]
then
    ssh_remote_host_spec="log-collector-lan"
else
    ssh_remote_host_spec="log-collector-wan"
fi
    


: ${ssh_command:=ssh -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -F ${HOME}/R4BigData_DIP_SquidLogsForwarder/ssh-config}
: ${src_folder_to_copy:=/var/log/squid3}

chmod go-rwx ~/R4BigData_DIP_SquidLogsForwarder/ssh-key-*

remote_destination_dir="~/CollectorIn/${my_name}"

src_file_list=`echo ${src_folder_to_copy}/* 2>/dev/null`

if [ -z "${src_file_list}" ]
then
   exit 1
fi

${ssh_command} ${ssh_remote_host_spec} "mkdir -p ${remote_destination_dir}"

rsync -I --delete -a -v -e "${ssh_command}" ${src_folder_to_copy} ${ssh_remote_host_spec}:${remote_destination_dir}
