FROM ghcr.io/osgeo/gdal:ubuntu-small-3.9.1

# Install necessary packages
RUN apt-get update && \
    apt-get install -y \
        jq \
        xmlstarlet \
        zip \
        default-jre \
        bc \
        nano \
        wget \
        python3-pip \
        curl \
        parallel \
        dpkg && \
    rm -rf /var/lib/apt/lists/*

# Download and install jacksum and s5cmd
RUN curl -L -O 'https://s3.waw3-2.cloudferro.com/swift/v1/jacksum/jacksum_1.7.0-4.1_all.deb' && \
    dpkg -i jacksum_1.7.0-4.1_all.deb && rm jacksum_1.7.0-4.1_all.deb && \
    curl -L -O 'https://github.com/peak/s5cmd/releases/download/v2.2.2/s5cmd_2.2.2_linux_amd64.deb' && \
    dpkg -i s5cmd_2.2.2_linux_amd64.deb && rm s5cmd_2.2.2_linux_amd64.deb

# Copy and set permissions for scripts
COPY COG2GRD.sh /bin/COG2GRD.sh
COPY GRD2COG.sh /bin/GRD2COG.sh
COPY sentinel1_burst_extractor.sh /bin/sentinel1_burst_extractor.sh

RUN chmod +x /bin/COG2GRD.sh /bin/GRD2COG.sh /bin/sentinel1_burst_extractor.sh

# Set environment variables
ENV AWS_S3_ENDPOINT=eodata.dataspace.copernicus.eu \
    # AWS_ACCESS_KEY_ID=ACCESS \
    # AWS_SECRET_ACCESS_KEY=DATA \
    AWS_HTTPS=YES \
    AWS_VIRTUAL_HOSTING=FALSE

# You can uncomment and set the working directory if needed
# WORKDIR /app
# COPY . .
