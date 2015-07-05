/*
--------------------------------------------------------------------
lookup2.c, by Bob Jenkins, December 1996, Public Domain.
hash(), hash2(), hash3, and mix() are externally useful functions.
Routines to test the hash are included if SELF_TEST is defined.
You can use this free for any purpose.  It has no warranty.
--------------------------------------------------------------------
*/
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
typedef  unsigned long  int  ub4;   /* unsigned 4-byte quantities */
typedef  unsigned       char ub1;

#define hashsize(n) ((ub4)1<<(n))
#define hashmask(n) (hashsize(n)-1)

/*
--------------------------------------------------------------------
mix -- mix 3 32-bit values reversibly.
For every delta with one or two bit set, and the deltas of all three
  high bits or all three low bits, whether the original value of a,b,c
  is almost all zero or is uniformly distributed,
* If mix() is run forward or backward, at least 32 bits in a,b,c
  have at least 1/4 probability of changing.
* If mix() is run forward, every bit of c will change between 1/3 and
  2/3 of the time.  (Well, 22/100 and 78/100 for some 2-bit deltas.)
mix() was built out of 36 single-cycle latency instructions in a 
  structure that could supported 2x parallelism, like so:
      a -= b; 
      a -= c; x = (c>>13);
      b -= c; a ^= x;
      b -= a; x = (a<<8);
      c -= a; b ^= x;
      c -= b; x = (b>>13);
      ...
  Unfortunately, superscalar Pentiums and Sparcs can't take advantage 
  of that parallelism.  They've also turned some of those single-cycle
  latency instructions into multi-cycle latency instructions.  Still,
  this is the fastest good hash I could find.  There were about 2^^68
  to choose from.  I only looked at a billion or so.
--------------------------------------------------------------------
*/
#define mix(a,b,c) \
{ \
  a -= b; a -= c; a ^= (c>>13); \
  b -= c; b -= a; b ^= (a<<8); \
  c -= a; c -= b; c ^= (b>>13); \
  a -= b; a -= c; a ^= (c>>12);  \
  b -= c; b -= a; b ^= (a<<16); \
  c -= a; c -= b; c ^= (b>>5); \
  a -= b; a -= c; a ^= (c>>3);  \
  b -= c; b -= a; b ^= (a<<10); \
  c -= a; c -= b; c ^= (b>>15); \
}

/* same, but slower, works on systems that might have 8 byte ub4's */
#define mix2(a,b,c) \
{ \
  a -= b; a -= c; a ^= (c>>13); \
  b -= c; b -= a; b ^= (a<< 8); \
  c -= a; c -= b; c ^= ((b&0xffffffff)>>13); \
  a -= b; a -= c; a ^= ((c&0xffffffff)>>12); \
  b -= c; b -= a; b = (b ^ (a<<16)) & 0xffffffff; \
  c -= a; c -= b; c = (c ^ (b>> 5)) & 0xffffffff; \
  a -= b; a -= c; a = (a ^ (c>> 3)) & 0xffffffff; \
  b -= c; b -= a; b = (b ^ (a<<10)) & 0xffffffff; \
  c -= a; c -= b; c = (c ^ (b>>15)) & 0xffffffff; \
}

/*
--------------------------------------------------------------------
hash() -- hash a variable-length key into a 32-bit value
  k     : the key (the unaligned variable-length array of bytes)
  len   : the length of the key, counting by bytes
  level : can be any 4-byte value
Returns a 32-bit value.  Every bit of the key affects every bit of
the return value.  Every 1-bit and 2-bit delta achieves avalanche.
About 36+6len instructions.

The best hash table sizes are powers of 2.  There is no need to do
mod a prime (mod is sooo slow!).  If you need less than 32 bits,
use a bitmask.  For example, if you need only 10 bits, do
  h = (h & hashmask(10));
In which case, the hash table should have hashsize(10) elements.

If you are hashing n strings (ub1 **)k, do it like this:
  for (i=0, h=0; i<n; ++i) h = hash( k[i], len[i], h);

By Bob Jenkins, 1996.  bob_jenkins@burtleburtle.net.  You may use this
code any way you wish, private, educational, or commercial.  It's free.

See http://burlteburtle.net/bob/hash/evahash.html
Use for hash table lookup, or anything where one collision in 2^32 is
acceptable.  Do NOT use for cryptographic purposes.
--------------------------------------------------------------------
*/

