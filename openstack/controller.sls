chrony_pkg_install:
  pkg.installed:
    - name: chrony
delete_server:
  cmd.run:
    - name: sed -i '/^server/s/server/\#server/' /etc/chrony.conf
    - require:
      - pkg: chrony_pkg_install
alter_chrony:
  cmd.run:
    - name: sed -i '/#server 0.centos.pool.ntp.org iburst/i\server 1.cn.pool.ntp.org iburst' /etc/chrony.conf
    - require:
      - cmd: delete_server
running_chrony:
  service.running:
    - name: chronyd
    - enable: true
    - restart: true
    - watch:
      - cmd: alter_chrony
chronyc_sources:
  cmd.run:
    - name: chronyc sources
    - require:
      - service: running_chrony
env_pkg:
  pkg.installed:
    - names:
      - mariadb
      - mariadb-server
      - python2-PyMySQL
      - rabbitmq-server
      - memcached
      - python-memcached
running_rabbit1:
  service.running:
    - name: rabbitmq-server
    - enable: true
    - restart: true
    - require:
      - pkg: env_pkg
create_rabbituser:
  cmd.run:
    - name: rabbitmqctl add_user openstack RABBIT_PASS
    - require:
      - service: running_rabbit1
rabbit_permit:
  cmd.run:
    - name: rabbitmqctl set_permissions openstack ".*" ".*" ".*"
    - watch:
      - cmd: create_rabbituser
restart_rabbit:
  cmd.run:
    - name: systemctl restart rabbitmq-server
    - require:
      - cmd: rabbit_permit
make_openstackconf:
  cmd.run:
    - name: touch /etc/my.cnf.d/openstack.cnf
    - require:
      - pkg: env_pkg
modify_openstackconf:
  cmd.run:
    - name: echo -e "[mysqld]\nbind-address = 192.168.1.140\ndefault-storage-engine = innodb\ninnodb_file_per_table = on\nmax_connections = 4096\ncollation-server = utf8_general_ci\ncharacter-set-server = utf8" > /etc/my.cnf.d/openstack.cnf
    - watch:
      - cmd: make_openstackconf
running_mysql:
  service.running:
    - name: mariadb
    - enable: true
    - restart: true
    - require:
      - cmd: modify_openstackconf
modify_mysqldata:
  cmd.run:
    - name: echo -e "\nY\nMYSQL_PASS\nMYSQL_PASS\nY\nn\nY\nY\n" | mysql_secure_installation
    - require:
      - service: running_mysql
modify_mem:
  cmd.run:
    - name: sed 's/1"/1,slave1"/g' /etc/sysconfig/memcached
    - require:
      - pkg: env_pkg
running_mem:
  service.running:
    - name: memcached
    - enable: true
    - restart: true
    - require:
      - cmd: modify_mem

install_keystone:
  pkg.installed:
    - names:
      - openstack-keystone
      - httpd
      - mod_wsgi
keystone_mysql:
  cmd.run:
    - names:
      - echo -e "CREATE DATABASE keystone;" | mysql -uroot -pMYSQL_PASS
      - echo -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'slave1' IDENTIFIED BY 'KEYSTONE_DBPASS';" | mysql -uroot -pMYSQL_PASS
      - echo -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'KEYSTONE_DBPASS';" | mysql -uroot -pMYSQL_PASS
    - require:
      - cmd: modify_mysqldata
modify_keystone:
  cmd.run:
    - name: sed -i '/\[database\]$/a\connection = mysql+pymysql://keystone:KEYSTONE_DBPASS@slave1/keystone' /etc/keystone/keystone.conf && sed -i '/token\]$/a\provider = fernet' /etc/keystone/keystone.conf
    - require:
      - pkg: install_keystone
      - cmd: keystone_mysql
sync_keystone:
  cmd.run:
    - name: su -s /bin/sh -c 'keystone-manage db_sync' keystone
    - require:
      - cmd: modify_keystone
sync_fernet1:
  cmd.run:
    - name: keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
    - require:
      - cmd: sync_keystone
sync_fernet2:
  cmd.run:
    - name: keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
    - require:
      - cmd: sync_fernet1
