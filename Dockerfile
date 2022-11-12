FROM postgres:13

ARG PG_VERSION
ENV PG_VERSION=${PG_VERSION:-13}
ARG DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ARG AWS_SDK_CPP_VERSION=1.8.14

# build dependencies
RUN apt update
RUN apt install -y gnupg2 postgresql-server-dev-13 lsb-release cmake build-essential git curl libcurl4-openssl-dev libssl-dev uuid-dev zlib1g-dev libpulse-dev

# dependency #1 - Apache arrow
RUN curl https://apache.jfrog.io/artifactory/arrow/$(lsb_release --id --short | tr 'A-Z' 'a-z')/apache-arrow-apt-source-latest-$(lsb_release --codename --short).deb -o arrow-source.deb && \
    apt-get install -y -V ./arrow-source.deb
RUN apt update
RUN apt-get remove -y libarrow-dev libparquet-dev
RUN apt-get install -y libarrow-dev=9.0.0-1 libparquet-dev=9.0.0-1

# dependency #2 - aws sdk for c++ (building source)
RUN git clone https://github.com/aws/aws-sdk-cpp.git
WORKDIR ./aws-sdk-cpp
RUN git checkout ${AWS_SDK_CPP_VERSION}
RUN mkdir build
WORKDIR ./build
#RUN cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/bin/aws-sdk
RUN cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/bin/aws-sdk -DBUILD_ONLY="core;s3"
RUN make
RUN make install -j1
RUN cp -R /root/bin/aws-sdk/ /usr/local/lib/.
# TODO: Clean this
RUN cp -R /usr/local/lib/aws-sdk/lib/* /usr/local/lib/.
RUN ldconfig

# prepare to build fdw extension 
WORKDIR /fdw_parquet_s3
ADD . /fdw_parquet_s3
RUN make clean USE_PGXS=1
RUN make install USE_PGXS=1 CPPFLAGS="-I/usr/local/lib/aws-sdk/include" LDFLAGS="-L/usr/local/lib/aws-sdk/lib"
# to ensure libs are reacheable from ld
RUN ldconfig
RUN ldconfig
