#!/bin/bash

# photoalbum (c) 2011 - 2014 by Paul Buetow
# http://photoalbum.buetow.org

declare -r ARG1="${1}" ; shift
declare -r VERSION='PHOTOALBUMVERSION'
declare -r DEFAULTRC=/etc/default/photoalbum

usage() {
  cat - <<USAGE >&2
  Usage: 
  $0 [clean|init|version|generate|all]
USAGE
}

init() {
  for dir in "${INCOMING_DIR}" "${DIST_DIR}/photos" "${DIST_DIR}/thumbs" "${DIST_DIR}/html"; do 
    [ -d "${dir}" ] || mkdir -vp "${dir}"
  done
}

clean() {
  echo "Not deleting ${INCOMING_DIR}"
  [ -d "${DIST_DIR}" ] && rm -Rf "${DIST_DIR}"
}

tarball() {
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

generate() {
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

  scale
  find "${DIST_DIR}/html" -type f -name \*.html -delete
  makedist 1
  template index ../index
  tarball
}

template() {
  local -r template=${1} ; shift
  local -r html=${1}     ; shift

  source "${TEMPLATE_DIR}/${template}.tmpl" >> "${DIST_DIR}/html/${html}.html"
}

scale() {
  cd "${INCOMING_DIR}" && find ./ -type f | sort | while read photo; do
    photo=$(sed 's#^\./##' <<< "${photo}")

    if [ ! -f "${DIST_DIR}/photos/${photo}" ]; then
      # Flatten directories / to __
      if [[ "${photo}" =~ / ]]; then
        destphoto="${photo//\//__}"
      else
        destphoto="${photo}"
      fi

      echo "Scaling ${photo} to ${DIST_DIR}/photos/${destphoto}"

      convert -auto-orient \
        -geometry ${GEOMETRY} "${photo}" "${DIST_DIR}/photos/${destphoto}"
    fi
  done

  echo 'Removing spaces from file names'
  find "${DIST_DIR}/photos" -type f -name '* *' | while read file; do
    rename 's/ /_/g' "${file}" 
  done
}

makedist() {
  local num=${1} ; shift
  local name=page-${num}
  local -i i=0

  template header ${name} 
  template header-first-add ${name}

  cd "${DIST_DIR}/photos" && find ./ -type f | sort | sed 's;^\./;;' |
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
      convert -geometry x${THUMBGEOMETRY} "${photo}" \
        "${DIST_DIR}/thumbs/${photo}"
    fi
  done

  template footer $(cd "${DIST_DIR}/html";ls -t page-*.html | head -n 1 | sed 's/.html//')

  cd "${DIST_DIR}/html" && ls *.html | grep -v page- | cut -d'-' -f1 | uniq |
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

source "${DEFAULTRC}"

if [ -f ~/.photoalbumrc ]; then
  source ~/.photoalbumrc
fi

case "${ARG1}" in
  all)
    clean
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
  *)
    usage
    ;;
esac

exit 0

