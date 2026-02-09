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
    Block<8, 8> _A; // 8-bit register that's expected to be accessed as 8-bit

    //// Flag
    Block<8, 4> _F; // 8-bit register expected to be accessed by Nibbles

    //// General purpose
    Block<16, 8> _BC; // 16-bit register expected to be accessed in 8-bit chunks
    Block<16, 8> _DE;
    Block<16, 8> _HL;

    // Program counter
    Block<16, 16> _PC; // 16-bit register expected to be accessed as 16-bit

    // Stack pointer
    Block<16, 16> _SP;

Allowing for access to each of these registers with varying access patterns (e.g., a 4-bit `Nibble`, an 8-bit `Byte`, or a 16-bit `Word`) but prioritizing the provided access granularity. With some good compile-time definitions in release builds, I suspect we can make this into the zero-cost abstraction meme.

### A Registry in Many Parts

The last bit for this particular update is my dream of making a compile-time registry of instruction handlers, in several files for organization.

To explain what that means, first let's get some points about instructions:
* Every instruction can just be broken down into a set of operands and operations on the memory and CPU state (for simplicity, I just map things through a single memory map for everything)
* Instruction operations can generally be categorized (loads, arithmetic, logic, etc...)
* Each instruction can map to an opcode (1 byte or 2 bytes) and some variable number of operands (0 to 2 bytes)

So we have instructions like `NOP`, `LD [HL], A` (load the value from A into the memory address represented by `HL`), and `INC BC` (increment `BC`). 

Referencing [gekkio's technical reference](https://github.com/Gekkio/gb-ctr), it's possible to get the general timing and behavior of all the instructions as well. We even have some [tests based on the Ares emulation core](https://github.com/SingleStepTests/sm83/) we can use to validate them!


The intuitive approach to this would be to have some functions for each instruction and maybe use templates to reduce boilerplate, and then finally just have a single large array to 'decode' opcodes.

Seems pretty straightforward... but also feels kinda boring. 

Firstly, I _don't want to keep track of a big array_ and I know with C++ I can define an array at compile-time pretty easily with something like:

    static constexpr auto CreateCallbackMap() noexcept
    {
        // An array of callbacks mapped to the bytes
        std::array<std::size_t (*)(MemoryMap&) noexcept, 0xFF + 1> callbacks{nullptr};

        // Fill the callback array somehow

        return callbacks;
    }

Second, I want to organize each instruction by category in separate files so I can define category-specific operations neatly.

Finally, I want all of this to happen at compile-time so no shenanigans like a static constructor to handle registration.

Given the above conditions, the obvious problem is that "creating a registry at compile-time" means somehow maintaining state at compile-time... luckily, there is a solution! One that's _technically_ within the bounds of the language and requires careful use to not violate the one-definition rule. Enter: `friend-njection` and `Argument-Dependent Lookup` (explained well in [this StackOverflow post](https://stackoverflow.com/questions/72598498/behaviour-of-friend-function-template-returning-deduced-dependent-type-in-class)).

To not bore you with many details, the actual registry header is [here](https://github.com/VariantXYZ/PowerGB/blob/c72b987418c6bdd5e9cedad3d6cb2b14a566f62e/src/common/registry.hpp). 

Effectively, we have an `InstructionDecoder` class template used that ties an opcode with functions and metadata (e.g., CPU ticks) and _also_ appends to a registry. 

The registry itself maintains a callback map that simply gets filled by:

    ((callbacks[Decoders::Opcode] = &Decoders::Execute), ...);

Then each instruction category can be defined in separate files and as long as they end up in the same translation unit (e.g., with `cpu.cpp`), we'll have a compile-time registry defined with everything in a separate file!


## Marching onwards

There were definitely a few things I skipped above, but those were the most interesting I think. Using known tests, I've been able to implement instructions without much trouble, albeit slowly and whenever I find time. It doesn't help that all of this work is happening on my old XPS 13 from 2016 with 8 GB of RAM. I might do another post later about my adventures in trying to speed up build times (those compile-time shenanigans definitely have a cost somewhere...).

In personal projects, especially ones related to reverse engineering, I've generally learned that there's a lot of value in taking the time to understand problems and build a solid foundation. Being able to take each step and validate it is a fantastic privilege that not many fields get to experience, so it feels a bit wasteful to not do it when I can. 

My old man philosophy aside, this has been a really fun project so far and I'm looking forward to researching and implementing the clock and interrupt behavior next, and then graphics!
