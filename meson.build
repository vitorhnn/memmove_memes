project('memmove_bench', 'cpp', version: '1.0',  default_options :
    ['warning_level=3', 'cpp_std=c++23'])

sources = [
    'main.cpp',
    'avx256_memmove_align.S',
    'memmove_wine.S',
    'avx256_memmove_unaligned.S',
    'avx256_memmove_combined.S'
]

executable('memmove_bench', sources)
