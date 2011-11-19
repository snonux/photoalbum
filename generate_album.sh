#!/bin/bash 

# Small image gallery script
# 2011 (c) Paul C. Buetow

declare -i THUMBGEOMETRY=250
declare -i GEOMETRY=800
declare -i MAXPREVIEWS=100

declare -r TITLE='Picture gallery'
declare -r INCOMING=./incoming

createdirs () {
        for dir in photos thumbs html; do 
                [ -d $dir ] || mkdir -vp $dir
        done
}

template () {
	local -r template=$1
	local -r html=$2

	if [ -d ./templates/ ]; then
		source ./templates/${template}.tmpl >> ./html/${html}.html
	else
		source ../templates/${template}.tmpl >> ../html/${html}.html
	fi
}

scale () {
	cd $INCOMING && find ./ -iname \*.jpg | sort | while read jpg; do
		if [ ! -f ../photos/$jpg ]; then
			echo Scaling $jpg
			convert -auto-orient \
				-geometry $GEOMETRY $jpg ../photos/$jpg; 
		fi
	done
	cd ..
}

generate () {
	local num=$1
	local name=page-${num}
	local -i i=0

	template header $name 
	template header-first-add $name

	cd photos && find ./ -iname \*.jpg | sort | sed 's;^\./;;' | \
		while read jpg; do 

		(( i++ ))

		if [ $i -gt $MAXPREVIEWS ]; then
			i=1
			(( num++ ))

			next=page-${num}
			template next $name
			template footer $name

			prev=$name
			name=$next
			template header $name 
			template prev $name
		fi

		# Preview page
		template preview $name

		# View page
		template header ${num}-${i}
		template view ${num}-${i}
		template footer ${num}-${i}

		if [ ! -f ../thumbs/$jpg ]; then 
			echo Creating thumb for $jpg;
			convert -geometry x$THUMBGEOMETRY $jpg \
				../thumbs/$jpg
		fi
	done
	cd ..

	template footer $(cd html;ls -t page-*.html | head -n 1 | sed 's/.html//')

	ls html/*.html | grep -v page- | cut -d'-' -f1 | uniq | \
		while read prefix; do 

		declare page=$(ls -t ${prefix}-*.html | \
			head -n 1 | sed 's#html/\(.*\)-.*.html#\1#')
		declare lastview=$(ls -t ${prefix}-*.html | \
			head -n 1 | sed 's/.*-\(.*\).html/\1/')
		declare prevredirect=${page}-0
		declare nextredirect=${page}-$((lastview+1))

		redirectpage=$(( page-1 ))-$MAXPREVIEWS
		template redirect $prevredirect

		if [ $lastview -eq $MAXPREVIEWS	]; then
			redirectpage=$(( page+1 ))-1
		else
			redirectpage=${page}-${lastview}
			template redirect 0-$MAXPREVIEWS

			redirectpage=1-1
		fi

		template redirect $nextredirect
	done
}

scale
rm html/*.html 2>/dev/null
createdirs
generate 1
