#! /bin/bash
controller=$1           #输入控制节点名称
compute=$2              #输入计算节点名称
cinder=$3               #输入存储节点名称
controller_ip=$4        #输入控制节点ip
compute_ip=$5           #输入计算节点ip
cinder_ip=$6            #输入存储节点ip
controller_eno=$7       #输入控制节点网卡接口名称
compute_eno=$8          #输入计算节点网卡接口名称
echo $controller | sed -i "s/slave1/${controller}/g" /root/openstack/* /root/envprepare/*
echo $compute | sed -i "s/slave2/${compute}/g" /root/openstack/* /root/envprepare/*
echo $cinder | sed -i "s/slave3/${cinder}/g" /root/envprepare/* /root/openstack/*
echo $controller_ip | sed -i "s/controller_ip/${controller_ip}/g" /root/openstack/controllersls
echo $compute_ip | sed -i "s/compute_ip/${compute_ip}/g" /root/openstack/installnova_slave.sls /root/openstack/installneu_slave.sls
echo $controller_eno | sed -i "s/enomaster/${controller_eno}/g" /root/openstack/controller.sls 
echo $compute_eno | sed -i "s/enocompute/${compute_eno}/g" /root/openstack/installneu_slave.sls
echo $cinder_ip | sed -i "s/cinder_ip/${cinder_ip}/g" /root/openstack/installcinder_slave.sls

#sh hosts.sh $1 $2 $3 $4 $5 $6 $7 $8
