#!/bin/bash
# Example of usage
#./sentinel1_burst_extractor_spatiotemporal.sh -o /home/ubuntu -s 2024-08-02 -e 2024-08-08 -x 13.228 -y 52.516 -p vv
#To install dependencies on Debian-like disctributions please execute 4 lines below:
#curl -L -O 'https://github.com/peak/s5cmd/releases/download/v2.2.2/s5cmd_2.2.2_linux_amd64.deb'
#sudo dpkg -i s5cmd_2.2.2_linux_amd64.deb
#sudo apt update
#sudo apt install -y xmlstarlet bc jq
version="1.00"
usage()
{
cat << EOF
#usage: $0 options
This utility extract multiple Sentinel1 SLC bursts given the:
	-Copernicus Data Space Ecosystem S3 credentials
	-Latitude of a Point of Interest (POI)
	-Longitude of a Point of Interest (POI)
	-SAR polarization e.g. vv,vh,hh,hv
	-Start date in format YYYY-MM-DD
	-End date in format YYYY-MM-DD 
To obtain the Copernicus Data Space Ecosystem S3 credentials please visit https://eodata-s3keysmanager.dataspace.copernicus.eu/)
The credentials have to be exported as environmental variables by typing:

export AWS_ACCESS_KEY_ID='replace-this-with-your-cdse-s3-access-key-id'
export AWS_SECRET_ACCESS_KEY='replace-this-with-your-cdse-s3-secret-access-key'  

Warning: GDAL version has to be at least 3.9!

OPTIONS:
   -e      End date 
   -h      this message
   -o      output directory. If not specified the output file will be created in $PWD 
   -p      SAR polarization, one of: vv,vh,hh,hv 
   -s	   Start date
   -v      sentinel1_burst_extractor_spatiotemporal version
   -x	   Longitude of a point
   -y	   Latitude of a point
   -S	   SwathIdentifier
EOF
}
s3_endpoint='eodata.dataspace.copernicus.eu'
while getopts “he:o:p:s:S:x:y:v” OPTION; do
	case $OPTION in
		e)  
			end_date=$OPTARG  
			;;
		h)
			usage
			exit 0
			;;
		o)  
			out_path=$OPTARG  
			;;
		p)
			polarization=$OPTARG
			;;
		s)
			start_date=$OPTARG
			;;
		S)
			sub_swath=$OPTARG
			;;
		x)
			lon=$OPTARG  
			;;
		y)
			lat=$OPTARG  
			;;
		v)
			echo Burst extractor version $version
			exit 0
			;;
		?)
			usage
			exit 1
			;;
	esac
done
if [ -z $AWS_ACCESS_KEY_ID -o -z $AWS_SECRET_ACCESS_KEY ]; then
	echo 'Environmental variables AWS_ACCESS_KEY_ID and/or AWS_SECRET_ACCESS_KEY not defined. For more info visit: https://eodata-s3keysmanager.dataspace.copernicus.eu/' && exit 6
fi
gdal_version=$(gdalinfo --version | cut -c 6-11 | cut -f1 -d ',')
if awk -v gv=${gdal_version::1} 'BEGIN {exit !(gv < 3)}' ; then
	echo "GDAL version has to be at least 3.8" && exit 2
fi
if awk -v gv=${gdal_version:2:4} 'BEGIN {exit !(gv < 8)}' ; then
	echo "GDAL version has to be at least 3.8" && exit 2
fi
if [ -z $(which jq) ]; then
	echo "jq has not been found. Type 'sudo apt update && sudo apt install -y jq'" && exit 2
fi
if [ -z $(which bc) ]; then
	echo "bc has not been found. Type 'sudo apt update && sudo apt install -y bc'" && exit 2
fi
if [ -z $(which xmlstarlet) ]; then
	echo "xmlstarlet has not been found. Type 'sudo apt update && sudo apt install -y xmlstarlet'" && exit 2
fi
if [ -z $start_date ]; then 
	echo "Start date not defined" && exit 3
fi
if [ -z $sub_swath ]; then
	echo "sub_swath not defined" && exit 3
fi
if [ -z $end_date ]; then 
	echo "End date not defined" && exit 3
fi
if [ ! "$polarization" = "vv" -a ! "$polarization" = "vh" -a ! "$polarization" = "hh" -a ! "$polarization" = "hv" ]; then 
	echo "polarization '$polarization' not equals one of vv,vh,hh,hv" && exit 3
fi
if [ -z $lon ]; then 
	echo "Longitude (x) not defined" && exit 3
fi
if [ -z $lat ]; then 
	echo "Latitude (y) not defined" && exit 3
fi

set -x
wget -qO - 'https://catalogue.dataspace.copernicus.eu/odata/v1/Bursts?$filter=((SwathIdentifier%20eq%20%27'$sub_swath'%27)%20and%20(PolarisationChannels%20eq%20%27'$(echo $polarization | tr a-z A-Z)'%27)%20and%20(ContentDate/Start%20ge%20'$start_date'T00:00:00.000Z%20and%20ContentDate/Start%20le%20'$end_date'T23:59:59.999Z)%20and%20(OData.CSC.Intersects(Footprint=geography%27SRID=4326;POINT%20('$lon'%20'$lat')%27)))&$top=1000' | jq -r '.value[] | "sentinel1_burst_extractor.sh -p '$polarization' -o '$HOME' -n " + .ParentProductName + " -s " + (.SwathIdentifier|ascii_downcase) + " -r " + (.BurstId|tostring)' | xargs -i bash -c "{}"
set +x
exit 0
