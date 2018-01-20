/*
 Generates SC_Info keys (.sinf and .supp)
 see https://archive.fo/PNfJ5
 */

#import "scinfo.h"

// create a SINF atom
void *create_atom(char *name, uint32_t len, void *content) {
    uint32_t atomsize = len + 8;
    void *buf = malloc(atomsize);

    atomsize = CFSwapInt32(atomsize);

    memcpy(buf, &atomsize, 4);             // copy atomsize
    memcpy((char *)buf + 4, name, 4);      // copy atom name
    memcpy((char *)buf + 8, content, len); // copy atom content

    return buf;
}

void *coalesced_atom(uint32_t amount, uint32_t name, ...) {
    va_list vl;
    va_start(vl, name);
    uint32_t atomsize = 8 + amount * 8; // 8 bytes per field, 8 bytes for atom header

    amount = amount * 2;

    void *buf = malloc(atomsize);

    atomsize = CFSwapInt32(atomsize);

    memcpy(buf, &atomsize, 4);         // copy atom size
    memcpy((char *)buf + 4, &name, 4); // copy name

    uint32_t *curpos = (uint32_t *)buf + 2;

    for (uint32_t i = 0; i < amount; i++) {
        uint32_t arg = va_arg(vl, uint32_t);
        if (i % 2) {
            arg = CFSwapInt32(arg);
        }

        memcpy(curpos, &arg, 4);
        curpos += 1;
    }

    va_end(vl);
    return buf;
}

void *combine_atoms(char *name, int amount, ...) {
    // combine all of the given atoms
    va_list vl;
    va_start(vl, amount);

    uint32_t atomsize = 8;

    for (int i = 0; i < amount; i++) {
        void *atom = va_arg(vl, void *);
        atomsize += CFSwapInt32(*(uint32_t *)atom);
    }

    void *buf = malloc(atomsize + 8);
    atomsize = CFSwapInt32(atomsize);

    memcpy(buf, &atomsize, 4);        // atom size
    memcpy((char *)buf + 4, name, 4); // atom name

    va_start(vl, amount);

    char *curloc = (char *)buf + 8;

    for (int i = 0; i < amount; i++) {
        void *atom = va_arg(vl, void *);
        uint32_t content = CFSwapInt32(*(uint32_t *)atom);

        memcpy(curloc, atom, content);
        curloc += content;
    }

    va_end(vl);

    return buf;
}

void *generate_supp(uint32_t *suppsize) {
    // create a random 100612 byte file
    uint32_t *supp = malloc(100612);
    *suppsize = 100612;

    for (int i = 0; i < 25153; i++) {
        supp[i] = arc4random();
    }

    return supp;
}

// generate a fake .sinf file
void *generate_sinf(int appid, char *person_name, int vendorID) {
    // sinf.schi.righ is an atom of several misc. fields related to the application
    void *fakerigh = coalesced_atom(10,
                                    *(uint32_t *)"righ",
                                    *(uint32_t *)"veID",
                                    vendorID, // ?
                                    *(uint32_t *)"plat",
                                    0, // platform?
                                    *(uint32_t *)"aver",
                                    0x1010100, // app version?
                                    *(uint32_t *)"tran",
                                    arc4random(), // transaction ID
                                    *(uint32_t *)"song",
                                    appid, // appid
                                    *(uint32_t *)"tool",
                                    1345598006, // itunes build?
                                    *(uint32_t *)"medi",
                                    0x80, // ?
                                    *(uint32_t *)"mode",
                                    0x0, // ?
                                    0x0,
                                    0x0, // padding
                                    0x0,
                                    0x0 // padding
    );

    // sinf.schi.user is a userid. make it random
    uint32_t fakeuserid = arc4random();
    void *user = create_atom("user", 4, &fakeuserid);

    // sinf.schi.key is a key index in itunes, a small integer. let's pick 1
    uint32_t fakekeyindex = CFSwapInt32(1);
    void *key = create_atom("key ", 4, &fakekeyindex);

    // sinf.schi.iviv is a 128bit IV for the private key
    uint32_t *iviv = malloc(16);
    for (int i = 0; i < 4; i++) {
        iviv[i] = arc4random();
    }

    void *fakeiviv = create_atom("iviv", 16, iviv);
    free(iviv);

    // sinf.schi.name is a 256 byte name of the iTunes account owner
    char *name = malloc(256);

    memset(name, 0x0, 256);
    memcpy(name, person_name, strlen(person_name));

    void *fakename = create_atom("name", 256, name);
    free(name);

    // sinf.schi.priv is a 440 byte private key
    uint32_t *fakepriv = malloc(440);

    for (int i = 0; i < 110; i++) {
        if (i > 107) {
            fakepriv[i] = 0;
        } else {
            fakepriv[i] = arc4random();
        }
    }

    void *priv = create_atom("priv", 440, fakepriv);
    free(fakepriv);

    void *schi = combine_atoms("schi", 6, user, key, fakeiviv, fakerigh, fakename, priv);
    free(user);
    free(key);
    free(fakeiviv);
    free(fakerigh);
    free(fakename);
    free(priv);

    // sinf.frma = "game"
    void *frma = create_atom("frma", 4, "game");

    // sinf.schm = "\x00000000itun\x00000000"
    void *schm = create_atom("schm", 12, "\x00\x00\x00\x00itun\x00\x00\x00\x00");

    uint32_t *sign = malloc(128);

    for (int i = 0; i < 32; i++) {
        sign[i] = arc4random();
    }

    void *fakesign = create_atom("sign", 128, sign);
    free(sign);

    void *sinf = combine_atoms("sinf", 4, frma, schm, schi, fakesign);
    free(frma);
    free(schm);
    free(schi);
    free(fakesign);

    return sinf;
}
