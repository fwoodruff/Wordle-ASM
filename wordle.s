; ----------------------------------------------------------------------------------------
;     nasm -fmacho64 wordle.s && cc wordle.o -o wordle && ./wordle hello world
;     hello (candidate word)
;     world (target word)
;     bbbgy (black, black, black, green, yellow)
; ----------------------------------------------------------------------------------------


%define SUCCESS 1
%define FAILURE 0x7fffffff

%macro STACK_FRAME  1
push rbp
mov rbp, rsp
sub rsp, %1 ; Allocate %1 bytes of space on the stack
%endmacro

%macro STACK_FRAME 2
STACK_FRAME %1
mov [rbp - %2], rdi
%endmacro

%macro STACK_FRAME 3
STACK_FRAME %1, %2
mov [rbp - %3], rsi
%endmacro

%macro STACK_FRAME 4
STACK_FRAME %1, %2, %3
mov [rbp - %4], rdx
%endmacro

%macro STACK_FRAME 5
STACK_FRAME %1, %2, %3, %4
mov [rbp - %5], rcx
%endmacro

%macro RETURN 0
mov rsp, rbp
pop rbp
ret
%endmacro

%macro RETURN 1
mov rax, %1
RETURN
%endmacro

%macro CALL_FN 2
mov rdi, %2
call %1
%endmacro

%macro CALL_FN 3
mov rsi, %3
CALL_FN %1, %2
%endmacro

%macro CALL_FN 4
mov rdx, %4
CALL_FN %1, %2, %3
%endmacro

%macro CALL_FN 5
mov rcx, %5
CALL_FN %1, %2, %3, %4
%endmacro

    global    _main
    section   .text

_myputs:
%assign str 8
STACK_FRAME 8, str
CALL_FN _str_len, [rbp - str]
mov rdx, rax
mov rsi, [rbp - 8]
mov rdi, 1
mov rax, 0x2000004
syscall
mov rax, 10
mov [rbp - str], rax
lea rsi, [rbp - str]
mov rdi, 1
mov rdx, 1
mov rax, 0x2000004
syscall
RETURN 0


_str_len:                               ; long str_len(char* str) {}
    mov rax, rdi                        ; char* begin = str
    mov rcx, rdi
    jmp str_len_while_cond
str_len_while_begin:                    ; while
    inc rax                             ; ++str
str_len_while_cond:
    xor dl, dl
    cmp [rax], dl                       ; condition (*str != 0)
    jne str_len_while_begin
    sub rax, rcx                        ; return str - begin
    ret

_is_lower:
    cmp dil, 'a'                        ; if (c < 'a') return 0
    jl is_lower_short
    cmp dil, 'z'
    jg is_lower_short                   ; if (c > 'z') return 0
    mov rax, SUCCESS                          ; return 1
    ret
is_lower_short:
    mov rax, FAILURE
    ret

_memory_clear:                          ; void memory_clear(char* p, long l)
    xor rcx, rcx
    xor al, al
memory_clear_for:                       ; for(long i = 0; i < l; i++) {
    mov [rdi + rcx], al                 ; p[i] = 0
    inc rcx
    cmp rcx, rsi
    jl memory_clear_for                 ; }
    ret                                 ; return

_string_copy:                           ; void string_copy(char* destination,
                                        ;                               char* source)
    xor rcx, rcx                        ; long i = 0
    xor dl, dl
string_copy_do_while:                   ; do {
    mov al, [rsi + rcx]
    mov [rdi + rcx], al                 ; destination[i] = source[i]
    cmp [rsi + rcx], dl
    inc rcx                             ; ++i
    jne string_copy_do_while            ; } while(source[i] == 0)
    ret                                 ; return

_get_idx:                               ; long get_idx(char *result, long idx,
%assign result 8                        ;              char *candidate, char *target)
%assign target 32
%assign candidate 24
%assign idx 16
%assign length 40
%assign candidate_idx 48
    STACK_FRAME 48, result, idx, candidate, target
    CALL_FN _str_len, [rbp - candidate]  ; long length = str_len(candidate)
    mov [rbp - length], rax
    mov rax, [rbp - candidate]
    add rax, [rbp - idx]
    mov cl, [rax]
    mov [rbp - candidate_idx], cl
    xor rcx, rcx
get_idx_for:                            ; for(long j = 0; j < length; ++j)
    mov rax, [rbp - target]
    mov al, [rax + rcx]                 ; target[j]
    mov rdx, [rbp - candidate]
    cmp al, [rbp - candidate_idx]       ; if (target[j] == candidate[i])
    jne get_idx_continue
    mov rax, [rbp - result]
    mov al, [rax + rcx]                 ; if (result[j] < 'a')
    cmp al, 'a'
    jge get_idx_continue                ; return j
    RETURN rcx
