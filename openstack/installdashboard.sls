pkg_dashboard:
  pkg.installed:
    - name: openstack-dashboard
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
running_dashboard:
  service.running:
    - names:
      - httpd
      - memcached
    - restart: true
    - require:
      - cmd: vim_dashboard
      - cmd: sed_dash
      - cmd: vim_httpddash





