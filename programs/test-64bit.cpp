#include <cstddef>
int main(int argc, char* argv[])
{
  enum {N = (sizeof(size_t) == 8 ? 8 : -1)};
  int x[N] = {N};
  return x[0];
}
