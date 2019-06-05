# saltstack-openstack
通过saltstack部署安装openstack
安装完saltstack后。
修改saltstack--master的配置文件：
file_roots:
  openstack:
    - /srv/openstack
  envprepare:
    - /srv/envprepare
重启saltstack服务。

先使用命令来部署openstack安装环境，部署完后，系统会自动重启以适用配置：

salt '*' state.highstate saltenv=envprepare

重启完后在使用命令来一键部署openstack：

salt '*' state.highstate saltenv=openstack



#Warnning
This project is just used for personal study.

Please use the commond:

salt '*' state.highstate saltenv=example  #you can replace example with the name of derectory like envprepare or openstack.
