#!/bin/bash

if test -z "$2" -o -z "$3" -o "$1" == "--help" ; then
  echo 'Usage:'
  echo "  $0 <basenameofvideo> <fps> <YoutubeURL>"
  echo "  e.g.: for a.mp4 at 10 fps from youtu.be/JwgFS1uh05I do '$0 a 10 \"https://www.youtube.com/watch?v=JwgFS1uh05I\"'."
  exit 1
fi

#export vidname="$1"
export fps="$2"
export url="$3"
export subfile="$1.en.vtt"
export subtype="VTT"

echo "Downloading $1.mp4 from $url"
youtube-dl -o "$1.mp4" --write-auto-sub --sub-format vtt -f 'mp4[height<480]' "$url"

mkdir ./frames
echo "Extracting frames - very CPU intensive and will take some time!"
ffmpeg -i "$1.mp4" -r $fps -s 512x288 -f image2 "frames/$1_%05d.png"

export numframes=`ls ./frames/$1_?????.png | wc -l`
echo "$numframes frames extracted."

mkdir ./itxt
echo "Creating itxt files - fairly CPU intensive and may take some time!"
for i in `seq 1 $numframes`; do
  export n=`printf %05d $i`
  echo "Converting frame $n ($1_$n.png)"
  ./pngtoitxt "./frames/$1_$n.png" "./itxt/$1_it_$n.txt" 7 15
  echo -ne "\033[2A"
done
echo -ne "\033[2B"

mkdir ./subs
echo "Extracting subtitles for each frame..."
for i in `seq 1 $numframes`; do
  export n=`printf %05d $i`
  export h=$((($i / (3600 * $fps)) % 24))
  export hh=`printf "%02d" $h`
  export m=$((($i / (60 * $fps)) % 60))
  export mm=`printf "%02d" $m`
  export s=$((($i / $fps) % 60))
  export ss=`printf "%02d" $s`
  export l=$((($i % $fps) * (1000 / $fps)))
  export lll=`printf "%03d" $l`
  ./subextractor "$subfile" "./subs/$1_sub_$n.txt" "$hh:$mm:$ss,$lll" "$subtype"
  echo "Extracted subtitle at $hh:$mm:$ss,$lll to ./subs/$1_sub_$n.txt"
  echo -ne "\033[A"
done
echo -ne "\033[B"

mkdir ./itxts
echo "Overlaying subtitles on each frame..."
for i in `seq 1 $numframes`; do
  export n=`printf %05d $i`
  ./itxtsub "./itxt/$1_it_$n.txt" "./itxts/$1_its_$n.txt" "./subs/$1_sub_$n.txt"
  echo "Overlaying subtitles on $n."
  echo -ne "\033[2A"
done
echo -ne "\033[2B"

mkdir ./ansi
echo "Creating ANSI frames..."
for i in `seq 1 $numframes`; do
  export n=`printf %05d $i`
  ./itxttoansi "./itxts/$1_its_$n.txt" "./ansi/$1_ansi_$n.txt"
  echo "Converting frame $n."
  echo -ne "\033[A"
done
echo -ne "\033[B"

echo "Creating 'play' script (running at $fps fps)..."

export sleepval=`printf 0.%02d $((100 / $fps))`
echo "#!/bin/sh" > "./ansi/play.sh"
echo "for i in " `seq 1 $numframes` "; do" >> "./ansi/play.sh"
echo '  export n=`printf %05d $i`' >> "./ansi/play.sh"
echo '  echo -ne "\033[H\033[J" ' >> "./ansi/play.sh"
echo "  cat $1_ansi_\$n.txt" >> "./ansi/play.sh"
echo "  sleep $sleepval" >> "./ansi/play.sh"
echo "done" >> "./ansi/play.sh"
chmod +x "./ansi/play.sh"

echo "Conversion Complete!"
echo "Enter the 'ansi' directory and run ./play.sh to watch."

exit 0


