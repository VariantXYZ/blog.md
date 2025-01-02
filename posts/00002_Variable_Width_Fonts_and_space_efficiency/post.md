<sub>Disclaimer: I'm not even remotely proficient in Japanese, but I definitely deal with a lot of Japanese text in both my hobbies and at work, so I happen to have some observations on it.</sub>

# Preface

A [recent study](https://www.science.org/doi/10.1126/sciadv.aaw2594) I saw popping up on some social media commented on how information density over time across spoken languages was fairly similar despite vastly different approaches (different syllable counts, general rate of speech, etc...). There are some obvious criticisms, of course. For example, language tends to bias towards specific cultural requirements and so there may be specific contexts where the language excels and conversely, specific ones where it falls short... but that aside, it did get me thinking a bit about *written* information density, especially when it comes to displaying things on fairly low-spec systems (<sub>yes I mean the Gameboy</sub>).

I've done a fair amount of reverse engineering on old GB stuff to enable translations from Japanese. I think I'm generally rather slow overall, but I do have a process:

1. Identify what's writing the text out
    * Text is usually represented as a set of indices into a larger tileset
2. Use the knowledge from (1) to figure out where the text itself is stored
    * Intuitively, text is probably being written out as part of a larger scripting system, but we generally don't need all of it to just translate text
    * Sometimes it's embedded in the script itself (like most old GBDK titles), which means we have to figure out the scripts to an extent anyway...
3. (Optionally) Dump the tileset to png and allow fo rebuilding with it cleanly
    * Sometimes, like with Sakura Wars GB2, the text itself already supports English font so I just reuse it
4. Extract the text into some common format (usually CSV) and rebuild with it cleanly (text extraction + reinsertion)

Generally after text extraction/insertion, the next big task to overcome is... how do we actually fit English text in the space originally meant for Japanese text? ...The answer is usually "it depends" from game to game and I won't bore you with the details (*for now*).

Instead, with the above context, I'd rather dive in a bit into Japanese text itself and how exactly it compares to the translated English. Japanese text in old games tends to be fairly [space efficient](## "The number of pixels consumed on screen for text when it's displayed") and [storage efficient](## "The amount of data used to store the text in memory itself"). Since it's New Years' day and I'm tired from all the festivities, I'll just briefly talk space efficiency here.

# Space Efficiency in Dragon Warrior 3

Randomly, on Cohost this year, a user [@Bek0ha](http://x.com/Bek0ha) ([bsky](https://bsky.app/profile/bekoha.bsky.social)) went and found and recreated a [cool font](https://archive.org/details/jimaku-font) that caught my eye:

![K.K. Kinema Font Lab](kinema.png "K.K. Kinema Font Lab - Handwritten Movie Subtitle Font")

Bekoha went so far as to even provide me an 8x8 version of it:

<style>
span.two img
{
    max-width: 49%;
    height: auto;
}
</style>
<span class="two">![Kinema 8-bit font](kinema_pixel.png "Standard Font") ![Kinema 8-bit narrow font](kinema_pixel_2.png "Narrow Font")</span>

Anyway, I figured I'd see how it would look in Dragon Warrior 3, which I had [disassembled](https://github.com/VariantXYZ/dragon-warrior-3-gbc) and gotten text reinsertion working for a while back for a re-localization project.

<style>
span.gifs img
{
    max-width: 24%;
    height: auto;
}
</style>

<span class="gifs">![Original Japanese](dw3_normal_jp.gif "Original Japanese") ![Original English](dw3_normal.gif "Original English") ![VWF English](dw3_vwf.gif "VWF English") ![VWF Narrow English](dw3_vwf_narrow.gif "VWF Narrow English")</span>

<sub>From left to right: The original Japanese, the original English, Kinema 8-bit, and Kinema 8-bit narrow</sub>

Let's look at these lines (note that things surrounded by brackets are a single tile):

<details>
<summary>Line 1</summary>
> ＊「[・・・][・・・]はあ　はあ.
>
> ＊「ねえ!　オルテガさんの　子供が
>
> 　　生まれたんですって!?


> [*:] Pant, pant…
>
> Is it true that
>
> Ortega had a baby?
</details>

<details><summary>Line 2</summary>
> ＊「そうとも!　すごい元気な
>
> 　　赤ちゃんだそうだ.


> [*:] That['s] right!
>
> I hear the baby['s]
> 
> really lively too.
</details>

<details><summary>Line 3</summary>
> ＊「アリアハンのゆうしゃ　オルテガの
>
> 　　子どもなら[・・・]
>
> ＊「きっと　りっぱな
>
> 　　戦士になるぞ!


> [*:] Any child of
>
> Ortega, Aliahan['s]
>
> hero, is sure to
>
> become a great
>
> warrior.
</details>

<details><summary>Line 4</summary>
> ＊「[・・・][・・・]そうよね.
>
> ＊「さあ　早く　赤ちゃんのかおを
>
> 　　見せてもらいましょう!


> [*:] That['s] true.
>
> We should go see
>
> the baby!
</details>

<sub>(Did you notice how the Japanese actually has enough leeway to indent lines around the asterisk? The English definitely didn't...)</sub>

I suspect if you have some common variable-width font for English enabled, the English text actually looks like it takes significantly less space than the fixed-width Japanese:

``
ねえ!　オルテガさんの　子供が 生まれたんですって!?
``

``
Is it true that Ortega had a baby?
``

So let's see some stats as measured on the Gameboy:

<style>
table.fonts
{
	width: 100%;
	border-collapse: collapse;
	margin: 0 auto;
}
th.fonts, td.fonts
{
	text-align: center;
	vertical-align: middle;
}
</style>

<table border="1" class="fonts">
	<tr>
		<th class="fonts">Line</th>
		<th class="fonts">JP Character Count</th>
		<th class="fonts">EN Character Count</th>
		<th class="fonts">JP Pixel Width</th>
		<th class="fonts">EN (Original) Pixel Width</th>
		<th class="fonts">EN (Kinema) Pixel Width</th>
		<th class="fonts">EN (Kinema Narrow) Pixel Width</th>
	</tr>
	<tr>
		<td class="fonts">1</td>
		<td class="fonts">10 + 17 + 13 = 40</td>
		<td class="fonts">13 + 15 + 18 = 46</td>
		<td class="fonts">80 + 136 + 104 = 320</td>
		<td class="fonts">104 + 120 + 144 = 368</td>
		<td class="fonts">74 + 132 + 68 = 274</td>
		<td class="fonts">56 + 124 + 24 = 204</td>
	</tr>
	<tr>
		<td class="fonts">2</td>
		<td class="fonts">14 + 11 = 25</td>
		<td class="fonts">14 + 16 + 18 = 48</td>
		<td class="fonts">112 + 88 = 200</td>
		<td class="fonts">112 + 128 + 144 = 384</td>
		<td class="fonts">88 + 140 + 58 = 286</td>
		<td class="fonts">66 + 136 + 16 = 218</td>
	</tr>
	<tr>
		<td class="fonts">3</td>
		<td class="fonts">18 + 8 + 10 + 9 = 45</td>
		<td class="fonts">14 + 16 + 16 + 14 + 8 = 68</td>
		<td class="fonts">144 + 64 + 80 + 72 = 360</td>
		<td class="fonts">112 + 128 + 128 + 112 + 64 = 544</td>
		<td class="fonts">126 + 130 + 108 + 48 = 412</td>
		<td class="fonts">140 + 140 + 36 = 316</td>
	</tr>
	<tr>
		<td class="fonts">4</td>
		<td class="fonts">9 + 16 + 13 = 38</td>
		<td class="fonts">13 + 16 + 9 = 38</td>
		<td class="fonts">72 + 128 + 104 = 304</td>
		<td class="fonts">104 + 128 + 72 = 304</td>
		<td class="fonts">80 + 122 + 34 = 236</td>
		<td class="fonts">60 + 120 = 180</td>
	</tr>
	<tr>
		<td class="fonts">Total</td>
		<td class="fonts">148</td>
		<td class="fonts">200</td>
		<td class="fonts">1184</td>
		<td class="fonts">1600</td>
		<td class="fonts">1208</td>
		<td class="fonts">918</td>
	</tr>
</table>

<sub>(The GIFs are direct 2x scale, so I just split the frames and used those to measure the pixels :D)</sub>

# Conclusions

It's not quite as apples-to-apples, but English taking 200 characters to convey what Japanese does in 148 is indicative of a larger trend we see that causes a lot of trouble when it comes to the actual storage of English text when memory is limited... This is a storage problem though, and on the topic of visual space: English can do pretty well!

If we're willing to render English variable-width text dynamically, we can fit as much, if not more information within the same visual space!

Now if we could just figure out a way to do it in a way that didn't involve needing to draw text dynamically while maintaining the same text storage efficiency... I suppose that's a deep dive for another time, or research for someone smarter than me to get into.

# Some final personal notes

One of my New Years' resolutions was to write a bit more and to get generally better at articulating my thoughts. It has a few other nice benefits too...

* I finally get to live out the HTML/CSS dream I missed because I scoffed at MySpace and personal blogs in my teenage years
* It's quite therapeutic to put things to paper and/or keyboard
* Writing things down in this format really lets me dig into topics I wouldn't really spend as much time on, especially with things like gathering stats!

Also, since I'm starting to forget more things recently, I figured it might be a good time to start really investing in archiving whatever knowledge I've accumulated... if for no one else's benefit but my future own.

So that being said, thanks for reading!