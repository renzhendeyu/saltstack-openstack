#! /bin/bash
controller=$1
compute=$2
cinder=$3
controller_ip=$4
compute_ip=$5
cinder_ip=$6
controller_eno=$7
compute_eno=$8
echo $controller | sed -i "s/slave1/${controller}/g" /root/openstack/* /root/envprepare/*
echo $compute | sed -i "s/slave2/${compute}/g" /root/openstack/* /root/envprepare/*
echo $cinder | sed -i "s/slave3/${cinder}/g" /root/envprepare/* /root/openstack/*
echo $controller_ip | sed -i "s/controller_ip/${controller_ip}/g" /root/openstack/installcinder_master.sls /root/openstack/installneu_master.sls /root/openstack/installnova_master.sls /root/openstack/rely_prepare.sls
echo $compute_ip | sed -i "s/compute_ip/${compute_ip}/g" /root/openstack/installnova_slave.sls /root/openstack/installneu_slave.sls
echo $controller_eno | sed -i "s/enomaster/${controller_eno}/g" /root/openstack/installneu_master.sls 
echo $compute_eno | sed -i "s/enocompute/${compute_eno}/g" /root/openstack/installneu_slave.sls
echo $cinder_ip | sed -i "s/cinder_ip/${cinder_ip}/g" /root/openstack/installcinder_slave.sls
