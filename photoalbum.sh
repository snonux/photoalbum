#!/bin/bash 

# Small quick n dirty photo album script
# 2011, 2012, 2013 Paul Buetow

source photoalbum.conf

function template () {
  local -r template=${1} ; shift
  local -r html=${1}     ; shift
  local destdir=${1}     ; shift

  if [ -z "${destdir}" ]; then
    destdir=./dist/html/
  fi

  if [ -d ./templates/ ]; then
    source ./templates/${template}.tmpl >> ${destdir}/${html}.html
  else
    source ../../templates/${template}.tmpl >> ../../${destdir}/${html}.html
  fi
}

function createdirs () {
  for dir in ./dist/{photos,thumbs,html}; do 
    [ -d ${dir} ] || mkdir -vp ${dir}
  done
}

function scale () {
  cd "${INCOMING}" || exit 1
  find . -type f | sed 's#^\./##' | 
  while read photo; do
    # Flatten directories / to __
    destphoto="${photo//\//__}"

    if [ ! -f "../dist/photos/${destphoto}" ]; then
      echo "Scaling ${photo} to ../dist/photos/${destphoto}"

      convert -auto-orient \
        -geometry ${GEOMETRY} "${photo}" "../dist/photos/${destphoto}"
    fi
  done
  cd - &>/dev/null

  echo 'Removing spaces from file names'
  find ./dist/photos -type f -name '* *' |
  while read file; do
    rename 's/ /_/g' "${file}" 
  done
}

function generate () {
  local num=1
  local name=page-${num}
  local -i i=0

  template header ${name} 
  template header-first-add ${name}

  cd ./dist/photos || exit 1

  find ./ -type f | sort | sed 's#^\./##' |
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

  cd - &>/dev/null

  template footer $(cd ./dist/html;ls -t page-*.html | head -n 1 | sed 's/.html//')

  # Generate HTTP redirect pages
  ls ./dist/html/*.html | grep -v page- | cut -d'-' -f1 | uniq |
  while read prefix; do 
    declare page=$(ls -t ${prefix}-*.html | head -n 1 | sed 's#./dist/html/\(.*\)-.*.html#\1#')
    declare lastview=$(ls -t ${prefix}-*.html | head -n 1 | sed 's/.*-\(.*\).html/\1/')

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

    template redirect ${nextredirect}
  done
}

function tarball () {
  # Cleanup tarball from prev run if any
  find ./dist/ -maxdepth 1 -type f -name \*.tar -delete

  if [ "${INCLUDETARBALL}" = 'yes' ]; then
    echo Creating tarball
    mv "${INCOMING}" "${TARBALLNAME}" 
    tar $TAROPTS  -f "./dist/${TARBALLNAME}${TARBALLSUFFIX}" "${TARBALLNAME}"
    mv "${TARBALLNAME}" "${INCOMING}"
  fi
}

createdirs
scale
find ./dist/ -type f -name \*.html -delete
template index index ./dist
generate
tarball

