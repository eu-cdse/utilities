#!/bin/bash
#example of usage: GRD2COG.sh -i S1A_IW_GRDH_1SDV_20230206T165050_20230206T165115_047118_05A716_53C5.SAFE.zip -o /tmp
#developed by CloudFerro 
#contact jmusial@cloudferro.com
###############################
#release notes:
#Version 1.00 [20230602] - initial release  
#Version 1.01 [20240808] - change generated file name to COG.SAFE.zip instead of COG.zip
version="1.01"
usage()
{
cat << EOF
#usage: $0 options
This utility converts compressed (zipped) GRD .SAFE product in .tiff format into compressed (zipped) GRD .SAFE product in COG format (cloud optimized geotiff).
Warning: GDAL version >= 3.6 is required.
OPTIONS:
   -h      this message
   -i      Sentinel-1 GRD.SAFE compressed product in .zip
   -o      output directory. If not specified the output file will be created in the SAFE.zip directory 
   -v      version

EOF
}
while getopts “hi:o:v” OPTION; do
	case $OPTION in
		h)
			usage
			exit 0
			;;
		i)
			GRD_zip=$OPTARG
			;;
		o)  
			out_dir=$OPTARG  
			;;
		v)
			echo GRD_cogifier version $version
			exit 0
			;;
		?)
			usage
			exit 1
			;;
	esac
done
[ "${GRD_zip##*_}" == "COG.zip" ] && echo "ERROR: $GRD_zip has been already converted to COG." && exit 1
[ -z $(which jacksum) ] && echo "ERROR: jacksum utility not installed. Please visit https://jacksum.net." && exit 1
[ -z $(which xmlstarlet) ] && echo "ERROR: xmlstarlet utility not installed. Please type in cmd: sudo apt install xmlstarlet" && exit 1
[ -z $(which gdal_translate) ] && echo "ERROR: GDAL library not installed. Please type in cmd: sudo apt install gdal-bin" && exit 1
[ -z "$out_dir" ] && out_dir=$(dirname $GRD_zip) 
start_time=$(date --utc --iso-8601=ns | cut -c-26 | tr ',' '.')
unzip $GRD_zip -d $out_dir
out_dir=${out_dir}/$(basename ${GRD_zip} .zip | sed 's/.SAFE//g').SAFE
cd $out_dir
input_tiffs=$(find $out_dir -name "*.tiff") 
output_manifest=${out_dir}/manifest.safe
for input_tiff in $input_tiffs; do
	output_tiff=${input_tiff%.*}'-cog.tiff'
	tiff_IFD_offset=$(od -An -j 4 -N 4 -i $input_tiff | tr -d ' ')
	tiff_ntags=$(od -An -j $tiff_IFD_offset -N 2 -i $input_tiff | tr -d ' ')
	read -r tag_size tag_offset < <(seq 0 $tiff_ntags | head -n -1 | xargs -I {} bash -c "echo \$(od -An -j \$(echo '$tiff_IFD_offset + 2 + {} * 12'  | bc ) -N 2 -i $input_tiff) \$(od -An -j \$(echo '$tiff_IFD_offset + 2 + 4 + {} * 12'  | bc ) -N 4 -i $input_tiff) \$(od -An -j \$(echo '$tiff_IFD_offset+2+8+{}*12' | bc) -N 4 -l $input_tiff)" | grep 273 | cut -f 2- -d ' ')
	read -r strip_start strip_end < <(od -An -j $tag_offset -N $(echo "${tag_size}*4"| bc) -t u4 -w4 $input_tiff  | sed -e 1b -e '$!d' | tr -d ' ' | tr '\n' ' ')
	strip_end=$(echo "$strip_end + $(od -An -j $(echo "$tiff_IFD_offset + 2 + 8" | bc) -N 2 -i $input_tiff)*2" | bc)
	original_header_size=$(head -c $strip_start $input_tiff | gzip -c | wc -c)
	original_footer_size=$(tail -c +$((1+$strip_end)) $input_tiff | gzip -c | wc -c)
	gdal_translate -of COG -a_nodata 0 -co OVERVIEW_COUNT=6 -co BLOCKSIZE=1024 -co BIGTIFF=NO -co OVERVIEW_RESAMPLING=RMS -co COMPRESS=ZSTD -co NUM_THREADS=ALL_CPUS -mo GRD_ORIGINAL_HEADER_SIZE=$original_header_size -mo GRD_ORIGINAL_FOOTER_SIZE=$original_footer_size $input_tiff $output_tiff
	tail -c +$((1+$strip_end)) $input_tiff | gzip -c >> $output_tiff
	head -c $strip_start $input_tiff | gzip -c >> $output_tiff
	md5_sum=$(md5sum $output_tiff | cut -f1 -d ' ')
	tiff_size=$(du -b $output_tiff | cut -f1)
	xmlstarlet ed --inplace \
	-u 'xfdu:XFDU/dataObjectSection/dataObject[ @ID = "'$(basename $input_tiff .tiff | tr -d '-')'"]/byteStream/fileLocation/@href' -v "./measurement/$(basename $output_tiff)" \
	-u 'xfdu:XFDU/dataObjectSection/dataObject[ @ID = "'product$(basename $input_tiff .tiff | tr -d '-')'"]/byteStream/fileLocation/@href' -v "./annotation/$(basename $output_tiff .tiff).xml" \
	-u 'xfdu:XFDU/dataObjectSection/dataObject[ @ID = "'noise$(basename $input_tiff .tiff | tr -d '-')'"]/byteStream/fileLocation/@href' -v "./annotation/calibration/noise-$(basename $output_tiff .tiff).xml" \
	-u 'xfdu:XFDU/dataObjectSection/dataObject[ @ID = "'rfi$(basename $input_tiff .tiff | tr -d '-')'"]/byteStream/fileLocation/@href' -v "./annotation/rfi/rfi-$(basename $output_tiff .tiff).xml" \
	-u 'xfdu:XFDU/dataObjectSection/dataObject[ @ID = "'calibration$(basename $input_tiff .tiff | tr -d '-')'"]/byteStream/fileLocation/@href' -v "./annotation/calibration/calibration-$(basename $output_tiff .tiff).xml" \
	-u 'xfdu:XFDU/dataObjectSection/dataObject[ @ID = "'$(basename $input_tiff .tiff | tr -d '-')'"]/byteStream/checksum' -v "$md5_sum" \
	-u 'xfdu:XFDU/dataObjectSection/dataObject[ @ID = "'$(basename $input_tiff .tiff | tr -d '-')'"]/byteStream/@size' -v "$tiff_size" \
	$output_manifest
	[ -r ./annotation/$(basename $output_tiff -cog.tiff).xml ] && mv ./annotation/$(basename $output_tiff -cog.tiff).xml ./annotation/$(basename $output_tiff .tiff).xml
	[ -r ./annotation/calibration/noise-$(basename $output_tiff -cog.tiff).xml ] && mv ./annotation/calibration/noise-$(basename $output_tiff -cog.tiff).xml ./annotation/calibration/noise-$(basename $output_tiff .tiff).xml
	[ -r ./annotation/rfi/rfi-$(basename $output_tiff -cog.tiff).xml ] && mv ./annotation/rfi/rfi-$(basename $output_tiff -cog.tiff).xml ./annotation/rfi/rfi-$(basename $output_tiff .tiff).xml
	[ -r ./annotation/calibration/calibration-$(basename $output_tiff -cog.tiff).xml ] && mv ./annotation/calibration/calibration-$(basename $output_tiff -cog.tiff).xml ./annotation/calibration/calibration-$(basename $output_tiff .tiff).xml
	rm $input_tiff
