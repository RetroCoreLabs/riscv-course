/* Lab 1: loads, stores, branches, calls and the ABI.
   main calls twice_sum, which calls add3. Built with -O0, so every function keeps
   its own stack frame and you can follow the calls frame by frame.
   Build: see the lab chapter, docs/labs/01-calls.md. */

int add3(int a, int b, int c)
{
    return a + b + c;
}

int twice_sum(int x)
{
    int s = add3(x, x, 1);
    return s + s;
}

int main(void)
{
    return twice_sum(10);
}
