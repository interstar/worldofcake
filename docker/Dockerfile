FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG HAXE_VERSION=4.3.6
ARG HXCPP_VERSION=4.3.2
ARG LIME_VERSION=8.1.3
ARG OPENFL_VERSION=9.3.4
ARG RACK_SDK_VERSION=2.6.6
ARG RACK_SDK_SHA256=420da2452def7b195f98e3a0650c35f1e0f058a98a71840b4347d3d203618532

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        g++ \
        gcc \
        git \
        jq \
        make \
        neko \
        openjdk-11-jre-headless \
        unzip \
        xxd \
        zip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/haxe /opt/haxelib \
    && curl -fsSL "https://github.com/HaxeFoundation/haxe/releases/download/${HAXE_VERSION}/haxe-${HAXE_VERSION}-linux64.tar.gz" \
        | tar -xz --strip-components=1 -C /opt/haxe \
    && ln -s /opt/haxe/haxe /usr/local/bin/haxe \
    && ln -s /opt/haxe/haxelib /usr/local/bin/haxelib

ENV PATH=/opt/haxe:$PATH \
    LD_LIBRARY_PATH=/opt/haxe:/opt/haxe/lib/neko:$LD_LIBRARY_PATH

RUN haxelib setup /opt/haxelib

RUN haxelib install hxcpp "${HXCPP_VERSION}" --always \
    && haxelib install lime "${LIME_VERSION}" --always \
    && haxelib install openfl "${OPENFL_VERSION}" --always \
    && haxelib run lime config arch 64

WORKDIR /opt/worldofcake

# Downloaded rather than copied so a fresh clone does not need the gitignored
# Rack-SDK-*.zip (or an extracted SDK directory) present locally.
RUN curl -fsSL "https://vcvrack.com/downloads/Rack-SDK-${RACK_SDK_VERSION}-lin-x64.zip" -o /tmp/rack-sdk.zip \
    && echo "${RACK_SDK_SHA256}  /tmp/rack-sdk.zip" | sha256sum -c - \
    && mkdir -p /opt/rack-sdk \
    && unzip -q /tmp/rack-sdk.zip -d /opt/rack-sdk \
    && rm /tmp/rack-sdk.zip


COPY vendor/layla/worldofcake-laylagen.jar /opt/worldofcake/vendor/layla/worldofcake-laylagen.jar
COPY vendor/layla/worldofcake-laylagen.jar.sha256 /tmp/worldofcake-laylagen.jar.sha256
RUN cd /opt/worldofcake && sha256sum -c /tmp/worldofcake-laylagen.jar.sha256

ENV RACK_DIR=/opt/rack-sdk/Rack-SDK \
    HOME=/root

COPY . /opt/worldofcake/

CMD ["bash"]
