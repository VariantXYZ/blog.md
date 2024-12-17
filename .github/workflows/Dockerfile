FROM ubuntu:latest

ARG QUICKJS_REPOSITORY=https://github.com/VariantXYZ/quickjs.git
ARG QUICKJS_VERSION=6e2e68fd0896957f92eb6c242a2e048c1ef3cae0

# Update git
RUN apt-get update && \
    apt-get -qq -y install \
      software-properties-common \
      build-essential

RUN add-apt-repository ppa:git-core/ppa -y && \
    apt-get update && \
    apt-get -qq -y install git && \
    git --version

# Install quickjs

RUN git clone --depth=1 $QUICKJS_REPOSITORY ~/quickjs && \
    cd ~/quickjs && \
    git fetch --depth=1 origin $QUICKJS_VERSION && \
    git checkout $QUICKJS_VERSION && \
    make -j && \
    mv qjs /usr/bin/qjs && \
    cd - && \
    rm -rf ~/quickjs && \
    qjs --help || echo ""