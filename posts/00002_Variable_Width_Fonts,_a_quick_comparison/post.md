# (WIP)

<sub>To preface everything, I'm not even remotely proficient in Japanese, but I definitely deal with a lot of Japanese text in both my hobbies and at work, so I happen to have some observations on it.</sub>

# Preface

A [recent study](https://www.science.org/doi/10.1126/sciadv.aaw2594) I saw popping up on some social media commented on how information density over time across spoken languages was fairly similar despite vastly different approaches (different syllable counts, general rate of speech, etc...). The obvious criticisms aside (e.g., languages being more or less efficient in specific contexts due to general cultural shifts), it did get me thinking a bit about *written* information density, especially when it comes to displaying things on fairly low-power limited systems (<sub>yes I mean the Gameboy</sub>).

Over the years, I've done a fair amount of reverse engineering on old GB stuff to enable translations from Japanese. I think I'm generally rather slow overall, but I do have a process:

1. Identify what's writing the text out
	* Text is usually represented as a set of indices into a larger tileset
2. Use the knowledge from (1) to figure out where the text itself is stored
	* Intuitively, text is probably being written out as part of a larger scripting system, but we generally don't need all of it to just translate text
	* Sometimes it's embedded in the script itself (like most old GBDK titles), which means we have to figure out the scripts to an extent anyway...
3. (Optionally) Dump the tileset to png and allow fo rebuilding with it cleanly
	* Sometimes, like with Sakura Wars GB2, the text itself already supports English font so I just reuse it
4. Extract the text into some common format (usually CSV) and rebuild with it cleanly (text extraction + reinsertion)

Generally after text extraction/insertion, the next big task to overcome is... how do we actually fit English text in the space originally meant for Japanese text? ...The answer is usually "it depends" from game to game and I won't bore you with the details (*for now*).

Instead, with the above context, I'd rather dive in a bit into Japanese text itself and how exactly it compares to the translated English. Japanese text in old games tends to be fairly [space efficient](## "The number of pixels consumed on screen for text when it's displayed") and [storage efficient](## "The amount of data used to store the text in memory itself"). 

# Space Efficiency

# Storage Efficiency

# Information Density (with my sample size of like, 3 games)

When I was looking for translators for Medarot 3, I had also spent time looking into groups that would work on commission. The group I ended up working with for part of the M3 translation, [AoiTenshi](https://aoitenshi.com), gave me an upper-bound cost per English word at approximately 2.5 Japanese Characters per English word. Upper-bound is a keyword though, because it usually was significantly higher than the actual number of English words at the end of the translation.

# Example: Dragon Warrior 3 (GBC, USA English)

Randomly, on Cohost this year, a user [@Bek0ha](http://x.com/Bek0ha) went and found and recreated a [cool font](https://archive.org/details/jimaku-font) that caught my eye:

![K.K. Kinema Font Lab](kinema.png "K.K. Kinema Font Lab - Handwritten Movie Subtitle Font")

Bek0ha went so far as to even provide me an 8x8 version of it... which I think is on my desktop, I'll update this post with it when I get to it.

Anyway, I figured I'd see how it would look in Dragon Warrior 3, which I had [disassembled](https://github.com/VariantXYZ/dragon-warrior-3-gbc) and gotten text reinsertion working for a while back for a re-localization project.

<style>
span.gifs img
{
	max-width: 32%;
    height: auto;
}
</style>

<span class="gifs">![Original English](dw3_normal.gif "Original English") ![VWF English](dw3_vwf.gif "VWF English") ![VWF Narrow English](dw3_vwf_narrow.gif "VWF Narrow English")</span>

<sub>From left to right: The original, Kinema 8-bit, and Kinema 8-bit narrow</sub>