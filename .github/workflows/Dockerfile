FROM ubuntu:latest

ARG WEBKIT_REPOSITORY=https://github.com/WebKit/WebKit.git
ARG WEBKIT_VERSION=wpewebkit-2.47.2

# Update git
RUN apt-get update && \
    apt-get -qq -y install \
      software-properties-common \
      build-essential

RUN add-apt-repository ppa:git-core/ppa -y && \
    apt-get update && \
    apt-get -qq -y install git && \
    git --version

# Install jsc
RUN git clone --depth=1 --branch $WEBKIT_VERSION $WEBKIT_REPOSITORY ~/webkit

RUN apt-get update && \
    apt-get -qq -y install \
      perl \
      cmake \
      ruby \
      libicu-dev

RUN cd ~/webkit && \
    Tools/Scripts/build-jsc --jsc-only --cmakeargs="-DENABLE_STATIC_JSC=ON" && \
    cd -

RUN cd ~/webkit && \
    mv ./WebKitBuild/JSCOnly/Release/bin/jsc /usr/bin/jsc && \
    cd - && \
    rm -rf ~/webkit && \
    jsc --help