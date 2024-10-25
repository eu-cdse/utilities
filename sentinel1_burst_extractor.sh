#!/bin/bash
# Example of usage
#./sentinel1_burst_extractor.sh -o /home/ubuntu/burst_test_v3 -n S1A_IW_SLC__1SDH_20240201T085352_20240201T085422_052363_0654EE_5132.SAFE -p hh -s iw1 -r 301345
#./sentinel1_burst_extractor.sh -o /home/ubuntu/burst_test_v3 -n S1A_IW_SLC__1SDV_20141012T051707_20141012T051734_002792_003250_1FD5.SAFE -p vh -s iw3 -r 202680
#developed by CloudFerro 
#contact jmusial@cloudferro.com
###############################
#release notes:
#Version 1.00 [20240807] - initial release
#Version 1.10 [20241025] - adjustments of annotation and manifest files
#To install dependencies on Debian-like disctributions please execute 4 lines below:
#curl -L -O 'https://github.com/peak/s5cmd/releases/download/v2.2.2/s5cmd_2.2.2_linux_amd64.deb'
#sudo dpkg -i s5cmd_2.2.2_linux_amd64.deb
#sudo apt update
#sudo apt install -y xmlstarlet bc jq
version="1.10"
usage()
{
cat << EOF
#usage: $0 options
This utility extract a single Sentinel1 SLC burst given the:
	-Copernicus Data Space Ecosystem S3 credentials
	-Sentinel-1 SLC TOPSAR product name e.g. S1A_IW_SLC__1SDH_20240201T085352_20240201T085422_052363_0654EE_5132.SAFE
	-SAR polarization e.g. vv
	-subswath ID e.g. iw3
	-realtive burst ID e.g. 202680
To obtain the Copernicus Data Space Ecosystem S3 credentials please visit https://eodata-s3keysmanager.dataspace.copernicus.eu/)
The credentials have to be exported as environmental variables by typing:

export AWS_ACCESS_KEY_ID='replace-this-with-your-cdse-s3-access-key-id'
export AWS_SECRET_ACCESS_KEY='replace-this-with-your-cdse-s3-secret-access-key'  

OPTIONS:
   -e      S3 endpoint. Default is eodata.dataspace.copernicus.eu 
   -h      this message
   -n	   name of the Sentinel-1 SLC product e.g. S1A_IW_SLC__1SDH_20240201T085352_20240201T085422_052363_0654EE_5132.SAFE 
   -o      output directory. If not specified the output file will be created in $PWD 
   -p      SAR polarization, one of: vv,vh,hh,hv 
   -s	   Sentinel-1 subswath ID, one of iw1,iw2,iw3,ew1,ew2,ew3
   -r	   Sentinel-1 relative burst ID, eg. 301345
   -v      sentinel1_burst_extractor version
EOF
}
s3_endpoint='eodata.dataspace.copernicus.eu'
while getopts “he:n:o:p:r:s:v” OPTION; do
	case $OPTION in
		e)  
			s3_endpoint=$OPTARG  
			;;
		h)
			usage
			exit 0
			;;
		n)  
			product_name=$OPTARG  
			;;
		o)  
			out_path=$OPTARG  
			;;
		p)
			polarization=$OPTARG
			;;
		r)
			relative_burst_id=$OPTARG
			;;
		s)
			subswath_id=$OPTARG
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
if [ -z $product_name ]; then 
	echo "Sentinel-1 SLC product name not defined" && exit 3
fi
in_path=$(curl --retry 5 --retry-all-errors -sS -L 'https://catalogue.dataspace.copernicus.eu/odata/v1/Products?$filter=((Name%20eq%20%27'${product_name}'%27))' | jq -r '.value.[].S3Path')
if [ -z $in_path ]; then 
	echo "Sentinel-1 SLC product '$product_name' not found in the Copernicus Data Space Ecosystem repository" && exit 4
fi
if [ -z $relative_burst_id ]; then 
	echo "Sentinel-1 relative burst ID not defined" && exit 3
fi
if [ ! "$polarization" = "vv" -a ! "$polarization" = "vh" -a ! "$polarization" = "hh" -a ! "$polarization" = "hv" ]; then 
	echo "polarization '$polarization' not equals one of vv,vh,hh,hv" && exit 3