ub4 hash( k, length, initval)
register ub1 *k;        /* the key */
register ub4  length;   /* the length of the key */
register ub4  initval;    /* the previous hash, or an arbitrary value */
{
   register ub4 a,b,c,len;

   /* Set up the internal state */
   len = length;
   a = b = 0x9e3779b9;  /* the golden ratio; an arbitrary value */
   c = initval;           /* the previous hash value */

   /*---------------------------------------- handle most of the key */
   while (len >= 12)
   {
      a += (k[0] +((ub4)k[1]<<8) +((ub4)k[2]<<16) +((ub4)k[3]<<24));
      b += (k[4] +((ub4)k[5]<<8) +((ub4)k[6]<<16) +((ub4)k[7]<<24));
      c += (k[8] +((ub4)k[9]<<8) +((ub4)k[10]<<16)+((ub4)k[11]<<24));
      mix(a,b,c);
      k += 12; len -= 12;
   }

   /*------------------------------------- handle the last 11 bytes */
   c += length;
   switch(len)              /* all the case statements fall through */
   {
   case 11: c+=((ub4)k[10]<<24);
   case 10: c+=((ub4)k[9]<<16);
   case 9 : c+=((ub4)k[8]<<8);
      /* the first byte of c is reserved for the length */
   case 8 : b+=((ub4)k[7]<<24);
   case 7 : b+=((ub4)k[6]<<16);
   case 6 : b+=((ub4)k[5]<<8);
   case 5 : b+=k[4];
   case 4 : a+=((ub4)k[3]<<24);
   case 3 : a+=((ub4)k[2]<<16);
   case 2 : a+=((ub4)k[1]<<8);
   case 1 : a+=k[0];
     /* case 0: nothing left to add */
   }
   mix(a,b,c);
   /*-------------------------------------------- report the result */
   return c;
}


/*
--------------------------------------------------------------------
 This works on all machines.  hash2() is identical to hash() on 
 little-endian machines, except that the length has to be measured
 in ub4s instead of bytes.  It is much faster than hash().  It 
 requires
 -- that the key be an array of ub4's, and
 -- that all your machines have the same endianness, and
 -- that the length be the number of ub4's in the key
--------------------------------------------------------------------
*/
ub4 hash2( k, length, initval)
register ub4 *k;        /* the key */
register ub4  length;   /* the length of the key, in ub4s */
register ub4  initval;  /* the previous hash, or an arbitrary value */
{
   register ub4 a,b,c,len;

   /* Set up the internal state */
   len = length;
   a = b = 0x9e3779b9;  /* the golden ratio; an arbitrary value */
   c = initval;           /* the previous hash value */

   /*---------------------------------------- handle most of the key */
   while (len >= 3)
   {
      a += k[0];
      b += k[1];
      c += k[2];
      mix(a,b,c);
      k += 3; len -= 3;
   }

   /*-------------------------------------- handle the last 2 ub4's */
   c += length;
   switch(len)              /* all the case statements fall through */
   {
     /* c is reserved for the length */
   case 2 : b+=k[1];
   case 1 : a+=k[0];
     /* case 0: nothing left to add */
   }
   mix(a,b,c);
   /*-------------------------------------------- report the result */
   return c;
}

/*
--------------------------------------------------------------------
 This is identical to hash() on little-endian machines (like Intel 
 x86s or VAXen).  It gives nondeterministic results on big-endian
 machines.  It is faster than hash(), but a little slower than 
 hash2(), and it requires
 -- that all your machines be little-endian
--------------------------------------------------------------------
*/

