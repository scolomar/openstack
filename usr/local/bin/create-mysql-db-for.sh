#!/bin/bash -e

set -x
if [ ! $1 ]
then
    echo -e "Usage: $0 <database-name> [management-nic=eth0]\nScript requires at least one parameter.\n"
    exit 1
fi
management_nic='eth0'
if [ $2 ]; then
    management_nic=$2
fi

# List of valid database names
declare -a service=( "keystone"
                     "glance"
                     "neutron"
                     "cinder"
                     "nova"
                     "heat"
                   )

# Check if input exists in service array
if [[ ! " ${service[@]} " =~ " $1 " ]]; then
    echo "<database-name> '$1' is not valid. Choose from: ${service[@]}"
    exit 1
fi

name=$1
conf_file=/tmp/$$-${name}.sql
management_ip=`ip -4 -o a show dev $management_nic | awk '{print $4}' | awk -F'/' '{print $1}'`

cat > ${conf_file} <<TEXT
drop database if exists $name;
drop user if exists '${name}User'@'%';
drop user if exists '${name}User'@'localhost';
create database $name;
create user '${name}User'@'%' identified by '${name}Pass';
create user '${name}User'@'localhost' identified by '${name}Pass';
grant all on ${name}.* to '${name}User'@'%' identified by '${name}Pass';
grant all on ${name}.* to '${name}User'@'localhost' identified by '${name}Pass';
flush privileges;
TEXT

if [ $name = "nova" ]; then
    echo "drop database if exists nova_api;" >> ${conf_file}
    echo "drop database if exists nova_cell0;" >> ${conf_file}
    echo "create database nova_api;" >> ${conf_file}
    echo "create database nova_cell0;" >> ${conf_file}
    echo "create database placement;" >> ${conf_file}
    echo "grant all on nova_api.* to 'novaUser'@'%' identified by 'novaPass';" >> ${conf_file}
    echo "grant all on nova_api.* to 'novaUser'@'localhost' identified by 'novaPass';" >> ${conf_file}
    echo "grant all on nova_cell0.* to 'novaUser'@'%' identified by 'novaPass';" >> ${conf_file}
    echo "grant all on nova_cell0.* to 'novaUser'@'localhost' identified by 'novaPass';" >> ${conf_file}
    echo "grant all on placement.* to 'novaUser'@'%' identified by 'novaPass';" >> ${conf_file}
    echo "grant all on placement.* to 'novaUser'@'localhost' identified by 'novaPass';" >> ${conf_file}
    
    echo "flush privileges;" >> ${conf_file}
fi

cat ${conf_file}
set -x
sudo mysql -u root -pstack < $conf_file
sudo mysql -h $management_ip -u ${name}User -p${name}Pass -e "show databases" ${name}
#sudo mysql -h localhost -u ${name}User -p${name}Pass -e "show databases" ${name}
rm ${conf_file}
