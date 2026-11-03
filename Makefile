.PHONY: clean build build-debug host host-debug pages

ELM_SRC = src/Main.elm
ELM_OUT = elm.js
CONTENT_PORT = 8000
APP_PORT = 3000
CONTENT_SERVER = http-server -p $(CONTENT_PORT) --cors -c-1 --no-clipboard content
APP_SERVER = http-server -p $(APP_PORT) -c-1 --no-clipboard .
SERVER_START = @echo "Starting content server on http://localhost:$(CONTENT_PORT)"; \
	echo "Starting main app on http://localhost:$(APP_PORT)"; \
	$(CONTENT_SERVER) & \
	$(APP_SERVER) & \
	trap 'kill 0' EXIT; \
	wait

# generate-feed.py writes content/feed.xml and index.html (from
# templates/index.html, with the no-JS list of blog posts filled in).
feed.xml index.html &: $(wildcard content/blog/*/post.json) templates/index.html generate-feed.py
	python3 generate-feed.py

# Blog posts are rendered to static HTML (math as MathML) by pandoc.
BLOG_POSTS = $(wildcard content/blog/*/post.md)
BLOG_PAGES = $(patsubst content/blog/%/post.md,blog/%/index.html,$(BLOG_POSTS))
PANDOC_TEMPLATE = templates/post.html
PANDOC_FILTERS = templates/date.lua templates/math-spacing.lua

blog/%/index.html: content/blog/%/post.md content/blog/%/post.json $(PANDOC_TEMPLATE) $(PANDOC_FILTERS)
	@mkdir -p $(dir $@)
	pandoc $< -f markdown-implicit_figures -t html5 --mathml \
	  --template $(PANDOC_TEMPLATE) \
	  $(addprefix --lua-filter ,$(PANDOC_FILTERS)) \
	  --metadata-file content/blog/$*/post.json \
	  -o $@

pages: $(BLOG_PAGES)

build: 404.html feed.xml content.js pages
	elm make $(ELM_SRC) --output=$(ELM_OUT) --optimize

build-debug: 404.html feed.xml content.js pages
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
	rm -f content.js index.html 404.html $(ELM_OUT) content/feed.xml
	rm -rf blog