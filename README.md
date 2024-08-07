# S1 Utilities

Bash functions for effective work with official Copernicus Programme Sentinel-1 products.

## Run via Docker container

Download the official repository, then from the extracted directory build the image:

```
docker build -t s1_utilities:latest .
```
Now run the container:
```
docker run -it -e AAWS_ACCESS_KEY_ID=*** \
           -e AWS_SECRET_ACCESS_KEY=*** \ 
           s1_utilities:latest /bin/bash
```
*** - These can be generated according to the instructions at Copernicus Data Space Documentation (https://documentation.dataspace.copernicus.eu/APIs/S3.html).

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
COG2GRD.sh -i '/tmp/S1A_IW_GRDH_1SDV_20230206T165050_20230206T165115_047118_05A716_2626_COG.zip' -o /tmp
```
