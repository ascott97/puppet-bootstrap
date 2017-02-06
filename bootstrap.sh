#!/bin/bash

puppet_ver='2016.5.1'
puppet_install="puppet-enterprise-${puppet_ver}-el-7-x86_64"
repo_url="github.com\/ascott97\/control_repo.git" #escape / so sed likes it

curl -O https://s3.amazonaws.com/pe-builds/released/${puppet_ver}/${puppet_install}.tar.gz

tar -zxvf ${puppet_install}.tar.gz

sed -i "s/git_repo/$repo_url/" bootstrap-pe.conf

#firewall-cmd --zone=public --add-port=3000/tcp --permanent
#firewall-cmd --zone=public --add-port=443/tcp --permanent
#firewall-cmd --zone=public --add-port=4433/tcp --permanent
#firewall-cmd --zone=public --add-port=8140/tcp --permanent
#firewall-cmd --zone=public --add-port=61613/tcp --permanent
#firewall-cmd --reload

$(pwd)/${puppet_install}/puppet-enterprise-installer -c $(pwd)/bootstrap-pe.conf

#Configure ssh keys
if [ ! -d /etc/puppetlabs/puppetserver/ssh/ ]; then
	mkdir -p /etc/puppetlabs/puppetserver/ssh/
fi

#cp id-control_repo.rsa /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa
#chown pe-puppet.pe-puppet /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa

#Add a license
#cp license.key /etc/puppetlabs/license.key
#chown pe-puppet.pe-puppet /etc/puppetlabs/license.key

#Copy config in place
#cp autosign.conf /etc/puppetlabs/puppet/autosign.conf

/opt/puppetlabs/bin/puppet agent -tv


#Configure Code-Manager User

password=$(</dev/urandom tr -dc a-z-A-Z-0-9 | head -c 8 ;echo;)

#Generate api token to use in calls
export TOKEN=$(curl -k -X POST -H 'Content-Type: application/json' -d '{"login": "admin", "password": "root"}' https://localhost:4433/rbac-api/v1/auth/token | awk -F \" '{print $4}')

#Create a user
curl -k -i -H "X-Authentication:$TOKEN" -H "Content-Type: application/json" -X POST -d '{"login":"deployment-user","email":"placeholder@email.com","display_name":"deploy","role_ids": [4],"password": "$password"}' https://localhost:4433/rbac-api/v1/users

#Create puppet token dir
if [ ! -d /root/.puppetlabs/ ]; then
	mkdir /root/.puppetlabs
fi

#Create token for code manager
curl -k -X POST -H 'Content-Type: application/json' -d '{"login": "deployment-user", "password": "$password", "lifetime": "0"}' https://localhost:4433/rbac-api/v1/auth/token | awk -F \" '{print $4}' > /root/.puppetlabs/token

echo 'pathmunge /opt/puppetlabs/bin' > /etc/profile.d/puppet.sh
chmod +x /etc/profile.d/puppet.sh
. /etc/profile

puppet-code deploy production --wait

#Completion message
echo "

---------------------------------------------------------
The Puppet Master installation is complete.
A user has been created and added to the deployment role.
Username: deployment-user
Password: $password

Admin Details
Username: admin
Password: root
---------------------------------------------------------"

