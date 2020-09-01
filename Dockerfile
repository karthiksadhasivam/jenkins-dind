FROM docker:18.06-dind
LABEL maintainer="Karthik Sadhasivam"

ARG user=jenkins
ARG group=jenkins
ARG uid=10000
ARG gid=10000

ENV LANG C.UTF-8
ENV HOME /home/${user}
ENV DOCKER_HOST tcp://0.0.0.0:2375

RUN { \
		echo '#!/bin/sh'; \
		echo 'set -e'; \
		echo; \
		echo 'dirname "$(dirname "$(readlink -f "$(which javac || which java)")")"'; \
	} > /usr/local/bin/docker-java-home \
	&& chmod +x /usr/local/bin/docker-java-home
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk
ENV PATH $PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin

ENV JAVA_VERSION 8u171
ENV JAVA_ALPINE_VERSION 8.252.09-r0

RUN set -x \
	&& apk add --no-cache \
		openjdk8="$JAVA_ALPINE_VERSION" \
	&& [ "$JAVA_HOME" = "$(docker-java-home)" ]

RUN addgroup -g ${gid} ${group}
RUN adduser -h $HOME -u ${uid} -G ${group} -D ${user}
LABEL Description="This is a base image, which provides the Jenkins agent executable (slave.jar)" Vendor="Jenkins project" Version="3.23"

RUN apk add --update --no-cache sudo shadow
# Allow jenkins user to run docker as root
RUN echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

ARG VERSION=3.26
ARG AGENT_WORKDIR=/home/${user}/agent

RUN apk add --update --no-cache curl bash git openssh-client openssl procps \
  && curl --create-dirs -sSLo /usr/share/jenkins/slave.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar \
  && chmod 755 /usr/share/jenkins \
  && chmod 644 /usr/share/jenkins/slave.jar 

RUN apk add py-pip && pip install --upgrade pip

RUN apk add --no-cache --virtual .build-deps gcc musl-dev python-dev libffi-dev openssl-dev make\
     && pip install cython && pip install pynacl

RUN pip install docker-compose
ENV AGENT_WORKDIR=${AGENT_WORKDIR}
RUN mkdir /home/${user}/.jenkins && mkdir -p ${AGENT_WORKDIR}
RUN apk add maven

RUN apk add --update --no-cache openjdk8
RUN chown -R ${user}:${user} /home/${user}
RUN groupadd -g 1000 docker && usermod -aG docker jenkins

WORKDIR /home/${user}

RUN apk add --no-cache \
		ca-certificates

COPY jenkins-slave /usr/local/bin/jenkins-slave

RUN usermod -aG jenkins dockremap

ENTRYPOINT ["/usr/local/bin/jenkins-slave"]

USER jenkins