key_manage:
  cmd.run:
    - name: keystone-manage bootstrap --bootstrap-password ADMIN_PASS --bootstrap-admin-url http://slave1:5000/v3/ --bootstrap-internal-url http://slave1:5000/v3/ --bootstrap-public-url http://slave1:5000/v3/ --bootstrap-region-id RegionOne
    - require:                                  
      - cmd: sync_fernet2
http_modify1:
  cmd.run:
    - name: sed -i 's/localhost/slave1/g' /etc/httpd/conf/httpd.conf && sed -i '/com:80$/a\ServerName slave1:80' /etc/httpd/conf/httpd.conf
    - require:
      - pkg: install_keystone
      - cmd: key_manage
ln_httpd:
  cmd.run:
    - name: ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
    - require:
      - cmd: http_modify1
running_httpd1:
  cmd.run:
    - name: systemctl enable httpd && systemctl start httpd
    - require:
      - cmd: ln_httpd
create_adenv:
  cmd.run:
    - name: echo -e 'export OS_USERNAME=admin\nexport OS_PASSWORD=ADMIN_PASS\nexport OS_PROJECT_NAME=admin\nexport OS_USER_DOMAIN_NAME=Default\nexport OS_PROJECT_DOMAIN_NAME=Default\nexport OS_AUTH_URL=http://slave1:5000/v3\nexport OS_IDENTITY_API_VERSION=3\nexport OS_IMAGE_API_VERSION=2' > /root/admin-openrc
create_demoenv:
  cmd.run:
    - name: echo -e 'export OS_PROJECT_DOMAIN_NAME=Default\nexport OS_USER_DOMAIN_NAME=Default\nexport OS_PROJECT_NAME=myproject\nexport OS_USERNAME=myuser\nexport OS_PASSWORD=MYUSER_PASS\nexport OS_AUTH_URL=http://slave1:5000/v3\nexport OS_IDENTITY_API_VERSION=3\nexport OS_IMAGE_API_VERSION=2' > /root/demo-openrc
create_service:
  cmd.run:
    - name: . /root/admin-openrc && openstack project create --domain default --description "Service Project" service
    - require:
      - cmd: create_adenv
      - cmd: running_httpd1
create_myproject:
  cmd.run:
    - name: . /root/admin-openrc && openstack project create --domain default --description "Demo Project" myproject
    - require:
      - cmd: create_adenv
      - cmd: running_httpd1
create_myuser:
  cmd.run:
    - name: . /root/admin-openrc && openstack user create --domain default myuser --password myuser_PASS
    - require:
      - cmd: create_adenv
      - cmd: running_httpd1
create_myrole:
  cmd.run:
    - name: . /root/admin-openrc && openstack role create myrole
    - require:
      - cmd: create_adenv
      - cmd: running_httpd1
add_myuser:
  cmd.run:
    - name: . /root/admin-openrc && openstack role add --project myproject --user myuser myrole
    - require:
      - cmd: create_myproject
      - cmd: create_myuser
      - cmd: create_myrole

install_glance:
  pkg.installed:
    - name: openstack-glance
create_glancemysql:
  cmd.run:
    - name: echo -e 'CREATE DATABASE glance;' | mysql -uroot -pMYSQL_PASS && echo -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'slave1' IDENTIFIED BY 'GLANCE_DBPASS';" | mysql -uroot -pMYSQL_PASS && echo -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'GLANCE_DBPASS';" | mysql -uroot -pMYSQL_PASS
    - require:
      - cmd: modify_mysqldata
create_userglance:
  cmd.run:
    - name: . /root/admin-openrc && openstack user create --domain default glance --password GLANCE_PASS
    - require:
      - cmd: create_service
create_roleglance:
  cmd.run:
    - name: . /root/admin-openrc && openstack role add --project service --user glance admin
    - require:
      - cmd: create_userglance
create_serviceglance:
  cmd.run:
    - name: . /root/admin-openrc && openstack service create --name glance --description "OpenStack Image" image
    - require:
      - cmd: create_userglance
