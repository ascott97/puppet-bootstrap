#!/bin/bash

puppet_ver='2016.5.1'
puppet_install="puppet-enterprise-${puppet_ver}-el-7-x86_64"
repo_url="https://github.com/ascott97/control_repo.git"

curl -O https://s3.amazonaws.com/pe-builds/released/${puppet_ver}/${puppet_install}.tar.gz


tar -zxvf ${puppet_install}.tar.gz

#Populate pe.conf with config
sed -i 's/"console_admin_password": ""/"console_admin_password": "root"/' $(pwd)/${puppet_install}/conf.d/pe.conf

sed -i '$i\  "puppet_enterprise::profile::master::code_manager_auto_configure": true' $(pwd)/${puppet_install}/conf.d/pe.conf

sed -i '$i\  "puppet_enterprise::profile::master::r10k_remote": "git_repo"' $(pwd)/${puppet_install}/conf.d/pe.conf

#Use different delimiter so sed likes it
sed -i "s,git_repo,$repo_url," $(pwd)/${puppet_install}/conf.d/pe.conf



#firewall-cmd --zone=public --add-port=3000/tcp --permanent
#firewall-cmd --zone=public --add-port=443/tcp --permanent
#firewall-cmd --zone=public --add-port=4433/tcp --permanent
#firewall-cmd --zone=public --add-port=8140/tcp --permanent
#firewall-cmd --zone=public --add-port=61613/tcp --permanent

$(pwd)/${puppet_install}/puppet-enterprise-installer -c $(pwd)/${puppet_install}/conf.d/pe.conf

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

password=$(</dev/urandom tr -dc a-z-A-Z-0-9 | head -c 8)

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

admin_pass=$(</dev/urandom tr -dc a-z-A-Z-0-9 | head -c 8)

/opt/puppetlabs/puppet/bin/ruby /opt/puppetlabs/server/data/enterprise/modules/pe_install/files/set_console_admin_password.rb $admin_pass


#Completion message
echo "

---------------------------------------------------------
The Puppet Master installation is complete.
A user has been created and added to the deployment role.
Username: deployment-user
Password: $password

Admin Details
Username: admin
Password: $admin_pass
---------------------------------------------------------"
