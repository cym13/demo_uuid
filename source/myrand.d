module myrand;

import std.range.primitives;
import std.traits;
import std.stdio;

/**
The $(LINK2 https://en.wikipedia.org/wiki/Mersenne_Twister, Mersenne Twister) generator.
 */
struct MersenneTwisterEngine(UIntType, size_t w, size_t n, size_t m, size_t r,
                             UIntType a, size_t u, UIntType d, size_t s,
                             UIntType b, size_t t,
                             UIntType c, size_t l, UIntType f)
if (isUnsigned!UIntType)
{
    static assert(0 < w && w <= UIntType.sizeof * 8);
    static assert(1 <= m && m <= n);
    static assert(0 <= r && 0 <= u && 0 <= s && 0 <= t && 0 <= l);
    static assert(r <= w && u <= w && s <= w && t <= w && l <= w);
    static assert(0 <= a && 0 <= b && 0 <= c);
    static assert(n <= ptrdiff_t.max);

    ///Mark this as a Rng
    enum bool isUniformRandom = true;

/**
Parameters for the generator.
*/
    enum size_t   wordSize   = w;
    enum size_t   stateSize  = n; /// ditto
    enum size_t   shiftSize  = m; /// ditto
    enum size_t   maskBits   = r; /// ditto
    enum UIntType xorMask    = a; /// ditto
    enum size_t   temperingU = u; /// ditto
    enum UIntType temperingD = d; /// ditto
    enum size_t   temperingS = s; /// ditto
    enum UIntType temperingB = b; /// ditto
    enum size_t   temperingT = t; /// ditto
    enum UIntType temperingC = c; /// ditto
    enum size_t   temperingL = l; /// ditto
    enum UIntType initializationMultiplier = f; /// ditto

    /// Smallest generated value (0).
    enum UIntType min = 0;
    /// Largest generated value.
    enum UIntType max = UIntType.max >> (UIntType.sizeof * 8u - w);
    // note, `max` also serves as a bitmask for the lowest `w` bits
    static assert(a <= max && b <= max && c <= max && f <= max);

    /// The default seed value.
    enum UIntType defaultSeed = 5489u;

    // Bitmasks used in the 'twist' part of the algorithm
    enum UIntType lowerMask = (cast(UIntType) 1u << r) - 1,
                  upperMask = (~lowerMask) & this.max;

    /*
       Collection of all state variables
       used by the generator
    */
    struct State
    {
        /*
           State array of the generator.  This
           is iterated through backwards (from
           last element to first), providing a
           few extra compiler optimizations by
           comparison to the forward iteration
           used in most implementations.
        */
        UIntType[n] data;

        /*
           Cached copy of most recently updated
           element of `data` state array, ready
           to be tempered to generate next
           `front` value
        */
        UIntType z;

        /*
           Most recently generated random variate
        */
        UIntType front;

        /*
           Index of the entry in the `data`
           state array that will be twisted
           in the next `popFront()` call
        */
        size_t index;
    }

    /*
       State variables used by the generator;
       initialized to values equivalent to
       explicitly seeding the generator with
       `defaultSeed`
    */
    State state = defaultState();
    /* NOTE: the above is a workaround to ensure
       backwards compatibility with the original
       implementation, which permitted implicit
       construction.  With `@disable this();`
       it would not be necessary. */

/**
   Constructs a MersenneTwisterEngine object.
*/
    this(UIntType value)   
    {
        seed(value);
    }

    /**
       Generates the default initial state for a Mersenne
       Twister; equivalent to the internal state obtained
       by calling `seed(defaultSeed)`
    */
    static State defaultState()   
    {
        if (!__ctfe) assert(false);
        State mtState;
        seedImpl(defaultSeed, mtState);
        return mtState;
    }

/**
   Seeds a MersenneTwisterEngine object.
   Note:
   This seed function gives 2^w starting points (the lowest w bits of
   the value provided will be used). To allow the RNG to be started
   in any one of its internal states use the seed overload taking an
   InputRange.
*/
    void seed()(UIntType value = defaultSeed)   
    {
        this.seedImpl(value, this.state);
    }

    /**
       Implementation of the seeding mechanism, which
       can be used with an arbitrary `State` instance
    */
    static void seedImpl(UIntType value, ref State mtState)
    {
        mtState.data[$ - 1] = value;
        static if (this.max != UIntType.max)
        {
            mtState.data[$ - 1] &= this.max;
        }

        foreach_reverse (size_t i, ref e; mtState.data[0 .. $ - 1])
        {
            e = f * (mtState.data[i + 1] ^ (mtState.data[i + 1] >> (w - 2))) + cast(UIntType)(n - (i + 1));
            static if (this.max != UIntType.max)
            {
                e &= this.max;
            }
        }

        mtState.index = n - 1;

        /* double popFront() to guarantee both `mtState.z`
           and `mtState.front` are derived from the newly
           set values in `mtState.data` */
        MersenneTwisterEngine.popFrontImpl(mtState);
        MersenneTwisterEngine.popFrontImpl(mtState);
    }

/**
   Seeds a MersenneTwisterEngine object using an InputRange.

   Throws:
   `Exception` if the InputRange didn't provide enough elements to seed the generator.
   The number of elements required is the 'n' template parameter of the MersenneTwisterEngine struct.
 */
    void seed(T)(T range) if (isInputRange!T && is(Unqual!(ElementType!T) == UIntType))
    {
        this.seedImpl(range, this.state);
    }

    /**
       Implementation of the range-based seeding mechanism,
       which can be used with an arbitrary `State` instance
    */
    static void seedImpl(T)(T range, ref State mtState)
        if (isInputRange!T && is(Unqual!(ElementType!T) == UIntType))
    {
        size_t j;
        for (j = 0; j < n && !range.empty; ++j, range.popFront())
        {
            ptrdiff_t idx = n - j - 1;
            mtState.data[idx] = range.front;
        }

        mtState.index = n - 1;

        if (range.empty && j < n)
        {
            import core.internal.string : UnsignedStringBuf, unsignedToTempString;

            UnsignedStringBuf buf = void;
            string s = "MersenneTwisterEngine.seed: Input range didn't provide enough elements: Need ";
            s ~= unsignedToTempString(n, buf, 10) ~ " elements.";
            throw new Exception(s);
        }

        /* double popFront() to guarantee both `mtState.z`
           and `mtState.front` are derived from the newly
           set values in `mtState.data` */
        MersenneTwisterEngine.popFrontImpl(mtState);
        MersenneTwisterEngine.popFrontImpl(mtState);
    }

/**
   Advances the generator.
*/
    void popFront() @trusted
    {
        this.popFrontImpl(this.state);
    }

    /*
       Internal implementation of `popFront()`, which
       can be used with an arbitrary `State` instance
    */
    static void popFrontImpl(ref State mtState)
    {
        /* This function blends two nominally independent
           processes: (i) calculation of the next random
           variate `mtState.front` from the cached previous
           `data` entry `z`, and (ii) updating the value
           of `data[index]` and `mtState.z` and advancing
           the `index` value to the next in sequence.

           By interweaving the steps involved in these
           procedures, rather than performing each of
           them separately in sequence, the variables
           are kept 'hot' in CPU registers, allowing
           for significantly faster performance. */
        ptrdiff_t index = mtState.index;
        ptrdiff_t next = index - 1;
        if (next < 0)
            next = n - 1;
        auto z = mtState.z;
        ptrdiff_t conj = index - m;
        if (conj < 0)
            conj = index - m + n;

        /*
        if (! __ctfe) {
            writefln("Index [%d]\t%0.8x %0.32b",
                     index, mtState.data[index], mtState.data[index]);
            writefln("Next  [%d]\t%0.8x %0.32b",
                     next, mtState.data[next], mtState.data[next]);
            writefln("Conj  [%d]\t%0.8x %0.32b",
                     conj, mtState.data[conj], mtState.data[conj]);
        }
        */

        static if (d == UIntType.max)
        {
            z ^= (z >> u);
        }
        else
        {
            z ^= (z >> u) & d;
        }

        auto q = mtState.data[index] & upperMask;
        auto p = mtState.data[next] & lowerMask;

        /*
        if (! __ctfe) {
            writefln("q %0.8x", q);
            writefln("p %0.8x", p);
        }
        */

        z ^= (z << s) & b;
        auto y = q | p;
        auto x = y >> 1;
        /*
        if (! __ctfe) {
            writefln("y %0.8x", y);
            writefln("x %0.8x", x);
        }
        */
        z ^= (z << t) & c;
        if (y & 1)
            x ^= a;
        auto e = mtState.data[conj] ^ x;
        /*
        if (! __ctfe) {
            writefln("y %0.8x", y);
            writefln("x %0.8x", x);
        }
        */
        z ^= (z >> l);
        mtState.z = mtState.data[index] = e;
        mtState.index = next;

        /* technically we should take the lowest `w`
           bits here, but if the tempering bitmasks
           `b` and `c` are set correctly, this should
           be unnecessary */
        mtState.front = z;
    }

/**
   Returns the current random value.
 */
    @property UIntType front()  const  
    {
        return this.state.front;
    }

///
    @property typeof(this) save()  const  
    {
        return this;
    }

/**
Always `false`.
 */
    enum bool empty = false;
}

