module app;

import std;
import web;
import crackutils;
import myrand;

void webDemo() {
    auto web = WebInterface();
    WebRequest  request;
    WebResponse response;
    CookieJar   cookies;

    request = WebRequest("username=user&password=userpassword", cookies);
    response = web.postLogin(request);
    assert(response.code == 200);
    cookies = response.cookies;

    writeln(cookies["SESSID"]);

    response = web.getAccountPage(WebRequest.init);
    writeln(response.content);
}

void testBasicPostdiction() {
    auto prng = myrand.Mt19937(5489u);

    auto n = 624;
    auto m = 397;

    uint[] rawOutput = prng.take(n*3).array;


    uint target = 1;
    uint conj   = target + m - 1;
    uint index  = target + n - 1;

    uint w = rawOutput[index];
    w &= 0b10111111111111111111111111111111;
    w |= 0b10000000000000000000000000000000;

    //w &= 0b11111111111111110100111111111111;
    //w |= 0b00000000000000000100000000000000;

    writefln("%0.32b", w);
    writefln("%0.32b", rawOutput[index]);

    writefln("%0.32b", reverseZrand(w));
    writefln("%0.32b", reverseZrand(rawOutput[index]));

    //uint z = reverseZrand(rawOutput[index]);
    uint z = reverseZrand(w);
    z ^= reverseZrand(rawOutput[conj]);

    writefln("Target:      %0.8x", reverseZrand(rawOutput[target]));
    writefln("Postdiction: %0.8x", reverseScramble(z));

    writefln("Target:      %0.32b", reverseZrand(rawOutput[target]));
    writefln("Postdiction: %0.32b", reverseScramble(z));
    writefln("             %0.32b", reverseZrand(rawOutput[target])
                                  ^ reverseScramble(z));
}

void testReverseZrand() {
    auto prng = myrand.Mt19937(5489u);

    uint z = prng.take(2).array[1];
    writefln("%0.8x\n%0.8x", z, reverseZrand(z));
}

void testPrediction() {
    auto prng = myrand.Mt19937(5489u);

    auto n = 624;
    auto m = 397;
    uint a = 0x9908b0df;

    uint[] rawOutput = prng.take(n*3).array;

    uint index  = 4;
    uint target = index + n;

    auto prediction = predictNumber(index, rawOutput);

    writefln("Target:     %0.8x %0.32b", rawOutput[target], rawOutput[target]);
    writefln("Prediction: %0.8x %0.32b", prediction, prediction);
}

void testPredictUuid() {
    auto prng = myrand.Mt19937(unpredictableSeed);

    UUID[] uuidLst = iota(624 / 4 + 10).map!(x => randomUUID(prng)).array;

    auto candidates = predictUuid(uuidLst, 0).array;

    writeln("Target: ", uuidLst[156]);
    writeln(candidates.canFind(uuidLst[156]) ? "UUID was found!" : "Not found");
}

void main(string[] argv) {
    testPredictUuid();
}
