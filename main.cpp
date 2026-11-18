#define ANKERL_NANOBENCH_IMPLEMENT
#include <sys/mman.h>

#include "nanobench.h"

extern "C" void *wine_memmove(void *dst, const void *src, size_t n);
extern "C" void *avx_memmove_unaligned(void *dst, const void *src, size_t n);
extern "C" void *avx_memmove_aligned(void *dst, const void *src, size_t n);
extern "C" void *avx_memmove_combined(void *dst, const void *src, size_t n);

using MemmoveFn = void *(*)(void *, const void *, size_t);

extern "C" void *sysv_thunk(void *dst, const void *src, size_t n, MemmoveFn fn);

struct Target
{
    const char *name;
    MemmoveFn fn;
    bool thunk;
};

const Target targets[] = {
    {"wine_memmove", &wine_memmove, true},       {"avx unaligned", &avx_memmove_unaligned, true},
    {"avx aligned", &avx_memmove_aligned, true}, {"avx combined", &avx_memmove_combined, true},
    {"libc memmove", &std::memmove, false},
};

constexpr size_t align_up(size_t v, size_t a)
{
    return (v + a - 1) & ~(a - 1);
}

std::string format_size(size_t bytes)
{
    if (bytes >= 1024u * 1024u && bytes % (1024u * 1024u) == 0u)
        return std::to_string(bytes / (1024u * 1024u)) + " MiB";
    if (bytes >= 1024u && bytes % 1024u == 0u)
        return std::to_string(bytes / 1024u) + " KiB";
    return std::to_string(bytes) + " B";
}

struct Arena
{
    char *base = nullptr;
    size_t cap = 0;

    Arena(size_t bytes)
    {
        cap = align_up(bytes, 4096);
        base = static_cast<char *>(mmap(nullptr, cap, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
        std::memset(base, 0xAA, cap);
    }

    Arena(const Arena &) = delete;
    Arena &operator=(const Arena &) = delete;
    ~Arena()
    {
        if (base)
            munmap(base, cap);
    }
};

enum class CopyMode
{
    NoOverlap,
    OverlapDstGtSrc,
    OverlapSrcGtDst,
};

struct Layout
{
    size_t total = 0;
    size_t src_offset = 0;
    size_t dst_offset = 0;
};

Layout make_layout(CopyMode mode, size_t n, size_t src_offset, size_t dst_offset, size_t overlap_delta)
{
    Layout L;

    switch (mode)
    {
    case CopyMode::NoOverlap: {
        const size_t needed = align_up(n ? n : 1, 64) + 256;
        L.src_offset = src_offset;
        // skip 2k to avoid 4k aliasing
        L.dst_offset = align_up(needed, 4096) + 2048 + dst_offset;
        L.total = L.dst_offset + needed;
        break;
    }
    case CopyMode::OverlapDstGtSrc: {
        L.src_offset = src_offset;
        L.dst_offset = src_offset + overlap_delta;
        L.total = align_up(n + overlap_delta + 64, 64) + 256;
        break;
    }
    case CopyMode::OverlapSrcGtDst: {
        L.dst_offset = dst_offset;
        L.src_offset = dst_offset + overlap_delta;
        L.total = align_up(n + overlap_delta + 64, 64) + 256;
        break;
    }
    }
    return L;
}

void run_suite(const char *title, CopyMode mode, const std::vector<size_t> &sizes, size_t src_offset, size_t dst_offset,
               size_t overlap_delta)
{
    if (sizes.empty())
        return;

    size_t arena_bytes = 4096;
    for (size_t n : sizes)
    {
        Layout L = make_layout(mode, n, src_offset, dst_offset, overlap_delta);
        if (L.total > arena_bytes)
            arena_bytes = L.total;
    }

    Arena A(arena_bytes);

    for (size_t n : sizes)
    {
        const Layout L = make_layout(mode, n, src_offset, dst_offset, overlap_delta);
        const std::string sz = format_size(n);

        ankerl::nanobench::Bench bench;
        bench.title(std::string(title) + " [" + sz + "]");
        bench.minEpochTime(std::chrono::milliseconds(10));
        bench.relative(true);
        if (n)
        {
            bench.batch(n);
            bench.unit("byte");
        }

        for (const auto &t : targets)
        {
            bench.run(t.name, [&] {
                char *s = A.base + L.src_offset;
                char *d = A.base + L.dst_offset;
                if (t.thunk)
                    ankerl::nanobench::doNotOptimizeAway(sysv_thunk(d, s, n, t.fn));
                else
                    ankerl::nanobench::doNotOptimizeAway(t.fn(d, s, n));
            });
        }
    }
}

int main()
{
    const std::vector<size_t> small = {0,  1,  2,  3,  4,  7,  8,  12, 13, 16, 17, 20, 24,  28, 31,
                                       32, 33, 36, 40, 44, 48, 52, 56, 60, 63, 64, 96, 127, 128};
    const std::vector<size_t> medium = {192,   256,    384,    512,    768,    1024,   1536,   2048,   3072,
                                        4096,  6144,   8192,   12288,  16384,  24576,  32768,  49152,  65536,
                                        98304, 131072, 196608, 262144, 393216, 524288, 786432, 1048576};
    const std::vector<size_t> overlap = {64, 256, 1024, 4096, 16384, 65536, 262144, 1048576};
    const std::vector<size_t> huge = {2 << 20, 32 << 20};

    const size_t split = 31;

    run_suite("small aligned", CopyMode::NoOverlap, small, 0, 0, 0);

    run_suite("small both unaligned", CopyMode::NoOverlap, small, split, split, 0);

    run_suite("medium aligned", CopyMode::NoOverlap, medium, 0, 0, 0);

    run_suite("medium dst unaligned", CopyMode::NoOverlap, medium, 0, split, 0);

    run_suite("huge aligned", CopyMode::NoOverlap, huge, 0, 0, 0);

    run_suite("huge unaligned", CopyMode::NoOverlap, huge, 0, split, 0);

    run_suite("overlap backward", CopyMode::OverlapDstGtSrc, overlap, 0, 0, 31);

    run_suite("overlap forward", CopyMode::OverlapSrcGtDst, overlap, 0, 0, 31);

    return 0;
}
