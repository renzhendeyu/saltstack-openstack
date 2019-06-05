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
      - sed -i '/\[linux_bridge\]$/a\physical_interface_mappings = provider:enomaster' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
      - sed -i '/\[vxlan\]$/a\enable_vxlan = true\nlocal_ip = controller_ip\nl2_population = true' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
      - sed -i '/\[securitygroup\]$/a\enable_security_group = true\nfirewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
      - sed -i '/\[DEFAULT\]$/a\interface_driver = linuxbridge' /etc/neutron/l3_agent.ini
      - sed -i '/\[DEFAULT\]$/a\interface_driver = linuxbridge\ndhcp_driver = neutron.agent.linux.dhcp.Dnsmasq\nenable_isolated_metadata = true' /etc/neutron/dhcp_agent.ini
      - sed -i '/\[DEFAULT\]$/a\nova_metadata_host = slave1\nmetadata_proxy_shared_secret = METADATA_SECRET' /etc/neutron/metadata_agent.ini
      - sed -i '/\[neutron\]$/a\url = http://slave1:9696\nauth_url = http://slave1:5000\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = neutron\npassword = NEUTRON_PASS\nservice_metadata_proxy = true\nmetadata_proxy_shared_secret = METADATA_SECRET' /etc/nova/nova.conf
    - require:
      - pkg: pkg_neutron
ln_neutron:
  cmd.run:
    - name: ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
    - require:
      - cmd: vim_neutron
su_neutron:
  cmd.run:
    - name: su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
    - require:
      - cmd: ln_neutron
restart_novamaster1:
  service.running:
    - name: openstack-nova-api
    - restart: true
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
      - service: restart_novamaster1
