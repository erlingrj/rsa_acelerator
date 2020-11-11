import rsa
import random

def mod_exp(A, B, n, N_BITS=256, debug = False):
    # This function takes the multiplicands A and B
    # and performs P = A*B (mod n)
    if debug:
        print(f"A={A}, B={B}, n={n}")
    P = 0
    for i in range(N_BITS-1, -1, -1):
        P = (P << 1) + A * ((B >> i) & 1)
        if (P >= n):
            P = P - n
        if (P >= n):
            P = P - n
        assert ( P < n ), f"Modulus operation failed P={P}, n={n}, i={i}"
        if debug:
            print("i={}, P={}".format(i,hex(P)))
    return P

def mod_mult_radix4(A,B,n,N_BITS=256, debug=False):
    P = 0
    for i in range(N_BITS-1, 0, -2):
        select = (B >> (i - 1)) & 0b11

        if select == 0b00:
            P = P << 2
        elif select == 0b10:
            P = (P << 2) + (A << 1)
        elif select == 0b01:
            P = (P << 2) + A
        elif select == 0b11:
            P = (P << 2) + (A << 1) + A
        if debug:
            print("i={} sel={} P1={}".format(i, select, hex(P)))
        for i in range(6):
            if (P >= n):
                P = P - n
        assert ( P < n ), "Modulus operation failed P={} n={}".format(hex(P),hex(n))
        if debug:
            print("i={}       P2={}".format(i, hex(P)))
    return P




def decrypt(M, n, e, N_BITS=256, debug = False):
    # This function takes the message M of 256bits and
    # public key e and n is the modulus
    assert (M < 2 ** N_BITS+1), "M has mropythine than 256 bits"
    assert (e < 2 ** N_BITS+1), "e has more than 256 bits"
    assert (M < n), "M is greater than n"


    # Compute C := M^e (mod n)
    if (e >> N_BITS-1) == 1:
        C = M
    else:
        C = 1

    for i in range(N_BITS-2, -1, -1):
        C = mod_mult_radix4(C, C, n, N_BITS)
        if ((e >> i) & 1) == 1:
            C = mod_mult_radix4(C, M, n, N_BITS)

        if debug:
            print("i={} msgout={}".format(i, hex(C)))
    return C

if __name__ == '__main__':
    # Generate a stimulus file with random stimuli
    GENERATE_MOD_MULT_STIMULI = True

    GENERATE_RSA_TOP_STIMULI = True
    if GENERATE_MOD_MULT_STIMULI:
        N_STIMULI = 1000
        f = open("modular_mult_tb_stimuli.txt", "w")
        for i in range(N_STIMULI):
            # get a realistic modulus
            n = rsa.newkeys(256)[0].n
            A = random.randint(0,n)
            B = random.randint(0,n)

            # Calculate result
            res = mod_exp(A,B,n, N_BITS=256, debug=False)
            # Write to file
            f.write(f"{A:064x} {B:064x} {n:064x} {res:064x}\n") 
        f.close()  
    
    if GENERATE_RSA_TOP_STIMULI:
        N_STIMULI = 100
        f = open("rsa_top_tb_stimuli.txt", "w")
        for i in range(N_STIMULI):
            
            pubkey = rsa.newkeys(256)[0]
            e = pubkey.e
            n = pubkey.n
            M = random.randint(0,n)

            # Calculate result
            res = decrypt(M,n,e)
            # Write to file
            f.write(f"{M:064x} {n:064x} {e:064x} {res:064x}\n") 
        f.close()  