```
git clone git@github.com:secobau/openstack.git
```
```
sed -i s/mgmtIP/$( ip r | awk '/dev eth0 proto/{ print $9 }' )/ openstack/etc/nova/nova.conf
sed -i s/publicIP/$( curl http://169.254.169.254/latest/meta-data/public-ipv4 )/ openstack/etc/nova/nova.conf
sudo cp -rv openstack/* /
sudo chmod +x /usr/local/bin/*
```
```
openstack-install.sh
```
