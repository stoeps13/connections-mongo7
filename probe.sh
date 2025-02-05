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

if [ -z "$MONGO_net_tls_mode" ]; then
  mongosh $(hostname -f):27017 --eval "db.adminCommand('ping')"  | grep "ok: 1"
else
   mongosh --tls --tlsCertificateKeyFile $(eval echo ${MONGO_net_tls_certificateKeyFile}) --tlsCAFile ${MONGO_net_tls_CAFile} --host $(hostname -f) --eval "db.adminCommand('ping')" | grep "ok: 1"
fi
