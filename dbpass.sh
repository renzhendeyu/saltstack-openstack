#! /bin/bash
$MYSQL_PASS=$1
$KEYSTONE_DBPASS=$2
$GLANCE_DBPASS=$3
$NOVA_DBPASS=$4
$PLACEMENT_DBPASS=$5
$NEUTRON_DBPASS=$6
$DASH_DBPASS=$7
$CINDER_DBPASS=$8
echo $MYSQL_PASS | sed -i "s/MYSQL_PASS/${MYSQL_PASS}/g" /root/openstack/installglance.sls /root/openstack/installcinder_master.sls /root/openstack/installkeystone.sls /root/openstack/installnova_master.sls /root/openstack/installneu_master.sls
echo $KEYSTONE_DBPASS | sed -i "s/KEYSTONE_DBPASS/${KEYSTONE_DBPASS}/g" /root/openstack/installkeystone.sls
echo $GLANCE_DBPASS | sed -i "s/GLANCE_DBPASS/${GLANCE_DBPASS}/g" /root/openstack/installglance.sls
echo $NOVA_DBPASS | sed -i "s/NOVA_DBPASS/${NOVA_DBPASS}/g" /root/openstack/installnova_master.sls
echo $PLACEMENT_DBPASS | sed -i "s/PLACEMENT_DBPASS/${PLACEMENT_DBPASS}/g" /root/openstack/installnova_master.sls
echo $NEUTRON_DBPASS | sed -i "s/NEUTRON_DBPASS/${NEUTRON_DBPASS}/g" /root/openstack/installneu_master.sls
echo $DASH_DBPASS | sed -i "s/DASH_DBPASS/${DASH_DBPASS}/g" /root/openstack/installdashboard.sls
echo $CINDER_DBPASS | sed -i "s/CINDER_DBPASS/${CINDER_DBPASS}/g" /root/openstack/installcinder_master.sls /root/openstack/installcinder_slave.sls













