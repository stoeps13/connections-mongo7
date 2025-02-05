# Upgrade & Clean Install
# NOTE THIS WILL NEED TO BE UPDATED TO REFLECT STEPS TO UPGRADE FROM v5 TO v7

## Pre-requirements before upgrading to version 7.0
1. MongoDB Database tools: 100.3.0.
2. Kubernetes version: v1.24.1
3. Mongo NodeJ5 for sidecar:  v14 to v16

## Backup | Restore UpDatabase.
    Refer to Documentation/BackupAndRestore.md

## Standalone Upgrade from Mongo 3.6 to 5.0
1. Make sure you upgrade first to atleast version 4.4 before you upgrade to version 5.0
2. In your upgrade version path, you must succesfully upgrade major releases until you reach version 4.4. Meaning from version 3.6, you upgrade first to version 4.0 then version 4.4
3. Once you reach version 4.4, make sure that 

## ReplicaSet Upgrade from Mongo 3.6 to 5.0

## Clean Install MongoDB v5.0

1. Dockerfile for Mongo7 and other sample script are available at connections-docker.artifactory.cwp.pnp-hcl.com/mongo7-Dockerfile.zip
2. Dockerfile for Mongo7 sidecar and other sample script are available at connections-docker.artifactory.cwp.pnp-hcl.com/mongo7-sidecar-Dockerfile.zip
3. ...
