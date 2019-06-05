yum_openstack:
  cmd.run:
    - name: yum -y install centos-release-openstack-rocky
yum_upgrade:
  cmd.run:
    - name: yum -y upgrade
yum_client:
  cmd.run:
    - name: yum -y install python-openstackclient
selinux_set:
  cmd.run:
    - name: sed -i 's/enforcing$/disabled/' /etc/sysconfig/selinux
set_firewalld:
  cmd.run:
    - name: systemctl disable firewalld
centos_reboot:
  cmd.run:
    - name: reboot
    - watch:
      - cmd: yum_openstack
      - cmd: yum_upgrade
      - cmd: yum_client
      - cmd: selinux_set
      - cmd: set_firewalld