get_idx_continue:
    inc rcx
    cmp rcx, [rbp - length]
    jl get_idx_for
    RETURN FAILURE

_set_yellows_inner:                     ; void set_yellow_inner(char *result,
                                        ;    long idx, char *candidate, char *target)
%assign result 8
%assign idx 16
%assign candidate 24
%assign target 32
%assign letter_idx 40
    STACK_FRAME 40, result, idx, candidate, target
                                        ; long letter_idx = get_idx(candidate, i,
                                        ;                               result, target)
    CALL_FN _get_idx, [rbp - result], [rbp - idx], [rbp - candidate], [rbp - target]
    mov [rbp - letter_idx], rax
    cmp rax, FAILURE                    ; if(letter_idx == -1)
    je set_yellow_inner_if              ; result[i] += ('b'-'n');
    mov rcx, [rbp - idx]
    mov rax, [rbp - result]
    mov dl, [rax + rcx]                 ; result[i] += ('y'-'n');
    add dl, 'y'
    sub dl, 'n'
    mov [rax + rcx], dl
    mov rcx, [rbp - letter_idx]
    mov dl, [rax + rcx]                 ; result[letter_idx] += ('a' - 'A');
    add dl, 'a'
    sub dl, 'A'
    mov [rax + rcx], dl
    jmp set_yellow_inner_both
set_yellow_inner_if:
    mov rcx, [rbp - idx]
    mov rax, [rbp - result]
    mov dl, [rax + rcx]
    add dl, 'b'
    sub dl, 'n'
    mov [rax + rcx], dl
set_yellow_inner_both:
    RETURN
    
_set_yellows:                           ; void set_yellows(char *result,
                                        ;           char *candidate, char *target)
%assign result 8
%assign candidate 16
%assign target 24
%assign length 32
%assign letter_idx 40
    STACK_FRAME 40, result, candidate, target
    CALL_FN _str_len, [rbp - candidate]
    mov [rbp - length], rax             ; long length = str_len(candidate)
    xor rcx, rcx
set_yellows_for:                        ; for(long i = 0; i < length; ++i)
    mov rax, [rbp - result]
    mov al, [rax + rcx]                 ; if(result[i] == 'n' || result[i] == 'N')
    cmp al, 'n'
    je set_yellows_call_inner
    cmp al, 'N'
    je set_yellows_call_inner
    jmp set_yellows_continue
set_yellows_call_inner:                 ; set_yellow_inner(result, candidate, target, i)
    mov rax, rcx
    push rcx
    CALL_FN _set_yellows_inner, [rbp - result], rax, [rbp - candidate], [rbp - target]
    pop rcx
set_yellows_continue:
    inc rcx
    cmp rcx, [rbp - length]
    jl set_yellows_for
    RETURN
    
_str_to_lower:                          ; void str_to_lower(char *result)
%assign result 8
    STACK_FRAME 8, result
    CALL_FN _str_len, [rbp - result]
    mov rsi, rax
    mov rdx, [rbp - result]
    xor rcx, rcx
str_to_lower_for:                       ; for(long i = 0; i < length; i ++)
    mov al, [rdx + rcx]
    cmp al, 'a'                         ; if(result[i] < 'a')
    jge str_to_lower_continue
    add al, 'a'                         ; result[i] += 'a' - 'A';
    sub al, 'A'
    mov [rdx + rcx], al
str_to_lower_continue:
    inc rcx
    cmp rcx, rsi
    jl str_to_lower_for
    RETURN

_set_greens:                            ; void set_greens(char *result,
                                        ;           char *candidate, char *target)
%assign length 8
%assign result 16
%assign candidate 24
%assign target 32
    STACK_FRAME 32, result, candidate, target ; put assign inside macro?
    CALL_FN _str_len, [rbp - candidate] ; long length = str_len(candidate)
    mov [rbp - length], rax
    xor rcx, rcx
set_greens_for:                         ; for(long i = 0; i < length; ++i)
    mov rax, [rbp - candidate]          ; if candidate[i] == target[i]
    mov al, [rax + rcx]
    mov rdx, [rbp - target]
    cmp al, [rdx + rcx]
    jne set_greens_else
    mov rax, [rbp - result]
    mov dl, 'g'
    mov [rax + rcx], dl                 ; result[i] = 'g';
    jmp set_greens_continue
set_greens_else:
    mov rax, [rbp - result]
    mov dl, 'N'
    mov [rax + rcx], dl                 ; result[i] = 'N';
