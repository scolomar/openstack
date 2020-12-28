```
echo deb http://ubuntu-cloud.archive.canonical.com/ubuntu bionic-updates/rocky main | sudo tee /etc/apt/sources.list.d/cloudarchive-rocky.list
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5EDB1B62EC4926EA
sudo apt-get update
```
```
git clone git@github.com:secobau/openstack.git --single-branch -b ec2
```
```
sudo cp -rv openstack/* /
sudo chmod +x /usr/local/bin/*
```
```
openstack-install.sh
```
