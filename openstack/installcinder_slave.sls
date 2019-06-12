pkg_cinderslave:
  pkg.installed:
    - names:
      - lvm2
      - device-mapper-persistent-data
      - openstack-cinder
      - targetcli
      - python-keystone
create_pv:
  cmd.run:
    - name: pvcreate /dev/sdb
create_vg:
  cmd.run:
    - name: vgcreate /dev/sdb
    - require:
      - cmd: create_pv
vim_lvm:
  cmd.run:
    - name: sed -i '/device:$/a\        filter = [ "a/sdb/", "r/.*/"]' /etc/lvm/lvm.conf
vim_cinderslave:
  cmd.run:
    - names:
      - sed -i '/\[database\]$/a\connection = mysql+pymysql://cinder:CINDER_DBPASS@slave1/cinder' /etc/cinder/cinder.conf
      - sed -i '/\[DEFAULT\]$/a\transport_url = rabbit://openstack:RABBIT_PASS@slave1\nauth_strategy = keystone\nmy_ip = cinder_ip\nenabled_backends = lvm\nglance_api_servers = http://slave1:9292' /etc/cinder/cinder.conf
      - sed -i '/\[keystone_authtoken\]$/a\www_authenticate_uri = http://slave1:5000\nauth_url = http://slave1:5000\nmemcached_servers = slave1:11211\nauth_type = password\nproject_domain_id = default\nuser_domain_id = default\nproject_name = service\nusername = cinder\npassword = CINDER_PASS' /etc/cinder/cinder.conf
      - sed -i '/\[keystone_authtoken\]$/i\[lvm]\nvolume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver\nvolume_group = cinder-volumes\niscsi_protocol = iscsi\niscsi_helper = lioadm' /etc/cinder/cinder.conf
      - sed -i '/\[oslo_concurrency\]$/i\lock_path = /var/lib/cinder/tmp' /etc/cinder/cinder.conf
    - require:
      - pkg: pkg_cinderslave
run_cinderslave:
  service.running:
    - names:
      - openstack-cinder-volume
      - target
    - enable: true
    - restart: true
    - require:
      - cmd: vim_cinderslave