set_greens_continue:
    inc rcx
    cmp rcx, [rbp - length]
    jl set_greens_for
    RETURN

_sanitise:                              ; long sanitise(char* result,
                                        ;   long buffer_len, char* candidate,
                                        ;                       char* target)
%assign target 8
%assign candidate 16
%assign length 24
%assign letter_idx 32
%assign result 40
%assign buffer_len 48
    STACK_FRAME 48, result, buffer_len, candidate, target
    mov rax, [rbp - candidate]
    cmp rax, 0                          ; if (candidate == NULL) return -1
    je sanitise_end
    mov rax, [rbp - target]
    cmp rax, 0                          ; if (target == NULL) return -1
    je sanitise_end
    mov rax, [rbp - result]
    cmp rax, 0                          ; if (result == NULL) return -1
    je sanitise_end
    CALL_FN _str_len, [rbp - candidate] ; long length = str_len(candidate)
    mov [rbp - length], rax
    CALL_FN _str_len, [rbp - target]    ; long count = str_len(target)
    cmp rax, [rbp - length]             ; if (length != letter_idx) return -1
    jne sanitise_end
    mov rax, [rbp - buffer_len]
    dec rax
    cmp [rbp - length], rax             ; if (length > buffer_len -1) return -1
    jg sanitise_end
    xor rcx, rcx
sanitise_for:                           ; for (int i = 0; i < length; ++i)
    mov rax, [rbp - target]
    CALL_FN _is_lower, [rax + rcx]      ; if(is_lower(target[i]) == 0) return -1
    cmp rax, FAILURE
    je sanitise_end
    mov rax, [rbp - candidate]
    CALL_FN _is_lower, [rax + rcx]      ; if(is_lower(candidate[i]) == 0) return -1
    cmp rax, FAILURE
    je sanitise_end
    inc rcx
    cmp rcx, [rbp - length]
    jl sanitise_for
    RETURN SUCCESS                      ; return 0
sanitise_end:
    RETURN FAILURE

_get_result:                            ; long get_result(char* result,
                                        ;           long buffer_len, char* candidate,
                                        ;                              char* target)
%assign result 8
%assign buffer_len 16
%assign candidate 24
%assign target 32
    STACK_FRAME 32, result, buffer_len, candidate, target
                                        ; sanitise(result, buffer_len, candidate, target)
    CALL_FN _sanitise, [rbp - result], [rbp - buffer_len], \
                        [rbp - candidate], [rbp - target]
    cmp rax, SUCCESS
    jne get_result_end                  ; return -1
    CALL_FN _str_len, [rbp - candidate] ;  long length = str_len(candidate)
    inc rax
    CALL_FN _memory_clear, [rbp - result], rax ; memory_clear(result, length + 1)
    CALL_FN _set_greens, [rbp - result], [rbp - candidate], [rbp - target]
                                        ; set_greens(result, candidate, target)
    CALL_FN _set_yellows, [rbp - result], [rbp - candidate], [rbp - target]
                                        ; set_yellows(result, candidate, target)
    CALL_FN _str_to_lower, [rbp - result] ; str_to_lower(result)
    RETURN SUCCESS
get_result_end:
    RETURN FAILURE

_main:
%assign argc 8
%assign argv 16
%assign argv_arr 40
%assign result 1072

STACK_FRAME 1072, argc, argv

    mov rax, [rbp - argc]               ; if(argc != 3)
    cmp rax, 3
    jne main_error

    mov rax, [rbp - argv]
    mov rdx, [rax]
    mov [rbp - argv_arr], rdx
    mov rdx, [rax + 8]
    mov [rbp - argv_arr + 8], rdx
    mov rdx, [rax + 16]
    mov [rbp - argv_arr + 16], rdx

    CALL_FN _myputs, [rbp - argv_arr + 8] ; puts(argv[1]);
    CALL_FN _myputs, [rbp - argv_arr + 16]; puts(argv[2]);

    lea rax, [rbp - result]             ; get_result(result, buffer_len,
                                        ;                       candidate, target)
    CALL_FN _get_result, rax, 1025, [rbp - argv_arr + 8], [rbp - argv_arr + 16]
    cmp rax, SUCCESS
    jne main_error
    lea rax, [rbp - result]
    CALL_FN _myputs, rax
    RETURN SUCCESS
main_error:
    lea rax, [rel bad_args]
    CALL_FN _myputs, rax                  ; puts(bad_args)
    RETURN FAILURE                      ; return 0x7fffffff

    section   .data
bad_args:   db        "Bad arguments", 0

