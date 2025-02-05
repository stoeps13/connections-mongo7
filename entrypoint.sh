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

if [[ ! -e /etc/ca/openssl.cnf ]]; then
    touch /etc/ca/openssl.cnf
    touch /etc/mongodb/mongod.conf.yaml
fi

MONGOCONFIG="/etc/mongodb/mongod.conf.yaml"
chown -R mongodb:mongodb ${MONGOCONFIG}
chmod -R 666 ${MONGOCONFIG}

export SSL_CONFIG=${SSL_CONFIG:-"/etc/ca/openssl.cnf"}
export APPLICATION_CERT_FOLDER=${APPLICATION_CERT_FOLDER:-"/etc/ca"}
export RANDFILE="${APPLICATION_CERT_FOLDER}/.rnd" # Needed for openssl if the user does not have a home directory.
export APPLICATION_CERT_PREFIX=${HOSTNAME}
export APPLICATION_CERT_PREFIX_ADMIN=user_admin
export APPLICATION_CERT_SUBJECT="/emailAddress=${HOSTNAME}.mongo@mongodb/CN=$(hostname -f)/OU=Connections/O=IBM/L=Dublin/ST=Ireland/C=IE"
export APPLICATION_CERT_SUBJECT_ADMIN="/emailAddress=admin@mongodb/CN=admin/OU=Connections-Middleware-Clients/O=IBM/L=Dublin/ST=Ireland/C=IE"

echo ${INTERNAL_CA_TRUSTCHAIN_CERT_PEM} | base64 -d > "${APPLICATION_CERT_FOLDER}/internal-ca-chain.cert.pem"
echo ${INTERNAL_CA_INTERMEDIATE_KEY_PEM} | base64 -d > "${APPLICATION_CERT_FOLDER}/intermediate.key.pem"

#Generating a custom openssl.cnf and add the allowed Subject Alternative Names (based on k8s service DNS's)
echo "====> Generating new config file ${SSL_CONFIG} with SAN..."
cat > ${SSL_CONFIG} <<EOM
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
subjectAltName = @alt_names
[alt_names]
EOM

IFS=","
dns=($(hostname -f))
if [[ -n ${SUBJECT_ALTERNATIVE_NAMES} ]]; then
    dns+=(${SUBJECT_ALTERNATIVE_NAMES})
fi

for i in "${!dns[@]}"; do
    echo DNS.$((i+1)) = ${dns[$i]} >> ${SSL_CONFIG}
done

#Create certificates
openssl req -new -nodes -newkey rsa:2048 -keyout ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX}.key -out ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX}.csr -subj "${APPLICATION_CERT_SUBJECT}" -config ${SSL_CONFIG}
openssl req -new -nodes -newkey rsa:2048 -keyout ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX_ADMIN}.key -out ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX_ADMIN}.csr -subj "${APPLICATION_CERT_SUBJECT_ADMIN}"

#Sign the CSRs with the CA and generate the public certificate of them (CRTs)
openssl x509 -CA ${APPLICATION_CERT_FOLDER}/internal-ca-chain.cert.pem -CAkey ${APPLICATION_CERT_FOLDER}/intermediate.key.pem -CAcreateserial -req -days 730 -in ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX}.csr -out ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX}.crt -extensions v3_req -extfile ${SSL_CONFIG}
openssl x509 -CA ${APPLICATION_CERT_FOLDER}/internal-ca-chain.cert.pem -CAkey ${APPLICATION_CERT_FOLDER}/intermediate.key.pem -CAcreateserial -req -days 730 -in ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX_ADMIN}.csr -out ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX_ADMIN}.crt

#Generate the pem files
cat ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX}.key ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX}.crt > ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX}.pem
cat ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX_ADMIN}.key ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX_ADMIN}.crt > ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX_ADMIN}.pem

# keep only the .pem file
rm -f ${RANDFILE} ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX}*.key ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX}*.crt ${APPLICATION_CERT_FOLDER}/${APPLICATION_CERT_PREFIX}*.csr


chown -R mongodb:mongodb ${APPLICATION_CERT_FOLDER}
chmod -R 755 ${APPLICATION_CERT_FOLDER}

LAUNCHPOINT=/usr/bin/start-mongod.sh
chown mongodb:mongodb ${LAUNCHPOINT}
chmod 755 ${LAUNCHPOINT}

echo "mongodb user information is:"
echo `id mongodb`

# # start as non-root
exec ${LAUNCHPOINT}
