/*
 Generates SC_Info keys (.sinf and .supp)
 see http://hackulo.us/wiki/SC_Info
*/

void *create_atom(char *name, uint32_t len, void *content);
void *coalesced_atom(uint32_t amount, uint32_t name, ...);
void *combine_atoms(char *name, int amount, ...);
void *generate_sinf(int appid, char *person_name, int vendorID);
void *generate_supp(uint32_t *suppsize);