create_glanceopenstack:
  cmd.run:
    - names: 
      - . /root/admin-openrc && openstack endpoint create --region RegionOne image public http://slave1:9292
      - . /root/admin-openrc && openstack endpoint create --region RegionOne image internal http://slave1:9292
      - . /root/admin-openrc && openstack endpoint create --region RegionOne image admin http://slave1:9292
    - require:
      - cmd: create_roleglance
      - cmd: create_serviceglance
vim_glanceapi:
  cmd.run:
    - names:
      - sed -i '/\[database\]$/a\connection = mysql+pymysql://glance:GLANCE_DBPASS@slave1/glance' /etc/glance/glance-api.conf
      - sed -i '/\[keystone_authtoken\]$/a\www_authenticate_uri  = http://slave1:5000\nauth_url = http://slave1:5000\nmemcached_servers = slave1:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = glance\npassword = GLANCE_PASS' /etc/glance/glance-api.conf
      - sed -i '/\[paste_deploy\]$/a\flavor = keystone' /etc/glance/glance-api.conf
      - sed -i '/\[glance_store\]$/a\stores = file,http\ndefault_store = file\nfilesystem_store_datadir = /var/lib/glance/images/' /etc/glance/glance-api.conf
    - require:
      - pkg: install_glance
vim_glancere:
  cmd.run:
    - names:
      - sed -i '/\[database\]$/a\connection = mysql+pymysql://glance:GLANCE_DBPASS@slave1/glance' /etc/glance/glance-registry.conf
      - sed -i '/\[keystone_authtoken\]$/a\www_authenticate_uri = http://slave1:5000\nauth_url = http://slave1:5000\nmemcached_servers = slave1:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nuser_domain_name = Default\nusername = glance\npassword = GLANCE_PASS' /etc/glance/glance-registry.conf
      - sed -i '/\[paste_deploy\]$/a\flavor = keystone' /etc/glance/glance-registry.conf
    - require:
      - pkg: install_glance
su_glance:
  cmd.run:
    - name: su -s /bin/sh -c "glance-manage db_sync" glance
    - require:
      - cmd: create_glancemysql
      - cmd: create_glanceopenstack
      - cmd: vim_glanceapi
      - cmd: vim_glancere
running_glance:
  service.running:
    - names:
      - openstack-glance-api
      - openstack-glance-registry
    - enable: true
    - restart: true
    - require:
      - cmd: su_glance


create_novadata:
  cmd.run:
    - names:
      - echo -e 'CREATE DATABASE nova_api;' | mysql -uroot -pMYSQL_PASS
      - echo -e 'CREATE DATABASE nova;' | mysql -uroot -pMYSQL_PASS
      - echo -e 'CREATE DATABASE nova_cell0;' | mysql -uroot -pMYSQL_PASS
      - echo -e 'CREATE DATABASE placement;' | mysql -uroot -pMYSQL_PASS
    - require:
      - cmd: modify_mysqldata
grant_nova:
  cmd.run:
    - names:
      - echo -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';" | mysql -uroot -pMYSQL_PASS
      - echo -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'slave1' IDENTIFIED BY 'NOVA_DBPASS';" | mysql -uroot -pMYSQL_PASS
      - echo -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';" | mysql -uroot -pMYSQL_PASS
      - echo -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'slave1' IDENTIFIED BY 'NOVA_DBPASS';" | mysql -uroot -pMYSQL_PASS
      - echo -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';" | mysql -uroot -pMYSQL_PASS
      - echo -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'slave1' IDENTIFIED BY 'NOVA_DBPASS';" | mysql -uroot -pMYSQL_PASS
      - echo -e "GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY 'PLACEMENT_DBPASS';" | mysql -uroot -pMYSQL_PASS
      - echo -e "GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'slave1' IDENTIFIED BY 'PLACEMENT_DBPASS';" | mysql -uroot -pMYSQL_PASS
    - require:
      - cmd: create_novadata
create_usernova:
  cmd.run:
    - names:
      - . /root/admin-openrc && openstack user create --domain default nova --password NOVA_PASS
      - . /root/admin-openrc && openstack user create --domain default placement --password PLACEMENT_PASS
    - require:
      - cmd: create_service
