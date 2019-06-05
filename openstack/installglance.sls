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
      - sed -i '/database]$/a\connection = mysql+pymysql://glance:GLANCE_DBPASS@slave1/glance' /etc/glance/glance-api.conf
      - sed -i '/keystone_authtoken]$/a\www_authenticate_uri  = http://slave1:5000\nauth_url = http://slave1:5000\nmemcached_servers = slave1:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = glance\npassword = GLANCE_PASS' /etc/glance/glance-api.conf
      - sed -i '/paste_deploy]$/a\flavor = keystone' /etc/glance/glance-api.conf
      - sed -i '/glance_store]$/a\stores = file,http\ndefault_store = file\nfilesystem_store_datadir = /var/lib/glance/images/' /etc/glance/glance-api.conf
    - require:
      - pkg: install_glance
vim_glancere:
  cmd.run:
    - names:
      - sed -i '/database]$/a\connection = mysql+pymysql://glance:GLANCE_DBPASS@slave1/glance' /etc/glance/glance-registry.conf
      - sed -i '/keystone_authtoken]$/a\www_authenticate_uri = http://slave1:5000\nauth_url = http://slave1:5000\nmemcached_servers = slave1:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nuser_domain_name = Default\nusername = glance\npassword = GLANCE_PASS' /etc/glance/glance-registry.conf
      - sed -i '/paste_deploy]$/a\flavor = keystone' /etc/glance/glance-registry.conf
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
