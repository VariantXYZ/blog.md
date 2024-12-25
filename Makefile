QJS := qjs
AWK := awk

BASE := .
POSTS_DIR := $(BASE)/posts
PUBLISH_OUT := $(BASE)/publish

POSTS := $(wildcard $(POSTS_DIR)/**/post.md)
TAGS := $(wildcard $(POSTS_DIR)/**/tags.txt)

PUBLISHED_POSTS := $(foreach POST,$(POSTS),$(PUBLISH_OUT)/$(POST).html)
HEADER_MD = $(POSTS_DIR)/header.md
FOOTER_MD = $(POSTS_DIR)/footer.md

.PHONY: all clean
all: $(PUBLISHED_POSTS)

clean:
	rm -rf $(PUBLISH_OUT)

# post.md -> post.md.html with header/footer
$(PUBLISH_OUT)/%.html: % $(HEADER_MD) $(FOOTER_MD)
	mkdir -p $(@D)
	qjs -I '$(BASE)/external/pagedown/Markdown.Converter.js' -e "var header=\"$$(awk '{printf "%s\\n", $$0}' $(HEADER_MD))\";var footer=\"$$(awk '{printf "%s\\n", $$0}' $(FOOTER_MD))\";var text=\"$$(awk '{printf "%s\\n", $$0}' $<)\";var converter = new Markdown.Converter();console.log(converter.makeHtml(header + text + footer));" > $@