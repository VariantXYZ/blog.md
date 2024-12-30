QJS := qjs
AWK := awk

BASE := .
POSTS_DIR := $(BASE)/posts
OUT_DIR := $(BASE)/output
INT_DIR := $(OUT_DIR)/intermediates
PUBLISH_DIR := $(OUT_DIR)/publish

POSTS := $(basename $(wildcard $(POSTS_DIR)/**/post.md))
TAGS := $(wildcard $(POSTS_DIR)/**/tags.txt)
HEADER_HTML = $(INT_DIR)/$(POSTS_DIR)/header.html
FOOTER_HTML = $(INT_DIR)/$(POSTS_DIR)/footer.html

# Outputs
PUBLISHED_POSTS := $(foreach POST,$(POSTS),$(PUBLISH_DIR)/$(word 3, $(subst _, ,$(subst /, ,$(dir $(POST)))) ).html)
TAGS_HTML := $(PUBLISH_DIR)/tags.html

.PHONY: site clean
site: $(PUBLISHED_POSTS) $(TAGS_HTML)

clean:
	rm -rf $(OUT_DIR)

# Split up the header/footer processing to take advantage of divs, despite markdown not strictly processing them
# output/intermediates/.../X.html -> output/publish/.../X.html
$(PUBLISH_DIR)/%.html: $(HEADER_HTML) $(INT_DIR)/%.html $(FOOTER_HTML) 
	mkdir -p $(@D)
	cat $^ > $@

# output/intermediates/.../X.md -> output/intermediates/.../X.html
# This is the key point that converts all our markdown into html
$(INT_DIR)/%.html: $(INT_DIR)/%.md
	mkdir -p $(@D)
	qjs -I '$(BASE)/external/pagedown/Markdown.Converter.js' -e "var text=String.raw\`$(shell awk '{ printf "%s\\n", $$0 }' $<)\`;var converter = new Markdown.Converter();console.log(converter.makeHtml(text.replaceAll('\\\\n','\\n')));" > $@

# For posts, we print the post title
# note that this will concatenate multiple posts with the same number in Make's sorted order (it's consistent within versions of Make, but we don't control the sort spec)
# Also this means we don't support underscores or forward slashes in titles...
$(INT_DIR)/%.md: $(POSTS_DIR)/%_*/post.md
	mkdir -p $(@D)
	echo \# $(wordlist 3,$(words $(filter-out post.md,$(subst _, ,$(subst /, ,$^)))), $(subst _, ,$(subst /, ,$^))) > $@
	cat $^ >> $@

# Special-case header/footer
$(INT_DIR)/%.md: %.md
	mkdir -p $(@D)
	cat $^ > $@

# (post/.../tags.txt) -> output/intermediate/tags.md
$(INT_DIR)/tags.md: $(POSTS_DIR)/tags.md $(TAGS)
	mkdir -p $(@D)
	cat $< >> $@
	rm -rf $(@D)/tag_*.md
	$(foreach TAGFILE, $(TAGS), $(foreach TAG, $(shell awk '{ gsub(/ /, "_"); print }' $(TAGFILE)), echo "<details><summary>$(TAG)</summary>" > $(@D)/tag_$(TAG).md; ))
	$(foreach TAGFILE, $(TAGS), $(foreach TAG, $(shell awk '{ gsub(/ /, "_"); print }' $(TAGFILE)), echo "[$(wordlist 4,$(words $(filter-out tags.txt,$(subst _, ,$(subst /, ,$(TAGFILE))))), $(subst _, ,$(subst /, ,$(TAGFILE))))](./$(word 3, $(subst _, ,$(subst /, ,$(TAGFILE)))).html)\n" >> $(@D)/tag_$(TAG).md; ))
	awk 'FNR==1 && NR!=1 && !empty {print "</details>"} {if (NF > 0) empty=0} {print} END {if (NR > 0) print "</details>"}' $(@D)/tag_*.md >> $@