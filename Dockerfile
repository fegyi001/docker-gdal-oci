FROM ubuntu:20.04

# Set time zone
ENV TZ=Europe/Budapest
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV POSTGRES_VERSION 12
ENV POSTGIS_VERSION 3

RUN apt-get -y update && \ 
  apt-get install -y wget gnupg2 && \
  # PostreSQL repo
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
  echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list && \
  # Install libs
  apt-get -y install \ 
    wget build-essential git cmake sqlite3 libsqlite3-dev libtiff-dev libcurl4-openssl-dev alien libaio1  \
    postgis postgresql-${POSTGRES_VERSION}-postgis-${POSTGIS_VERSION} pkg-config libpq-dev python3 python3-pip

ENV INSTALL_DIR /opt/install
RUN mkdir -p ${INSTALL_DIR}
WORKDIR ${INSTALL_DIR}

# Install Proj
ENV PROJ_VERSION 7.1.1
RUN git clone --depth 1 --branch ${PROJ_VERSION} https://github.com/OSGeo/PROJ.git
WORKDIR ${INSTALL_DIR}/PROJ
RUN mkdir build 
WORKDIR ${INSTALL_DIR}/PROJ/build
RUN cmake .. && \
  cmake --build . && \
  cmake --build . --target install

# Install Oracle client
# https://help.ubuntu.com/community/Oracle%20Instant%20Client
RUN mkdir -p ${INSTALL_DIR}/oracle
WORKDIR ${INSTALL_DIR}/oracle
ENV ORACLE_VERSION 19.8
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
ENV GDAL_VERSION 3.1.3
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

# Update C env vars so compiler can find gdal
ENV CPLUS_INCLUDE_PATH=/usr/local/include
ENV C_INCLUDE_PATH=/usr/local/include

# Install python libs
WORKDIR ${INSTALL_DIR}
COPY requirements.txt .
RUN pip3 install numpy==1.19.2 && \
  pip3 install GDAL==${GDAL_VERSION} --global-option=build_ext --global-option="-I/usr/local/include" && \
  pip3 install -r requirements.txt

WORKDIR /root

# Uninstall unnecessary dependencies and delete install folder
RUN apt-get -y autoremove build-essential wget git alien && \
  rm -rf ${INSTALL_DIR}