fi
case $subswath_id in
	iw1)
		T0_delta="0$(echo 'scale=8;0.81531490/2.0'|bc)";;
	iw2)
		T0_delta="0$(echo 'scale=8;1.06087913/2.0'|bc)";;
	iw3)
		T0_delta="0$(echo 'scale=8;0.83045822/2.0'|bc)";;
	ew1)
		T0_delta="0$(echo 'scale=8;0.66551400/2.0'|bc)";;
	ew2)
		T0_delta="0$(echo 'scale=8;0.54139519/2.0'|bc)";;
	ew3)
		T0_delta="0$(echo 'scale=8;0.59473403/2.0'|bc)";;
	ew4)
		T0_delta="0$(echo 'scale=8;0.54745052/2.0'|bc)";;
	ew5)
		T0_delta="0$(echo 'scale=8;0.60098234/2.0'|bc)";;
	*)
		echo "subswath '$subswath_id' not equals one of iw1,iw2,iw3,ew1,ew2,ew3,ew4,ew5" && exit 3 ;;
esac
annotation_xml=$(s5cmd --endpoint-url "https://${s3_endpoint}" -r 5 ls --show-fullpath "s3:/${in_path}/annotation/s1*${subswath_id}-slc-${polarization}*.xml" 2>&1)
if [ $(printf "$annotation_xml" | grep -c 'EC2MetadataError') -eq 1 ]; then
	echo "ERROR:Failed to connect with $s3_endpoint" && exit 7
fi
annotation_data=$(s5cmd --endpoint-url "https://${s3_endpoint}" -r 5 cat $annotation_xml)
manifest_data=$(s5cmd --endpoint-url "https://${s3_endpoint}" -r 5 cat s3:/${in_path}/manifest.safe)
datatake_id=$(printf "$annotation_data" | xmlstarlet sel -t -m '/product/generalAnnotation/downlinkInformationList/downlinkInformation/downlinkValues' -v dataTakeId | awk '{printf("%06d",$1)}')
number_of_lines=$(printf "$annotation_data" | xmlstarlet sel -t -m '/product/swathTiming' -v linesPerBurst)
number_of_samples=$(printf "$annotation_data" | xmlstarlet sel -t -m '/product/swathTiming' -v samplesPerBurst)
burst_number=$(printf "$annotation_data" | xmlstarlet sel -t -m "//burst/burstId" -v . -n | grep -B 1000 ${relative_burst_id} | wc -l)
if [ $burst_number -eq 0 ]; then
	T0_b1=$(printf "$annotation_data" | xmlstarlet sel -t -m "/product/swathTiming/burstList/burst" -n -v sensingTime | grep . | xargs -i date -d {} "+%s.%N") 
	Tanx=$(printf "$manifest_data" | xmlstarlet sel -t -m 'xfdu:XFDU/metadataSection/metadataObject/metadataWrap/xmlData/safe:orbitReference/safe:extension/s1:orbitProperties' -v 's1:ascendingNodeTime' | xargs -i date -d {} "+%s.%N")
	Or=$(printf "$manifest_data" | xmlstarlet sel -t -m "xfdu:XFDU/metadataSection/metadataObject/metadataWrap/xmlData/safe:orbitReference/safe:relativeOrbitNumber[@type='start']" -v '.')
	#constants
	Od=$(echo "scale=8;12*24*3600/175" | bc)
	if [ "${subswath_id:0:2}" == 'iw' ]; then
		Tbeam=2.758273
		T_pre=2.299849
	else
		Tbeam=3.038376
		T_pre=2.299970
	fi
	BurstIds=$(printf "$T0_b1" | xargs -i echo "1 + ((({} + $T0_delta - $Tanx)+($Or-1)*$Od) - $T_pre)/$Tbeam;" | bc)
	burst_number=$(printf "$BurstIds" | grep -B 1000 ${relative_burst_id} | wc -l)
	if [ $burst_number -eq 0 ]; then
		echo "Relative burst id '$relative_burst_id' not found in the ${product_name}" && exit 5 
	fi
fi

