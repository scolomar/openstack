```
sudo snap install microstack --beta --devmode

sudo microstack init --auto --control

sudo snap get microstack config.credentials.keystone-password

microstack.openstack service list

sudo microstack launch cirros --name test

sudo sysctl net.ipv4.ip_forward=1
```
