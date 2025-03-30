#!/bin/bash

# Input image file
IMAGE_FILE="404.png"
IMAGE_NAME=$(basename "$IMAGE_FILE" | cut -d. -f1)

# Output directory
OUTPUT_DIR="output"
mkdir -p $OUTPUT_DIR/dash
mkdir -p $OUTPUT_DIR/hls

# Durasi video dalam detik
DURATION=60

# Resolusi dan bitrate
declare -A RESOLUTIONS
RESOLUTIONS["426x240"]="400k"
RESOLUTIONS["640x360"]="800k"
RESOLUTIONS["854x480"]="1200k"
RESOLUTIONS["1280x720"]="2400k"
RESOLUTIONS["1920x1080"]="4800k"

# Buat video dari gambar dengan berbagai resolusi
for RES in "${!RESOLUTIONS[@]}"; do
  BITRATE=${RESOLUTIONS[$RES]}
  ffmpeg -loop 1 -i $IMAGE_FILE -c:v libx264 -t $DURATION -s $RES -b:v $BITRATE -vf "fps=24,format=yuv420p" -f mp4 -y $OUTPUT_DIR/video_${RES}.mp4
done

# Buat file manifest DASH
ffmpeg \
  -re -i $OUTPUT_DIR/video_426x240.mp4 \
  -re -i $OUTPUT_DIR/video_640x360.mp4 \
  -re -i $OUTPUT_DIR/video_854x480.mp4 \
  -re -i $OUTPUT_DIR/video_1280x720.mp4 \
  -re -i $OUTPUT_DIR/video_1920x1080.mp4 \
  -map 0:v -map 1:v -map 2:v -map 3:v -map 4:v \
  -b:v:0 400k -b:v:1 800k -b:v:2 1200k -b:v:3 2400k -b:v:4 4800k \
  -use_timeline 1 -use_template 1 \
  -init_seg_name "${IMAGE_NAME}_init\$RepresentationID\$.m4s" \
  -media_seg_name "${IMAGE_NAME}_chunk\$RepresentationID\$_\$Number\$.m4s" \
  -adaptation_sets "id=0,streams=v" \
  -f dash -seg_duration 2 \
  -y $OUTPUT_DIR/dash/index.mpd

# Buat file playlist HLS
for RES in "${!RESOLUTIONS[@]}"; do
  BITRATE=${RESOLUTIONS[$RES]}
  ffmpeg -i $OUTPUT_DIR/video_${RES}.mp4 -c:v copy -hls_time 2 -hls_playlist_type vod -hls_segment_filename "$OUTPUT_DIR/hls/${IMAGE_NAME}_${RES}_%03d.ts" -b:v $BITRATE -y $OUTPUT_DIR/hls/video_${RES}.m3u8
done

# Buat master playlist HLS
echo "#EXTM3U" > $OUTPUT_DIR/hls/master.m3u8
for RES in "${!RESOLUTIONS[@]}"; do
  WIDTH=$(echo $RES | cut -d'x' -f1)
  HEIGHT=$(echo $RES | cut -d'x' -f2)
  BANDWIDTH=$((${RESOLUTIONS[$RES]//k/} * 1000))
  echo "#EXT-X-STREAM-INF:BANDWIDTH=$BANDWIDTH,RESOLUTION=$RES" >> $OUTPUT_DIR/hls/master.m3u8
  echo "video_${RES}.m3u8" >> $OUTPUT_DIR/hls/master.m3u8
done