burst_byteoffset=$(printf "$annotation_data" | xmlstarlet sel -t -m "/product/swathTiming/burstList/burst" -n -v byteOffset | grep . | head -${burst_number} | tail -1)
burst_sensing_start=$(printf "$annotation_data" | xmlstarlet sel -t -m "/product/swathTiming/burstList/burst[byteOffset=$burst_byteoffset]" -v sensingTime | tr -d '\-\:' | cut -f 1 -d '.')
burst_sensing_start_date=$(echo ${burst_sensing_start:0:19} | tr -d '\-\.\:')
burst_azimuth_start=$(printf "$annotation_data" | xmlstarlet sel -t -m "product/swathTiming/burstList/burst[byteOffset=$burst_byteoffset]" -v azimuthTime)
pri=$(printf "$annotation_data" | xmlstarlet sel -t -m "product/generalAnnotation/downlinkInformationList/downlinkInformation/downlinkValues/pri" -v '.')
TZ='UTC'
burst_azimuth_end=$(date --date '@'"$(echo $(date --date "$burst_azimuth_start" '+%s.%N')+$number_of_lines*$(printf '%.20f' $pri) | bc)" +'%Y-%m-%dT%H:%M:%S.%N' | sed 's/...$//')
relative_burst_id=$(printf '%06d' ${relative_burst_id})
starting_line=$(echo "(${burst_number}-1)*${number_of_lines}" | bc)
ending_line=$((${starting_line}+${number_of_lines}))
platform_number=$(printf "$manifest_data" | xmlstarlet sel -t -m 'xfdu:XFDU/metadataSection/metadataObject/metadataWrap/xmlData/safe:platform/safe:number' -v '.')
[ -z $out_path ] && out_path="./S1${platform_number}_SLC_"${burst_sensing_start_date}_${relative_burst_id}_$(echo ${subswath_id}| tr a-z A-Z)_$(echo ${polarization}| tr a-z A-Z)_${datatake_id}.SAFE || out_path=${out_path}"/S1${platform_number}_SLC_"${burst_sensing_start_date}_${relative_burst_id}_$(echo ${subswath_id}| tr a-z A-Z)_$(echo ${polarization}| tr a-z A-Z)_${datatake_id}.SAFE
new_pattern=${annotation_xml: -68:15}${relative_burst_id}-${burst_sensing_start}-${datatake_id}
new_pattern_short=$(echo $new_pattern | tr -d '-')
mkdir -p ${out_path}/measurement/ ${out_path}/annotation/calibration/

annotation_data=$(printf "$annotation_data" | xmlstarlet ed \
-d "product/swathTiming/burstList/burst[byteOffset!=$burst_byteoffset]" \
-d "product/geolocationGrid/geolocationGridPointList/geolocationGridPoint[line<$starting_line]" \
-d "product/geolocationGrid/geolocationGridPointList/geolocationGridPoint[line>$ending_line]" \
-u "product/geolocationGrid/geolocationGridPointList/geolocationGridPoint[line=$starting_line]/line" -v 0 \
-u "product/geolocationGrid/geolocationGridPointList/geolocationGridPoint[line=$ending_line]/line" -v $number_of_lines \
-u 'product/swathTiming/burstList/@count' -v 1 -u 'product/imageAnnotation/imageInformation/@numberOfLines' -v ${number_of_lines} \
-u 'product/imageAnnotation/imageInformation/numberOfLines' -v ${number_of_lines} \
-u "product/imageAnnotation/imageInformation/productFirstLineUtcTime" -v $burst_azimuth_start \
-u "product/adsHeader/startTime" -v $burst_azimuth_start \
-u "product/imageAnnotation/imageInformation/productLastLineUtcTime" -v $burst_azimuth_end \
-u "product/adsHeader/stopTime" -v $burst_azimuth_end)
printf "$annotation_data">${out_path}/annotation/${new_pattern}.xml
s5cmd --endpoint-url "https://${s3_endpoint}" -r 5 cat $(echo $annotation_xml | sed 's/annotation\//annotation\/calibration\/calibration-/g') | xmlstarlet ed \
-u 'calibration/calibrationVectorList/calibrationVector/line' -x ".-$starting_line" \
-u 'calibration/adsHeader/startTime' -v $burst_azimuth_start \
-u 'calibration/adsHeader/stopTime' -v $burst_azimuth_end >${out_path}/annotation/calibration/calibration-${new_pattern}.xml

