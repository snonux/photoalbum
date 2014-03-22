NAME=photoalbum
all: version documentation build
build:
	test ! -d ./bin && mkdir ./bin || exit 0
	sed "s/PHOTOALBUMVERSION/$$(cat .version)/" src/$(NAME).sh > ./bin/$(NAME)
	chmod 0755 ./bin/$(NAME)
install:
	test ! -d $(DESTDIR)/usr/bin && mkdir -p $(DESTDIR)/usr/bin || exit 0
	cp ./bin/* $(DESTDIR)/usr/bin
	test ! -d $(DESTDIR)/usr/share/photoalbum/templates && mkdir -p $(DESTDIR)/usr/share/photoalbum/templates || exit 0
	cp -R ./share/templates $(DESTDIR)/usr/share/photoalbum/
	test ! -d $(DESTDIR)/etc/default && mkdir -p $(DESTDIR)/etc/default || exit 0
	cp ./src/photoalbum.default.conf $(DESTDIR)/etc/default/photoalbum
deinstall:
	test ! -z "$(DESTDIR)" && test -f $(DESTDIR)/usr/bin/$(NAME) && rm $(DESTDIR)/usr/bin/$(NAME) || exit 0
	test ! -z "$(DESTDIR)" && test -d $(DESTDIR)/usr/share/$(NAME) && rm -r $(DESTDIR)/usr/share/$(NAME) || exit 0
	test ! -z "$(DESTDIR)" && test -f $(DESTDIR)/etc/default/photoalbum && rm $(DESTDIR)/etc/default/photoalbum || exit 0
clean:
	test -d ./bin && rm -Rf ./bin || exit 0
	test -d ./debian/photoalbum && rm -Rf ./debian/photoalbum || exit 0
version:
	cut -d' ' -f2 debian/changelog | head -n 1 | sed 's/(//;s/)//' > .version
# Builds the documentation into a manpage
documentation:
	pod2man --release="$(NAME) $$(cat .version)" \
		--center="User Commands" ./docs/$(NAME).pod > ./docs/$(NAME).1
	pod2text ./docs/$(NAME).pod > ./docs/$(NAME).txt
deb: all
	dpkg-buildpackage 
dch: 
	dch -i
dput:
	dput -u wheezy-buetowdotorg ../$(NAME)_$$(cat ./.version)_amd64.changes
release: all dch deb dput
	bash -c "git tag $$(cat .version)"
	git push --tags
	git commit -a -m 'New release'
	git push origin master
clean-top:
	rm ../$(NAME)_*.tar.gz
	rm ../$(NAME)_*.dsc
	rm ../$(NAME)_*.changes
	rm ../$(NAME)_*.deb