create_rolenova:
  cmd.run:
    - names:
      - . /root/admin-openrc && openstack role add --project service --user nova admin
      - . /root/admin-openrc && openstack role add --project service --user placement admin
    - require:
      - cmd: create_usernova
create_servicenova:
  cmd.run:
    - names:
      - . /root/admin-openrc && openstack service create --name nova --description "OpenStack Compute" compute
      - . /root/admin-openrc && openstack service create --name placement --description "Placement API" placement
    - require:
      - cmd: create_rolenova
create_novaopenstack:
  cmd.run:
    - names:
      - . /root/admin-openrc && openstack endpoint create --region RegionOne compute public http://slave1:8774/v2.1
      - . /root/admin-openrc && openstack endpoint create --region RegionOne compute internal http://slave1:8774/v2.1
      - . /root/admin-openrc && openstack endpoint create --region RegionOne compute admin http://slave1:8774/v2.1
      - . /root/admin-openrc && openstack endpoint create --region RegionOne placement public http://slave1:8778
      - . /root/admin-openrc && openstack endpoint create --region RegionOne placement internal http://slave1:8778
      - . /root/admin-openrc && openstack endpoint create --region RegionOne placement admin http://slave1:8778
    - require:
      - cmd: create_servicenova
pkg_installnova:
  pkg.installed:
    - names:
      - openstack-nova-api
      - openstack-nova-conductor
      - openstack-nova-console
      - openstack-nova-novncproxy
      - openstack-nova-scheduler
      - openstack-nova-placement-api
vim_novaconf:
  cmd.run:
    - names:
      - sed -i '/\[DEFAULT\]$/a\firewall_driver = nova.virt.firewall.NoopFirewallDriver\nuse_neutron = true\nmy_ip = 192.168.1.140\ntransport_url = rabbit://openstack:RABBIT_PASS@slave1\nenabled_apis = osapi_compute,metadata' /etc/nova/nova.conf
      - sed -i '/\[api_database\]$/a\connection = mysql+pymysql://nova:NOVA_DBPASS@slave1/nova_api' /etc/nova/nova.conf
      - sed -i '/\[database\]$/a\connection = mysql+pymysql://nova:NOVA_DBPASS@slave1/nova' /etc/nova/nova.conf
      - sed -i '/\[placement_database\]$/a\connection = mysql+pymysql://placement:PLACEMENT_DBPASS@slave1/placement' /etc/nova/nova.conf
      - sed -i '/\[api\]$/a\auth_strategy = keystone' /etc/nova/nova.conf
      - sed -i '/\[keystone_authtoken\]$/a\auth_url = http://slave1:5000/v3\nmemcached_servers = slave1:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = nova\npassword = NOVA_PASS' /etc/nova/nova.conf
      - sed -i '/\[vnc\]$/a\enabled = true\nserver_listen = $my_ip\nserver_proxyclient_address = $my_ip' /etc/nova/nova.conf
      - sed -i '/\[glance\]$/a\api_servers = http://slave1:9292' /etc/nova/nova.conf
      - sed -i '/\[oslo_concurrency\]$/a\lock_path = /var/lib/nova/tmp' /etc/nova/nova.conf
      - sed -i '/\[placement\]$/a\region_name = RegionOne\nproject_domain_name = Default\nproject_name = service\nauth_type = password\nuser_domain_name = Default\nauth_url = http://slave1:5000/v3\nusername = placement\npassword = PLACEMENT_PASS' /etc/nova/nova.conf
      - sed -i '/\[scheduler\]$/a\discover_hosts_in_cells_interval = 300' /etc/nova/nova.conf
    - require:
      - pkg: pkg_installnova
vim_placeapi:
  cmd.run:
    - name: echo -e '\n<Directory /usr/bin>\n   <IfVersion >= 2.4>\n      Require all granted\n   </IfVersion>\n   <IfVersion < 2.4>\n      Order allow,deny\n      Allow from all\n   </IfVersion>\n</Directory>' >> /etc/httpd/conf.d/00-nova-placement-api.conf
    - require:
      - pkg: pkg_installnova
      - cmd: running_httpd1
