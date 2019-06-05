#! /bin/bash
sed -i "/^ *'BACKEND'/a\        'LOCATION': 'slave1:11211'," /etc/openstack-dashboard/local_settings
sed -i '/^#OPENSTACK_API_VERSIONS/i\OPENSTACK_API_VERSIONS = {\n        "identity": 3,\n        "image": 2,\n        "volume": 2,\n}' /etc/openstack-dashboard/local_settings