s5cmd --endpoint-url "https://${s3_endpoint}" -r 5 cat $(echo $annotation_xml | sed 's/annotation\//annotation\/calibration\/noise-/g') | xmlstarlet ed \
-u 'noise/noiseRangeVectorList/noiseRangeVector/line' -x ".-$starting_line" \
-u 'noise/adsHeader/startTime' -v $burst_azimuth_start \
-u 'noise/adsHeader/stopTime' -v $burst_azimuth_end>${out_path}/annotation/calibration/noise-${new_pattern}.xml
if [ "$(s5cmd --endpoint-url "https://${s3_endpoint}" -r 5 ls s3:/${in_path}/annotation/ | grep -c rfi)" -eq "1" ]; then
	mkdir -p ${out_path}/annotation/rfi/
	s5cmd --endpoint-url "https://${s3_endpoint}" -r 5 cat $(echo $annotation_xml | sed 's/annotation\//annotation\/rfi\/rfi-/g') | xmlstarlet ed -u 'rfi/adsHeader/startTime' -v $burst_azimuth_start -u 'rfi/adsHeader/stopTime' -v $burst_azimuth_end >${out_path}/annotation/rfi/rfi-${new_pattern}.xml
fi

new_gcps=$(printf "$annotation_data" | xmlstarlet sel -t -m 'product/geolocationGrid/geolocationGridPointList/geolocationGridPoint' -v "concat('gcp=',pixel,',',line,',',longitude,',',latitude,',',height,'|')"| tr '|' '&')
footprint=$(printf "$annotation_data" | xmlstarlet sel -t -m 'product/geolocationGrid/geolocationGridPointList/geolocationGridPoint[line=0]' -v "concat(number(longitude),' ',number(latitude),',')" | awk -F',' 'BEGIN{OFS=","}{print($1,$(NF-1))}')
footprint=${footprint}','$(printf "$annotation_data" | xmlstarlet sel -t -m 'product/geolocationGrid/geolocationGridPointList/geolocationGridPoint[not(line=0)]' -v "concat(number(longitude),' ',number(latitude),',')" | awk -F',' 'BEGIN{OFS=","}{print($(NF-1),$1)}')','"${footprint%,*}"

printf "$manifest_data" | sed "s/${annotation_xml: -68:64}/${new_pattern}/g" | sed "s/$(echo ${annotation_xml: -68:64} | tr -d '-')/$(echo ${new_pattern} | tr -d '-')/g" | xmlstarlet ed \
-u 'xfdu:XFDU/metadataSection/metadataObject/metadataWrap/xmlData/safe:acquisitionPeriod/safe:startTime' -v ${burst_azimuth_start} \
-u 'xfdu:XFDU/metadataSection/metadataObject/metadataWrap/xmlData/safe:acquisitionPeriod/safe:stopTime' -v $burst_azimuth_end \
-u 'xfdu:XFDU/dataObjectSection/dataObject/byteStream/checksum' -v '' \
-u 'xfdu:XFDU/dataObjectSection/dataObject/byteStream/@size' -v '' \
-u 'xfdu:XFDU/metadataSection/metadataObject/metadataWrap/xmlData/safe:frameSet/safe:frame/safe:footPrint/gml:coordinates' -v "$footprint" \
-d 'xfdu:XFDU/dataObjectSection/dataObject[@ID = "quicklook"]' \
-d 'xfdu:XFDU/dataObjectSection/dataObject[@ID = "mapoverlay"]' \
-d 'xfdu:XFDU/dataObjectSection/dataObject[@ID = "productpreview"]' \
-d 'xfdu:XFDU/metadataSection/metadataObject/metadataWrap/xmlData/safe:platform/safe:instrument/safe:extension/s1sarl1:instrumentMode/s1sarl1:swath[not(text()="'$(echo $subswath_id | tr [:lower:] [:upper:])'")]' \
-d 'xfdu:XFDU/dataObjectSection/dataObject[not(contains(@ID,"'$new_pattern_short'"))]' \
-d 'xfdu:XFDU/metadataSection/metadataObject/dataObjectPointer[not(contains(@dataObjectID,"'$new_pattern_short'"))]/..' \
-d 'xfdu:XFDU/informationPackageMap/xfdu:contentUnit/xfdu:contentUnit/dataObjectPointer[not(contains(@dataObjectID,"'$new_pattern_short'"))]/..' \
-d 'xfdu:XFDU/metadataSection/metadataObject[@classification="SYNTAX"]' > ${out_path}/manifest.safe

gdal_translate -of GTiff --config AWS_S3_ENDPOINT ${s3_endpoint} --config GDAL_HTTP_MAX_RETRY 5 --config AWS_HTTPS YES --config AWS_VIRTUAL_HOSTING FALSE --config NUM_THREADS -1 --config COMPRESS ZSTD vrt:///vsis3$(echo ${annotation_xml:4:-3} | sed 's/annotation\//measurement\//g')tiff?${new_gcps}srcwin=0,${starting_line},${number_of_samples},${number_of_lines} ${out_path}/measurement/${new_pattern}.tiff
