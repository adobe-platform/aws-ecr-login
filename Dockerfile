FROM       alpine:3.4
MAINTAINER AdobePlatform <fuller@adobe.com>

ENV     SHELL /bin/bash
WORKDIR "/data"

RUN apk update && \
    apk add \
      bash \
      curl \
      tar \
      'jq' \
      'python<3.0' \
      'py-pip<8.2.0' \
    && \
    rm -rf /var/cache/apk/*

RUN pip install awscli

ADD ecr-login.sh /opt/ethos/ecr-login

CMD [ "/opt/ethos/ecr-login" ]
