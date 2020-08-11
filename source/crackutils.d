module crackutils;

import std;

uint b = 0x9d2c5680;
uint c = 0xefc60000;

/**
 * Phobo's MT19937 output function
 */
uint zrand(uint z) {
    z ^=  z >> 11;
    z ^= (z <<  7) & b;
    z ^= (z << 15) & c;
    z ^= (z >> 18);
    return z;
}

uint reverseZrand(uint z) {
    z ^= (z >> 18);
    z ^= (z << 15) & c;
    z = undoLshiftXorMask(z, 7, b);
    z ^= z >> 11;
    z ^= z >> 22;
    return z;
}
unittest {
    uint z = 0x12345678;
    assert(z == reverseZrand(zrand(z)));
}

uint undoLshiftXorMask(uint v, uint shift, uint mask) {
    uint bits(uint v, uint start, uint size) {
        return (v >> start) & ((1 << size) - 1);
    }

    foreach (i ; iota(shift, 32, shift))
        v ^= (bits(v, i-shift, shift) & bits(mask, i, shift)) << i;
    return v;
}

/**
 * Recovers the 31 lowest bits of z where z=S_i+n ^ S_i+m
 * The highest bit is the highest bit from the next value
 */
uint reverseScramble(uint z) {
    uint a = 0x9908b0df;

    bool lowbit = false;
    if ((z >> 31) % 2 == 1) {
        z ^= a;
        lowbit = true;
    }

    z = z << 1;
    z |= lowbit;

    return z;
}

uint predictNumber(size_t index, uint[] rawData)
in {
    assert(rawData.length >= index+397);
}
body {
    auto output = rawData.map!reverseZrand.array;

    auto i = output[index];
    auto n = output[index+1];
    auto c = output[index+397];

    return predictNumberImpl(i, n, c);
}

uint predictNumber(uint index, uint next, uint conj) {
    return predictNumberImpl(index.reverseZrand,
                             next.reverseZrand,
                             conj.reverseZrand);
}

uint predictNumberImpl(uint index, uint next, uint conj) {
    immutable n = 624;
    immutable m = 397;
    immutable a = 0x9908b0df;

    uint lowerMask = (cast(uint) 1u << 31) - 1;
    uint upperMask = (~lowerMask) & uint.max;

    uint q = index & upperMask;
    uint p = next  & lowerMask;

    uint y = q | p;

    auto x = y >>1;
    if (y & 1)
        x ^= a;
    x ^= conj;

    return zrand(x);
}

uint[] uuidToUints(UUID u) {
    return u.data[]
            .chunks(4)
            .map!(p => p.to!(ubyte[4]).littleEndianToNative!uint)
            .array;
}

auto predictUuid(UUID[] uuidLst, size_t uuidIndex) {
    uint[] data = uuidLst.map!uuidToUints.join;

    size_t index = uuidIndex * 8;

    uint[] part0;
    foreach (mask1 ; 0..16) {
        uint c = data[index+397];

        c &= ~(15 << 32-12);
        c |= mask1 << 32-12;

        foreach (mask2 ; 0..16) {
            uint n  = data[index+1];

            n &= ~(15 << 32-12);
            n |= mask2 << 32-12;

            part0 ~= predictNumber(data[index], n, c);
        }
    }

    uint[] part1;
    foreach (mask1 ; 0..4) {
        uint n = data[index+1+1];

        n &= ~(3 << 6);
        n |= mask1 << 6;

        foreach (mask2 ; 0..4) {
            uint c = data[index+1+397];

            c &= ~(3 << 6);
            c |= mask2 << 6;

            uint i = data[index+1];
            part1 ~= predictNumber(i, n, c);

            i ^= 1 << 31;
            part1 ~= predictNumber(i, n, c);
        }
    }

    uint part2 = predictNumber(data[index+2],
                               data[index+2+1],
                               data[index+2+397]);

    uint part3 = predictNumber(data[index+3],
                               data[index+3+1],
                               data[index+3+397]);

    UUID[] candidates;
    foreach (p0 ; part0) {
        foreach (p1 ; part1) {
            ubyte[16] candidate;
            candidate[ 0 ..  4] = nativeToLittleEndian(p0);
            candidate[ 4 ..  8] = nativeToLittleEndian(p1);
            candidate[ 8 .. 12] = nativeToLittleEndian(part2);
            candidate[12 .. 16] = nativeToLittleEndian(part3);

            candidate[8] &= 0b10111111;
            candidate[8] |= 0b10000000;

            candidate[6] &= 0b01001111;
            candidate[6] |= 0b01000000;

            candidates ~= UUID(candidate);
        }
    }

    return candidates;
}
