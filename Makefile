BLOG_TITLE := Blog
BLOG_ROOT_LINK := https://www.example.com
BLOG_DESCRIPTION := An interactive web experience

BASE := .
POSTS_DIR := $(BASE)/posts
RESOURCES_DIR := $(BASE)/resources
OUT_DIR := $(BASE)/output
INT_DIR := $(OUT_DIR)/intermediates
PUBLISH_DIR := $(OUT_DIR)/publish

POSTS := $(basename $(wildcard $(POSTS_DIR)/**/post.md))
TAGS := $(wildcard $(POSTS_DIR)/**/tags.txt)
RESOURCES := $(wildcard $(RESOURCES_DIR)/*)
HEADER_HTML := $(INT_DIR)/$(POSTS_DIR)/header.html
FOOTER_HTML := $(INT_DIR)/$(POSTS_DIR)/footer.html
POST_NUMBERS := $(foreach POST,$(POSTS),$(word 3, $(subst _, ,$(subst /, ,$(dir $(POST))))))

# Outputs
PUBLISHED_POSTS := $(foreach POST_NUMBER,$(POST_NUMBERS),$(PUBLISH_DIR)/$(POST_NUMBER).html)
PUBLISHED_RESOURCES := $(foreach RESOURCE,$(RESOURCES),$(PUBLISH_DIR)/$(notdir $(RESOURCE)))
TAGS_HTML := $(PUBLISH_DIR)/tags.html
LATEST_HTML := $(PUBLISH_DIR)/latest.html
INDEX_HTML := $(PUBLISH_DIR)/index.html
RSS_XML := $(PUBLISH_DIR)/rss.xml
INTERMEDIATE_RSS_XML := $(foreach POST_NUMBER,$(POST_NUMBERS),$(INT_DIR)/$(POST_NUMBER).xml)

# Helpers
empty =
space = $(empty) $(empty)
quote = "
comma = ,
dollar = $$
bracket_left = {
ESCAPE_STRING = $(subst $(comma),\$(comma),$(subst !,\!,$(subst ?,\?,$(subst $(space),\$(space),$(subst $(quote),\$(quote),$(1))))))
ESCAPE_QUOTES = $(subst $(quote),\$(quote),$(1))
ESCAPE_DOLLAR = $(subst $(dollar),\$(dollar),$(1))
ESCAPE_BRACKETS = $(subst $(bracket_left),\$${"{"},$(1)) # Only need to escape one to avoid unintentional interpolation
ESCAPE_JSC_RAWSTRING = $(subst $(quote),\$(quote),$(subst `,\$${"\`"},$(call ESCAPE_BRACKETS,$(call ESCAPE_DOLLAR,$(1)))))

.SECONDARY:
.PHONY: site clean new
site: $(PUBLISHED_POSTS) $(PUBLISHED_RESOURCES) $(TAGS_HTML) $(LATEST_HTML) $(INDEX_HTML) $(RSS_XML)
	if [ "$(CNAME)" != "" ];\
	then printf "$(CNAME)" > $(PUBLISH_DIR)/CNAME;\
	fi;

clean:
	rm -rf $(OUT_DIR)

# POST_TITLE="New Post Title!"
new:
	if [ "$(POST_TITLE)" == "" ];\
	then echo "Set POST_TITLE" && exit 1;\
	fi;
	export POST_TITLE=$(call ESCAPE_STRING,$(subst $(space),_,$(POST_TITLE)));\
	export NEW_DIRECTORY=$(POSTS_DIR)/$(shell echo '$(lastword $(POST_NUMBERS))' | awk '{ printf "%05d", $$1 + 1 }')_$$POST_TITLE;\
	mkdir -p "$$NEW_DIRECTORY";\
	touch "$$NEW_DIRECTORY/post.md" "$$NEW_DIRECTORY/tags.txt";\
	date -R | tr -d '\n' > "$$NEW_DIRECTORY/timestamp";\

# Split up the header/footer processing to take advantage of divs, despite markdown not strictly processing them
# output/intermediates/.../X.html -> output/publish/.../X.html
$(PUBLISH_DIR)/%.html: $(HEADER_HTML) $(INT_DIR)/%.html $(FOOTER_HTML)
	mkdir -p $(@D)
	printf '<!DOCTYPE html>\n' > $@
	cat $^ >> $@

# Latest is just going to be the last post, which is ordered, so just copy it
$(LATEST_HTML): $(lastword $(PUBLISHED_POSTS))
	mkdir -p $(@D)
	cp $< $@

$(RSS_XML): $(INTERMEDIATE_RSS_XML)
	mkdir -p $(@D)
	printf '<?xml version="1.0" encoding="UTF-8" ?>\n' > $@
	printf '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">\n' >> $@
	printf '<channel>\n' >> $@
	printf '<atom:link href="$(BLOG_ROOT_LINK)/rss.xml" rel="self" type="application/rss+xml" />\n' >> $@
	printf '<title>$(BLOG_TITLE)</title>\n' >> $@
	printf '<link>$(BLOG_ROOT_LINK)</link>\n' >> $@
	printf '<description>$(BLOG_DESCRIPTION)</description>\n' >> $@
	cat $^ >> $@
	printf '</channel>\n' >> $@
	printf '</rss>' >> $@

# output/intermediates/.../X.md -> output/intermediates/.../X.html
# This is the key point that converts all our markdown into html
$(INT_DIR)/%.html: $(INT_DIR)/%.md
	mkdir -p $(@D)
	qjs -I '$(BASE)/external/pagedown/Markdown.Converter.js' -e "var text=String.raw\`$(call ESCAPE_JSC_RAWSTRING,$(shell awk '{ printf "%s\\n", $$0 }' $<))\`;var converter = new Markdown.Converter();console.log(converter.makeHtml(text.replaceAll('\\\\n','\\n')));" > $@

# Generate the RSS entry for this post, but avoid including the link to the next/previous post
# Note that we get the original post title from the timestamp directory
$(INT_DIR)/%.xml: $(POSTS_DIR)/%_*/timestamp $(INT_DIR)/article_%.html
	printf '<item>\n' > $@
	printf '<title>$(wordlist 3,$(words $(filter-out timestamp,$(subst _, ,$(subst /, ,$<)))), $(subst _, ,$(subst /, ,$<)))</title>\n' >> $@
	printf '<description>' >> $@
	printf '<![CDATA[' >> $@
	cat "$(INT_DIR)/article_$*.html" >> $@
	printf ']]>' >> $@
	printf '</description>\n' >> $(INT_DIR)/$*.xml
	printf '<link>$(BLOG_ROOT_LINK)/$*.html</link>\n' >> $@
	printf '<guid>$(BLOG_ROOT_LINK)/$*.html</guid>\n' >> $@
	printf '<pubDate>' >> $@
	cat "$(call ESCAPE_QUOTES,$<)" >> $@
	printf '</pubDate>\n' >> $@
	printf '</item>\n' >> $@

# For posts, we print the post title and before/after posts
# note that this will concatenate multiple posts with the same number in Make's sorted order (it's consistent within versions of Make, but we don't control the sort spec)
# Also this means we don't support underscores or forward slashes in titles since they'll get replaced
$(INT_DIR)/article_%.md: $(POSTS_DIR)/%_*/post.md
	mkdir -p $(@D)
	cat "$(call ESCAPE_QUOTES,$<)" >> $@

$(INT_DIR)/%.md: $(POSTS_DIR)/%_*/timestamp $(INT_DIR)/article_%.md
	mkdir -p $(@D)
	printf "<head><meta charset=\"UTF-8\"><title>$(call ESCAPE_QUOTES,$(wordlist 3,$(words $(filter-out timestamp,$(subst _, ,$(subst /, ,$<)))), $(subst _, ,$(subst /, ,$<))))</title></head>\n" > $@
	printf "<article>\n" >> $@
	printf "<sub>Posted on " >> $@
	cat "$(call ESCAPE_QUOTES,$<)" >> $@
	printf "</sub>\n" >> $@
	printf "# [$(call ESCAPE_QUOTES,$(wordlist 3,$(words $(filter-out timestamp,$(subst _, ,$(subst /, ,$<)))), $(subst _, ,$(subst /, ,$<))))]($*.html)\n" >> $@
	cat $(lastword $^) >> $@
	printf '\n</article>\n' >> $@

	@export PREVIOUS_POST="$(strip $(filter-out $*.html, $(subst $(PUBLISH_DIR)/,,$(shell echo $(PUBLISHED_POSTS) | tr ' ' '\n' | grep -B1 $*.html))))";\
	export NEXT_POST="$(strip $(filter-out $*.html, $(subst $(PUBLISH_DIR)/,,$(shell echo $(PUBLISHED_POSTS) | tr ' ' '\n' | grep -A1 $*.html))))";\
	if [ "$$PREVIOUS_POST" != "" ] || [ "$$NEXT_POST" != "" ];\
		then printf "\n\n" >> $(INT_DIR)/$*.md;\
	fi;\
	if [ "$$PREVIOUS_POST" != "" ];\
		then printf "[<< Previous Post]($$PREVIOUS_POST) " >> $@;\
	fi;\
	if [ "$$NEXT_POST" != "" ];\
		then printf "[Next Post >>]($$NEXT_POST)" >> $@;\
	fi;

# Resources
$(PUBLISH_DIR)/%: $(RESOURCES_DIR)/%
	mkdir -p $(@D)
	cp $< $@

# Special-case header/footer
$(INT_DIR)/%.md: %.md
	mkdir -p $(@D)
	cat $^ > $@

# Fallback, catches index
$(INT_DIR)/%.md: $(POSTS_DIR)/%.md
	mkdir -p $(@D)
	cp $^ $@

# (post/.../tags.txt) -> output/intermediate/tags.md
$(INT_DIR)/tags.md: $(POSTS_DIR)/tags.md $(TAGS)
	mkdir -p $(@D)
	cat $< > $@
	rm -rf $(@D)/tag_*.md
	$(foreach TAGFILE, $(TAGS), $(foreach TAG, $(shell awk '{ gsub(/ /, "_"); print }' $(call ESCAPE_STRING,$(TAGFILE))), printf "<details><summary>$(call ESCAPE_QUOTES,$(TAG))</summary>\n\n" > $(@D)/tag_$(TAG).md; ))
	$(foreach TAGFILE, $(TAGS), $(foreach TAG, $(shell awk '{ gsub(/ /, "_"); print }' $(call ESCAPE_STRING,$(TAGFILE))), printf "[$(call ESCAPE_QUOTES,$(wordlist 4,$(words $(filter-out tags.txt,$(subst _, ,$(subst /, ,$(TAGFILE))))), $(subst _, ,$(subst /, ,$(TAGFILE)))))](./$(word 3, $(subst _, ,$(subst /, ,$(TAGFILE)))).html)\n\n" >> $(@D)/tag_$(TAG).md; ))
	awk 'FNR==1 && NR!=1 && !empty {print "</details>"} {if (NF > 0) empty=0} {print} END {if (NR > 0) print "</details>"}' $(@D)/tag_*.md >> $@


