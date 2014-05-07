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
  find "${DIST_DIR}" -type f -name \*.html -delete

  # Figure out wether we want sub-albums or not
  # TODO: Refactor, store dirs in a Bash Array
  dirs=$(find "${DIST_DIR}/photos" -mindepth 1 -maxdepth 1 -type d | head | wc -l)
  if [[ "${SUB_ALBUMS}" != yes || ${dirs} -eq 0 ]]; then
    makealbumhtml photos html thumbs ..

  else
    IS_SUBALBUM=yes
    find "${DIST_DIR}/photos" -mindepth 1 -maxdepth 1 -type d |
    while read dir; do
      basename=$(basename "${dir}")
      makealbumhtml "photos/${basename}" "html/${basename}" "thumbs/${basename}" ../..
    done
    # Create an album selection screen
    makealbumoverviewhtml
  fi

  # Create top level index/redirect page
  HTML_DIR=./
  REDIRECT_PAGE=./html/index
  template redirect index

  tarball
}

function template() {
  local -r template=${1}  ; shift
  local -r html=${1}      ; shift
  local -r dist_html="${DIST_DIR}/${HTML_DIR}"

  #echo "Creating ${dist_html}/${html}.html from ${template}.tmpl"
  [ ! -d "${dist_html}" ] && mkdir -p "${dist_html}"
  source "${TEMPLATE_DIR}/${template}.tmpl" >> "${dist_html}/${html}.html"
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
    fi
  done
}

function makealbumhtml() {
  # First initialize some globals (used as template vars)
  PHOTOS_DIR="${1}" ; shift
  HTML_DIR="${1}"   ; shift
  THUMBS_DIR="${1}" ; shift
  BACKHREF="${1}"   ; shift

  local -i num=1
  local -i i=0
  local name=page-${num}

  template header ${name}
  template header-first-add ${name}

  cd "${DIST_DIR}/${PHOTOS_DIR}" && find ./ -type f | sort | sed 's;^\./;;' |
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

    if [ ! -f "${DIST_DIR}/${THUMBS_DIR}/${photo}" ]; then 
      echo "Creating thumb ${DIST_DIR}/${THUMBS_DIR}/${photo}";
      dirname=$(dirname "${DIST_DIR}/${THUMBS_DIR}/${photo}")
      [ ! -d "${dirname}" ] && mkdir -p "${dirname}"
      convert -geometry x${THUMBGEOMETRY} "${photo}" \
        "${DIST_DIR}/${THUMBS_DIR}/${photo}"
    fi
  done

  template footer $(cd "${DIST_DIR}/${HTML_DIR}";ls -t page-*.html |
  head -n 1 | sed 's/.html//') "${DIST_DIR}/${HTML_DIR}"

  cd "${DIST_DIR}/${HTML_DIR}" && ls *.html | grep -v page- | cut -d'-' -f1 | uniq |
  while read prefix; do 
    declare page=$(ls -t ${prefix}-*.html |
    head -n 1 | sed 's#\(.*\)-.*.html#\1#')

    declare lastview=$(ls -t ${prefix}-*.html |
    head -n 1 | sed 's/.*-\(.*\).html/\1/')

    declare prevredirect=${page}-0
    declare nextredirect=${page}-$((lastview+1))

    REDIRECT_PAGE=$(( page-1 ))-${MAXPREVIEWS}
    template redirect ${prevredirect}

    if [ ${lastview} -eq ${MAXPREVIEWS} ]; then
      REDIRECT_PAGE=$(( page+1 ))-1
    else
      REDIRECT_PAGE=${page}-${lastview}
      template redirect 0-${MAXPREVIEWS}

      REDIRECT_PAGE=1-1
    fi

    template redirect ${nextredirect}
  done

  # Create per album index/redirect page
  REDIRECT_PAGE=page-1
  template redirect index
}

function makealbumoverviewhtml() {
  HTML_DIR=html
  BACKHREF=..
  IS_SUBALBUM=no

  template header index
  template header-first-add index

  find "${DIST_DIR}/photos" -mindepth 1 -maxdepth 1 -type d | sort |
  while read dir; do
    basename=$(basename "$dir")
    ALBUM=$basename
    thumbs_dir="${DIST_DIR}/thumbs/${basename}"
    pictures=$(ls "${thumbs_dir}" | wc -l)
    random=$(( 1 + $RANDOM % $pictures ))
    RANDOM_THUMB="./thumbs/${basename}"/$(find "$thumbs_dir" -type f -printf "%f\n" |
    head -n $random | tail -n 1)
    pages=$(( $pictures / $MAXPREVIEWS + 1))
    test $pages -gt 1 && s=s || s=''
    DESCRIPTION="${pictures} pictures / ${pages} page$s"
    template index-preview index 
  done

  template footer index
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

if [ -f "${RC}" ]; then
  source "${RC}"
else
  if [ -f ~/.photoalbumrc ]; then
    source ~/.photoalbumrc
  fi
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

