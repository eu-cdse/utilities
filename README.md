# Copernicus Data Space Ecosystem (CDSE) Utilities

This repository contains various utilities for reformating/(pre)processing of Sentinel data published within the Copernicus Data Space Ecosystem project.

## Build a Docker container

Build the cdse_utilities Docker image:

```
docker build --no-cache https://github.com/j-musial/utilities.git -t cdse_utilities
```
## Importnat Note: Handling of the inpout/output directories using [Bind Mounts](https://docs.docker.com/storage/bind-mounts/) in Docker
The local storage of your computer can be attached directly to the Docker Container as a Bind Mount. Consequently, you can easily manage ingestion/outputing data directly from/to your local storage. For instance:
```
docker run -it -v /home/JohnLane:/home/ubuntu  
```
maps the content of the local home directory name /home/JohnLane to the /home/ubuntu directory in the Docker container.

## Extract a single Senitnel-1 SLC burst using Docker environment:
```
docker run -it -v /home/ubuntu:/home/ubuntu -e AWS_ACCESS_KEY_ID=YOUR_CDSE_ACCESS_KEY -e AWS_SECRET_ACCESS_KEY=YOUR_CDSE_SECRET_KEY cdse_utilities sentinel1_burst_extractor.sh -o /home/ubuntu -n S1A_IW_SLC__1SDH_20240201T085352_20240201T085422_052363_0654EE_5132.SAFE -p hh -s iw1 -r 301345
```
Click [here](https://eodata-s3keysmanager.dataspace.copernicus.eu/) to generate CDSE S3 credentials. For more information on the CDSE S3 API please click [here](https://documentation.dataspace.copernicus.eu/APIs/S3.html).

## Convert Sentinel-1 GRD poduct from [GeoTIFF](https://gdal.org/drivers/raster/gtiff.html) to [COG](https://gdal.org/drivers/raster/cog.html) format 
```
sudo docker run -it -v /home/ubuntu:/home/ubuntu cdse_utilities GRD2COG.sh -i /home/ubuntu/S1A_IW_GRDH_1SDV_20230206T165050_20230206T165115_047118_05A716_53C5.SAFE.zip -o /home/ubuntu
```

## Convert Sentinel-1 COG GRD poduct from [COG](https://gdal.org/drivers/raster/cog.html) to [GeoTIFF](https://gdal.org/drivers/raster/gtiff.html) format
```
sudo docker run -it -v /home/ubuntu:/home/ubuntu cdse_utilities COG2COG.sh -i /home/ubuntu/docker_test/S1A_IW_GRDH_1SDV_20230206T165050_20230206T165115_047118_05A716_1A19_COG.SAFE.zip -o /home/ubuntu
```
