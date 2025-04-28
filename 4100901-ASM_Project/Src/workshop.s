// --- Ejemplo de parpadeo de LED LD2 en STM32F476RGTx -------------------------
    .section .text
    .syntax unified
    .thumb

    .global main
    .global init_led
    .global init_systick
    .global SysTick_Handler
    .global init_buton

// --- Definiciones de registros para LD2 (Ver RM0351) -------------------------
    .equ RCC_BASE,       0x40021000         @ Base de RCC
    .equ RCC_AHB2ENR,    RCC_BASE + 0x4C    @ Enable GPIOA clock (AHB2ENR)
    .equ GPIOA_BASE,     0x48000000         @ Base de GPIOA
    .equ GPIOA_MODER,    GPIOA_BASE + 0x00  @ Mode register
    .equ GPIOA_ODR,      GPIOA_BASE + 0x14  @ Output data register
    .equ LD2_PIN,        5                  @ Pin del LED LD2

// --- Definiciones de registros para el botón (Ver RM0351) ---------------------
    .equ GPIOC_BASE,     0x48000800         @ Base de GPIOC
    .equ GPIOC_MODER,    GPIOC_BASE + 0x00  @ Mode register
    .equ GPIOC_IDR,      GPIOC_BASE + 0x10  @ Input data register
    .equ B1_PIN,         13                 @ Pin del botón

// --- Definiciones de registros para SysTick (Ver PM0214) ---------------------
    .equ SYST_CSR,       0xE000E010         @ Control and status
    .equ SYST_RVR,       0xE000E014         @ Reload value register
    .equ SYST_CVR,       0xE000E018         @ Current value register
    .equ HSI_FREQ,       4000000            @ Reloj interno por defecto (4 MHz)

// --- Programa principal ------------------------------------------------------
    .data
led_on_flag: .word 0

    .text
main:
    bl init_led        // Configura el GPIO para encender el LED
    //bl init_systick
    bl init_buton      // Inicializa el botón PC13 como entrada
loop:
    // Leer botón (PC13)
    movw  r0, #:lower16:GPIOC_IDR
    movt  r0, #:upper16:GPIOC_IDR
    ldr   r1, [r0]
    lsrs  r1, r1, #B1_PIN           // Bit 13 a posición 0
    ands  r1, r1, #1                // r1 = estado del botón

    cmp   r1, #0                    // ¿Botón presionado? (activo bajo)
    bne   check_led

    // Si el LED está apagado, enciéndelo y marca flag
    ldr   r2, =led_on_flag
    ldr   r3, [r2]
    cmp   r3, #0
    bne   check_led

    // Encender LED
    movw  r0, #:lower16:GPIOA_ODR
    movt  r0, #:upper16:GPIOA_ODR
    ldr   r1, [r0]
    orr   r1, r1, #(1 << LD2_PIN)
    str   r1, [r0]

// Habilitar SysTick para 3 segundos
    bl init_systick


wait_release:
    // Esperar a que se suelte el botón
    movw  r0, #:lower16:GPIOC_IDR
    movt  r0, #:upper16:GPIOC_IDR
    ldr   r1, [r0]
    lsrs  r1, r1, #B1_PIN
    ands  r1, r1, #1
    cmp   r1, #0
    beq   wait_release

    // Marcar flag
    movs  r3, #1
    ldr   r2, =led_on_flag
    str   r3, [r2]


check_led:
    b loop

// --- Inicialización de GPIOA PA5 para el LED LD2 -----------------------------
init_led:
    movw  r0, #:lower16:RCC_AHB2ENR
    movt  r0, #:upper16:RCC_AHB2ENR
    ldr   r1, [r0]
    orr   r1, r1, #(1 << 0)                @ Habilita reloj GPIOA
    str   r1, [r0]

    movw  r0, #:lower16:GPIOA_MODER
    movt  r0, #:upper16:GPIOA_MODER
    ldr   r1, [r0]
    bic   r1, r1, #(0b11 << (LD2_PIN * 2)) @ Limpia bits MODER5
    orr   r1, r1, #(0b01 << (LD2_PIN * 2)) @ PA5 como salida
    str   r1, [r0]  
    bx    lr

// --- Inicialización de Botón GPIOC PC13 como entrada -------------------------
init_buton:
    movw  r0, #:lower16:RCC_AHB2ENR
    movt  r0, #:upper16:RCC_AHB2ENR
    ldr   r1, [r0]
    orr   r1, r1, #(1 << 2)                @ Habilita reloj GPIOC (bit 2)
    str   r1, [r0]

    movw  r0, #:lower16:GPIOC_MODER
    movt  r0, #:upper16:GPIOC_MODER
    ldr   r1, [r0]
    bic   r1, r1, #(0b11 << (B1_PIN * 2))  @ Configura PC13 como entrada (00)
    str   r1, [r0]
    bx    lr

// --- Inicialización de Systick para 3 s --------------------------------------
init_systick:
    movw  r0, #:lower16:SYST_RVR
    movt  r0, #:upper16:SYST_RVR
    movw  r1, #0xE0C0           @ 12000000 & 0xFFFF = 0xE0C0
    movt  r1, #0x000B           @ 12000000 >> 16 = 0x000B
    subs  r1, r1, #1            @ reload = 12,000,000 - 1
    str   r1, [r0]

    movw  r0, #:lower16:SYST_CSR
    movt  r0, #:upper16:SYST_CSR
    movs  r1, #(1 << 0)|(1 << 1)|(1 << 2)  @ ENABLE=1, TICKINT=1, CLKSOURCE=1
    str   r1, [r0]
    bx    lr

// --- Manejador de la interrupción SysTick ------------------------------------
    .thumb_func
SysTick_Handler:
    // Apagar LED
    movw  r0, #:lower16:GPIOA_ODR
    movt  r0, #:upper16:GPIOA_ODR
    ldr   r1, [r0]
    bic   r1, r1, #(1 << LD2_PIN)  // Apagar LED
    str   r1, [r0]

    // Limpiar flag
    ldr   r2, =led_on_flag
    movs  r3, #0
    str   r3, [r2]

    // Deshabilitar SysTick
    movw  r0, #:lower16:SYST_CSR
    movt  r0, #:upper16:SYST_CSR
    movs  r1, #0
    str   r1, [r0]

    bx    lr
