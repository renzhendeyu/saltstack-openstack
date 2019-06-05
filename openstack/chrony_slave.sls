chrony_pkg_install:
  pkg.installed:
    - name: chrony
delete_server:
  cmd.run:
    - name: sed -i '/^server/s/server/\#server/' /etc/chrony.conf
    - require:
      - pkg: chrony_pkg_install
alter_chrony:
  cmd.run:
    - name: sed -i '/#server 0.centos.pool.ntp.org iburst/i\server master iburst' /etc/chrony.conf
    - require:
      - cmd: delete_server
running_chrony:
  service.running:
    - name: chronyd
    - enable: true
    - restart: true
    - watch:
      - cmd: alter_chrony
chronyc_sources:
  cmd.run:
    - name: chronyc sources
    - require:
      - service: running_chrony