restart_httpd1:
  cmd.run:
    - name: systemctl restart httpd
    - require:
      - cmd: vim_placeapi
su_nova1:
  cmd.run:
    - name: su -s /bin/sh -c "nova-manage api_db sync" nova 
    - require:
      - cmd: vim_novaconf
      - cmd: grant_nova
      - cmd: create_novaopenstack
su_nova2:
  cmd.run:
    - name: su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
    - watch:
      - cmd: su_nova1
su_nova3:
  cmd.run:
    - name: su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
    - watch:
      - cmd: su_nova2
su_nova4:
  cmd.run:
    - name: su -s /bin/sh -c "nova-manage db sync" nova
    - watch:
      - cmd: su_nova3
su_novacheck:
  cmd.run:
    - name: su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
    - require:
      - cmd: su_nova4
running_nova:
  service.running:
    - names:
      - openstack-nova-api
      - openstack-nova-consoleauth
      - openstack-nova-scheduler
      - openstack-nova-conductor
      - openstack-nova-novncproxy
    - enable: true
    - restart: true
    - require:
      - cmd: su_novacheck
      - cmd: restart_httpd1

create_neudata:
  cmd.run:
    - name: echo -e 'CREATE DATABASE neutron;' | mysql -uroot -pMYSQL_PASS
    - require:
      - cmd: modify_mysqldata
grant_neu:
  cmd.run:
    - names:
      - echo -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'slave1' IDENTIFIED BY 'NEUTRON_DBPASS';" | mysql -uroot -pMYSQL_PASS
      - echo -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'NEUTRON_DBPASS';" | mysql -uroot -pMYSQL_PASS
    - require:
      - cmd: create_neudata
create_userneu:
  cmd.run:
    - name: . /root/admin-openrc && openstack user create --domain default neutron --password NEUTRON_PASS
    - require:
      - cmd: create_service
create_roleneu:
  cmd.run:
    - name: . /root/admin-openrc && openstack role add --project service --user neutron admin
    - require:
      - cmd: create_userneu
create_serviceneu:
  cmd.run:
    - name: . /root/admin-openrc && openstack service create --name neutron --description "OpenStack Networking" network
    - require:
      - cmd: create_roleneu
create_apineu:
  cmd.run:
    - names:
      - . /root/admin-openrc && openstack endpoint create --region RegionOne network public http://slave1:9696
      - . /root/admin-openrc && openstack endpoint create --region RegionOne network internal http://slave1:9696
      - . /root/admin-openrc && openstack endpoint create --region RegionOne network admin http://slave1:9696
    - require:
      - cmd: create_serviceneu
pkg_neutron:
  pkg.installed:
    - names:
      - openstack-neutron 
      - openstack-neutron-ml2
      - openstack-neutron-linuxbridge
      - ebtables
