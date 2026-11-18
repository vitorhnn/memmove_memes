.text
.globl  wine_memmove

wine_memmove:
.cfi_startproc
        pushq %rsi
.cfi_adjust_cfa_offset 8
        pushq %rdi
.cfi_adjust_cfa_offset 8
        movq %rcx, %rdi
        movq %rdx, %rsi

        mov  %rdi, %r9 /* check copying direction */
        sub  %rsi, %r9 
        cmp  %r8, %r9 
        jb copy_bwd
        /* copy forwards */
        cmp $4,  %r8  /* 4-bytes align */
        jb copy_fwd3
        mov  %rdi ,  %r9 
        shr $1,  %r9 
        jnc 1f
        movsb
        dec  %r8 
        inc  %r9 
1:
        shr $1,  %r9 
        jnc 1f
        movsw
        sub $2,  %r8 
        inc  %r9 
        1: /* 16-bytes align */
        cmp $16,  %r8 
        jb copy_fwd15
        shr $1,  %r9 
        jnc 1f
        movsl
        sub $4,  %r8 
        inc  %r9 
1:
        shr $1,  %r9 
        jnc 1f
        movsl
        movsl
        sub $8,  %r8 
1:
        cmp $64,  %r8 
        jb copy_fwd63
1: /* copy 64-bytes blocks in loop, dest 16-bytes aligned */
        movdqu 0x00( %rsi ), %xmm0
        movdqu 0x10( %rsi ), %xmm1
        movdqu 0x20( %rsi ), %xmm2
        movdqu 0x30( %rsi ), %xmm3
        movdqa %xmm0, 0x00( %rdi )
        movdqa %xmm1, 0x10( %rdi )
        movdqa %xmm2, 0x20( %rdi )
        movdqa %xmm3, 0x30( %rdi )
        add $64,  %rsi 
        add $64,  %rdi 
        sub $64,  %r8 
        cmp $64,  %r8 
        jae 1b
copy_fwd63: /* copy last 63 bytes, dest 16-bytes aligned */
        mov  %r8 ,  %r9 
        and $15,  %r8 
        shr $5,  %r9 
        jnc 1f
        movdqu 0( %rsi ), %xmm0
        movdqa %xmm0, 0( %rdi )
        add $16,  %rsi 
        add $16,  %rdi 
1:
        shr $1,  %r9 
        jnc copy_fwd15
        movdqu 0x00( %rsi ), %xmm0
        movdqu 0x10( %rsi ), %xmm1
        movdqa %xmm0, 0x00( %rdi )
        movdqa %xmm1, 0x10( %rdi )
        add $32,  %rsi 
        add $32,  %rdi 
copy_fwd15: /* copy last 15 bytes, dest 4-bytes aligned */
        mov  %r8 ,  %r9 
        and $3,  %r8 
        shr $3,  %r9 
        jnc 1f
        movsl
        1:
        shr $1,  %r9 
        jnc copy_fwd3
        movsl
        movsl
copy_fwd3: /* copy last 3 bytes */
        shr $1,  %r8 
        jnc 1f
        movsb
1:
        shr $1,  %r8 
        jnc 1f
        movsw
1:
        movq %rcx, %rax
        popq %rdi
.cfi_adjust_cfa_offset -8
        popq %rsi
.cfi_adjust_cfa_offset -8
        ret


copy_bwd:
        lea ( %rdi ,  %r8 ),  %rdi 
        lea ( %rsi ,  %r8 ),  %rsi 
        cmp $4,  %r8  /* 4-bytes align */
        jb copy_bwd3
        mov  %rdi ,  %r9 
        shr $1,  %r9 
        jnc 1f
        dec  %rsi 
        dec  %rdi 
        movb ( %rsi ), %al
        movb %al, ( %rdi )
        dec  %r8 
1:
        shr $1,  %r9 
        jnc 1f
        sub $2,  %rsi 
        sub $2,  %rdi 
        movw ( %rsi ), %ax
        movw %ax, ( %rdi )
        sub $2,  %r8 
1: /* 16-bytes align */
        cmp $16,  %r8 
        jb copy_bwd15
        shr $1,  %r9 
        jnc 1f
        sub $4,  %rsi 
        sub $4,  %rdi 
        movl ( %rsi ), %eax
        movl %eax, ( %rdi )
        sub $4,  %r8 
1:
        shr $1,  %r9 
        jnc 1f
        sub $8,  %rsi 
        sub $8,  %rdi 
        movl 4( %rsi ), %eax
        movl %eax, 4( %rdi )
        movl ( %rsi ), %eax
        movl %eax, ( %rdi )
        sub $8,  %r8 
1:
        cmp $64,  %r8 
        jb copy_bwd63
1: /* copy 64-bytes blocks in loop, dest 16-bytes aligned */
        sub $64,  %rsi 
        sub $64,  %rdi 
        movdqu 0x00( %rsi ), %xmm0
        movdqu 0x10( %rsi ), %xmm1
        movdqu 0x20( %rsi ), %xmm2
        movdqu 0x30( %rsi ), %xmm3
        movdqa %xmm0, 0x00( %rdi )
        movdqa %xmm1, 0x10( %rdi )
        movdqa %xmm2, 0x20( %rdi )
        movdqa %xmm3, 0x30( %rdi )
        sub $64,  %r8 
        cmp $64,  %r8 
        jae 1b
copy_bwd63: /* copy last 63 bytes, dest 16-bytes aligned */
        mov  %r8 ,  %r9 
        and $15,  %r8 
        shr $5,  %r9 
        jnc 1f
        sub $16,  %rsi 
        sub $16,  %rdi 
        movdqu ( %rsi ), %xmm0
        movdqa %xmm0, ( %rdi )
1:
        shr $1,  %r9 
        jnc copy_bwd15
        sub $32,  %rsi 
        sub $32,  %rdi 
        movdqu 0x00( %rsi ), %xmm0
        movdqu 0x10( %rsi ), %xmm1
        movdqa %xmm0, 0x00( %rdi )
        movdqa %xmm1, 0x10( %rdi )
copy_bwd15: /* copy last 15 bytes, dest 4-bytes aligned */
        mov  %r8 ,  %r9 
        and $3,  %r8 
        shr $3,  %r9 
        jnc 1f
        sub $4,  %rsi 
        sub $4,  %rdi 
        movl ( %rsi ), %eax
        movl %eax, ( %rdi )
1:
        shr $1,  %r9
        jnc copy_bwd3
        sub $8,  %rsi 
        sub $8,  %rdi 
        movl 4( %rsi ), %eax
        movl %eax, 4( %rdi )
        movl ( %rsi ), %eax
        movl %eax, ( %rdi )
copy_bwd3: /* copy last 3 bytes */
        shr $1,  %r8 
        jnc 1f
        dec  %rsi 
        dec  %rdi 
        movb ( %rsi ), %al
        movb %al, ( %rdi )
1:
        shr $1,  %r8 
        jnc 1f
        movw -2( %rsi ), %ax
        movw %ax, -2( %rdi )
1:
        movq %rcx, %rax
        popq %rdi
.cfi_adjust_cfa_offset -8
        popq %rsi
.cfi_adjust_cfa_offset -8
        ret
.cfi_endproc
