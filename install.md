```
sudo apt-get install -y chrony mysql-server python-pymysql rabbitmq-server python-openstackclient
sudo mysql_secure_installation
sudo rabbitmqctl change_password guest password
sudo rabbitmq-plugins enable rabbitmq_management --offline
echo [{rabbit, [{loopback_users, []}]}]. | sudo tee /etc/rabbitmq/rabbitmq.config
sudo service rabbitmq-server restart
curl localhost:15672 -I
/usr/local/bin/create-mysql-db-for.sh keystone
sudo apt-get install -y keystone apache2 libapache2-mod-wsgi
echo manual | sudo tee /etc/init/keystone.override
sudo service apache2 restart
sudo keystone-manage db_sync
sudo keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sudo keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
sudo apt-get install -y python-openstackclient
export OS_TOKEN=ADMIN OS_URL=http://hostname:5000/v3 OS_IDENTITY_API_VERSION=3
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
openstack endpoint create --region RegionOne identity public http://hostname:5000/v3
openstack endpoint create --region RegionOne identity internal http://hostname:5000/v3
openstack endpoint create --region RegionOne identity admin http://hostname:5000/v3
unset OS_IDENTITY_API_VERSION OS_TOKEN OS_URL
/usr/local/bin/create-mysql-db-for.sh glance
openstack user create --domain default --password glance glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image service" image
openstack endpoint create --region RegionOne image public http://hostname:9292
openstack endpoint create --region RegionOne image internal http://hostname:9292
openstack endpoint create --region RegionOne image admin http://hostname:9292
sudo apt-get install -y glance
sudo service glance-api restart
sudo service glance-registry restart
sudo glance-manage db_sync
wget http://download.cirros-cloud.net/0.5.1/cirros-0.5.1-x86_64-disk.img
openstack image create --disk-format qcow2 --file cirros-0.5.1-x86_64-disk.img --container-format bare --public cirros-0.5.1
openstack image set --property architecture=x86_64 --property hypervisor_type=qemu cirros-0.5.1
/usr/local/bin/create-mysql-db-for.sh neutron
openstack user create --domain default --password neutron neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://hostname:9696
openstack endpoint create --region RegionOne network internal http://hostname:9696
openstack endpoint create --region RegionOne network admin http://hostname:9696
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
sudo ip addr del x.x.x.x/24 dev eth1
sudo ip addr add x.x.x.x/24 dev br-ex
sudo ip link set dev br-ex up
sudo sed --in-place /ifconfig.eth1.*24/s/^/#/ /etc/network/if-up.d/dummy


```
