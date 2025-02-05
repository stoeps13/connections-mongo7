#!/bin/bash
#Copyright 2025 HCLTech
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

if [[ -z "$MONGO_replication_replSetName" ]]; then
    export MONGO_replication_replSetName="rs0"
fi

if [[ -z "$CONTAINER_LIMIT_MEMORY" ]] && [[ -z "$MONGO_storage_wiredTiger_engineConfig_cacheSizeGB" ]]; then
  echo "Env variable 'CONTAINER_LIMIT_MEMORY' must be set in order to calculate the 'storage.wiredTiger.engineConfig.cacheSizeGB'. As an alternative you can set the variable 'MONGO_storage_wiredTiger_engineConfig_cacheSizeGB' directly"
  exit 1;
fi
if [[ -z "$MONGO_storage_wiredTiger_engineConfig_cacheSizeGB" ]]; then

  if [[ ! -z $CONTAINER_LIMIT_MEMORY ]]; then

    CONTAINER_LIMIT_MEMORY_N=$(echo "${CONTAINER_LIMIT_MEMORY//[!0-9]/}")
    CONTAINER_LIMIT_MEMORY_GB=$(awk "BEGIN { print ($CONTAINER_LIMIT_MEMORY_N / 1024) }")

    #see https://docs.mongodb.com/manual/reference/configuration-options/#storage.wiredTiger.engineConfig.cacheSizeGB
    cacheSizeGB_proposed=$(awk "BEGIN { print (($CONTAINER_LIMIT_MEMORY_GB / 2) -1) }")
    awk "BEGIN {return_code=($cacheSizeGB_proposed < 0.25) ? 0 : 1; exit} END {exit return_code}"
    if [ $? -ne 0 ]; then
      export MONGO_storage_wiredTiger_engineConfig_cacheSizeGB=$(echo "$cacheSizeGB_proposed" | awk '{ printf("%.3f", $1) }')
    else
      export MONGO_storage_wiredTiger_engineConfig_cacheSizeGB="0.25"
    fi
  fi
fi

for VAR in `env`
do
  if [[ $VAR =~ ^MONGO_ && ! $VAR =~ ^MONGO_VERSION && ! $VAR =~ ^MONGO_TOOLS_VERSION && ! $VAR =~ ^MONGO_SECRET_VOL_PATH ]]; then
    mongo_name=`echo "$VAR" | sed -r "s/MONGO_(.*)=.*/\1/g" | tr _ .`
    env_var=`echo "$VAR" | sed -r "s/(.*)=.*/\1/g"`
    if egrep -q "(^|^#)$mongo_name: " /etc/mongodb/mongod.conf.yaml; then
        #note that no config values may contain an '@' char
        sed -r -i "s@(^|^#)($mongo_name)=(.*)@\2: ${!env_var}@g" /etc/mongodb/mongod.conf.yaml
    else
        # eval is needed, thus variables like MONGO_net_ssl_clusterFile will be parsed properly
        eval echo "$mongo_name: ${!env_var}" >> /etc/mongodb/mongod.conf.yaml
    fi
  fi
done

#start as account mongodb
exec mongod --config /etc/mongodb/mongod.conf.yaml