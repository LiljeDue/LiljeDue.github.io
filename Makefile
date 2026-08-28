.PHONY: clean build build-debug host host-debug

ELM_SRC = src/Main.elm
ELM_OUT = elm.js
CONTENT_PORT = 8000
APP_PORT = 3000
CONTENT_SERVER = http-server -p $(CONTENT_PORT) --cors -c-1 --no-clipboard content
APP_SERVER = serve -p $(APP_PORT) -s --no-clipboard .
SERVER_START = @echo "Starting content server on http://localhost:$(CONTENT_PORT)"; \
	echo "Starting main app on http://localhost:$(APP_PORT)"; \
	$(CONTENT_SERVER) & \
	$(APP_SERVER) & \
	trap 'kill 0' EXIT; \
	wait

feed.xml: $(wildcard content/blog/*/post.json)
	python3 generate-feed.py

build: 404.html feed.xml content.js
	elm make $(ELM_SRC) --output=$(ELM_OUT) --optimize

build-debug: 404.html feed.xml content.js
	elm make $(ELM_SRC) --output=$(ELM_OUT)

host: build
	$(SERVER_START)

host-debug: build-debug
	$(SERVER_START)

content.js: content 404.html
	@echo "const content = [" > content.js
	@find content -type f | sort | sed 's|^content/||g' | sed 's/^/  "/g' | sed 's/$$/",/g' >> content.js
	@echo "];" >> content.js
	@echo "" >> content.js
	@echo "content.js has been generated with $(shell find content -type f | wc -l) file paths"

404.html: index.html
	@echo "Copying index. html to 404.html"
	@cp index.html 404.html

clean:
	rm -f content.js 404.html $(ELM_OUT) content/feed.xml