/**
A `MersenneTwisterEngine` instantiated with the parameters of the
original engine $(HTTP math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html,
MT19937), generating uniformly-distributed 32-bit numbers with a
period of 2 to the power of 19937. Recommended for random number
generation unless memory is severely restricted, in which case a $(LREF
LinearCongruentialEngine) would be the generator of choice.
 */
alias Mt19937 = MersenneTwisterEngine!(uint, 32, 624, 397, 31,
                                       0x9908b0df, 11, 0xffffffff, 7,
                                       0x9d2c5680, 15,
                                       0xefc60000, 18, 1_812_433_253);

/**
 * ditto
 */
template isUniformRNG(Rng)
{
    enum bool isUniformRNG = isInputRange!Rng &&
        is(typeof(
        {
            static assert(Rng.isUniformRandom); //tag
        }));
}

/**
 * Test if Rng is seedable. The overload
 * taking a SeedType also makes sure that the Rng can be seeded with SeedType.
 *
 * A seedable random-number generator has the following additional features:
 * $(UL
 *   $(LI it has a 'seed(ElementType)' function)
 * )
 */
template isSeedable(Rng, SeedType)
{
    enum bool isSeedable = isUniformRNG!(Rng) &&
        is(typeof(
        {
            Rng r = void;              // can define a Rng object
            SeedType s = void;
            r.seed(s); // can seed a Rng
        }));
}

///ditto
template isSeedable(Rng)
{
    enum bool isSeedable = isUniformRNG!Rng &&
        is(typeof(
        {
            Rng r = void;                     // can define a Rng object
            alias SeedType = typeof(r.front);
            SeedType s = void;
            r.seed(s); // can seed a Rng
        }));
}

