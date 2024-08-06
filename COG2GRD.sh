#!/bin/bash
#example of usage: COG2GRD.sh -i '/tmp/S1A_IW_GRDH_1SDV_20230206T165050_20230206T165115_047118_05A716_2626_COG.zip' -o /tmp
#developed by CloudFerro 
#contact jmusial@cloudferro.com
###############################
#release notes:
#Version 1.00 [20230602] - initial release
version="1.00"
usage()
{
cat << EOF
#usage: $0 options
This utility converts compressed (zipped) GRD .SAFE product in .COG format (cloud optimized geotiff) into compressed (zipped) GRD .SAFE product in .tiff.
Warning GDAL version >= 3.6 is required.
OPTIONS:
   -h      this message
   -i      Sentinel-1 GRD_COG.SAFE compressed product in .zip
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
			COG_zip=$OPTARG
			;;
		o)  
			out_dir=$OPTARG  
			;;
		v)
			echo GRD_decogifier version $version
			exit 0
			;;
		?)
			usage
			exit 1
			;;
	esac
done

[ "${COG_zip##*_}" != "COG.zip" ] && echo "ERROR: $COG_zip does not appear to be a valid GRD COG file." && exit 1
[ -z $(which jacksum) ] && echo "ERROR: jacksum utility not installed. Please visit https://jacksum.net." && exit 1
[ -z $(which xmlstarlet) ] && echo "ERROR: xmlstarlet utility not installed. Please type in cmd: sudo apt install xmlstarlet" && exit 1
[ -z $(which gdal_translate) ] && echo "ERROR: GDAL library not installed. Please type in cmd: sudo apt install gdal-bin" && exit 1
[ -z "$out_dir" ] && out_dir=$(dirname $GRD_zip)
 
cd $out_dir
unzip $COG_zip -d $out_dir
out_dir=${out_dir}/$(basename ${COG_zip} .zip).SAFE
input_cogs=$(find $out_dir -name "*.tiff")
output_manifest=${out_dir}/manifest.safe
for input_cog in $input_cogs; do
	output_tmp=${input_cog%-*}'.tmp'
	output_tiff=${input_cog%-*}'.tiff' 
	read -r original_footer_size original_header_size < <(gdalinfo -nogcp $input_cog | grep 'GRD_ORIGINAL_FOOTER\|GRD_ORIGINAL_HEADER' | cut -f 2 -d '=' | tr '\n' ' ')
	gdal_translate -of GTIFF -co NUM_THREADS=ALL_CPUS $input_cog $output_tmp
	tiff_IFD_offset=$(od -An -j 4 -N 4 -i $output_tmp | tr -d ' ')
	tiff_ntags=$(od -An -j $tiff_IFD_offset -N 2 -i $output_tmp | tr -d ' ')
	read -r tag_size tag_offset < <(seq 0 $tiff_ntags | head -n -1 | xargs -I {} bash -c "echo \$(od -An -j \$(echo '$tiff_IFD_offset + 2 + {} * 12'  | bc ) -N 2 -i $output_tmp) \$(od -An -j \$(echo '$tiff_IFD_offset + 2 + 4 + {} * 12'  | bc ) -N 4 -i $output_tmp) \$(od -An -j \$(echo '$tiff_IFD_offset+2+8+{}*12' | bc) -N 4 -l $output_tmp)" | grep 273 | cut -f 2- -d ' ')
	read -r strip_start strip_end < <(od -An -j $tag_offset -N $(echo "${tag_size}*4"| bc) -t u4 -w4 $output_tmp  | sed -e 1b -e '$!d' | tr -d ' ' | tr '\n' ' ')
	strip_end=$(echo "$strip_end + $(od -An -j $(echo "$tiff_IFD_offset + 2 + 8" | bc) -N 2 -i $output_tmp)*2" | bc)
	tail -c $original_header_size $input_cog | gzip -d > $output_tiff
	tail -c +$((1+$strip_start)) $output_tmp >> $output_tiff 
	tail -c $(("$original_footer_size+$original_header_size")) $input_cog | head -c $original_footer_size | gzip -d >> $output_tiff	
	tiff_size=$(du -b $output_tiff | cut -f1)
	md5_sum=$(md5sum $output_tiff | cut -f1 -d ' ')
	xmlstarlet ed --inplace \
	-u 'xfdu:XFDU/dataObjectSection/dataObject[ @ID = "'$(basename $input_cog -cog.tiff | tr -d '-')'"]/byteStream/fileLocation/@href' -v "./measurement/$(basename $output_tiff)" \
	-u 'xfdu:XFDU/dataObjectSection/dataObject[ @ID = "'$(basename $input_cog -cog.tiff | tr -d '-')'"]/byteStream/checksum' -v "$md5_sum" \
	-u 'xfdu:XFDU/dataObjectSection/dataObject[ @ID = "'$(basename $input_cog -cog.tiff | tr -d '-')'"]/byteStream/@size' -v "$tiff_size" \
	$output_manifest
	rm $input_cog $output_tmp
done
xmlstarlet ed --inplace \
-m '/xfdu:XFDU/metadataSection/metadataObject[ @ID = "processing"]/metadataWrap/xmlData/safe:processing/safe:resource/safe:processing' '/xfdu:XFDU/metadataSection/metadataObject[ @ID = "processing"]/metadataWrap/xmlData' \
-d '/xfdu:XFDU/metadataSection/metadataObject[ @ID = "processing"]/metadataWrap/xmlData/safe:processing[ @name = "COG Conversion"]' \
-i '/xfdu:XFDU/metadataSection/metadataObject[ @ID = "processing"]/metadataWrap/xmlData/safe:processing/safe:resource/safe:processing' -t attr -n 'xmlns' -v 'http://www.esa.int/safe/sentinel-1.0' $output_manifest
sed -i 's/processing xmlns="http:\/\/www.esa.int\/safe\/sentinel-1.0" name="SLC Processing"/processing name="SLC Processing"/g' $output_manifest
sed -i 's/-cog//g' $output_manifest
find ${out_dir} -name '*cog.xml' -exec sh -c 'mv {} $(echo {} | sed "s/-cog//g")' \;
CRC_16=$(jacksum -a 'crc:16,1021,FFFF,false,false,0' -X -F '#CHECKSUM' $output_manifest)
mv ${out_dir} $(echo $out_dir | rev | cut -f3- -d '_' | rev)_${CRC_16}.SAFE
out_dir=$(echo $out_dir | rev | cut -f3- -d '_' | rev)_${CRC_16}.SAFE
zip -rm ${out_dir%.*}.zip $(basename $out_dir)
exit 0
