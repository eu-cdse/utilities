# CDSE Utilities

This repository contains various utilities for reformating/(pre)processing Sentinel data published within the Copernicus Data Space Ecosystem project.

## Run via Docker container

Download the official repository, then from the extracted directory build the image:

```
docker build -t cdse_utilities:latest .
```
Now run the container:
```
docker run -it -e AWS_ACCESS_KEY_ID=YOUR_CDSE_ACCESS_KEY -e AWS_SECRET_ACCESS_KEY=YOUR_CDSE_SECRET_KEY cdse_utilities:latest /bin/bash
```
To generate S3 se can be generated according to the instructions at Copernicus Data Space Documentation (https://documentation.dataspace.copernicus.eu/APIs/S3.html).

## Example usage
sentinel1_burst_extractor
```
sentinel1_burst_extractor.sh -o /home/ubuntu -n S1A_IW_SLC__1SDH_20240201T085352_20240201T085422_052363_0654EE_5132.SAFE -p hh -s iw1 -r 301345
```
GRD2COG
```
GRD2COG.sh -i S1A_IW_GRDH_1SDV_20230206T165050_20230206T165115_047118_05A716_53C5.SAFE.zip -o /tmp
```
COG2GRD
```
COG2GRD.sh -i S1A_IW_GRDH_1SDV_20230206T165050_20230206T165115_047118_05A716_1A19_COG.SAFE.zip -o /tmp
```
