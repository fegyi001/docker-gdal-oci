FROM ubuntu:20.04

# Software versions
ENV GDAL_VERSION 3.1.2
ENV PROJ_VERSION 7.1.1
ENV ORACLE_VERSION 19.8
ENV POSTGRES_VERSION 12
ENV POSTGIS_VERSION 3

# Set time zone
ENV TZ=Europe/Budapest
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get -y update && \ 
  apt-get install -y wget gnupg2 && \
  # PostreSQL repo
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
  echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list && \
  # Install libs
  apt-get -y install \ 
    wget build-essential git cmake sqlite3 libsqlite3-dev libtiff-dev libcurl4-openssl-dev alien libaio1  \
    postgis postgresql-${POSTGRES_VERSION}-postgis-${POSTGIS_VERSION} pkg-config libpq-dev

ENV INSTALL_DIR /opt/install
RUN mkdir -p ${INSTALL_DIR}
WORKDIR ${INSTALL_DIR}

# Install Proj
RUN git clone --depth 1 --branch ${PROJ_VERSION} https://github.com/OSGeo/PROJ.git
WORKDIR ${INSTALL_DIR}/PROJ
RUN mkdir build 
WORKDIR ${INSTALL_DIR}/PROJ/build
RUN cmake .. && \
  cmake --build . && \
  cmake --build . --target install

# Install Oracle client
RUN mkdir -p ${INSTALL_DIR}/oracle
WORKDIR ${INSTALL_DIR}/oracle
RUN wget https://download.oracle.com/otn_software/linux/instantclient/19800/oracle-instantclient${ORACLE_VERSION}-basic-${ORACLE_VERSION}.0.0.0-1.x86_64.rpm && \
  wget https://download.oracle.com/otn_software/linux/instantclient/19800/oracle-instantclient${ORACLE_VERSION}-devel-${ORACLE_VERSION}.0.0.0-1.x86_64.rpm && \
  wget https://download.oracle.com/otn_software/linux/instantclient/19800/oracle-instantclient${ORACLE_VERSION}-sqlplus-${ORACLE_VERSION}.0.0.0-1.x86_64.rpm && \
  alien -i oracle-instantclient${ORACLE_VERSION}-basic-*.rpm && \
  alien -i oracle-instantclient${ORACLE_VERSION}-devel-*.rpm && \
  alien -i oracle-instantclient${ORACLE_VERSION}-sqlplus-*.rpm
ENV LD_LIBRARY_PATH=/usr/lib/oracle/${ORACLE_VERSION}/client64/lib/${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
ENV ORACLE_HOME=/usr/lib/oracle/${ORACLE_VERSION}/client64
RUN ln -s /usr/include/oracle/${ORACLE_VERSION}/client64 $ORACLE_HOME/include
ENV PATH=$PATH:$ORACLE_HOME/bin
RUN ldconfig

# Download & compile GDAL
WORKDIR ${INSTALL_DIR}
RUN wget https://github.com/OSGeo/gdal/releases/download/v${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz && \
  tar xvzf gdal-*.tar.gz
WORKDIR ${INSTALL_DIR}/gdal-${GDAL_VERSION}
COPY configure .
RUN chown 1000:1000 configure && \
  chmod +x configure && \
  ./configure --with-oci=yes --with-oci-lib=${ORACLE_HOME}/lib --with-oci-include=${ORACLE_HOME}/include --with-pg=yes && \
  make && \
  make install && \
  ldconfig
WORKDIR /root
RUN rm -rf ${INSTALL_DIR}

RUN apt-get -y autoremove build-essential wget git alien