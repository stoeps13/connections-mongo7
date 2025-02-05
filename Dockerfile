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

FROM ubuntu:22.04

ENV MONGO_VERSION 7.0.12
ENV MONGO_TOOLS_VERSION 7.0.12

RUN mkdir -p /etc/mongodb
RUN mkdir -p /data/db /etc/ca

ADD start-mongod.sh /usr/bin/start-mongod.sh
ADD probe.sh /usr/bin/probe.sh
ADD entrypoint.sh /usr/bin/entrypoint.sh
ADD disable-transparent-hugepages /etc/init.d/

RUN groupadd -g 1001 mongodb \
  && useradd -g mongodb -u 1001 mongodb \
  && chown -R mongodb:mongodb /etc/ca/ /data/db /etc/mongodb /usr/bin/start-mongod.sh /usr/bin/*.sh /home/ /opt/

RUN apt-get clean \
  && apt update --fix-missing && apt-get install -y --no-install-recommends wget apt-transport-https gnupg python3-dev python3-pip python3-setuptools python3-wheel build-essential manpages-dev openssl procps \
  && export DEBIAN_FRONTEND=noninteractive \
  && wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | apt-key add - \
  && echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list \
  && apt-get clean \
  && apt-get update \
# install MongoDB 7.0
  && apt-get install -y mongodb-org=$MONGO_VERSION mongodb-org-database=$MONGO_VERSION mongodb-org-server=$MONGO_VERSION mongodb-org-shell=$MONGO_VERSION mongodb-org-mongos=$MONGO_VERSION mongodb-org-tools=$MONGO_TOOLS_VERSION \
  && rm -rf /var/lib/apt/lists/* \
  && cd /usr/local/bin/ \
  && chmod +x /etc/init.d/disable-transparent-hugepages; sync \
  && sh /etc/init.d/disable-transparent-hugepages 

USER mongodb

ENV PATH="/home/mongodb/.local/bin:${PATH}"

VOLUME /data/db
EXPOSE 27017

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