ub4 hash3( k, length, initval)
register ub1 *k;        /* the key */
register ub4  length;   /* the length of the key */
register ub4  initval;  /* the previous hash, or an arbitrary value */
{
   register ub4 a,b,c,len;

   /* Set up the internal state */
   len = length;
   a = b = 0x9e3779b9;    /* the golden ratio; an arbitrary value */
   c = initval;           /* the previous hash value */

   /*---------------------------------------- handle most of the key */
   if (((ub4)k)&3)
   {
      while (len >= 12)    /* unaligned */
      {
         a += (k[0] +((ub4)k[1]<<8) +((ub4)k[2]<<16) +((ub4)k[3]<<24));
         b += (k[4] +((ub4)k[5]<<8) +((ub4)k[6]<<16) +((ub4)k[7]<<24));
         c += (k[8] +((ub4)k[9]<<8) +((ub4)k[10]<<16)+((ub4)k[11]<<24));
         mix(a,b,c);
         k += 12; len -= 12;
      }
   }
   else
   {
      while (len >= 12)    /* aligned */
      {
         a += *(ub4 *)(k+0);
         b += *(ub4 *)(k+4);
         c += *(ub4 *)(k+8);
         mix(a,b,c);
         k += 12; len -= 12;
      }
   }

   /*------------------------------------- handle the last 11 bytes */
   c += length;
   switch(len)              /* all the case statements fall through */
   {
   case 11: c+=((ub4)k[10]<<24);
   case 10: c+=((ub4)k[9]<<16);
   case 9 : c+=((ub4)k[8]<<8);
      /* the first byte of c is reserved for the length */
   case 8 : b+=((ub4)k[7]<<24);
   case 7 : b+=((ub4)k[6]<<16);
   case 6 : b+=((ub4)k[5]<<8);
   case 5 : b+=k[4];
   case 4 : a+=((ub4)k[3]<<24);
   case 3 : a+=((ub4)k[2]<<16);
   case 2 : a+=((ub4)k[1]<<8);
   case 1 : a+=k[0];
     /* case 0: nothing left to add */
   }
   mix(a,b,c);
   /*-------------------------------------------- report the result */
   return c;
}



#ifdef SELF_TEST

/* used for timings */
void driver1()
{
  ub4 buf[256];
  ub4 i;
  ub4 h=0;

  for (i=0; i<256; ++i) 
  {
    h = hash(buf,i,h);
  }
}

/* check that every input bit changes every output bit half the time */
#define HASHSTATE 1
#define HASHLEN   1
#define MAXPAIR 80
#define MAXLEN 70
void driver2()
{
  ub1 qa[MAXLEN+1], qb[MAXLEN+2], *a = &qa[0], *b = &qb[1];
  ub4 c[HASHSTATE], d[HASHSTATE], i, j=0, k, l, m, z;
  ub4 e[HASHSTATE],f[HASHSTATE],g[HASHSTATE],h[HASHSTATE];
  ub4 x[HASHSTATE],y[HASHSTATE];
  ub4 hlen;

  printf("No more than %d trials should ever be needed \n",MAXPAIR/2);
  for (hlen=0; hlen < MAXLEN; ++hlen)
  {
    z=0;
    for (i=0; i<hlen; ++i)  /*----------------------- for each input byte, */
    {
      for (j=0; j<8; ++j)   /*------------------------ for each input bit, */
      {
	for (m=1; m<8; ++m) /*------------ for serveral possible initvals, */
	{
	  for (l=0; l<HASHSTATE; ++l) e[l]=f[l]=g[l]=h[l]=x[l]=y[l]=~((ub4)0);

      	  /*---- check that every output bit is affected by that input bit */
	  for (k=0; k<MAXPAIR; k+=2)
	  { 
	    ub4 finished=1;
	    /* keys have one bit different */
	    for (l=0; l<hlen+1; ++l) {a[l] = b[l] = (ub1)0;}
	    /* have a and b be two keys differing in only one bit */
	    a[i] ^= (k<<j);
	    a[i] ^= (k>>(8-j));
	     c[0] = hash(a, hlen, m);
	    b[i] ^= ((k+1)<<j);
	    b[i] ^= ((k+1)>>(8-j));
	     d[0] = hash(b, hlen, m);
	    /* check every bit is 1, 0, set, and not set at least once */
	    for (l=0; l<HASHSTATE; ++l)
	    {
	      e[l] &= (c[l]^d[l]);
	      f[l] &= ~(c[l]^d[l]);
	      g[l] &= c[l];
	      h[l] &= ~c[l];
	      x[l] &= d[l];
	      y[l] &= ~d[l];
	      if (e[l]|f[l]|g[l]|h[l]|x[l]|y[l]) finished=0;
	    }
	    if (finished) break;
	  }
	  if (k>z) z=k;
	  if (k==MAXPAIR) 
	  {
	     printf("Some bit didn't change: ");
	     printf("%.8lx %.8lx %.8lx %.8lx %.8lx %.8lx  ",
	            e[0],f[0],g[0],h[0],x[0],y[0]);
	     printf("i %ld j %ld m %ld len %ld\n",i,j,m,hlen);
	  }
	  if (z==MAXPAIR) goto done;
	}
      }
    }
   done:
    if (z < MAXPAIR)
    {
      printf("Mix success  %2ld bytes  %2ld initvals  ",i,m);
      printf("required  %ld  trials\n",z/2);
    }
  }
  printf("\n");
}

