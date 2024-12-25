QJS := qjs
AWK := awk

BASE := .
POSTS_DIR := $(BASE)/posts
OUT_DIR := $(BASE)/output
INT_DIR := $(OUT_DIR)/intermediates
PUBLISH_DIR := $(OUT_DIR)/publish

POSTS := $(wildcard $(POSTS_DIR)/**/post.md)
TAGS := $(wildcard $(POSTS_DIR)/**/tags.txt)
HEADER_MD = $(POSTS_DIR)/header.md
FOOTER_MD = $(POSTS_DIR)/footer.md

# Outputs
PUBLISHED_POSTS := $(foreach POST,$(POSTS),$(PUBLISH_DIR)/$(POST).html)
TAGS_HTML := $(PUBLISH_DIR)/tags.md.html

.PHONY: site clean
site: $(PUBLISHED_POSTS) $(TAGS_HTML)

clean:
	rm -rf $(OUT_DIR)

# intermediates/.../X.md -> output/publish/.../X.md.html
# This is the key point that converts all our markdown into html
$(PUBLISH_DIR)/%.html: $(INT_DIR)/%
	mkdir -p $(@D)
	qjs -I '$(BASE)/external/pagedown/Markdown.Converter.js' -e "var text=\"$$(awk '{printf "%s\\n", $$0}' $<)\";var converter = new Markdown.Converter();console.log(converter.makeHtml(text));" > $@

$(INT_DIR)/%.md: $(HEADER_MD) %.md $(FOOTER_MD)
	mkdir -p $(@D)
	cat $^ > $@

# (post/.../tags.txt) -> output/intermediate/tags.md
$(INT_DIR)/tags.md: $(POSTS_DIR)/tags.md $(TAGS) $(HEADER_MD) $(FOOTER_MD)
	mkdir -p $(@D)
	cat $(HEADER_MD) > $@
	cat $< >> $@
	rm -rf $(@D)/tag_*.md
	$(foreach TAGFILE, $(TAGS), $(foreach TAG, $(shell awk '{ gsub(/ /, "_"); print }' $(TAGFILE)), echo "<details><summary>$(TAG)</summary>" > $(@D)/tag_$(TAG).md; ))
	$(foreach TAGFILE, $(TAGS), $(foreach TAG, $(shell awk '{ gsub(/ /, "_"); print }' $(TAGFILE)), echo $$"[$(word 2, $(subst _, ,$(word 3, $(subst /, ,$(TAGFILE)))) )]($(subst tags.txt,post.md.html,$(TAGFILE)))\n" >> $(@D)/tag_$(TAG).md; ))
	awk 'FNR==1 && NR!=1 && !empty {print "</details>"} {if (NF > 0) empty=0} {print} END {if (NR > 0) print "</details>"}' $(@D)/tag_*.md >> $@
	cat $(FOOTER_MD) >> $@