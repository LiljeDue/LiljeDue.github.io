.PHONY: clean build debug

build: content.js
	elm make src/Main.elm --output=elm.js --optimize

debug: content.js
	elm make src/Main.elm --output=elm.js

host: content.js
	npx serve@latest -s .

content.js: content
	@echo "const content = [" > content.js
	@find content -type f | sort | sed 's/^/  "/g' | sed 's/$$/",/g' >> content.js
	@echo "];" >> content.js
	@echo "" >> content.js
	@echo "content.js has been generated with $(shell find content -type f | wc -l) file paths"

clean:
	rm -f content.js
