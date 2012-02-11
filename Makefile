all: generate dist
generate:
	./generate_album.sh
dist:
	rm -Rf dist 2>/dev/null
	mkdir dist
	mv thumbs html photos dist
	cp index.html dist
