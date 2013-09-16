/*
 Generates SC_Info keys (.sinf and .supp)
 see http://hackulo.us/wiki/SC_Info
*/

void *create_atom(char *name, int len, void *content);
void *coalesced_atom(int amount, uint32_t name, ...);
void *combine_atoms(char *name, int amount, ...);
void *generate_sinf(int appid, char *cracker_name, int vendorID);
void *generate_supp(uint32_t *suppsize);