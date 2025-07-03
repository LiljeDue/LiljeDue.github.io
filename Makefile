.PHONY: clean build debug host

build: content.js 404.html
	elm make src/Main.elm --output=elm.js --optimize

debug: content.js 404.html
	elm make src/Main.elm --output=elm.js

host: content.js 404.html
	npx serve@latest -s .

content.js: content 404.html
	@echo "const content = [" > content.js
	@find content -type f | sort | sed 's/^/  "/g' | sed 's/$$/",/g' >> content.js
	@echo "];" >> content.js
	@echo "" >> content.js
	@echo "content.js has been generated with $(shell find content -type f | wc -l) file paths"

404.html: index.html
	@echo "Copying index.html to 404.html"
	@cat index.html > 404.html

clean:
	rm -f content.js 404.html
