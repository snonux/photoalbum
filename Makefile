all: generate dist
generate:
	./generate_album.sh
clean:
	rm -Rf dist *.html photos 
dist:
	rm -Rf dist 2>/dev/null
	mkdir dist
	mv thumbs html photos dist
	cp index.html dist
