pkg_novaslave:
  pkg.installed:
    - name: openstack-nova-compute
vim_novaslave:
  cmd.run:
    - names:
      - sed -i '/\[DEFAULT\]$/a\enabled_apis = osapi_compute,metadata\ntransport_url = rabbit://openstack:RABBIT_PASS@slave1\nmy_ip = 192.168.1.97\nuse_neutron = true\nfirewall_driver = nova.virt.firewall.NoopFirewallDriver' /etc/nova/nova.conf
      - sed -i '/\[api\]$/a\auth_strategy = keystone' /etc/nova/nova.conf
      - sed -i '/\[keystone_authtoken\]$/a\auth_url = http://slave1:5000/v3\nmemcached_servers = slave1:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = nova\npassword = NOVA_PASS' /etc/nova/nova.conf
      - sed -i '/\[vnc\]$/a\enabled = true\nserver_listen = 0.0.0.0\nserver_proxyclient_address = $my_ip\nnovncproxy_base_url = http://slave1:6080/vnc_auto.html' /etc/nova/nova.conf
      - sed -i '/\[glance\]/a\api_servers = http://slave1:9292' /etc/nova/nova.conf
      - sed -i '/\[oslo_concurrency\]$/a\lock_path = /var/lib/nova/tmp' /etc/nova/nova.conf
      - sed -i '/\[placement\]$/a\region_name = RegionOne\nproject_domain_name = Default\nproject_name = service\nauth_type = password\nuser_domain_name = Default\nauth_url = http://slave1:5000/v3\nusername = placement\npassword = PLACEMENT_PASS' /etc/nova/nova.conf
      - sed -i '/\[libvirt\]$/a\virt_type = qemu' /etc/nova/nova.conf 
    - require:
      - pkg: pkg_novaslave
running_novaslave:
  service.running:
    - names: 
      - libvirtd.service
      - openstack-nova-compute
    - enable: true
    - restart: true
    - require:
      - cmd: vim_novaslave
















