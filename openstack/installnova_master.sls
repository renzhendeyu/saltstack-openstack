create_novadata:
  cmd.run:
    - names:
      - echo -e 'CREATE DATABASE nova_api;' | mysql -uroot -p123456
      - echo -e 'CREATE DATABASE nova;' | mysql -uroot -p123456
      - echo -e 'CREATE DATABASE nova_cell0;' | mysql -uroot -p123456
      - echo -e 'CREATE DATABASE placement;' | mysql -uroot -p123456
    - require:
      - cmd: modify_mysqldata
grant_nova:
  cmd.run:
    - names:
      - echo -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';" | mysql -uroot -p123456
      - echo -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'slave1' IDENTIFIED BY 'NOVA_DBPASS';" | mysql -uroot -p123456
      - echo -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';" | mysql -uroot -p123456
      - echo -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'slave1' IDENTIFIED BY 'NOVA_DBPASS';" | mysql -uroot -p123456
      - echo -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';" | mysql -uroot -p123456
      - echo -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'slave1' IDENTIFIED BY 'NOVA_DBPASS';" | mysql -uroot -p123456
      - echo -e "GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY 'PLACEMENT_DBPASS';" | mysql -uroot -p123456
      - echo -e "GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'slave1' IDENTIFIED BY 'PLACEMENT_DBPASS';" | mysql -uroot -p123456
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
      - sed -i '/\[DEFAULT\]$/a\firewall_driver = nova.virt.firewall.NoopFirewallDriver\nuse_neutron = true\nmy_ip = 192.168.1.66\ntransport_url = rabbit://openstack:RABBIT_PASS@slave1\nenabled_apis = osapi_compute,metadata' /etc/nova/nova.conf
      - sed -i '/\[api_database\]$/a\connection = mysql+pymysql://nova:NOVA_DBPASS@slave1/nova_api' /etc/nova/nova.conf
      - sed -i '/\[database\]$/a\connection = mysql+pymysql://nova:NOVA_DBPASS@slave1/nova' /etc/nova/nova.conf
      - sed -i '/\[placement_database\]$/a\connection = mysql+pymysql://placement:PLACEMENT_DBPASS@slave1/placement' /etc/nova/nova.conf
      - sed -i '/\[api\]$/a\auth_strategy = keystone' /etc/nova/nova.conf
      - sed -i '/\[keystone_authtoken\]$/a\auth_url = http://slave1:5000/v3\nmemcached_servers = slave1:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = nova\npassword = NOVA_PASS' /etc/nova/nova.conf
      - sed -i '/\[vnc\]$/a\enabled = true\nserver_listen = $my_ip\nserver_proxyclient_address = $my_ip' /etc/nova/nova.conf
      - sed -i '/\[glance\]$/a\api_servers = http://slave1:9292' /etc/nova/nova.conf
      - sed -i '/\[oslo_concurrency\]$/a\lock_path = /var/lib/nova/tmp' /etc/nova/nova.conf
      - sed -i '/\[placement\]$/a\region_name = RegionOne\nproject_domain_name = Default\nproject_name = service\nauth_type = password\nuser_domain_name = Default\nauth_url = http://slave1:5000/v3\nusername = placement\npassword = PLACEMENT_PASS' /etc/nova/nova.conf
    - require:
      - pkg: pkg_installnova
vim_placeapi:
  cmd.run:
    - name: echo -e '\n<Directory /usr/bin>\n   <IfVersion >= 2.4>\n      Require all granted\n   </IfVersion>\n   <IfVersion < 2.4>\n      Order allow,deny\n      Allow from all\n   </IfVersion>\n</Directory>' >> /etc/httpd/conf.d/00-nova-placement-api.conf
restart_httpd1:
  service.running:
    - name: httpd
    - restart: true
    - watch:
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
      - service: restart_httpd1

