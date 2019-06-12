yum_openstack:
  cmd.run:
    - name: yum -y install centos-release-openstack-rocky
yum_upgrade:
  cmd.run:
    - name: yum -y upgrade
    - require:
      - cmd: yum_openstack
yum_client:
  cmd.run:
    - name: yum -y install python-openstackclient
selinux_set:
  cmd.run:
    - name: sed -i 's/enforcing$/disabled/' /etc/sysconfig/selinux
set_firewalld:
  cmd.run:
    - name: systemctl disable firewalld
