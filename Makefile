QJS := qjs
AWK := awk

BASE := .
POSTS_DIR := $(BASE)/posts
PUBLISH_OUT := $(BASE)/publish

POSTS := $(wildcard $(POSTS_DIR)/**/post.md)
TAGS := $(wildcard $(POSTS_DIR)/**/tags.txt)

PUBLISHED_POSTS := $(foreach POST,$(POSTS),$(PUBLISH_OUT)/$(POST).html)

.PHONY: all clean
all: $(PUBLISHED_POSTS)

clean:
	rm -rf $(PUBLISH_OUT)

$(PUBLISH_OUT)/%.html: %
	mkdir -p $(@D)
	qjs -I '$(BASE)/external/pagedown/Markdown.Converter.js' -e "var text=\"$$(awk '{printf "%s\\n", $$0}' $<)\";var converter = new Markdown.Converter();console.log(converter.makeHtml(text));" > $@