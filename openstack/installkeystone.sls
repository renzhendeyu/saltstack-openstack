install_keystone:
  pkg.installed:
    - names:
      - openstack-keystone
      - httpd
      - mod_wsgi
keystone_mysql:
  cmd.run:
    - name: echo -e "CREATE DATABASE keystone;" | mysql -uroot -p123456 && echo -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'slave1' IDENTIFIED BY 'KEYSTONE_DBPASS';" | mysql -uroot -p123456 && echo -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'KEYSTONE_DBPASS';" | mysql -uroot -p123456
modify_keystone:
  cmd.run:
    - name: sed -i '/database\]$/a\connection = mysql+pymysql://keystone:KEYSTONE_DBPASS@slave1/keystone' /etc/keystone/keystone.conf && sed -i '/token\]$/a\provider = fernet' /etc/keystone/keystone.conf
    - watch:
      - cmd: keystone_mysql
sync_keystone:
  cmd.run:
    - name: su -s /bin/sh -c 'keystone-manage db_sync' keystone
    - require:
      - cmd: modify_keystone
sync_fernet:
  cmd.run:
    - name: keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone && keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
    - require:
      - cmd: sync_keystone
key_manage:
  cmd.run:
    - name: keystone-manage bootstrap --bootstrap-password ADMIN_PASS --bootstrap-admin-url http://slave1:5000/v3/ --bootstrap-internal-url http://slave1:5000/v3/ --bootstrap-public-url http://slave1:5000/v3/ --bootstrap-region-id RegionOne
    - require:
      - cmd: sync_fernet
http_modify1:
  cmd.run:
    - name: sed -i 's/localhost/slave1/g' /etc/httpd/conf/httpd.conf && sed -i '/com:80$/a\ServerName slave1:80' /etc/httpd/conf/httpd.conf
    - require:
      - pkg: install_keystone
ln_httpd:
  cmd.run:
    - name: ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
    - require:
      - cmd: http_modify1
running_httpd1:
  service.running:
    - name: httpd
    - enable: true
    - restart: true
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
create_myproject:
  cmd.run:
    - name: . /root/admin-openrc && openstack project create --domain default --description "Demo Project" myproject
    - require:
      - cmd: create_adenv
create_myuser:
  cmd.run:
    - name: . /root/admin-openrc && openstack user create --domain default myuser --password myuser_PASS
    - require:
      - cmd: create_adenv
create_myrole:
  cmd.run:
    - name: . /root/admin-openrc && openstack role create myrole
    - require:
      - cmd: create_adenv
add_myuser:
  cmd.run:
    - name: . /root/admin-openrc && openstack role add --project myproject --user myuser myrole
    - require:
      - cmd: create_myproject
      - cmd: create_myuser
      - cmd: create_myrole

