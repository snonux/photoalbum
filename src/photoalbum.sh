#!/bin/bash

# photoalbum (c) 2011 - 2014 by Paul C. Buetow
# http://photoalbum.buetow.org

declare -r VERSION='0.3.1develop'
declare -r DEFAULTRC=/etc/default/photoalbum
declare -r ARG1="${1}" ; shift
declare    RC_FILE="${1}"   ; shift

function usage() {
  cat - <<USAGE >&2
  Usage: 
  $0 clean|init|version|generate|all [rcfile]
USAGE
}

function clean() {
  [ -d "${DIST_DIR}" ] && rm -Rf "${DIST_DIR}"
}

function tarball() {
  # Cleanup tarball from prev run if any
  find "${DIST_DIR}" -maxdepth 1 -type f -name \*.tar -delete

  if [ "${TARBALL_INCLUDE}" = yes ]; then
    local -r base=$(basename "${INCOMING_DIR}")

    echo "Creating tarball ${DIST_DIR}/${tarball_name} from ${INCOMING_DIR}"
    cd $(dirname "${INCOMING_DIR}")
    tar $TAR_OPTS  -f "${DIST_DIR}/${tarball_name}" "${base}"
    cd - &>/dev/null
  fi
}

function template() {
  local -r template=${1}  ; shift
  local -r html=${1}      ; shift
  local -r dist_html="${DIST_DIR}/${html_dir}"

  #echo "Creating ${dist_html}/${html}.html from ${template}.tmpl"
  [ ! -d "${dist_html}" ] && mkdir -p "${dist_html}"
  source "${TEMPLATE_DIR}/${template}.tmpl" >> "${dist_html}/${html}.html"
}

