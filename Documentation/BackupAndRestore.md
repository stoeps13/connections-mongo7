# Backup | Restore Data - Replica Set

## Backup data with x509 Authentication activated. Replica Set

1. Attach to the container then create the directory where the backup will be created:
```
    kubectl exec --stdin --tty mongo-0 -- bash
    mkdir -p /data/db/backups/catalog-bkp1
```     
note: the directory created should be inside the PV, thus you can copy it aftwards from outside the container.

2. Connect to a Mongo7 daemon:
```
    mongosh --tls --host $(hostname -f) \
    --tlsCertificateKeyFile /etc/ca/user_admin.pem \
    --tlsCAFile /etc/ca/internal-ca-chain.cert.pem \
    --username 'C=IE,ST=Ireland,L=Dublin,O=IBM,OU=Connections-Middleware-Clients,CN=admin,emailAddress=admin@mongodb' \
    --authenticationDatabase '$external' \
    --authenticationMechanism=MONGODB-X509
```

3. Lock the data sync:
```
    use admin
    db.fsyncLock()
```

4. Exit Mongo7 daemon then backup the database:
```
    mongodump --tls --host $(hostname -f) \
    --tlsCertificateKeyFile /etc/ca/user_admin.pem \
    --tlsCAFile /etc/ca/internal-ca-chain.cert.pem \
    --username 'C=IE,ST=Ireland,L=Dublin,O=IBM,OU=Connections-Middleware-Clients,CN=admin,emailAddress=admin@mongodb' \
    --authenticationDatabase '$external' \
    --authenticationMechanism=MONGODB-X509 \
    --db catalog \
    --out /data/db/backups/catalog-bkp1
```

5. Connect to the daemon again (perform step 2), and unlock the datasync:
```
    use admin
    db.fsyncUnlock()
```

6. Migrate the backup to the Volume where you want to restore it. Eg:
```
    cp -rf /data/pink/mongo-node-0/data/db/backups/catalog-bkp1 /data/pink/mongo-node-0/data/db
```

7. Attach to the container of the target mongo Replica Set:
```
    kubectl exec --stdin --tty mongo-0 -- bash
```

## Restore Data. Replica Set (Same NAMESPACE)
8. Restore the database with no x509 Authentication:
```
    mongorestore --host $(hostname -f) --db catalog /data/db/catalog-bkp1/catalog
```

9. Restore the database with x509 Authentication activated:
```
    mongorestore --tls --host $(hostname -f) \
    --tlsCertificateKeyFile /etc/ca/user_admin.pem \
    --tlsCAFile /etc/ca/internal-ca-chain.cert.pem \
    --username 'C=IE,ST=Ireland,L=Dublin,O=IBM,OU=Connections-Middleware-Clients,CN=admin,emailAddress=admin@mongodb' \
    --authenticationDatabase '$external' \
    --authenticationMechanism=MONGODB-X509 \
    --db catalog /data/db/catalog-bkp1/catalog
```

10. Check the data
### For x509 Authentication activated:
```
    kubectl exec --stdin --tty mongo-0 -- bash
```
```
    mongosh --tls --host $(hostname -f) \
    --tlsCertificateKeyFile /etc/ca/user_admin.pem \
    --tlsCAFile /etc/ca/internal-ca-chain.cert.pem \
    --username 'C=IE,ST=Ireland,L=Dublin,O=IBM,OU=Connections-Middleware-Clients,CN=admin,emailAddress=admin@mongodb' \
    --authenticationDatabase '$external' \
    --authenticationMechanism=MONGODB-X509
```
```
    show databases
        admin    0.000GB
        catalog  0.001GB
        local    0.098GB

    rs0:PRIMARY> use catalog
    switched to db catalog

    rs0:PRIMARY> show collections
        AppDetail
        AppDetail_nls
        AppSecrets
        Apps
        Apps_nls
        ConfigOptions
        DbVersion
        Extensions
        MyApps
```

### For no x509 Authentication:
```
    kubectl exec --stdin --tty mongo-0 -- bash
```
```
    mongosh $(hostname -f):27017
```
```
    show databases
        admin    0.000GB
        catalog  0.001GB
        local    0.098GB

    rs0:PRIMARY> use catalog
    switched to db catalog

    rs0:PRIMARY> show collections
        AppDetail
        AppDetail_nls
        AppSecrets
        Apps
        Apps_nls
        ConfigOptions
        DbVersion
        Extensions
        MyApps
```


