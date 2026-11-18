.text
.globl  avx_memmove_aligned

avx_memmove_aligned:
        mov %rcx, %rax
        test %r8, %r8
        jz .Lleave
        cmp %rcx, %rdx
        je .Lleave
        cmp $128, %r8
        ja .Lcopy_large

        lea (%rdx, %r8), %r11 /* src end ptr */
        lea (%rcx, %r8), %r10 /* dst end ptr */

        cmp $64, %r8
        jb .Lcheck_64
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

.Lcheck_64:
        cmp $32, %r8
        jb .Lcheck_32
        /* overlapping 32-64 byte copy */
        vmovdqu 0x0(%rdx), %ymm0
        vmovdqu -0x20(%r11), %ymm1
        vmovdqu %ymm0, 0x0(%rcx)
        vmovdqu %ymm1, -0x20(%r10)
        vzeroupper
        ret

.Lcheck_32:
        cmp $16, %r8
        jb .Lcheck_16
        /* overlapping 16-32 byte copy */
        vmovdqu 0x0(%rdx), %xmm0
        vmovdqu -0x10(%r11), %xmm1
        vmovdqu %xmm0, 0x0(%rcx)
        vmovdqu %xmm1, -0x10(%r10)
        ret
        /* free gprs for copy: r8 after cmp, r9 */
.Lcheck_16:
        cmp $8, %r8
        jb .Lcheck_8
        /* overlapping 8-16 byte copy */
        mov 0x0(%rdx), %r8
        mov -0x8(%r11), %r9
        mov %r8, 0x0(%rcx)
        mov %r9, -0x8(%r10)
        ret
.Lcheck_8:
        cmp $4, %r8
        jb .Lcheck_4
        /* overlapping 4-8 byte copy */
        mov 0x0(%rdx), %r8d
        mov -0x4(%r11), %r9d
        mov %r8d, 0x0(%rcx)
        mov %r9d, -0x4(%r10)
        ret
.Lcheck_4:
        cmp $2, %r8
        jb .Lsingle_store
        /* overlapping 2-4 byte copy */
        movzwl 0x0(%rdx), %r8d
        movzwl -0x2(%r11), %r9d
        mov %r8w, 0x0(%rcx)
        mov %r9w, -0x2(%r10)
        ret
.Lsingle_store:
        movzbl 0x0(%rdx), %r8d
        mov %r8b, 0x0(%rcx)
.Lleave:
        ret

.Lcopy_large:
        sub $56, %rsp
        vmovdqa %xmm6, (%rsp)
        vmovdqa %xmm7, 0x10(%rsp)
        vmovdqa %xmm8, 0x20(%rsp)

        mov %rcx, %r9
        sub %rdx, %r9
        cmp %r8, %r9
        jb .Lcopy_large_aligned_bwd

.Lcopy_large_aligned_fwd:
        lea -0x80(%rcx, %r8), %r11 /* end */
        /* align to the next boundary */
        mov %rcx, %rax /* rax = d */
        or $0x1f, %rcx
        add $1, %rcx /* rcx = aligned_d (d2) */
        mov %rcx, %r10
        sub %rax, %r10 /* r10 = aligned_d - d */
        vmovdqu 0x0(%rdx), %ymm4 /* load 32 from start */
        vmovdqu -0x20(%rdx, %r8), %ymm5 /* load 128 from end */
        vmovdqu -0x40(%rdx, %r8), %ymm6
        vmovdqu -0x60(%rdx, %r8), %ymm7
        vmovdqu -0x80(%rdx, %r8), %ymm8
        add %r10, %rdx /* displace s to align with d2 */
        cmp %r11, %rcx
        jnb .Ltail_fwd
.p2align 4,, 16
.Lloop_fwd:
        /* 128 byte copy kernel */
        sub $-0x80, %rdx
        sub $-0x80, %rcx
        vmovdqu -0x80(%rdx), %ymm0
        vmovdqu -0x60(%rdx), %ymm1
        vmovdqu -0x40(%rdx), %ymm2
        vmovdqu -0x20(%rdx), %ymm3
        vmovdqa %ymm0, -0x80(%rcx)
        vmovdqa %ymm1, -0x60(%rcx)
        vmovdqa %ymm2, -0x40(%rcx)
        vmovdqa %ymm3, -0x20(%rcx)
        cmp %r11, %rcx
        jb .Lloop_fwd

.Ltail_fwd:
        vmovdqu %ymm4, 0x0(%rax) /* store preloads */
        vmovdqu %ymm5, -0x20(%rax, %r8)
        vmovdqu %ymm6, -0x40(%rax, %r8)
        vmovdqu %ymm7, -0x60(%rax, %r8)
        vmovdqu %ymm8, -0x80(%rax, %r8)
        vzeroupper

        vmovdqa (%rsp), %xmm6
        vmovdqa 0x10(%rsp), %xmm7
        vmovdqa 0x20(%rsp), %xmm8
        add $56, %rsp
        ret

.Lcopy_large_aligned_bwd:
        vmovdqu -0x20(%rdx, %r8), %ymm4
        vmovdqu 0x0(%rdx), %ymm5
        vmovdqu 0x20(%rdx), %ymm6
        vmovdqu 0x40(%rdx), %ymm7
        vmovdqu 0x60(%rdx), %ymm8
        lea -0x81(%rax, %r8), %rcx /* d2 = d + n - 129 */
        and $-0x20, %rcx /* align */
        mov %rcx, %r10
        sub %rax, %r10 /* d2 - d */
        add %r10, %rdx /* displace s to align with d2 */

        cmp %rcx, %rax
        jnb .Ltail_bwd
.p2align 4,, 16
.Lloop_bwd:
        vmovdqu 0x0(%rdx), %ymm0
        vmovdqu 0x20(%rdx), %ymm1
        vmovdqu 0x40(%rdx), %ymm2
        vmovdqu 0x60(%rdx), %ymm3
        add $-0x80, %rdx
        vmovdqa %ymm0, 0x0(%rcx)
        vmovdqa %ymm1, 0x20(%rcx)
        vmovdqa %ymm2, 0x40(%rcx)
        vmovdqa %ymm3, 0x60(%rcx)
        add $-0x80, %rcx
        cmp %rcx, %rax
        jb .Lloop_bwd
.Ltail_bwd:
        vmovdqu %ymm4, -0x20(%rax, %r8)
        vmovdqu %ymm8, 0x60(%rax)
        vmovdqu %ymm7, 0x40(%rax)
        vmovdqu %ymm6, 0x20(%rax)
        vmovdqu %ymm5, 0x0(%rax)
        vzeroupper

        vmovdqa (%rsp), %xmm6
        vmovdqa 0x10(%rsp), %xmm7
        vmovdqa 0x20(%rsp), %xmm8

        add $56, %rsp
        ret
