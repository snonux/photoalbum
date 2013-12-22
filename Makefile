all: generate dist
generate:
	./photoalbum.sh
clean:
	rm -Rf dist photos 
dist:
	rm -Rf dist 2>/dev/null
	mkdir dist
	mv thumbs html photos dist
	mv index.html ./dist
