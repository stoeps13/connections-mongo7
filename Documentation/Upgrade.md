## Note before upgrading to latest version of MongoDB: 
For upgrade from Mongo 3.6 to MongoDB 5.x and is currently using a mongodb-sidecar(NodeJS), you will encounter compatibility issues related to MongoDB
    1. Mongo 3.6 is still using SSL while 5.x is already using TLS. Your mongo-driver will still connect but most of the features available to mongodb 5 will not work.
    2. Mongo connector may or may not work due to syntax issue. 

## Standalone Upgrade from Mongo 3.6 to 5.0   
1. Make sure you upgrade first to atleast version 4.4 before you upgrade to version 5.0
2. In your upgrade version path, you must succesfully upgrade major releases until you reach version 4.4. Meaning from version 3.6, you upgrade first to version 4.0 then version 4.4
3. Once you reach version 4.4, make sure that ...

## ReplicaSet Upgrade from Mongo 3.6 to 5.0