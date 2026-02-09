First post of 2026! (Albeit a bit later than I expected...) 

I've been feeling pretty mentally exhausted from work and life things, and so the only projects I've really put time into have been ones that are more creative than investigative. That is to say, I haven't felt like reverse engineering things for a little bit but I'm sure I'll get back into it soon.

On the creative side though, my little pet GB emulator project [PowerGB](https://github.com/VariantXYZ/PowerGB/) has been an exercise in seeing how far I can get pure portable C++20 to go.

## A GameBoy Emulator should have a Philosophy

I imagine for a lot of people, a GameBoy emulator is usually a really fun sounding project. It's a well-documented system with a large support community, a ton of people who've gone through the same struggles you'll run into, and a lot of open-source working examples to reference. It's an absolutely phenomenal platform for development experiments and learning.

You'll find implementations that are highly accurate down to the CPU tick, ones that provide Python interfaces for automation, and even things that do JIT and static-based recompilation. 

So given what's already out there, I figured I wanted to approach this with my own philosophy as I study the newer features of C++, originally propagated by my earlier [post](./00003.html) where I documented my adventures getting a C++20-compatible cross-compiler working on OSX Tiger. 

### As close as we can to a consteval world

As I went through thinking and defining various parts of the process, which I'll go into more detail below, I attempted to push as much of the work as possible to compile-time evaluation and correctness, even if it meant fighting the language a little. This meant extensive use of `static_assert` to make sure things were being evaluated at compile-time.

The easier we can prove to a compiler that something can be optimized out, the better.

## Life's no fun without a few complications

I think C++ introduces opportunities for overengineering for meager advantages a lot, and really emphasizes the fun in the journey rather than the destination. I've really come to embrace this in personal projects because no one'll fire me for taking too long thinking about minor things. I wonder how people get away with reimplementing boost in production code though...

### Debugging sucks, so let's make sure error scenarios are clear

I spent a lot of time putting together a pretty flexible results system within a single header, a little like Rust's own `Result<...>` type.

It works like this:
* A `Result` is defined via a string literal description and whether or not it should be considered a success
* A `ResultSet` is a wrapper around several results and a particular object (a return value)

It's possible to cast a `ResultSet` of one function into another as long as the target result set can handle all the possible results of the source set.

So every single result is expected to be explicitly handled, or caught at compile-time when it's not. The results themselves have string literals that can be propagated up to callers.

So you can go from one result type to another while preserving the underlying Result value, as long as the states can be determined at compile-time:

    
    {
        using ResultSetTestInt   = ResultSet<int, ResultSuccess>;
        using ResultSetTestFloat = ResultSet<float, ResultSuccess, ResultFailure>;

        int  a                   = 255;
        auto resultInt           = ResultSetTestInt::DefaultResultSuccess(a);
        TEST_CHECK(static_cast<int>(resultInt) == 0xFF);

        auto resultFloat = static_cast<ResultSetTestFloat>(resultInt);
        TEST_CHECK(static_cast<float>(resultFloat) == 255.0f);
    }

The caller will (must) always know what it's calling can actually return. No offline integer-to-string lookups or dynamic exception handling.

    
### Basic Building Blocks

So in another fun over-complication, I decided to think about how to represent the underlying register types.

The GameBoy has a register file that contains a handful of registers that can also be referenced in pairs, including:
* An 8-bit accumulator register `A` and "4-bit" (8 with the lower 4 bits always 0) flag register `F`
* Several registers accessible as 8-bit pairs or a single 16-bit register (`BC` or `B` and `C`, `DE` or `D` and `E`, `HL` or `H` and `L`)
* A program counter and stack pointer, each accessible as 16-bit registers (`PC` and `SP`, respectively)

Each register has different access expectations and would benefit from slightly different access patterns, with the flexibility to be used in multiple configurations. While it's pretty trivial to just create some `uint16_t` values and some neat little bitmasking functions, that's not what I'm about. Enter the `Block` class: a representation of data that's meant to emphasize specific access patterns while allowing for others.

For example, given a template `Block<Size, AccessGranularity>`, we can have each register above defined like so:

    //// Accumulator
    Block<8, 8> _A;

    //// Flag
    Block<8, 4> _F;

    //// General purpose
    Block<16, 8> _BC;
    Block<16, 8> _DE;
    Block<16, 8> _HL;

    // Program counter
    Block<16, 16> _PC;

    // Stack pointer
    Block<16, 16> _SP;

Allowing for access to each of these registers with varying access patterns (e.g., a 4-bit `Nibble`, an 8-bit `Byte`, or a 16-bit `Word`).

### A Registry in Many Parts