function generate() {
  if [ ! -d "${INCOMING_DIR}" ]; then
    echo "ERROR: You have to create ${INCOMING_DIR} first" >&2
    exit 1
  fi

  if [ "${TARBALL_INCLUDE}" = yes ]; then
    local -r base=$(basename "${INCOMING_DIR}")
    local -r now=$(date +'%Y-%m-%d-%H%M%S')
    declare -r tarball_name="${base}-${now}${TARBALL_SUFFIX}"
  fi

  makescale

  find "${DIST_DIR}" -type f -name \*.html -delete
  local -a dirs=( $(find "${DIST_DIR}/photos" -mindepth 1 -maxdepth 1 -type d |
    sort) )

  # Figure out wether we want sub-albums or not
  if [[ "${SUB_ALBUMS}" != yes || ${#dirs[*]} -eq 0 ]]; then
    declare is_subalbum=no
    makealbumhtml photos html thumbs ..

  else
    declare is_subalbum=yes
    for dir in ${dirs[*]}; do
      local basename=$(basename "${dir}")
      makealbumhtml \
        "photos/${basename}" "html/${basename}" "thumbs/${basename}" ../..
    done
    # Create an album selection screen
    makealbumindexhtml "${dirs[*]}"
  fi

  # Create top level index/redirect page
  html_dir=./
  redirect_page=./html/index
  template redirect index

  tarball
}

function makescale() {
  cd "${INCOMING_DIR}" && find ./ -type f | sort | while read photo; do
    declare photo=$(sed 's#^\./##' <<< "${photo}")
    declare destphoto="${DIST_DIR}/photos/${photo}"
    declare destphoto_nospace=${destphoto// /_}

    declare dirname=$(dirname "${destphoto}")
    [ ! -d "${dirname}" ] && mkdir -p "${dirname}"

    if [ ! -f "${destphoto_nospace}" ]; then
      echo "Scaling ${photo} to ${destphoto_nospace}"
      convert -auto-orient \
        -geometry ${GEOMETRY} "${photo}" "${destphoto_nospace}"
    fi
  done
}

function makealbumhtml() {
  # First initialize some globals (used as template vars)
  photos_dir="${1}" ; shift
  html_dir="${1}"   ; shift
  thumbs_dir="${1}" ; shift
  backhref="${1}"   ; shift
  declare is_subalbum=no

  local -i num=1
  local -i i=0
  local name=page-${num}
  local next=''

  template header ${name}
  template header-first-add ${name}

  cd "${DIST_DIR}/${photos_dir}" && find ./ -type f | sort | sed 's;^\./;;' |
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

    if [ ! -f "${DIST_DIR}/${thumbs_dir}/${photo}" ]; then 
      echo "Creating thumb ${DIST_DIR}/${thumbs_dir}/${photo}";
      dirname=$(dirname "${DIST_DIR}/${thumbs_dir}/${photo}")
      [ ! -d "${dirname}" ] && mkdir -p "${dirname}"
      convert -geometry x${THUMBGEOMETRY} "${photo}" \
        "${DIST_DIR}/${thumbs_dir}/${photo}"
    fi
  done

  template footer $(cd "${DIST_DIR}/${html_dir}";ls -t page-*.html |
  head -n 1 | sed 's/.html//') "${DIST_DIR}/${html_dir}"

  cd "${DIST_DIR}/${html_dir}" && ls *.html | grep -v page- | cut -d'-' -f1 | uniq |
  while read prefix; do 
    declare page=$(ls -t ${prefix}-*.html |
    head -n 1 | sed 's#\(.*\)-.*.html#\1#')

    declare lastview=$(ls -t ${prefix}-*.html |
    head -n 1 | sed 's/.*-\(.*\).html/\1/')

    declare prevredirect=${page}-0
    declare nextredirect=${page}-$((lastview+1))

    redirect_page=$(( page-1 ))-${MAXPREVIEWS}
    template redirect ${prevredirect}

    if [ ${lastview} -eq ${MAXPREVIEWS} ]; then
      redirect_page=$(( page+1 ))-1
    else
      redirect_page=${page}-${lastview}
      template redirect 0-${MAXPREVIEWS}

      redirect_page=1-1
    fi

    template redirect ${nextredirect}
  done

  # Create per album index/redirect page
  redirect_page=page-1
  template redirect index
}

function makealbumindexhtml() {
  local -a dirs=( "${1}" )
  html_dir=html
  backhref=..

  template header index
  template header-first-add index

  for dir in ${dirs[*]}; do
    declare basename=$(basename "$dir")
    declare album=$basename
    declare thumbs_dir="${DIST_DIR}/thumbs/${basename}"
    declare pictures=$(ls "${thumbs_dir}" | wc -l)
    declare random_num=$(( 1 + $RANDOM % $pictures ))
    declare random_thumb="./thumbs/${basename}"/$(find \
      "$thumbs_dir" -type f -printf "%f\n" |
      head -n $random_num | tail -n 1)
    declare pages=$(( $pictures / $MAXPREVIEWS + 1))
    [ $pages -gt 1 ] && s=s || s=''
    declare description="${pictures} pictures / ${pages} page$s"
    template index-preview index 
  done

  template footer index
}

function makemake() {
  [ ! -f ./photoalbumrc ] && cp /etc/default/photoalbum ./photoalbumrc
  cat <<MAKEFILE > ./Makefile
all:
	photoalbum generate photoalbumrc
clean:
	photoalbum clean photoalbumrc
MAKEFILE
  echo You may now customize ./photoalbumrc and run make
}

if [ -z "${RC_FILE}" ]; then
  if [ -f ~/.photoalbumrc ]; then
    RC_FILE=~/.photoalbumrc
  else
    RC_FILE="${DEFAULTRC}"
  fi
fi

if [ ! -f "${RC_FILE}" ]; then
  echo "Error: Can not find config file ${RC_FILE}" >&2
  exit 1
fi

source "${RC_FILE}"

case "${ARG1}" in
  all)      clean; generate;;
  clean)    clean;;
  generate) generate;;
  version)  echo "This is Photoalbum Version ${VERSION}";;
  makemake) makemake;;
  *)        usage;;
esac

exit 0

