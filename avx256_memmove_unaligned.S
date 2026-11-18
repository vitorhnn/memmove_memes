.text
.globl  avx_memmove_unaligned

avx_memmove_unaligned:
        mov %rcx, %rax
        test %r8, %r8
        jz .Lleave
        cmp %rcx, %rdx
        je .Lleave

        lea (%rcx, %r8), %r10 /* dst end ptr */

        cmp $128, %r8
        ja copy_large
overlapping_start:
        lea (%rdx, %r8), %r11 /* src end ptr */

        cmp $64, %r8
        jb 1f
        /* overlapping 64-128 byte copy */
        vmovdqu 0x0(%rdx), %ymm0
        vmovdqu 0x20(%rdx), %ymm1
        vmovdqu -0x20(%r11), %ymm2
        vmovdqu -0x40(%r11), %ymm3
        vmovdqu %ymm0, 0x0(%rcx)
        vmovdqu %ymm1, 0x20(%rcx)
        vmovdqu %ymm2, -0x20(%r10)
        vmovdqu %ymm3, -0x40(%r10)
        vzeroupper
        ret

1:
        cmp $32, %r8
        jb 1f
        /* overlapping 32-64 byte copy */
        vmovdqu 0x0(%rdx), %ymm0
        vmovdqu -0x20(%r11), %ymm1
        vmovdqu %ymm0, 0x0(%rcx)
        vmovdqu %ymm1, -0x20(%r10)
        vzeroupper
        ret

1:
        cmp $16, %r8
        jb 1f
        /* overlapping 16-32 byte copy */
        vmovdqu 0x0(%rdx), %xmm0
        vmovdqu -0x10(%r11), %xmm1
        vmovdqu %xmm0, 0x0(%rcx)
        vmovdqu %xmm1, -0x10(%r10)
        ret
        /* free gprs for copy: r8 after cmp, r9 */
1:
        cmp $8, %r8
        jb 1f
        /* overlapping 8-16 byte copy */
        mov 0x0(%rdx), %r8
        mov -0x8(%r11), %r9
        mov %r8, 0x0(%rcx)
        mov %r9, -0x8(%r10)
        ret
1:
        cmp $4, %r8
        jb 1f
        /* overlapping 4-8 byte copy */
        mov 0x0(%rdx), %r8d
        mov -0x4(%r11), %r9d
        mov %r8d, 0x0(%rcx)
        mov %r9d, -0x4(%r10)
        ret
1:
        cmp $2, %r8
        jb 1f
        /* overlapping 2-4 byte copy */
        movzwl 0x0(%rdx), %r8d
        movzwl -0x2(%r11), %r9d
        mov %r8w, 0x0(%rcx)
        mov %r9w, -0x2(%r10)
        ret
1:
        movzbl 0x0(%rdx), %r8d
        mov %r8b, 0x0(%rcx)
.Lleave:
        ret

copy_large:
        mov %rcx, %r9
        sub %rdx, %r9
        cmp %r8, %r9
        jb copy_large_unaligned_bwd

copy_large_unaligned_fwd:
        shr $7, %r8
1:
        add $0x80, %rdx
        add $0x80, %rcx
        vmovdqu -0x80(%rdx), %ymm0
        vmovdqu -0x60(%rdx), %ymm1
        vmovdqu -0x40(%rdx), %ymm2
        vmovdqu -0x20(%rdx), %ymm3
        vmovdqu %ymm0, -0x80(%rcx)
        vmovdqu %ymm1, -0x60(%rcx)
        vmovdqu %ymm2, -0x40(%rcx)
        vmovdqu %ymm3, -0x20(%rcx)
        dec %r8
        jnz 1b
        vzeroupper

        /* handle tail via overlapping copies */
        mov %r10, %r8
        sub %rcx, %r8 /* bytes left */
        jnz overlapping_start
        ret

copy_large_unaligned_bwd:
        lea (%rdx, %r8), %r11 /* src end ptr */
        shr $7, %r8
1:
        sub $0x80, %r11
        sub $0x80, %r10
        vmovdqu 0x0(%r11), %ymm0
        vmovdqu 0x20(%r11), %ymm1
        vmovdqu 0x40(%r11), %ymm2
        vmovdqu 0x60(%r11), %ymm3
        vmovdqu %ymm0, 0x0(%r10)
        vmovdqu %ymm1, 0x20(%r10)
        vmovdqu %ymm2, 0x40(%r10)
        vmovdqu %ymm3, 0x60(%r10)
        dec %r8
        jnz 1b
        vzeroupper

        /* handle tail via overlapping copies */
        mov %r10, %r8
        sub %rax, %r8 /* bytes left */
        jnz overlapping_start
        ret
