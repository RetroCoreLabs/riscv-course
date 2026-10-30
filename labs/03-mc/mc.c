/* Lab 3: M and C, RV32 vs RV64.
   The same C file is built four times: for RV32 and RV64, each with and without the C
   (compressed) extension. product, quotient and remainder_of use the M extension's mul,
   div and rem. A long is 32 bits on RV32 and 64 bits on RV64, so 100000 * 100000 fits on
   RV64 and wraps on RV32. The results go to the array results, where the debugger and the
   tests read them.
   Build: see the lab chapter, docs/labs/03-mc.md. */

long results[3];

/* noipa: keep each function a real call, so the compiler cannot work the answer out early. */
__attribute__((noipa)) long product(long a, long b)
{
    return a * b;
}

__attribute__((noipa)) long quotient(long a, long b)
{
    return a / b;
}

__attribute__((noipa)) long remainder_of(long a, long b)
{
    return a % b;
}

int main(void)
{
    results[0] = product(100000, 100000);
    results[1] = quotient(-7, 2);
    results[2] = remainder_of(-7, 2);
    return 0;
}
