#!/bin/bash

# photoalbum (c) 2011 - 2014 by Paul C. Buetow
# http://photoalbum.buetow.org

declare -r VERSION='PHOTOALBUMVERSION'
declare -r DEFAULTRC=/etc/default/photoalbum

declare -r ARG1="${1}" ; shift
declare    RC="${1}"   ; shift

if [ -z "${RC}" ]; then
  RC="${DEFAULTRC}"
fi

if [ ! -f "${RC}" ]; then
  echo "Error: Can not find config file ${RC}" >&2
  exit 1
fi

function usage() {
  cat - <<USAGE >&2
  Usage: 
  $0 clean|init|version|generate|all [rcfile]
USAGE
}

function init() {
  for dir in "${INCOMING_DIR}" "${DIST_DIR}/photos" "${DIST_DIR}/thumbs" "${DIST_DIR}/html"; do 
    [ -d "${dir}" ] || mkdir -vp "${dir}"
  done
}

function clean() {
  echo "Not deleting ${INCOMING_DIR} but ${DIST_DIR}"
  [ -d "${DIST_DIR}" ] && rm -Rf "${DIST_DIR}"
}

function tarball() {
  # Cleanup tarball from prev run if any
  find "${DIST_DIR}" -maxdepth 1 -type f -name \*.tar -delete

  if [ "${TARBALL_INCLUDE}" = yes ]; then
    local -r BASE=$(basename "${INCOMING_DIR}")

    echo "Creating tarball ${DIST_DIR}/${TARBALL_NAME} from ${INCOMING_DIR}"
    cd $(dirname "${INCOMING_DIR}")
    tar $TAR_OPTS  -f "${DIST_DIR}/${TARBALL_NAME}" "${BASE}"
    cd - &>/dev/null
  fi
}

function generate() {
  if [ ! -d "${INCOMING_DIR}" ]; then
    echo "ERROR: You may run init first, no such directory: ${INCOMING_DIR}" >&2
    exit 1
  fi
  if [ ! -d "${DIST_DIR}" ]; then
    echo "ERROR: You may run init first, no such directory: ${DIST_DIR}" >&2
    exit 1
  fi

  if [ "${TARBALL_INCLUDE}" = yes ]; then
    local -r BASE=$(basename "${INCOMING_DIR}")
    local -r NOW=$(date +'%Y-%m-%d-%H%M%S')
    # New global variable
    TARBALL_NAME="${BASE}-${NOW}${TARBALL_SUFFIX}"
  fi

  makescale
  find "${DIST_DIR}/html" -type f -name \*.html -delete
  makehtml "${DIST_DIR}/photos" "${DIST_DIR}/html"
  template index ../index
  tarball
}

function template() {
  local -r template=${1} ; shift
  local -r html=${1}     ; shift

  source "${TEMPLATE_DIR}/${template}.tmpl" >> "${DIST_DIR}/html/${html}.html"
}

function makescale() {
  cd "${INCOMING_DIR}" && find ./ -type f | sort | while read photo; do
    photo=$(sed 's#^\./##' <<< "${photo}")
    destphoto="${DIST_DIR}/photos/${photo}"
    destphoto_nospace=${destphoto// /_}

    dirname=$(dirname "${destphoto}")
    [ ! -d "${dirname}" ] && mkdir -p "${dirname}"

    if [ ! -f "${destphoto_nospace}" ]; then
      echo "Scaling ${photo} to ${destphoto_nospace}"
      convert -auto-orient \
        -geometry ${GEOMETRY} "${photo}" "${destphoto_nospace}"
    else
      echo "Not scaling ${photo} to ${destphoto_nospace}, already exists"
    fi
  done
}

function makehtml() {
  local dist_photo="${1}" ; shift
  local dist_html="${1}"  ; shift
  local -i num=1
  local -i i=0
  local name=page-${num}

  template header ${name} 
  template header-first-add ${name}

  cd "${dist_photo}" && find ./ -type f | sort | sed 's;^\./;;' |
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

    if [ ! -f "${DIST_DIR}/thumbs/${photo}" ]; then 
      echo "Creating thumb for ${photo}";
      dirname=$(dirname "${DIST_DIR}/thumbs/${photo}")
      [ ! -d "${dirname}" ] && mkdir -p "${dirname}"
      convert -geometry x${THUMBGEOMETRY} "${photo}" \
        "${DIST_DIR}/thumbs/${photo}"
    else
      echo "Not creating thumb for ${photo}, already exists";
    fi
  done

  template footer $(cd "${DIST_DIR}/html";ls -t page-*.html | head -n 1 | sed 's/.html//')

  cd "${dist_html}" && ls *.html | grep -v page- | cut -d'-' -f1 | uniq |
  while read prefix; do 
    declare page=$(ls -t ${prefix}-*.html |
    head -n 1 | sed 's#\(.*\)-.*.html#\1#')

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

    template redirect ${nextredirect}
  done
}

function makemake() {
  [ ! -f ./photoalbumrc ] && cp /etc/default/photoalbum ./photoalbumrc
  cat <<MAKEFILE > ./Makefile
all:
	photoalbum all photoalbumrc
clean:
	photoalbum clean photoalbumrc
MAKEFILE
  echo You may now customize ./photoalbumrc and run make
}

source "${RC}"

if [ -f ~/.photoalbumrc ]; then
  source ~/.photoalbumrc
fi

case "${ARG1}" in
  all)
    init
    generate
    ;;
  init)
    init
    ;;
  clean)
    clean
    ;;
  generate)
    generate
    ;;
  version)
    echo "This is Photoalbum Version ${VERSION}"
    ;;
  makemake)
    makemake
    ;;
  *)
    usage
    ;;
esac

exit 0