vim_neutron:
  cmd.run:
    - names:
      - sed -i '/\[DEFAULT\]$/a\core_plugin = ml2\nservice_plugins = router\nallow_overlapping_ips = True\ntransport_url = rabbit://openstack:RABBIT_PASS@slave1\nauth_strategy = keystone\nnotify_nova_on_port_status_changes = true\nnotify_nova_on_port_data_changes = true' /etc/neutron/neutron.conf
      - sed -i '/\[database\]$/a\connection = mysql+pymysql://neutron:NEUTRON_DBPASS@slave1/neutron' /etc/neutron/neutron.conf
      - sed -i '/\[keystone_authtoken\]$/a\www_authenticate_uri = http://slave1:5000\nauth_url = http://slave1:5000\nmemcached_servers = slave1:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = neutron\npassword = NEUTRON_PASS' /etc/neutron/neutron.conf
      - sed -i '/\[nova\]$/a\auth_url = http://slave1:5000\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = nova\npassword = NOVA_PASS' /etc/neutron/neutron.conf
      - sed -i '/\[oslo_concurrency\]$/a\lock_path = /var/lib/neutron/tmp' /etc/neutron/neutron.conf
      - sed -i '/\[ml2\]$/a\type_drivers = flat,vlan,vxlan\ntenant_network_types = vxlan\nmechanism_drivers = linuxbridge,l2population\nextension_drivers = port_security' /etc/neutron/plugins/ml2/ml2_conf.ini
      - sed -i '/\[ml2_type_flat\]$/a\flat_networks = provider' /etc/neutron/plugins/ml2/ml2_conf.ini
      - sed -i '/\[ml2_type_vxlan\]$/a\vni_ranges = 1:1000' /etc/neutron/plugins/ml2/ml2_conf.ini
      - sed -i '/\[securitygroup\]$/a\enable_ipset = true' /etc/neutron/plugins/ml2/ml2_conf.ini
      - sed -i '/\[linux_bridge\]$/a\physical_interface_mappings = provider:ens33' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
      - sed -i '/\[vxlan\]$/a\enable_vxlan = true\nlocal_ip = 192.168.1.140\nl2_population = true' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
      - sed -i '/\[securitygroup\]$/a\enable_security_group = true\nfirewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
      - sed -i '/\[DEFAULT\]$/a\interface_driver = linuxbridge' /etc/neutron/l3_agent.ini
      - sed -i '/\[DEFAULT\]$/a\interface_driver = linuxbridge\ndhcp_driver = neutron.agent.linux.dhcp.Dnsmasq\nenable_isolated_metadata = true' /etc/neutron/dhcp_agent.ini
      - sed -i '/\[DEFAULT\]$/a\nova_metadata_host = slave1\nmetadata_proxy_shared_secret = METADATA_SECRET' /etc/neutron/metadata_agent.ini
      - sed -i '/^\[neutron\]/a\url = http://slave1:9696\nauth_url = http://slave1:5000\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = neutron\npassword = NEUTRON_PASS\nservice_metadata_proxy = true\nmetadata_proxy_shared_secret = METADATA_SECRET' /etc/nova/nova.conf
    - require:
      - pkg: pkg_neutron
ln_neutron:
  cmd.run:
    - name: ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
    - require:
      - cmd: vim_neutron
su_neutron:
  cmd.run:
    - name: su -s /bin/sh -c 'neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head' neutron
    - require:
      - cmd: ln_neutron
restart_novamaster1:
  cmd.run:
    - name: systemctl restart openstack-nova-api
    - require: 
      - cmd: vim_neutron
      - service: running_nova
running_neutron:
  service.running:
    - names:
      - neutron-server
      - neutron-linuxbridge-agent
      - neutron-dhcp-agent
      - neutron-metadata-agent
      - neutron-l3-agent
    - enable: true
    - restart: true
    - require:
      - cmd: su_neutron
      - cmd: restart_novamaster1

pkg_dashboard:
  pkg.installed:
    - name: openstack-dashboard
    - require:
      - service: running_neutron
vim_dashboard:
  cmd.run:
    - names:
      - sed -i 's/127.0.0.1/slave1/g' /etc/openstack-dashboard/local_settings
      - sed -i "s/'horizon.example.com', 'localhost'/'*'/g" /etc/openstack-dashboard/local_settings
      - sed -i "s/locmem.LocMemCache/memcached.MemcachedCache/g" /etc/openstack-dashboard/local_settings
      - sed -i '/^#OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT/a\OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True' /etc/openstack-dashboard/local_settings
      - sed -i "/^#OPENSTACK_KEYSTONE_DEFAULT_DOMAIN/a\OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = 'Default'" /etc/openstack-dashboard/local_settings
      - sed -i "s/\"_member_\"/'myrole'/g" /etc/openstack-dashboard/local_settings
    - require:
      - pkg: pkg_dashboard
sed_dash:
  cmd.script:
    - source: salt://files/sed.sh
    - require:
      - pkg: pkg_dashboard
vim_httpddash:
  cmd.run:
    - name: sed -i '/\/wsgi$/a\WSGIApplicationGroup %\{GLOBAL\}' /etc/httpd/conf.d/openstack-dashboard.conf
    - require:
      - pkg: pkg_dashboard
