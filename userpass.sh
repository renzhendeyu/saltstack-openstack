#! /bin/bash
ADMIN_PASS=$1
myuser_PASS=$2
GLANCE_PASS=$3
NOVA_PASS=$4
PLACEMENT_PASS=$5
NEUTRON_PASS=$6
METADATA_SECRET=$7
CINDER_PASS=$8
RABBIT_PASS=$10
echo $ADMIN_PASS | sed -i "s/ADMIN_PASS/${ADMIN_PASS}/g" /root/openstack/installkeystone.sls
echo $myuser_PASS |  sed -i "s/myuser_PASS/${myuser_PASS}/g" /root/openstack/installkeystone.sls
echo $GLANCE_PASS |  sed -i "s/GLANCE_PASS/${GLANCE_PASS}/g" /root/openstack/installglance.sls
echo $NOVA_PASS | sed -i "s/NOVA_PASS/${NOVA_PASS}/g" /root/openstack/installnova_master.sls /root/openstack/installneu_master.sls /root/openstack/installnova_slave.sls
echo $PLACEMENT_PASS |  sed -i "s/PLACEMENT_PASS/${PLACEMENT_PASS}/g" /root/openstack/installnova_master.sls /root/openstack/installnova_slave.sls
echo $NEUTRON_PASS |  sed -i "s/NEUTRON_PASS/${NEUTRON_PASS}/g" /root/openstack/installneu_slave.sls /root/openstack/installneu_master.sls
echo $METADATA_SECRET | sed -i "s/METADATA_SECRET/${METADATA_SECRET}/g" /root/openstack/installneu_master.sls
echo $CINDER_PASS | sed -i "s/CINDER_PASS/${CINDER_PASS}/g" /root/openstack/installcinder_master.sls /root/openstack/installcinder_slave.sls
echo $RABBIT_PASS | sed -i "s/RABBIT_PASS/${RABBIT_PASS}/g" /root/openstack/installcinder_slave.sls /root/openstack/installcinder_master.sls /root/openstack/installnova_master.sls /root/openstack/installneu_slave.sls /root/openstack/installneu_master.sls /root/openstack/installnova_slave.sls /root/openstack/rely_prepare.sls

