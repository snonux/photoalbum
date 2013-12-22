#!/bin/bash 

source photoalbum.conf

function createdirs () {
  for dir in photos thumbs html; do 
    [ -d ${dir} ] || mkdir -vp ${dir}
  done
}

function template () {
  local -r template=${1} ; shift
  local -r html=${1}     ; shift
  local destdir=${1}     ; shift

  if [ -z "${destdir}" ]; then
    destdir=html/
  fi

  if [ -d ./templates/ ]; then
    source ./templates/${template}.tmpl >> ./${destdir}/${html}.html
  else
    source ../templates/${template}.tmpl >> ../${destdir}/${html}.html
  fi
}

function scale () {
  cd ${INCOMING} && find ./ -type f | sort | while read photo; do
  if [ ! -f "../photos/${photo}" ]; then

    # Flatten directories / to __
    if [[ "${photo}" =~ / ]]; then
      destphoto="${photo//\//__}"
    else
      destphoto="${photo}"
    fi

    destphoto="${destphoto//./}"

    echo "Scaling ${photo} to ../photos/${destphoto}"

    convert -auto-orient \
      -geometry ${GEOMETRY} "${photo}" "../photos/${destphoto}"
  fi
  done

  echo 'Removing spaces from file names'
  find ../photos -type f -name '* *' | while read file; do
    rename 's/ /_/g' "${file}" 
  done

  cd ..
}

function generate () {
  local num=${1} ; shift
  local name=page-${num}
  local -i i=0

  template header ${name} 
  template header-first-add ${name}

  cd photos && find ./ -type f | sort | sed 's;^\./;;' |
  while read photo; do 
    : $(( i++ ))

    if [ ${i} -gt ${MAXPREVIEWS} ]; then
      i=1
      : $(( num++ ))

      next=page-${num}
      template next ${name}
      template footer ${name}

      prev=${name}
      name=${next}
      template header ${name} 
      template prev ${name}
    fi

    # Preview page
    template preview ${name}

    # View page
    template header ${num}-${i}
    template view ${num}-${i}
    template footer ${num}-${i}

    if [ ! -f "../thumbs/${photo}" ]; then 
      echo "Creating thumb for ${photo}";
      convert -geometry x${THUMBGEOMETRY} "${photo}" \
        "../thumbs/${photo}"
    fi
  done

  cd ..
  template footer $(cd html;ls -t page-*.html | head -n 1 | sed 's/.html//')

  ls html/*.html | grep -v page- | cut -d'-' -f1 | uniq | 
  while read prefix; do 

    declare page=$(ls -t ${prefix}-*.html |
    head -n 1 | sed 's#html/\(.*\)-.*.html#\1#')

    declare lastview=$(ls -t ${prefix}-*.html |
    head -n 1 | sed 's/.*-\(.*\).html/\1/')

    declare prevredirect=${page}-0
    declare nextredirect=${page}-$((lastview+1))

    redirectpage=$(( page-1 ))-${MAXPREVIEWS}
    template redirect ${prevredirect}

    if [ ${lastview} -eq ${MAXPREVIEWS} ]; then
      redirectpage=$(( page+1 ))-1
    else
      redirectpage=${page}-${lastview}
      template redirect 0-${MAXPREVIEWS}

      redirectpage=1-1
    fi

    template redirect ${next}redirect
  done
}

createdirs
scale
find ./html -type f -name \*.html -delete
generate 1
template index index .