running_dashboard:
  cmd.run:
    - names:
      - systemctl restart httpd
      - systemctl restart memcached
    - require:
      - cmd: vim_dashboard
      - cmd: sed_dash
      - cmd: vim_httpddash

create_cinderdata:
  cmd.run:
    - name: echo -e 'CREATE DATABASE cinder;' | mysql -uroot -pMYSQL_PASS
    - require:
      - cmd: modify_mysqldata
grant_cinder:
  cmd.run:
    - names:
      - echo -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'slave1' IDENTIFIED BY 'CINDER_DBPASS';" | mysql -uroot -pMYSQL_PASS
      - echo -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'CINDER_DBPASS';" | mysql -uroot -pMYSQL_PASS
    - require:
      - cmd: create_cinderdata
create_usercinder:
  cmd.run:
    - name: . /root/admin-openrc && openstack user create --domain default cinder --password CINDER_PASS
    - require:
      - cmd: create_service
create_rolecinder:
  cmd.run:
    - name: . /root/admin-openrc && openstack role add --project service --user cinder admin
    - require:
      - cmd: create_usercinder
create_servicecinder:
  cmd.run:
    - names:
      - . /root/admin-openrc && openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
      - . /root/admin-openrc && openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
    - require:
      - cmd: create_rolecinder
create_apicinder:
  cmd.run:
    - names:
      - . /root/admin-openrc && openstack endpoint create --region RegionOne volumev2 public http://slave1:8776/v2/%\(project_id\)s 
      - . /root/admin-openrc && openstack endpoint create --region RegionOne volumev2 internal http://slave1:8776/v2/%\(project_id\)s
      - . /root/admin-openrc && openstack endpoint create --region RegionOne volumev2 admin http://slave1:8776/v2/%\(project_id\)s
      - . /root/admin-openrc && openstack endpoint create --region RegionOne volumev3 public http://slave1:8776/v3/%\(project_id\)s
      - . /root/admin-openrc && openstack endpoint create --region RegionOne volumev3 internal http://slave1:8776/v3/%\(project_id\)s
      - . /root/admin-openrc && openstack endpoint create --region RegionOne volumev3 admin http://slave1:8776/v3/%\(project_id\)s
    - require:
      - cmd: create_servicecinder
pkg_cinder:
  pkg.installed:
    - name: openstack-cinder
    - require:
      - service: running_neutron
vim_cindercontroller:
  cmd.run:
    - names:
      - sed -i '/\[database\]$/a\connection = mysql+pymysql://cinder:CINDER_DBPASS@slave1/cinder' /etc/cinder/cinder.conf
      - sed -i '/\[DEFAULT\]$/a\transport_url = rabbit://openstack:RABBIT_PASS@slave1\nauth_strategy = keystone\nmy_ip = 192.168.1.140' /etc/cinder/cinder.conf
      - sed -i '/\[keystone_authtoken\]$/a\www_authenticate_uri = http://slave1:5000\nauth_url = http://slave1:5000\nmemcached_servers = slave1:11211\nauth_type = password\nproject_domain_id = default\nuser_domain_id = default\nproject_name = service\nusername = cinder\npassword = CINDER_PASS' /etc/cinder/cinder.conf
      - sed -i '/\[oslo_concurrency\]$/a\lock_path = /var/lib/cinder/tmp' /etc/cinder/cinder.conf
    - require:
      - pkg: pkg_cinder
su_cinder:
  cmd.run:
    - name: su -s /bin/sh -c "cinder-manage db sync" cinder
    - require:
      - cmd: vim_cindercontroller
vim_novacinder:
  cmd.run:
    - name: sed -i '/\[cinder\]$/a\os_region_name = RegionOne' /etc/nova/nova.conf
    - require:
      - cmd: su_cinder
restart_novamaster2:
  cmd.run:
    - name: systemctl restart openstack-nova-api
    - require:
      - cmd: vim_novacinder
      - cmd: restart_novamaster1
running_cindermaster:
  service.running:
    - names:
      - openstack-cinder-api
      - openstack-cinder-scheduler
    - enable: true
    - restart: true
    - require:
      - cmd: su_cinder
      - cmd: restart_novamaster2






