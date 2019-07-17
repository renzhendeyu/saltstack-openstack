openstack:
  'slave1':
    - rely_prepare
    - installcontroller.sls
  'slave2':
    - chrony_slave
    - installnova_slave
    - installneu_slave
  'slave3':
    - chrony_slave
    - installcinder_slave




  
