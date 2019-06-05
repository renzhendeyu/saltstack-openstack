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
vim_cindercontroller:
  cmd.run:
    - names:
      - sed -i '/\[database\]$/a\connection = mysql+pymysql://cinder:CINDER_DBPASS@slave1/cinder' /etc/cinder/cinder.conf
      - sed -i '/\[DEFAULT\]$/a\transport_url = rabbit://openstack:RABBIT_PASS@slave1\nauth_strategy = keystone\nmy_ip = controller_ip' /etc/cinder/cinder.conf
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
restart_novamaster2:
  service.running:
    - name: openstack-nova-api
    - restart: true
    - require:
      - cmd: vim_novacinder
      - service: restart_novamaster1
running_cindermaster:
  service.running:
    - names:
      - openstack-cinder-api
      - openstack-cinder-scheduler
    - enable: true
    - restart: true
    - require:
      - cmd: su_cinder
      - service: restart_novamaster2