/* Check for reading beyond the end of the buffer and alignment problems */
void driver3()
{
  ub1 buf[MAXLEN+20], *b;
  ub4 len;
  ub1 q[] = "This is the time for all good men to come to the aid of their country";
  ub1 qq[] = "xThis is the time for all good men to come to the aid of their country";
  ub1 qqq[] = "xxThis is the time for all good men to come to the aid of their country";
  ub1 qqqq[] = "xxxThis is the time for all good men to come to the aid of their country";
  ub4 h,i,j,ref,x,y;

  printf("Endianness.  These should all be the same:\n");
  printf("%.8lx\n", hash(q, sizeof(q)-1, (ub4)0));
  printf("%.8lx\n", hash(qq+1, sizeof(q)-1, (ub4)0));
  printf("%.8lx\n", hash(qqq+2, sizeof(q)-1, (ub4)0));
  printf("%.8lx\n", hash(qqqq+3, sizeof(q)-1, (ub4)0));
  printf("\n");
  for (h=0, b=buf+1; h<8; ++h, ++b)
  {
    for (i=0; i<MAXLEN; ++i)
    {
      len = i;
      for (j=0; j<i; ++j) *(b+j)=0;

      /* these should all be equal */
      ref = hash(b, len, (ub4)1);
      *(b+i)=(ub1)~0;
      *(b-1)=(ub1)~0;
      x = hash(b, len, (ub4)1);
      y = hash(b, len, (ub4)1);
      if ((ref != x) || (ref != y)) 
      {
	printf("alignment error: %.8lx %.8lx %.8lx %ld %ld\n",ref,x,y,h,i);
      }
    }
  }
}

/* check for problems with nulls */
 void driver4()
{
  ub1 buf[1];
  ub4 h,i,state[HASHSTATE];


  buf[0] = ~0;
  for (i=0; i<HASHSTATE; ++i) state[i] = 1;
  printf("These should all be different\n");
  for (i=0, h=0; i<8; ++i)
  {
    h = hash(buf, (ub4)0, h);
    printf("%2ld  0-byte strings, hash is  %.8lx\n", i, h);
  }
}


int main()
{
  driver1();   /* test that the key is hashed: used for timings */
  driver2();   /* test that whole key is hashed thoroughly */
  driver3();   /* test that nothing but the key is hashed */
  driver4();   /* test hashing multiple buffers (all buffers are null) */
  return 1;
}

#endif  /* SELF_TEST */
