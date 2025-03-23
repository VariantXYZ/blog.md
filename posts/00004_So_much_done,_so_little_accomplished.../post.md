Well, I wanted to try making a post once a month but lost track of time, so that's one New Years' resolution broken quite quickly. I was actually doing things though! Let me explain!

## Making 2025 the year of productive PowerPC usage

If you recall [my earlier post](00003.html), I had gotten GCC 14.2 building things for Mac OS X 10.4 PowerPC (darwin8). Of course, after going through all that trouble, I did want to actually use the thing.

I figured an old PPC G4 could still find life as a GameBoy development machine, so I got to work trying to build everything necessary to checkout a repository, build a GB ROM, and actually debug and test it. 

This meant building:

* rgbds
* Python 3
* git with openssl support
* An emulator

Simple enough, right? Well, sorta. Turns out, all software is just built on top of other software so there's quite a bit of work to do...

![xkcd](dependency_2x.png "An xkcd for everything")

Here's a glimpse at what it takes to build Git, for example:

![Building git](build_git.png "GitHub is not very efficient")

<sub>(I wish GitHub would let me properly re-use build flows in a sane way)</sub>

I won't bore you guys with all the details, but there was a lot of random little changes in various projects and a handful of forks and research. 

All of that work can be found in the GitHub Actions [here](https://github.com/VariantXYZ/gbdev-powerpc-apple-darwin8) and the forks I reference in them.

Everything culminated in being able to build and run the Medarot 3 patch at a glacial framerate:

<blockquote class="bluesky-embed" data-bluesky-uri="at://did:plc:bxec6nf4fgw2njjhxbwhsord/app.bsky.feed.post/3lie2fcysqc2n" data-bluesky-cid="bafyreiaqnv2qh242pywak4zl3hx4ioxyflsfxtlo7cnjcdtkuctpgpyhke" data-bluesky-embed-color-mode="system"><p lang="en">Well, patched up enough of SDL 2.0.3 and added some stuff from 2.0.4 to build SameBoy. 

If you listen closely, you can hear Ikki&#x27;s voice played at 5 Hz.<br><br><a href="https://bsky.app/profile/did:plc:bxec6nf4fgw2njjhxbwhsord/post/3lie2fcysqc2n?ref_src=embed">[image or embed]</a></p>&mdash; Variant (<a href="https://bsky.app/profile/did:plc:bxec6nf4fgw2njjhxbwhsord?ref_src=embed">@vxyz.me</a>) <a href="https://bsky.app/profile/did:plc:bxec6nf4fgw2njjhxbwhsord/post/3lie2fcysqc2n?ref_src=embed">February 16, 2025 at 9:49 PM</a></blockquote><script async src="https://embed.bsky.app/static/embed.js" charset="utf-8"></script>

...Alright, so we still have some work to do here, but it's a good(?) transition into what's been eating up my time more recently.

## Wonder what it'd take to write an emulator?

SameBoy is well known as being a highly accurate GB/GBC emulator that's fairly feature rich, but... it's not really designed nor optimized for a single-thread machine from 2003 that only supports OpenGL 1.1. The video above showcases a pretty common issue I've had.

Other emulators exist, but they either opt to drop accuracy for speed (so, not great for development and they usually don't have debugging features), or are even worse performing for a richer feature set. I even had Calindro, the Emulicious dev, reach out and had me test some builds but to no avail. Nothing really achieves a practical debugging experience on a Mac OS X 10.4 PPC that I could find...

So, of course, here I am with a pretty unique problem statement and set of resourcees, and I figure... if I've got a C++ 20 compiler and an understanding of the exact workflow I'm trying to build a tool for, maybe I can start writing an emulator with the features I need myself? It would also finally give me an opportunity to play around with C++20 and I could probably spin that as some form of professional development... at least, that's what I told myself.

The project, aptly named [PowerGB](https://github.com/VariantXYZ/PowerGB/tree/add_instructions), is still a work-in-progress. I've been finally getting to the stage of adding instruction parsing after working on it on-and-off after work. If you're wondering why it's taking me so long, it's because I keep finding new things in C++20 that make me interested and I waste days doing things like [writing a comprehensive result wrapper](https://github.com/VariantXYZ/PowerGB/blob/main/src/common/result.hpp) instead of doing actual work.

Though, to be honest, I'll probably put this on hold because there are other things I'd like to get done...

## Medabots GBC titles before 2030!?

Yeah, the Medabots GBC titles are still a slow work-in-progress... but we're still making progress.

### Medabots 3 "US Localized" Version

andwhyisit handled some of the graphics work for the Medabots 3 US-English localization patch and I finally got around to writing that text replacement script, so the first (unfinished) nightly release of tr_EN-US is [here](https://github.com/Medabots/medarot3/releases/tag/tr_EN-US%2Bnightly.20250323).

<style>
span.medabots img
{
    max-width: 49%;
    height: auto;
}
</style>

<span class="medabots">![Medabots 3 Rubberobo](medabots3_rubberobo.png "Rubberobo Gang") ![Medabots 3 Kuwagata](medabots3_kwg.png "Kuwagata Version")</span>
<sub>Poor Shrimplips is almost entirely covered by the text :(</sub>

### The other GBC titles

The development aside, the 4th title is about 40% more text than the 3rd, so I have a feeling I might not be the major bottleneck... eventually anyway.

I think the 5th title should be a bit smaller, at least.

At the rate we're going it might be cutting it close to get it all done by 2030, but uh, I'm sure we'll be fine if I don't get distracted [by](https://github.com/VariantXYZ/sakura-wars-gb2/tree/master) [other](https://github.com/VariantXYZ/dragon-warrior-3-gbc) [projects](https://github.com/VariantXYZ/metamode/tree/dump_dialog).

## Work and other things

My job tend to be quite technically challenging so my brain wants to shut-off at times. I suspect things might get easier in the coming months, but phew, it's a real motivator to try and save up as much as I can to retire early so I can devote more time into projects and other things... alas, if only it were that simple.

### Games! Actually playing them!

In the last several years, investing any amount of time into a title has been pretty difficult. I beat Radiant Historia over the course of 2 years, Dragon Quest 11 took me a year, and even now I'm finally approaching the end of the DQ3 remake at about 40 hours. I'm thankful that I'm finding some time to play, but phew, 40 hours really feels like the limit of a reasonable sink... maybe I'm just getting old.

That being said, DQ3's Recall mechanic being streamlined is such a nice feature. I wish every JRPG had a button I could press to let me remember NPC dialog at any moment. It's such a nice touch, and probably my favorite feature of DQ3 in general.

## Finishing up

Anywho, I guess we'll all see how things shape up in the coming year. At a later date, maybe I'll do some more technical deep dives... but for that, I might need to dive in a bit deeper myself first.
