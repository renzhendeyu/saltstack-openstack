openstack:
  'slave1':
    - rely_prepare
    - chrony_master
    - installkeystone
    - installglance
    - installnova_master
    - installneu_master
    - installdashboard
    - installcinder_master
  'slave2':
    - chrony_slave
    - installnova_slave
    - installneu_slave
  'slave3':
    - chrony_slave
    - installcinder_slave




  
