#!/bin/sh -x
set -e

extIP=$( ip r | awk '/eth1 proto/{ print $9 }' )
extIPnet=$( echo $extIP | cut -d. -f1,2,3 )
mgmtIP=$( ip r | awk '/eth0 proto/{ print $9 }' )
publicIP=$( curl http://169.254.169.254/latest/meta-data/public-ipv4 )

sudo apt-get install -y chrony mysql-server python-pymysql rabbitmq-server python-openstackclient
sudo mysql_secure_installation
sudo rabbitmqctl change_password guest password
sudo rabbitmq-plugins enable rabbitmq_management --offline
echo [{rabbit, [{loopback_users, []}]}]. | sudo tee /etc/rabbitmq/rabbitmq.config
sudo service rabbitmq-server restart
create-mysql-db-for.sh keystone
sudo apt-get install -y keystone apache2 libapache2-mod-wsgi
echo manual | sudo tee /etc/init/keystone.override
sudo service apache2 restart
sudo keystone-manage db_sync
sudo keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sudo keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
export OS_TOKEN=ADMIN OS_URL=http://localhost:5000/v3 OS_IDENTITY_API_VERSION=3
openstack domain create --description 'Default OpenStack domain' default
openstack project create --domain default --description "Admin project" admin
openstack user create --domain default --password admin admin
openstack role create admin
openstack role add --project admin --user admin admin
openstack project create --domain default --description "Service project" service
openstack project create --domain default --description "Demo project" demo
openstack user create --domain default --password demo demo
openstack role create member
openstack role add --project demo --user demo member
openstack role add --project demo --user admin admin
openstack service create --name keystone --description "OpenStack Identity" identity
openstack endpoint create --region RegionOne identity public http://localhost:5000/v3
openstack endpoint create --region RegionOne identity internal http://localhost:5000/v3
openstack endpoint create --region RegionOne identity admin http://localhost:5000/v3
unset OS_IDENTITY_API_VERSION OS_TOKEN OS_URL
. ./adminrc.sh
create-mysql-db-for.sh glance
openstack user create --domain default --password glance glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image service" image
openstack endpoint create --region RegionOne image public http://localhost:9292
openstack endpoint create --region RegionOne image internal http://localhost:9292
openstack endpoint create --region RegionOne image admin http://localhost:9292
sudo apt-get install -y glance
sudo service glance-api restart
sudo service glance-registry restart
sudo glance-manage db_sync
wget http://download.cirros-cloud.net/0.5.1/cirros-0.5.1-x86_64-disk.img
openstack image create --disk-format qcow2 --file cirros-0.5.1-x86_64-disk.img --container-format bare --public cirros-0.5.1
openstack image set --property architecture=x86_64 --property hypervisor_type=qemu cirros-0.5.1
create-mysql-db-for.sh neutron
openstack user create --domain default --password neutron neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://localhost:9696
openstack endpoint create --region RegionOne network internal http://localhost:9696
openstack endpoint create --region RegionOne network admin http://localhost:9696
sudo sed -i s/extIP/$extIP/ /etc/neutron/metada_agent.ini
sudo sed -i s/extIP/$extIP/ /etc/network/interfaces.d/br-ex.cfg
sudo apt-get install -y neutron-server
sudo neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head
sudo service neutron-server restart
sudo apt-get install -y openvswitch-switch
sudo ovs-vsctl add-br br-int
sudo ovs-vsctl add-br br-eth2
sudo ovs-vsctl add-port br-eth2 eth2
sudo apt-get install -y neutron-openvswitch-agent
sudo service neutron-openvswitch-agent restart
sudo ovs-vsctl add-br br-ex
sudo ovs-vsctl add-port br-ex eth1
sudo ip addr del extIP/24 dev eth1
sudo ip addr add extIP/24 dev br-ex
sudo ip link set dev br-ex up
sudo sed --in-place /ifconfig.eth1.*24/s/^/#/ /etc/network/if-up.d/dummy
sudo apt-get install -y neutron-l3-agent
sudo service neutron-l3-agent restart
sudo service openvswitch-switch restart
sudo service neutron-server restart
sudo service neutron-openvswitch-agent restart
sudo service neutron-l3-agent restart
sudo apt-get install -y neutron-dhcp-agent
sudo service neutron-dhcp-agent restart
sudo service neutron-metadata-agent restart
openstack network create --external --provider-network-type flat --provider-physical-network external public
openstack subnet create public-subnet --no-dhcp --gateway extIP --subnet-range $extIPnet.0/24 --allocation-pool start=$extIPnet.100,end=$extIPnet.109 --network public
openstack floating ip create public
openstack network create private
openstack subnet create net1 --subnet-range 10.0.0.0/24 --network private
openstack router create router1
openstack router set --external-gateway public router1
openstack router add subnet router1 net1
create-mysql-db-for.sh nova
openstack user create --domain default --password nova nova
openstack role add --project service --user nova admin
openstack user create --domain default --password nova placement
openstack role add --project service --user placement admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://localhost:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://localhost:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://localhost:8774/v2.1
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public http://localhost:8778
openstack endpoint create --region RegionOne placement internal http://localhost:8778
openstack endpoint create --region RegionOne placement admin http://localhost:8778
sudo sed -i s/mgmtIP/$mgmtIP/ /etc/nova/nova.conf
sudo sed -i s/publicIP/$publicIP/ /etc/nova/nova.conf
sudo apt-get install -y nova-api
sudo service nova-api restart
sudo apt-get install -y nova-placement-api
sudo nova-manage api_db sync
sudo nova-manage cell_v2 map_cell0
sudo nova-manage cell_v2 create_cell --name=cell1 --verbose
sudo nova-manage db sync
sudo apt-get install -y nova-scheduler nova-conductor
sudo apt-get install -y nova-consoleauth nova-novncproxy nova-xvpvncproxy
sudo service nova-consoleauth restart
sudo service nova-xvpvncproxy restart
sudo service nova-novncproxy restart
sudo apt-get install -y nova-compute python-guestfs
sudo dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-4.15.0-48-generic
sudo chmod +x /etc/kernel/postinst.d/statoverride
sudo service nova-compute restart
sudo nova-manage cell_v2 discover_hosts --verbose
sudo service neutron-server restart
sudo service neutron-metadata-agent restart
sudo service nova-consoleauth restart
sudo service nova-xvpvncproxy restart
sudo service nova-novncproxy restart
sudo service nova-compute restart
sudo service nova-api restart
sudo service apache2 restart
openstack flavor create --vcpus 1 --disk 1 --ram 512 m1.tiny
sudo rm -f /var/lib/nova/nova.sqlite
sudo virsh net-destroy default
sudo virsh net-undefine default
create-mysql-db-for.sh cinder
openstack user create --domain default --password cinder cinder
openstack role add --project service --user cinder admin
openstack service create --name cinderv2 --description "Block Storage" volumev2
openstack service create --name cinderv3 --description "Block Storage" volumev3
openstack endpoint create --region RegionOne volumev2 public http://localhost:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 internal http://localhost:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 admin http://localhost:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 public http://localhost:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 internal http://localhost:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 admin http://localhost:8776/v3/%\(project_id\)s
sudo apt-get install -y cinder-api
sudo cinder-manage db sync
sudo apt-get install -y cinder-scheduler
sudo apt-get install -y lvm2 thin-provisioning-tools
sudo pvcreate /dev/xvda3
sudo vgcreate cinder-volumes /dev/xvda3
sudo apt-get install -y cinder-volume
sudo service cinder-volume restart
sudo service cinder-scheduler restart
sudo service apache2 restart
sudo service tgt restart
sudo apt-get install -y memcached python-memcache
sudo apt-get install -y openstack-dashboard
sudo apt-get remove --purge -y openstack-dashboard-ubuntu-theme
sudo service apache2 restart
sudo service memcached restart
create-mysql-db-for.sh heat
openstack user create --domain default --password heat heat
openstack role add --project service --user heat admin
openstack service create --name heat --description "Orchestration" orchestration
openstack service create --name heat-cfn --description "Orchestration" cloudformation
openstack endpoint create --region RegionOne orchestration public http://localhost:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne orchestration internal http://localhost:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne orchestration admin http://localhost:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne cloudformation public http://localhost:8000/v1
openstack endpoint create --region RegionOne cloudformation internal http://localhost:8000/v1
openstack endpoint create --region RegionOne cloudformation admin http://localhost:8000/v1
openstack domain create --description "Stack projects and users" heat
openstack user create --domain heat --password heat heat_domain_admin
openstack role add --domain heat --user-domain heat --user heat_domain_admin admin
openstack role create heat_stack_owner
openstack role add --project admin --user admin heat_stack_owner
openstack role create heat_stack_user
sudo apt-get install -y heat-api heat-api-cfn
sudo apt-get install -y heat-engine
sudo heat-manage db_sync
sudo service heat-api restart
sudo service heat-api-cfn restart
sudo service heat-engine restart
sudo apt-get install -y python-heat-dashboard
sudo service apache2 restart
sudo service memcached restart
