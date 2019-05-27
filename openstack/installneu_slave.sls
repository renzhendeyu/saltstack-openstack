pkg_neutroncompute:
  pkg.installed:
    - names:
      - openstack-neutron-linuxbridge
      - ebtables
      - ipset
vim_neucompute:
  cmd.run:
    - names:
      - sed -i '/\[DEFAULT\]$/a\transport_url = rabbit://openstack:RABBIT_PASS@slave1' /etc/neutron/neutron.conf
      - sed -i '/\[keystone_authtoken\]$/a\www_authenticate_uri = http://slave1:5000\nauth_url = http://slave1:5000\nmemcached_servers = slave1:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = neutron\npassword = NEUTRON_PASS' /etc/neutron/neutron.conf
      - sed -i '/\[oslo_concurrency\]$/a\lock_path = /var/lib/neutron/tmp' /etc/neutron/neutron.conf
      - sed -i '/\[linux_bridge\]$/a\physical_interface_mappings = provider:ens33' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
      - sed -i '/\[vxlan\]$/a\enable_vxlan = true\nlocal_ip = 192.168.1.141\nl2_population = true' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
      - sed -i '/\[securitygroup\]$/a\enable_security_group = true\nfirewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver' /etc/neutron/plugins/ml2/linuxbridge_agent.ini
      - sed -i '/\[neutron\]$/a\url = http://slave1:9696\nauth_url = http://slave1:5000\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = neutron\npassword = NEUTRON_PASS' /etc/nova/nova.conf
    - require:
      - pkg: pkg_neutroncompute
running_neucompute:
  service.running:
    - names:
      - openstack-nova-compute
      - neutron-linuxbridge-agent
    - restart: true
    - enable: true
    - require:
      - cmd: vim_neucompute
      - service: running_novaslave

