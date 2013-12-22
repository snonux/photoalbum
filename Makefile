all: generate dist
generate:
	./photoalbum.sh
clean:
	sh -c 'rm -Rf dist *.tar; exit 0'