# Backup | Restore Data - Standalone

## Backup data with x509 Authentication activated. 

1. Attach to the container then create the directory where the backup will be created:
```
    kubectl exec --stdin --tty mongo -- bash
    mkdir -p /data/db/backups/catalog-bkp1
```     
note: the directory created should be inside the PV, thus you can copy it aftwards from outside the container.

2. Connect to a Mongo7 daemon:
```
    mongosh --tls --host $(hostname -f) \
    --tlsCertificateKeyFile /etc/ca/user_admin.pem \
    --tlsCAFile /etc/ca/internal-ca-chain.cert.pem \
    --username 'C=IE,ST=Ireland,L=Dublin,O=IBM,OU=Connections-Middleware-Clients,CN=admin,emailAddress=admin@mongodb' \
    --authenticationDatabase '$external' \
    --authenticationMechanism=MONGODB-X509
```

3. Lock the data sync:
```
    use admin
    db.fsyncLock()
```

4. Exit Mongo7 daemon then backup the database:
```
    mongodump --tls --host $(hostname -f) \
    --tlsCertificateKeyFile /etc/ca/user_admin.pem \
    --tlsCAFile /etc/ca/internal-ca-chain.cert.pem \
    --username 'C=IE,ST=Ireland,L=Dublin,O=IBM,OU=Connections-Middleware-Clients,CN=admin,emailAddress=admin@mongodb' \
    --authenticationDatabase '$external' \
    --authenticationMechanism=MONGODB-X509 \
    --db catalog \
    --out /data/db/backups/catalog-bkp1
```

5. Connect to the daemon again (perform step 2), and unlock the datasync:
```
    use admin
    db.fsyncUnlock()
```

6. Migrate the backup to the Volume where you want to restore it. Eg:
```
    cp -rf /data/db/backups/catalog-bkp1 /data/db
```

7. Attach to the container of the target mongo Replica Set:
```
    kubectl exec --stdin --tty mongo-0 -- bash
```

## Restore Data. Standalone
8. Restore the database with no x509 Authentication:
```
    mongorestore --host $(hostname -f):27017 --db catalog /data/db/catalog-bkp1/catalog
```

9. Restore the database with x509 Authentication activated:
```
    mongorestore --tls --host $(hostname -f) \
    --tlsCertificateKeyFile /etc/ca/user_admin.pem \
    --tlsCAFile /etc/ca/internal-ca-chain.cert.pem \
    --username 'C=IE,ST=Ireland,L=Dublin,O=IBM,OU=Connections-Middleware-Clients,CN=admin,emailAddress=admin@mongodb' \
    --authenticationDatabase '$external' \
    --authenticationMechanism=MONGODB-X509 \
    --db catalog /data/db/catalog-bkp1/catalog
```

10. Check the data
### For x509 Authentication activated:
```
    kubectl exec --stdin --tty mongo -- bash
```
```
    mongosh --tls --host $(hostname -f) \
    --tlsCertificateKeyFile /etc/ca/user_admin.pem \
    --tlsCAFile /etc/ca/internal-ca-chain.cert.pem \
    --username 'C=IE,ST=Ireland,L=Dublin,O=IBM,OU=Connections-Middleware-Clients,CN=admin,emailAddress=admin@mongodb' \
    --authenticationDatabase '$external' \
    --authenticationMechanism=MONGODB-X509
```
```
    show databases
        admin    0.000GB
        catalog  0.001GB
        local    0.098GB

    rs0:PRIMARY> use catalog
    switched to db catalog

    rs0:PRIMARY> show collections
        AppDetail
        AppDetail_nls
        AppSecrets
        Apps
        Apps_nls
        ConfigOptions
        DbVersion
        Extensions
        MyApps
```

### For no x509 Authentication:
```
    kubectl exec --stdin --tty mongo -- bash
```
```
    mongosh $(hostname -f):27017
```
```
    show databases
        admin    0.000GB
        catalog  0.001GB
        local    0.098GB

    > use catalog
    switched to db catalog

    > show collections
        AppDetail
        AppDetail_nls
        AppSecrets
        Apps
        Apps_nls
        ConfigOptions
        DbVersion
        Extensions
        MyApps
```