done
end_time=$(date --utc --iso-8601=ns | cut -c-26 | tr ',' '.')
xmlstarlet ed --inplace \
-s 'xfdu:XFDU/metadataSection/metadataObject[ @ID = "processing"]/metadataWrap/xmlData' -t elem -n 'safe:processing' \
--var PROCESSING '$prev' \
-s '$PROCESSING' -t elem -name 'safe:facility' \
--var FACILITY '$prev' \
-a '$PROCESSING' -t attr -name 'name' -v 'COG Conversion' \
-a '$PROCESSING' -t attr -name 'start' -v "$start_time" \
-a '$PROCESSING' -t attr -name 'stop' -v "$end_time" \
-s '$FACILITY' -t elem -name 'safe:software' \
--var SOFTWARE '$prev' \
-a '$FACILITY' -t attr -name 'country' -v 'Poland' \
-a '$FACILITY' -t attr -name 'name' -v 'Copernicus Data Space Ecosystem' \
-a '$FACILITY' -t attr -name 'organisation' -v 'CloudFerro' \
-a '$FACILITY' -t attr -name 'site' -v 'Copernicus Data Space Ecosystem-CloudFerro' \
-a '$SOFTWARE' -t attr -name 'name' -v 'Sentinel-1 COGifier' \
-a '$SOFTWARE' -t attr -name 'version' -v "$version" \
-s '$PROCESSING' -t elem -name 'safe:resource' \
--var RESOURCE '$prev' \
-a '$RESOURCE' -t attr -name 'name' -v "$(basename ${GRD_dir} | sed 's/.SAFE//g').SAFE" \
-a '$RESOURCE' -t attr -name 'role' -v 'Level-1 GRD Product' \
-m 'xfdu:XFDU/metadataSection/metadataObject/metadataWrap/xmlData/safe:processing[not(name = "COG Conversion")]' '$RESOURCE' \
$output_manifest
CRC_16=$(jacksum -a 'crc:16,1021,FFFF,false,false,0' -X -F '#CHECKSUM' $output_manifest)
cd ..
mv ${out_dir} ${out_dir%_*}_${CRC_16}_COG.SAFE
out_dir=${out_dir%_*}_${CRC_16}_COG.SAFE
zip -0rm ${out_dir%.*}.SAFE.zip $(basename $out_dir)
exit 0
