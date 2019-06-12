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
    - watch:
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
running_rabbit2:
  service.running:
    - name: rabbitmq-server
    - enable: true
    - restart: true
    - watch:
      - cmd: rabbit_permit
make_openstackconf:
  cmd.run:
    - name: touch /etc/my.cnf.d/openstack.cnf
    - require:
      - pkg: env_pkg
modify_openstackconf:
  cmd.run:
    - name: echo -e "[mysqld]\nbind-address = controller_ip\ndefault-storage-engine = innodb\ninnodb_file_per_table = on\nmax_connections = 4096\ncollation-server = utf8_general_ci\ncharacter-set-server = utf8" > /etc/my.cnf.d/openstack.cnf
    - watch:
      - cmd: make_openstackconf
running_mysql:
  service.running:
    - name: mariadb
    - enable: true
    - restart: true
    - watch:
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
    - watch:
      - cmd: modify_mem 




