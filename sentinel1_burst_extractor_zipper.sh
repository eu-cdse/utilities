#!/bin/bash
#release notes:
#Version 1.00 [20241025] - initial release
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
This utility extract a single Sentinel1 SLC burst given. Example of usage:
./sentinel1_burst_extractor_zipper.sh -o /home/ubuntu/burst_test_v4 -i /eodata/Sentinel-1/SAR/IW_SLC__1S/2024/08/28/S1A_IW_SLC__1SDV_20240828T170133_20240828T170200_055416_06C252_8591.SAFE -p vh -s iw3 -r 92688 -b 777784419 -e eodata.dataspace.copernicus.eu

To obtain the Copernicus Data Space Ecosystem S3 credentials please visit https://eodata-s3keysmanager.dataspace.copernicus.eu/)
The credentials have to be exported as environmental variables by typing:

export AWS_ACCESS_KEY_ID='replace-this-with-your-cdse-s3-access-key-id'
export AWS_SECRET_ACCESS_KEY='replace-this-with-your-cdse-s3-secret-access-key'  

OPTIONS:
   -b      Burst byte offset. Odata counterpart: ByteOffset
   -e      S3 endpoint. Default is eodata.dataspace.copernicus.eu 
   -h      this message
   -i	   path to root dir of a Sentinel-1 SLC product. eg.  Odata counterpart:S3Path 
   -o      output directory. If not specified the output file will be created in $PWD 
   -p      SAR polarization, one of: vv,vh,hh,hv Odata counterpart:
   -s	   Sentinel-1 subswath ID, one of iw1,iw2,iw3,ew1,ew2,ew3,ew4,ew5,ew6 Odata counterpart: SwathIdentifier
   -r	   Sentinel-1 relative burst ID, eg. 301345 Odata counterpart: BurstId
   -v      sentinel1_burst_extractor_zipper.sh version 
EOF
}

while getopts “hb:e:i:o:p:r:s:v” OPTION; do
	case $OPTION in
		b)
			burst_byteoffset=$OPTARG
			;;
		e)  
			s3_endpoint=$OPTARG  
			;;
		h)
			usage
			exit 0
			;;
		i)  
			in_path=$OPTARG  
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

annotation_xml=$(s5cmd --endpoint-url "https://${s3_endpoint}" -r 5 ls --show-fullpath "s3:/${in_path}/annotation/s1*${subswath_id}-slc-${polarization}*.xml" 2>&1)
annotation_data=$(s5cmd --endpoint-url "https://${s3_endpoint}" -r 5 cat $annotation_xml)
manifest_data=$(s5cmd --endpoint-url "https://${s3_endpoint}" -r 5 cat s3:/${in_path}/manifest.safe)
datatake_id=$(printf "$annotation_data" | xmlstarlet sel -t -m '/product/generalAnnotation/downlinkInformationList/downlinkInformation/downlinkValues' -v dataTakeId | awk '{printf("%06d",$1)}')
number_of_lines=$(printf "$annotation_data" | xmlstarlet sel -t -m '/product/swathTiming' -v linesPerBurst)
number_of_samples=$(printf "$annotation_data" | xmlstarlet sel -t -m '/product/swathTiming' -v samplesPerBurst)
burst_number=$(printf "$annotation_data" | xmlstarlet sel -t -m "//burst/byteOffset" -v . -n | grep -B 1000 ${burst_byteoffset} | wc -l)
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
